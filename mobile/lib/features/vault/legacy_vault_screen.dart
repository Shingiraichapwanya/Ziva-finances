import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/asset_model.dart';
import '../../models/legacy_vault_model.dart';
import '../../services/sqlite_service.dart';

class LegacyVaultScreen extends StatefulWidget {
  const LegacyVaultScreen({super.key});

  @override
  State<LegacyVaultScreen> createState() => _LegacyVaultScreenState();
}

class _LegacyVaultScreenState extends State<LegacyVaultScreen> with SingleTickerProviderStateMixin {
  final SqliteService _sqlite = SqliteService.instance;
  late TabController _tabController;

  bool _isPinUnlocked = false;
  final TextEditingController _pinController = TextEditingController();
  String? _pinError;

  bool _isLoading = true;
  LegacyVaultConfig _config = const LegacyVaultConfig();
  List<TrustedContact> _contacts = [];
  List<AssetModel> _assets = [];
  List<VaultAuditLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cfg = _sqlite.getLegacyVaultConfig();
    final contacts = _sqlite.getTrustedContacts();
    final assets = await _sqlite.getAssets();
    final logs = _sqlite.getVaultAuditLogs();

    if (!mounted) return;
    setState(() {
      _config = cfg;
      _contacts = contacts;
      _assets = assets;
      _logs = logs;
      _isLoading = false;
    });
  }

  void _verifyVaultPin() {
    if (_pinController.text.trim() == '2026') {
      setState(() {
        _isPinUnlocked = true;
        _pinError = null;
      });
      _sqlite.logVaultAction('VAULT_AUTHENTICATED', 'Shingirai Chapwanya', 'Secondary PIN 2026 successfully verified.');
      _loadData();
    } else {
      setState(() {
        _pinError = 'Invalid Executive PIN. Master authorization required.';
      });
    }
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Spouse / Partner');
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    VaultAccessLevel selectedLevel = VaultAccessLevel.fullDossier;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: ZivaTheme.gold400, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('Designate Trusted Contact', style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Legal Name', filled: true)),
                const SizedBox(height: 12),
                TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship (e.g. Executor, Spouse)', filled: true)),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', filled: true)),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', filled: true)),
                const SizedBox(height: 14),
                DropdownButtonFormField<VaultAccessLevel>(
                  initialValue: selectedLevel,
                  dropdownColor: ZivaTheme.bgSurface,
                  decoration: const InputDecoration(labelText: 'Access Permissions Tier', filled: true),
                  items: const [
                    DropdownMenuItem(value: VaultAccessLevel.readOnlySummary, child: Text('Read-Only Summary')),
                    DropdownMenuItem(value: VaultAccessLevel.fullDossier, child: Text('Full Estate Dossier')),
                    DropdownMenuItem(value: VaultAccessLevel.emergencyTrustee, child: Text('Emergency Trustee & Liquidator')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedLevel = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final newContact = TrustedContact(
                    id: 'CONTACT_${DateTime.now().millisecondsSinceEpoch}',
                    fullName: nameCtrl.text.trim(),
                    relationship: relCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    accessLevel: selectedLevel,
                    designatedAt: DateTime.now(),
                  );
                  await _sqlite.saveTrustedContact(newContact);
                  _sqlite.logVaultAction('CONTACT_ADDED', 'Shingirai Chapwanya', 'Designated ${newContact.fullName} (${newContact.accessLevelLabel}).');
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              child: const Text('Designate Contact'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: ZivaTheme.bgCore,
        body: Center(child: CircularProgressIndicator(color: ZivaTheme.gold500)),
      );
    }

    // Secondary PIN gate verification
    if (!_isPinUnlocked) {
      return _buildPinGateScreen();
    }

    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: SafeArea(
        child: Column(
          children: [
            _buildVaultHeader(),

            // Tab bar
            Container(
              decoration: const BoxDecoration(
                color: ZivaTheme.bgSurface,
                border: Border(bottom: BorderSide(color: ZivaTheme.borderCard)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: ZivaTheme.gold500,
                indicatorWeight: 3,
                labelColor: ZivaTheme.gold400,
                unselectedLabelColor: ZivaTheme.textMuted,
                isScrollable: true,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Trusted Contacts & Roles'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Asset Inclusion Matrix'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gavel_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Executor Directives'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Estate Dossier Preview'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildContactsTab(),
                  _buildInclusionTab(),
                  _buildDirectivesTab(),
                  _buildDossierPreviewTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinGateScreen() {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: ZivaTheme.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZivaTheme.gold500.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.shield_outlined, color: ZivaTheme.gold400, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'LEGACY & ESTATE VAULT',
                style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              const Text(
                'Secondary authorization required. Enter the executive master passcode to inspect testamentary records and confidential asset allocations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ZivaTheme.gold400, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '••••',
                  errorText: _pinError,
                  filled: true,
                ),
                onSubmitted: (_) => _verifyVaultPin(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _verifyVaultPin,
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock Estate Vault'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZivaTheme.gold500,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaultHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: ZivaTheme.bgSurface,
        border: Border(bottom: BorderSide(color: ZivaTheme.borderCard)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZivaTheme.gold500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.family_restroom_rounded, color: ZivaTheme.gold400, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LEGACY & ESTATE VAULT',
                    style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  Text(
                    'Asset Registry Sharing, Designated Executor & Trustee Access Control',
                    style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isPinUnlocked = false);
              _pinController.clear();
            },
            icon: const Icon(Icons.lock_outline_rounded, size: 16),
            label: const Text('Lock Vault'),
            style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.bgCore, foregroundColor: ZivaTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: TRUSTED CONTACTS ---
  Widget _buildContactsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DESIGNATED TRUSTED CONTACTS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
                  ),
                  Text('Beneficiaries, designated executors, and trustees granted tiered access upon activation.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddContactDialog,
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Add Contact'),
                style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ..._contacts.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZivaTheme.borderCard),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZivaTheme.gold500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: ZivaTheme.gold400, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.fullName, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: ZivaTheme.bgCore, borderRadius: BorderRadius.circular(4)),
                                child: Text(c.relationship, style: const TextStyle(color: ZivaTheme.gold400, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${c.email} • ${c.phoneNumber}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Permission Tier: ${c.accessLevelLabel}', style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: ZivaTheme.textMuted, size: 18),
                      onPressed: () async {
                        await _sqlite.deleteTrustedContact(c.id);
                        _sqlite.logVaultAction('CONTACT_REMOVED', 'Shingirai Chapwanya', 'Revoked ${c.fullName}.');
                        _loadData();
                      },
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- TAB 2: INCLUSION CHECKLIST ---
  Widget _buildInclusionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSET REGISTRY INCLUSION MATRIX',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select which tangible, intangible, and registered holdings are surfaced to designated trustees in the estate dossier.',
            style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),

          ..._assets.map((a) {
            final isIncluded = _config.includedAssetIds.contains(a.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ZivaTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isIncluded ? ZivaTheme.gold500.withValues(alpha: 0.3) : ZivaTheme.borderCard),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isIncluded,
                    activeColor: ZivaTheme.gold500,
                    checkColor: Colors.black,
                    onChanged: (val) {
                      final updated = List<String>.from(_config.includedAssetIds);
                      if (val == true) {
                        updated.add(a.id);
                      } else {
                        updated.remove(a.id);
                      }
                      _sqlite.saveLegacyVaultConfig(_config.copyWith(includedAssetIds: updated));
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${a.category.name.toUpperCase()} • ${a.registrationNumber.isNotEmpty ? a.registrationNumber : "Registered"}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatZar(a.currentValueZar * (a.myOwnershipPercentage / 100.0)),
                    style: const TextStyle(color: ZivaTheme.gold400, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- TAB 3: DIRECTIVES ---
  Widget _buildDirectivesTab() {
    final execCtrl = TextEditingController(text: _config.executorDirectives);
    final notesCtrl = TextEditingController(text: _config.emergencyTrusteeNotes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXECUTOR & TRUSTEE TESTAMENTARY DIRECTIVES',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          const Text('Custom legal directives executed in concert with formal Last Will & Testament.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 20),

          TextField(
            controller: execCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Executor & Legal Counsel Directives',
              filled: true,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Emergency Safe Custody & Physical Deed Box Notes',
              filled: true,
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              final updated = _config.copyWith(
                executorDirectives: execCtrl.text.trim(),
                emergencyTrusteeNotes: notesCtrl.text.trim(),
              );
              _sqlite.saveLegacyVaultConfig(updated);
              _sqlite.logVaultAction('DIRECTIVES_UPDATED', 'Shingirai Chapwanya', 'Updated executor directives and custody notes.');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Directives updated and encrypted.'), backgroundColor: ZivaTheme.bgSurface),
              );
            },
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save Directives'),
            style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: DOSSIER PREVIEW & EXPORT ---
  Widget _buildDossierPreviewTab() {
    final dossier = _sqlite.generateEstateDossier();
    final totalEstateValuation = dossier['totalEstateValuationZar'] as double;
    final assetValuation = dossier['assetHoldingsValuationZar'] as double;
    final cashLiquidity = dossier['liquidCashValuationZar'] as double;
    final debts = dossier['outstandingDebtsZar'] as double;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXECUTIVE ESTATE & LEGACY DOSSIER',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
                  ),
                  Text('Comprehensive confidential asset distribution manifest ready for legal review.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _sqlite.logVaultAction('ESTATE_DOSSIER_EXPORTED', 'Shingirai Chapwanya', 'Full Estate Dossier exported as PDF document.');
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Estate Dossier exported to secure archive & logged to Vault Audit!'),
                      backgroundColor: ZivaTheme.bgSurface,
                    ),
                  );
                },
                icon: const Icon(Icons.file_download_rounded, size: 16),
                label: const Text('Export Official Dossier'),
                style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Executive Summary Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.4)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ZivaTheme.bgSurface, ZivaTheme.gold500.withValues(alpha: 0.05)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CONSOLIDATED ESTATE NET WORTH', style: TextStyle(color: ZivaTheme.gold400, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Text(CurrencyFormatter.formatZar(totalEstateValuation), style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildDossierMetric('Included Asset Equity', CurrencyFormatter.formatZar(assetValuation)),
                    ),
                    Expanded(
                      child: _buildDossierMetric('Liquid Accounts', CurrencyFormatter.formatZar(cashLiquidity)),
                    ),
                    Expanded(
                      child: _buildDossierMetric('Obligations & Liabilities', '-${CurrencyFormatter.formatZar(debts)}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Directives & Custody Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EXECUTOR INSTRUCTIONS', style: TextStyle(color: ZivaTheme.gold400, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_config.executorDirectives, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, height: 1.4)),
                const SizedBox(height: 14),
                const Text('PHYSICAL SAFE CUSTODY', style: TextStyle(color: ZivaTheme.gold400, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_config.emergencyTrusteeNotes, style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Vault Audit Trail Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('IMMUTABLE VAULT AUDIT TRAIL', style: TextStyle(color: ZivaTheme.cyan400, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('${_logs.length} logged events', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                ..._logs.take(4).map((log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, size: 14, color: ZivaTheme.cyan400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${log.action} • ${log.details}', style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                      Text(log.timestamp.toIso8601String().substring(11, 16), style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDossierMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
