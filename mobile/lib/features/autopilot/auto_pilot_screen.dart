import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/confidence_rule_model.dart';
import '../../models/deposit_slip_model.dart';
import '../../models/email_transaction_proposal.dart';
import '../../models/reconciliation_model.dart';
import '../../services/sqlite_service.dart';

class AutoPilotScreen extends StatefulWidget {
  const AutoPilotScreen({super.key});

  @override
  State<AutoPilotScreen> createState() => _AutoPilotScreenState();
}

class _AutoPilotScreenState extends State<AutoPilotScreen> with SingleTickerProviderStateMixin {
  final SqliteService _sqlite = SqliteService.instance;
  late TabController _tabController;

  bool _isLoading = true;
  bool _isScanning = false;
  bool _isSyncing = false;

  List<EmailTransactionProposal> _emailProposals = [];
  GoogleWorkspaceConnection _workspaceConn = const GoogleWorkspaceConnection();
  List<DepositSlipModel> _depositSlips = [];
  List<ReconciliationMatch> _reconciliationMatches = [];
  ConfidenceEngineConfig _confidenceConfig = const ConfidenceEngineConfig();
  List<AutoAddAuditRecord> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() => _isLoading = true);
    final proposals = _sqlite.getEmailProposals();
    final conn = _sqlite.getWorkspaceConnection();
    final slips = _sqlite.getDepositSlips();
    final matches = _sqlite.getReconciliationMatches();
    final conf = _sqlite.getConfidenceConfig();
    final audits = _sqlite.getAutoAddAuditLogs();

    setState(() {
      _emailProposals = proposals;
      _workspaceConn = conn;
      _depositSlips = slips;
      _reconciliationMatches = matches;
      _confidenceConfig = conf;
      _auditLogs = audits;
      _isLoading = false;
    });
  }

  Future<void> _scanEmails() async {
    setState(() => _isScanning = true);
    final count = await _sqlite.scanGoogleWorkspaceEmails();
    _loadData();
    if (!mounted) return;
    setState(() => _isScanning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: ZivaTheme.gold400, size: 18),
            const SizedBox(width: 8),
            Text('Google Workspace scan complete. Parsed $count financial documents.'),
          ],
        ),
        backgroundColor: ZivaTheme.bgSurface,
      ),
    );
  }

  Future<void> _keepProposal(String id) async {
    await _sqlite.keepEmailProposal(id);
    _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Proposal converted to live ledger transaction & queued for BigQuery sync!'),
        backgroundColor: ZivaTheme.bgSurface,
      ),
    );
  }

  Future<void> _removeProposal(String id, {bool ignorePattern = false}) async {
    await _sqlite.removeEmailProposal(id, ignorePattern: ignorePattern);
    _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ignorePattern ? 'Proposal removed & sender marked to ignore in future.' : 'Proposal discarded.'),
        backgroundColor: ZivaTheme.bgSurface,
      ),
    );
  }

  Future<void> _syncBankBalances() async {
    setState(() => _isSyncing = true);
    await _sqlite.syncBankBalances();
    _loadData();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.sync_rounded, color: ZivaTheme.emerald400, size: 18),
            SizedBox(width: 8),
            Text('Bank accounts synced via OpenBanking APIs & statement reconciliation executed!'),
          ],
        ),
        backgroundColor: ZivaTheme.bgSurface,
      ),
    );
  }

  void _showAddDepositSlipDialog() {
    final amountCtrl = TextEditingController(text: '75000.00');
    final refCtrl = TextEditingController(text: 'DEP-SANDTON-CASH');
    String selectedBank = 'Standard Bank Private';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: ZivaTheme.gold400, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('Upload Deposit Slip (OCR)', style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select bank format and upload photo or document:', style: TextStyle(color: ZivaTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedBank,
                  dropdownColor: ZivaTheme.bgSurface,
                  decoration: const InputDecoration(labelText: 'Issuing Bank & Slip Format', filled: true),
                  items: const [
                    DropdownMenuItem(value: 'Standard Bank Private', child: Text('Standard Bank Private')),
                    DropdownMenuItem(value: 'First National Bank', child: Text('First National Bank (FNB)')),
                    DropdownMenuItem(value: 'Nedbank Private Wealth', child: Text('Nedbank Private Wealth')),
                    DropdownMenuItem(value: 'Ecobank / FBC', child: Text('Ecobank / FBC Offshore USD')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedBank = val);
                  },
                ),
                const SizedBox(height: 14),
                // Simulated Slip Photo Preview / Upload Area
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3), style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, color: ZivaTheme.gold400, size: 32),
                      SizedBox(height: 6),
                      Text('Deposit Slip Image Attached', style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('slip_teller_camera_capture.jpg (High Resolution)', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Deposit Amount (ZAR)', filled: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Reference / Stamp ID', filled: true),
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
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 75000.0;
                await _sqlite.processDepositSlipOcr(
                  bankName: selectedBank,
                  manualAmount: amt,
                  reference: refCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deposit slip uploaded! OCR extracted figures and mapped account.'),
                      backgroundColor: ZivaTheme.bgSurface,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              child: const Text('Run OCR Pipeline'),
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

    final reconSummary = _sqlite.getReconciliationSummary();

    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: SafeArea(
        child: Column(
          children: [
            // Top Executive Auto Pilot Header
            _buildExecutiveHeader(reconSummary),

            // Tab Navigation Bar
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
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined, size: 16),
                        const SizedBox(width: 8),
                        Text('Email Ingestion (${_emailProposals.where((p) => p.status == ProposalStatus.pending).length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.document_scanner_outlined, size: 16),
                        const SizedBox(width: 8),
                        Text('Deposit Slips OCR (${_depositSlips.where((s) => s.status == DepositSlipStatus.readyForReview).length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.compare_arrows_rounded, size: 16),
                        const SizedBox(width: 8),
                        Text('Reconciliation (${reconSummary.exceptionsCount} Exceptions)'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_alt_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Bank Sync (APIs)'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rule_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Confidence & Auto-Add'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmailQueueTab(),
                  _buildDepositSlipsTab(),
                  _buildReconciliationTab(reconSummary),
                  _buildBankSyncTab(),
                  _buildConfidenceRulesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader(ReconciliationSummary reconSummary) {
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
                child: const Icon(Icons.auto_mode_rounded, color: ZivaTheme.gold400, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTO PILOT INTELLIGENCE',
                    style: TextStyle(
                      color: ZivaTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Autonomous Google Workspace Ingestion, Deposit OCR & Bank Statement Reconciliation',
                    style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Google Workspace Connected Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ZivaTheme.emerald500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ZivaTheme.emerald500.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_done_rounded, color: ZivaTheme.emerald400, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _workspaceConn.isConnected ? 'Gmail Synced' : 'Offline',
                      style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanEmails,
                icon: _isScanning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_isScanning ? 'Scanning...' : 'Pull Workspace Emails'),
                style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SUB-TAB 1: EMAIL INGESTION QUEUE ---
  Widget _buildEmailQueueTab() {
    final pending = _emailProposals.where((p) => p.status == ProposalStatus.pending).toList();
    final processed = _emailProposals.where((p) => p.status != ProposalStatus.pending).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: ZivaTheme.gold400, size: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zero Silent Commitments Protocol', style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text(
                        'Items scoring ≥95% confidence are auto-added to the ledger. Medium (70-95%) and Low (<70%) confidence proposals require your explicit "Keep" authorization.',
                        style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'PENDING EMAIL PROPOSALS (${pending.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),

          if (pending.isEmpty)
            _buildEmptyState('No pending proposals. All email documents have been reviewed or auto-committed.')
          else
            ...pending.map((p) => _buildEmailProposalCard(p)),

          const SizedBox(height: 32),
          Text(
            'HISTORICAL PROCESSED ITEMS (${processed.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          ...processed.map((p) => _buildEmailProposalCard(p, isHistorical: true)),
        ],
      ),
    );
  }

  Widget _buildEmailProposalCard(EmailTransactionProposal p, {bool isHistorical = false}) {
    Color confColor = ZivaTheme.rose400;
    if (p.isHighConfidence) {
      confColor = ZivaTheme.emerald400;
    } else if (p.isMediumConfidence) {
      confColor = ZivaTheme.gold400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.isHighConfidence ? ZivaTheme.gold500.withValues(alpha: 0.3) : ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: confColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: confColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${p.formattedConfidence} Confidence',
                      style: TextStyle(color: confColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ZivaTheme.bgCore,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ZivaTheme.borderCard),
                    ),
                    child: Text(
                      p.documentType.name.toUpperCase(),
                      style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Text(
                '${p.isCredit ? '+' : '-'}${CurrencyFormatter.formatZar(p.extractedAmount)}',
                style: TextStyle(
                  color: p.isCredit ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.counterparty, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(p.emailSubject, style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ZivaTheme.bgCore, borderRadius: BorderRadius.circular(8)),
            child: Text(p.rawSnippet, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_outlined, color: ZivaTheme.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Text(p.accountIdentifier, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                  const SizedBox(width: 12),
                  const Icon(Icons.tag_rounded, color: ZivaTheme.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Text(p.referenceNumber, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                ],
              ),
              if (!isHistorical)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _removeProposal(p.id),
                      icon: const Icon(Icons.close_rounded, color: ZivaTheme.rose400, size: 16),
                      label: const Text('Remove', style: TextStyle(color: ZivaTheme.rose400, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _removeProposal(p.id, ignorePattern: true),
                      icon: const Icon(Icons.block_rounded, color: ZivaTheme.textMuted, size: 16),
                      label: const Text('Ignore Pattern', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _keepProposal(p.id),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Keep (Add to Ledger)'),
                      style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.status == ProposalStatus.autoAdded ? ZivaTheme.emerald500.withValues(alpha: 0.15) : ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.status == ProposalStatus.autoAdded ? 'Auto-Added (High Confidence)' : p.status.name.toUpperCase(),
                    style: TextStyle(
                      color: p.status == ProposalStatus.autoAdded ? ZivaTheme.emerald400 : ZivaTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SUB-TAB 2: DEPOSIT SLIPS OCR PIPELINE ---
  Widget _buildDepositSlipsTab() {
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
                    'HANDWRITTEN BANK DEPOSIT SLIPS (OCR QUEUE)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
                  ),
                  Text('Capture physical bank teller deposit slips with multi-field handwriting extraction.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddDepositSlipDialog,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Upload Deposit Slip'),
                style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_depositSlips.isEmpty)
            _buildEmptyState('No deposit slips uploaded. Click "Upload Deposit Slip" to scan a handwritten teller slip.')
          else
            ..._depositSlips.map((s) => _buildDepositSlipCard(s)),
        ],
      ),
    );
  }

  Widget _buildDepositSlipCard(DepositSlipModel slip) {
    final amountCtrl = TextEditingController(text: slip.effectiveAmount.toStringAsFixed(2));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
              Row(
                children: [
                  const Icon(Icons.receipt_rounded, color: ZivaTheme.gold400, size: 20),
                  const SizedBox(width: 8),
                  Text(slip.bankName, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ZivaTheme.bgCore, borderRadius: BorderRadius.circular(4)),
                    child: Text(slip.status.name.toUpperCase(), style: const TextStyle(color: ZivaTheme.gold400, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(
                CurrencyFormatter.formatZar(slip.effectiveAmount),
                style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Extracted Fields Grid
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ZivaTheme.bgCore, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EXTRACTED ACCOUNT', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(slip.extractedAccountNumber ?? 'Not detected', style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${(slip.accountConfidence * 100).toStringAsFixed(0)}% confidence', style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 10)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EXTRACTED BRANCH', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(slip.extractedBranch ?? 'Main Branch', style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${(slip.branchConfidence * 100).toStringAsFixed(0)}% confidence', style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 10)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INTERNAL MAPPED ACCOUNT', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(slip.matchedAccountName ?? 'Unassigned', style: const TextStyle(color: ZivaTheme.gold400, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Match Type: ${slip.matchType.name.toUpperCase()}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Inline Correction & Action Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall OCR Confidence: ${slip.formattedOverallConfidence}',
                style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 12),
              ),
              if (slip.status == DepositSlipStatus.readyForReview)
                Row(
                  children: [
                    SizedBox(
                      width: 140,
                      height: 36,
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(labelText: 'Adjust Amount', isDense: true),
                        onSubmitted: (val) {
                          final newAmt = double.tryParse(val);
                          if (newAmt != null) {
                            _sqlite.updateDepositSlipCorrection(slip.id, correctedAmount: newAmt);
                            _loadData();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final newAmt = double.tryParse(amountCtrl.text.trim());
                        if (newAmt != null) {
                          _sqlite.updateDepositSlipCorrection(slip.id, correctedAmount: newAmt);
                        }
                        await _sqlite.approvePendingDeposit(slip.id);
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Deposit approved and posted to live ledger!'),
                              backgroundColor: ZivaTheme.bgSurface,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('Approve Pending Deposit'),
                      style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: ZivaTheme.emerald500.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Approved & Reconciled', style: TextStyle(color: ZivaTheme.emerald400, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SUB-TAB 3: RECONCILIATION ENGINE ---
  Widget _buildReconciliationTab(ReconciliationSummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Metric Telemetry Cards
          Row(
            children: [
              Expanded(
                child: _buildReconKpiCard(
                  title: 'RECONCILED TRANSACTIONS',
                  value: '${summary.reconciledCount}',
                  subtitle: CurrencyFormatter.formatZar(summary.reconciledTotalZar),
                  color: ZivaTheme.emerald400,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildReconKpiCard(
                  title: 'EXCEPTIONS NEEDING REVIEW',
                  value: '${summary.exceptionsCount}',
                  subtitle: CurrencyFormatter.formatZar(summary.unreconciledTotalZar),
                  color: ZivaTheme.rose400,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildReconKpiCard(
                  title: 'RECONCILIATION RATE',
                  value: '${summary.reconciliationRatePercent.toStringAsFixed(1)}%',
                  subtitle: 'Overall Portfolio Target: 100%',
                  color: ZivaTheme.gold400,
                  icon: Icons.pie_chart_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Matches & Exceptions Table Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RECONCILIATION MATRIX (STATEMENT VS INTERNAL LEDGER)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _sqlite.runReconciliationEngine();
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reconciliation cycle completed!'),
                        backgroundColor: ZivaTheme.bgSurface,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.autorenew_rounded, size: 16),
                label: const Text('Re-Run Matcher'),
                style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.bgSurface, foregroundColor: ZivaTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ..._reconciliationMatches.map((m) => _buildReconciliationRow(m)),
        ],
      ),
    );
  }

  Widget _buildReconKpiCard({required String title, required String value, required String subtitle, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Text(title, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildReconciliationRow(ReconciliationMatch m) {
    final isClean = m.status == ReconciliationMatchStatus.reconciled;
    final color = isClean ? ZivaTheme.emerald400 : (m.status == ReconciliationMatchStatus.needsReview ? ZivaTheme.gold400 : ZivaTheme.rose400);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(isClean ? Icons.check_rounded : Icons.priority_high_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.statementTransaction.counterparty, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Bank Ref: ${m.statementTransaction.reference} • ${m.statementTransaction.accountName}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                Text(m.reconciliationNotes, style: TextStyle(color: color, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${m.statementTransaction.isCredit ? '+' : '-'}${CurrencyFormatter.formatZar(m.statementTransaction.amountZar)}',
                  style: TextStyle(color: m.statementTransaction.isCredit ? ZivaTheme.emerald400 : ZivaTheme.rose400, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                Text(m.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (!isClean)
            ElevatedButton(
              onPressed: () async {
                await _sqlite.resolveReconciliationMismatch(m.id, action: 'confirmAsMissing');
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Missing statement transaction generated and reconciled!'),
                      backgroundColor: ZivaTheme.bgSurface,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              child: const Text('Resolve'),
            ),
        ],
      ),
    );
  }

  // --- SUB-TAB 4: BANK SYNC (APIS) ---
  Widget _buildBankSyncTab() {
    final conns = _sqlite.getBankConnections();

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
                    'REAL-TIME BANKING FEEDS & API SYNCHRONIZATION',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
                  ),
                  Text('Direct Open Banking OAuth pipes pulling live balances and feed entries into the command center.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncBankBalances,
                icon: _isSyncing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync All Bank Feeds'),
                style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ...conns.map((c) => Container(
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
                      decoration: BoxDecoration(color: ZivaTheme.gold500.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_rounded, color: ZivaTheme.gold400, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.institutionName, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${c.accountType} (${c.accountNumberMasked}) • Provider: ${c.provider}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Last synchronized: ${c.syncAgeDescription}', style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatZar(c.currentBalanceZar),
                          style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        if (c.nativeCurrency != 'ZAR')
                          Text('${c.nativeCurrency} ${c.nativeBalance.toStringAsFixed(2)}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- SUB-TAB 5: CONFIDENCE RULES & AUDIT LOG ---
  Widget _buildConfidenceRulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Threshold Sliders Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONFIDENCE-BASED FILTER & AUTO-ADD THRESHOLDS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
                    ),
                    Switch(
                      value: _confidenceConfig.autoAddEnabled,
                      activeThumbColor: ZivaTheme.gold500,
                      onChanged: (val) {
                        final updated = _confidenceConfig.copyWith(autoAddEnabled: val);
                        _sqlite.saveConfidenceConfig(updated);
                        _loadData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'High Confidence Auto-Commit Threshold: ${_confidenceConfig.highConfidenceThresholdPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _confidenceConfig.highConfidenceThresholdPercent,
                  min: 80.0,
                  max: 99.0,
                  divisions: 19,
                  activeColor: ZivaTheme.gold500,
                  onChanged: (val) {
                    final updated = _confidenceConfig.copyWith(highConfidenceThresholdPercent: val);
                    _sqlite.saveConfidenceConfig(updated);
                    _loadData();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Medium Confidence Review Queue Floor: ${_confidenceConfig.mediumConfidenceThresholdPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _confidenceConfig.mediumConfidenceThresholdPercent,
                  min: 50.0,
                  max: 85.0,
                  divisions: 35,
                  activeColor: ZivaTheme.cyan400,
                  onChanged: (val) {
                    final updated = _confidenceConfig.copyWith(mediumConfidenceThresholdPercent: val);
                    _sqlite.saveConfidenceConfig(updated);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Tamper-Evident Auto-Add Audit Log
          const Text(
            'AUTO-ADD AUDIT LOG (TAMPER-EVIDENT TRAIL)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),

          if (_auditLogs.isEmpty)
            _buildEmptyState('No auto-added transactions recorded yet.')
          else
            ..._auditLogs.map((log) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.security_rounded, color: ZivaTheme.emerald400, size: 16),
                              const SizedBox(width: 8),
                              Text(log.counterparty, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('(${log.formattedConfidence} Confidence)', style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 11)),
                            ],
                          ),
                          Text(CurrencyFormatter.formatZar(log.amountZar), style: const TextStyle(color: ZivaTheme.emerald400, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(log.decisionReason, style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('Source: ${log.sourceType} • Txn ID: ${log.createdTransactionId}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ZivaTheme.bgSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: ZivaTheme.borderCard)),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: ZivaTheme.textMuted),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
