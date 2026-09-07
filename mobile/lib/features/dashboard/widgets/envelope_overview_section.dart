import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/envelope_model.dart';
import '../../../services/sqlite_service.dart';

/// EnvelopeOverviewSection - Visual Zero-Based Allocation Bar & Envelope Budget Cards
class EnvelopeOverviewSection extends StatefulWidget {
  final List<EnvelopeModel> envelopes;
  final String selectedCurrency;
  final VoidCallback onEnvelopesUpdated;

  const EnvelopeOverviewSection({
    super.key,
    required this.envelopes,
    this.selectedCurrency = 'ZAR',
    required this.onEnvelopesUpdated,
  });

  @override
  State<EnvelopeOverviewSection> createState() => _EnvelopeOverviewSectionState();
}

class _EnvelopeOverviewSectionState extends State<EnvelopeOverviewSection> {
  String _activeFilter = 'ALL';

  Color _getGroupColor(String group) {
    switch (group.toUpperCase()) {
      case 'ESSENTIALS':
      case 'LIVING_EXPENSES':
        return ZivaTheme.gold400;
      case 'DISCRETIONARY':
        return const Color(0xFF0284C7); // Sky / Blue
      case 'SINKING_FUNDS':
      case 'VAULT_INVESTMENTS':
        return ZivaTheme.emerald400;
      case 'DEBT_OBLIGATIONS':
        return ZivaTheme.rose400;
      default:
        return ZivaTheme.textMuted;
    }
  }

  String _formatGroupLabel(String group) {
    switch (group.toUpperCase()) {
      case 'ESSENTIALS':
        return 'Essentials';
      case 'LIVING_EXPENSES':
        return 'Living Expenses';
      case 'DISCRETIONARY':
        return 'Discretionary';
      case 'SINKING_FUNDS':
        return 'Sinking Funds';
      case 'DEBT_OBLIGATIONS':
        return 'Debt Obligations';
      case 'VAULT_INVESTMENTS':
        return 'Vault / Wealth';
      default:
        return group;
    }
  }

  double get _totalPlannedZar => widget.envelopes.fold(0.0, (s, e) => s + e.plannedAmountZar);
  double get _totalSpentZar => widget.envelopes.fold(0.0, (s, e) => s + e.actualSpentZar);
  double get _totalRemainingZar => (_totalPlannedZar - _totalSpentZar).clamp(0.0, double.infinity);

  List<EnvelopeModel> get _filteredEnvelopes {
    if (_activeFilter == 'ALL') return widget.envelopes;
    return widget.envelopes.where((e) => e.categoryGroup.toUpperCase() == _activeFilter).toList();
  }

  Map<String, double> get _groupAllocations {
    final map = <String, double>{};
    for (final e in widget.envelopes) {
      final grp = e.categoryGroup.toUpperCase();
      map[grp] = (map[grp] ?? 0.0) + e.plannedAmountZar;
    }
    return map;
  }

  void _showCreateEnvelopeDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String group = 'ESSENTIALS';
    String tier = 'MONTHLY_ALLOCATION';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ZivaTheme.borderCard),
          ),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: ZivaTheme.gold400),
              SizedBox(width: 10),
              Text('Create New Envelope', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Envelope Name', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Health & Wellness',
                    hintStyle: const TextStyle(color: ZivaTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Category Grouping', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: group,
                  dropdownColor: ZivaTheme.bgCard,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ESSENTIALS', child: Text('Essentials (50% rule)')),
                    DropdownMenuItem(value: 'DISCRETIONARY', child: Text('Discretionary (30% rule)')),
                    DropdownMenuItem(value: 'SINKING_FUNDS', child: Text('Sinking Funds (20% rule)')),
                    DropdownMenuItem(value: 'DEBT_OBLIGATIONS', child: Text('Debt Obligations')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => group = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Planned Amount (ZAR)', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: 'R ',
                    prefixStyle: const TextStyle(color: ZivaTheme.gold400, fontWeight: FontWeight.bold),
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: ZivaTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Notes / Obligation', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Optional notes...',
                    hintStyle: const TextStyle(color: ZivaTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (name.isEmpty || amount <= 0) return;

                final id = 'CAT_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}';
                final newEnv = EnvelopeModel(
                  categoryId: id,
                  categoryName: name,
                  categoryGroup: group,
                  cashFlowTier: tier,
                  plannedAmountZar: amount,
                  actualSpentZar: 0.0,
                  notes: notesController.text.trim(),
                );

                Navigator.of(ctx).pop();
                SqliteService.instance.saveEnvelope(newEnv).then((_) {
                  widget.onEnvelopesUpdated();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ZivaTheme.gold500,
                foregroundColor: Colors.black,
              ),
              child: const Text('Create Envelope', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveFundsDialog({EnvelopeModel? defaultSource}) {
    if (widget.envelopes.length < 2) return;

    EnvelopeModel fromEnv = defaultSource ?? widget.envelopes.first;
    EnvelopeModel toEnv = widget.envelopes.firstWhere((e) => e.categoryId != fromEnv.categoryId);
    final amountController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ZivaTheme.borderCard),
          ),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: ZivaTheme.gold400),
              SizedBox(width: 10),
              Text('Move Funds Between Envelopes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Source Envelope (Move From)', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: fromEnv.categoryId,
                  dropdownColor: ZivaTheme.bgCard,
                  isExpanded: true,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                  items: widget.envelopes.map((e) {
                    return DropdownMenuItem(
                      value: e.categoryId,
                      child: Text('${e.categoryName} (Bal: R ${e.currentBalanceZar.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        fromEnv = widget.envelopes.firstWhere((e) => e.categoryId == val);
                        if (toEnv.categoryId == fromEnv.categoryId) {
                          toEnv = widget.envelopes.firstWhere((e) => e.categoryId != fromEnv.categoryId);
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                const Text('Destination Envelope (Move To)', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: toEnv.categoryId,
                  dropdownColor: ZivaTheme.bgCard,
                  isExpanded: true,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                  items: widget.envelopes.where((e) => e.categoryId != fromEnv.categoryId).map((e) {
                    return DropdownMenuItem(
                      value: e.categoryId,
                      child: Text('${e.categoryName} (Bal: R ${e.currentBalanceZar.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        toEnv = widget.envelopes.firstWhere((e) => e.categoryId == val);
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transfer Amount (ZAR)', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('Available: R ${fromEnv.currentBalanceZar.toStringAsFixed(2)}', style: const TextStyle(color: ZivaTheme.gold400, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: 'R ',
                    prefixStyle: const TextStyle(color: ZivaTheme.gold400, fontWeight: FontWeight.bold),
                    hintText: '0.00',
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [500.0, 1000.0, 2500.0].map((quickAmt) {
                    return ActionChip(
                      label: Text('+R ${quickAmt.toInt()}', style: const TextStyle(fontSize: 11, color: ZivaTheme.textPrimary)),
                      backgroundColor: ZivaTheme.bgCard,
                      side: const BorderSide(color: ZivaTheme.borderCard),
                      onPressed: () {
                        amountController.text = quickAmt.toStringAsFixed(0);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                Navigator.of(ctx).pop();
                SqliteService.instance.transferFunds(
                  fromCategoryId: fromEnv.categoryId,
                  toCategoryId: toEnv.categoryId,
                  amount: amount,
                ).then((_) {
                  widget.onEnvelopesUpdated();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ZivaTheme.gold500,
                foregroundColor: Colors.black,
              ),
              child: const Text('Complete Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopUpDialog(EnvelopeModel env, {bool isReduce = false}) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZivaTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ZivaTheme.borderCard),
        ),
        title: Row(
          children: [
            Icon(isReduce ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded, color: isReduce ? ZivaTheme.rose400 : ZivaTheme.emerald400),
            const SizedBox(width: 10),
            Text(isReduce ? 'Reduce Envelope' : 'Top-Up Envelope', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${env.categoryName} • Planned: R ${env.plannedAmountZar.toStringAsFixed(2)}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'R ',
                prefixStyle: const TextStyle(color: ZivaTheme.gold400, fontWeight: FontWeight.bold),
                hintText: '0.00',
                filled: true,
                fillColor: ZivaTheme.bgCore,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim()) ?? 0.0;
              if (amount <= 0) return;

              Navigator.of(ctx).pop();
              final future = isReduce
                  ? SqliteService.instance.reduceEnvelope(env.categoryId, amount)
                  : SqliteService.instance.topUpEnvelope(env.categoryId, amount);
              future.then((_) {
                widget.onEnvelopesUpdated();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isReduce ? ZivaTheme.rose500 : ZivaTheme.emerald500,
              foregroundColor: Colors.white,
            ),
            child: Text(isReduce ? 'Reduce' : 'Top Up', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditEnvelopeDialog(EnvelopeModel env) {
    final nameController = TextEditingController(text: env.categoryName);
    final amountController = TextEditingController(text: env.plannedAmountZar.toStringAsFixed(0));
    final notesController = TextEditingController(text: env.notes);
    String group = env.categoryGroup;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ZivaTheme.borderCard),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_outlined, color: ZivaTheme.gold400),
              SizedBox(width: 10),
              Text('Edit Envelope', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Envelope Name', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Category Grouping', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: group,
                  dropdownColor: ZivaTheme.bgCard,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ESSENTIALS', child: Text('Essentials (50% rule)')),
                    DropdownMenuItem(value: 'DISCRETIONARY', child: Text('Discretionary (30% rule)')),
                    DropdownMenuItem(value: 'SINKING_FUNDS', child: Text('Sinking Funds (20% rule)')),
                    DropdownMenuItem(value: 'DEBT_OBLIGATIONS', child: Text('Debt Obligations')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => group = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Planned Allocation (ZAR)', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: 'R ',
                    prefixStyle: const TextStyle(color: ZivaTheme.gold400, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Notes', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ZivaTheme.bgCore,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? env.plannedAmountZar;
                if (name.isEmpty) return;

                final updated = env.copyWith(
                  categoryName: name,
                  categoryGroup: group,
                  plannedAmountZar: amount,
                  notes: notesController.text.trim(),
                );

                Navigator.of(ctx).pop();
                SqliteService.instance.saveEnvelope(updated).then((_) {
                  widget.onEnvelopesUpdated();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ZivaTheme.gold500,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmArchiveEnvelope(EnvelopeModel env) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZivaTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ZivaTheme.borderCard),
        ),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: ZivaTheme.rose400),
            SizedBox(width: 10),
            Text('Archive Envelope', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary)),
          ],
        ),
        content: Text('Are you sure you want to deactivate "${env.categoryName}"? Existing transactions will remain intact.',
            style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              SqliteService.instance.archiveEnvelope(env.categoryId).then((_) {
                widget.onEnvelopesUpdated();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.rose500, foregroundColor: Colors.white),
            child: const Text('Archive Envelope', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION HEADER & TOOLBAR
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 650;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: ZivaTheme.gold400, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ENVELOPE BUDGET OVERVIEW',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: ZivaTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Zero-Based Envelopes • Planned vs Live Balances',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ZivaTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showMoveFundsDialog(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZivaTheme.gold400,
                            side: const BorderSide(color: ZivaTheme.gold500),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                          label: const Text('Move Funds', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showCreateEnvelopeDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZivaTheme.gold500,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: const Text('New Envelope', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: ZivaTheme.gold400, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ENVELOPE BUDGET OVERVIEW & ALLOCATION',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: ZivaTheme.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero-Based Envelopes • Planned Capital Distribution & Live Balances',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ZivaTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showMoveFundsDialog(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZivaTheme.gold400,
                        side: const BorderSide(color: ZivaTheme.gold500),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Move Funds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateEnvelopeDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZivaTheme.gold500,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New Envelope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // SUMMARY METRICS (Responsive 2x2 on compact, 4-col on desktop)
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 650;
            if (isCompact) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZivaTheme.borderCard),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCell(
                          label: 'PLANNED',
                          value: CurrencyFormatter.formatAmount(_totalPlannedZar, currency: widget.selectedCurrency),
                          color: ZivaTheme.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCell(
                          label: 'SPENT',
                          value: CurrencyFormatter.formatAmount(_totalSpentZar, currency: widget.selectedCurrency),
                          color: _totalSpentZar > _totalPlannedZar ? ZivaTheme.rose400 : ZivaTheme.gold400,
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: ZivaTheme.borderCard),
                    Row(
                      children: [
                        _buildStatCell(
                          label: 'AVAILABLE',
                          value: CurrencyFormatter.formatAmount(_totalRemainingZar, currency: widget.selectedCurrency),
                          color: ZivaTheme.emerald400,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCell(
                          label: 'ENVELOPES',
                          value: '${widget.envelopes.length}',
                          color: ZivaTheme.textPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZivaTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZivaTheme.borderCard),
              ),
              child: Row(
                children: [
                  _buildStatCell(
                    label: 'TOTAL PLANNED ALLOCATION',
                    value: CurrencyFormatter.formatAmount(
                      _totalPlannedZar,
                      currency: widget.selectedCurrency,
                    ),
                    color: ZivaTheme.textPrimary,
                  ),
                  _buildStatDivider(),
                  _buildStatCell(
                    label: 'ACTUAL SPENT',
                    value: CurrencyFormatter.formatAmount(
                      _totalSpentZar,
                      currency: widget.selectedCurrency,
                    ),
                    color: _totalSpentZar > _totalPlannedZar ? ZivaTheme.rose400 : ZivaTheme.gold400,
                  ),
                  _buildStatDivider(),
                  _buildStatCell(
                    label: 'AVAILABLE TO SPEND',
                    value: CurrencyFormatter.formatAmount(
                      _totalRemainingZar,
                      currency: widget.selectedCurrency,
                    ),
                    color: ZivaTheme.emerald400,
                  ),
                  _buildStatDivider(),
                  _buildStatCell(
                    label: 'ACTIVE ENVELOPES',
                    value: '${widget.envelopes.length}',
                    color: ZivaTheme.textPrimary,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // VISUAL ALLOCATION BAR
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZivaTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZivaTheme.borderCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'PORTFOLIO ALLOCATION DISTRIBUTION',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: ZivaTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Target 50/30/20',
                    style: TextStyle(fontSize: 10, color: ZivaTheme.gold400, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Segmented Proportional Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 18,
                  child: Row(
                    children: _buildAllocationSegments(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Legend Badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _groupAllocations.entries.map((entry) {
                  final group = entry.key;
                  final amount = entry.value;
                  final pct = _totalPlannedZar > 0 ? (amount / _totalPlannedZar) * 100 : 0.0;
                  final color = _getGroupColor(group);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_formatGroupLabel(group)}: ${pct.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // FILTER CHIPS ROW
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All Envelopes (${widget.envelopes.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('ESSENTIALS', 'Essentials'),
              const SizedBox(width: 8),
              _buildFilterChip('DISCRETIONARY', 'Discretionary'),
              const SizedBox(width: 8),
              _buildFilterChip('SINKING_FUNDS', 'Sinking Funds'),
              const SizedBox(width: 8),
              _buildFilterChip('DEBT_OBLIGATIONS', 'Debt Obligations'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ENVELOPE CARDS GRID
        if (_filteredEnvelopes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: const Text('No active envelopes found in this group.', style: TextStyle(color: ZivaTheme.textMuted)),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1000 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 185,
                ),
                itemCount: _filteredEnvelopes.length,
                itemBuilder: (context, index) {
                  final env = _filteredEnvelopes[index];
                  return _buildEnvelopeCard(env);
                },
              );
            },
          ),
      ],
    );
  }

  List<Widget> _buildAllocationSegments() {
    if (_totalPlannedZar <= 0) {
      return [
        Expanded(
          child: Container(color: ZivaTheme.borderCard),
        )
      ];
    }

    return _groupAllocations.entries.map((entry) {
      final flex = (entry.value * 100).round();
      if (flex <= 0) return const SizedBox.shrink();

      return Expanded(
        flex: flex,
        child: Container(
          color: _getGroupColor(entry.key),
          margin: const EdgeInsets.symmetric(horizontal: 1),
        ),
      );
    }).toList();
  }

  Widget _buildEnvelopeCard(EnvelopeModel env) {
    final groupColor = _getGroupColor(env.categoryGroup);
    final pct = env.pctConsumed;
    final isOver = env.budgetStatus == 'OVER_BUDGET';
    final isNear = env.budgetStatus == 'NEAR_LIMIT';

    Color progressColor = ZivaTheme.emerald400;
    if (isOver) {
      progressColor = ZivaTheme.rose500;
    } else if (isNear) {
      progressColor = ZivaTheme.gold400;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOver ? ZivaTheme.rose500.withValues(alpha: 0.6) : ZivaTheme.borderCard,
          width: isOver ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Name, Group Badge, Options Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      env.categoryName,
                      style: const TextStyle(
                        color: ZivaTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: groupColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatGroupLabel(env.categoryGroup).toUpperCase(),
                        style: TextStyle(
                          color: groupColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: ZivaTheme.textMuted),
                color: ZivaTheme.bgCard,
                onSelected: (val) {
                  if (val == 'edit') _showEditEnvelopeDialog(env);
                  if (val == 'archive') _confirmArchiveEnvelope(env);
                  if (val == 'transfer') _showMoveFundsDialog(defaultSource: env);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'transfer', child: Row(children: [Icon(Icons.swap_horiz_rounded, size: 16, color: ZivaTheme.gold400), SizedBox(width: 8), Text('Move Funds')])),
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: ZivaTheme.textSecondary), SizedBox(width: 8), Text('Edit Envelope')])),
                  const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Icons.archive_outlined, size: 16, color: ZivaTheme.rose400), SizedBox(width: 8), Text('Archive')])),
                ],
              ),
            ],
          ),

          // Middle: Planned, Spent, Remaining
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BUDGET', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(
                    'R ${env.plannedAmountZar.toStringAsFixed(0)}',
                    style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('SPENT', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(
                    'R ${env.actualSpentZar.toStringAsFixed(0)}',
                    style: TextStyle(color: isOver ? ZivaTheme.rose400 : ZivaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('AVAILABLE', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(
                    'R ${env.currentBalanceZar.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isOver ? ZivaTheme.rose400 : ZivaTheme.emerald400,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Progress Bar with Status Label
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOver ? 'OVER BUDGET' : (isNear ? 'NEAR LIMIT' : 'ON TRACK'),
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(color: progressColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100.0).clamp(0.0, 1.0),
                  backgroundColor: ZivaTheme.bgCore,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 5,
                ),
              ),
            ],
          ),

          // Quick Action Footer: Top-Up & Reduce
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _showTopUpDialog(env, isReduce: true),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.remove, size: 12, color: ZivaTheme.rose400),
                      SizedBox(width: 4),
                      Text('Reduce', style: TextStyle(fontSize: 10, color: ZivaTheme.textSecondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showTopUpDialog(env, isReduce: false),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZivaTheme.gold500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 12, color: ZivaTheme.gold400),
                      SizedBox(width: 4),
                      Text('Top Up', style: TextStyle(fontSize: 10, color: ZivaTheme.gold400, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell({required String label, required String value, required Color color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: ZivaTheme.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: ZivaTheme.borderCard,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ZivaTheme.gold500 : ZivaTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? ZivaTheme.gold500 : ZivaTheme.borderCard),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : ZivaTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
