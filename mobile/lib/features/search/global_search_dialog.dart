import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../models/asset_model.dart';
import '../../models/debt_model.dart';
import '../../models/envelope_model.dart';
import '../../models/scenario_model.dart';
import '../../models/strategic_goal_model.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';

class GlobalSearchDialog extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const GlobalSearchDialog({super.key, this.onNavigateToTab});

  static Future<void> show(BuildContext context, {void Function(int tabIndex)? onNavigateToTab}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => GlobalSearchDialog(onNavigateToTab: onNavigateToTab),
    );
  }

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<TransactionModel> _allTransactions = [];
  List<EnvelopeModel> _allEnvelopes = [];
  List<DebtModel> _allDebts = [];
  List<AssetModel> _allAssets = [];
  List<ScenarioModel> _allScenarios = [];
  List<StrategicGoalModel> _allGoals = [];

  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAllEntities();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAllEntities() async {
    final txs = await SqliteService.instance.getTransactions(limit: 200);
    final envs = await SqliteService.instance.getEnvelopes();
    final debts = await SqliteService.instance.getDebts();
    final assets = await SqliteService.instance.getAssets();
    final scenarios = SqliteService.instance.getScenarios();
    final goals = SqliteService.instance.getStrategicGoals();

    if (mounted) {
      setState(() {
        _allTransactions = txs;
        _allEnvelopes = envs;
        _allDebts = debts;
        _allAssets = assets;
        _allScenarios = scenarios;
        _allGoals = goals;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();

    final matchedAssets = q.isEmpty
        ? <AssetModel>[]
        : _allAssets.where((a) {
            return a.name.toLowerCase().contains(q) ||
                a.categoryLabel.toLowerCase().contains(q) ||
                a.location.toLowerCase().contains(q) ||
                a.registrationNumber.toLowerCase().contains(q);
          }).take(4).toList();

    final matchedDebts = q.isEmpty
        ? <DebtModel>[]
        : _allDebts.where((d) {
            return d.counterparty.toLowerCase().contains(q) ||
                d.typeLabel.toLowerCase().contains(q) ||
                d.notes.toLowerCase().contains(q);
          }).take(4).toList();

    final matchedScenarios = q.isEmpty
        ? <ScenarioModel>[]
        : _allScenarios.where((s) {
            return s.title.toLowerCase().contains(q) ||
                s.description.toLowerCase().contains(q);
          }).take(4).toList();

    final matchedGoals = q.isEmpty
        ? <StrategicGoalModel>[]
        : _allGoals.where((g) {
            return g.title.toLowerCase().contains(q) ||
                g.rawInputPrompt.toLowerCase().contains(q) ||
                g.intent.name.toLowerCase().contains(q);
          }).take(4).toList();

    final matchedEnvelopes = q.isEmpty
        ? <EnvelopeModel>[]
        : _allEnvelopes.where((e) {
            return e.categoryName.toLowerCase().contains(q) ||
                e.categoryGroup.toLowerCase().contains(q) ||
                e.notes.toLowerCase().contains(q);
          }).take(4).toList();

    final matchedTransactions = q.isEmpty
        ? <TransactionModel>[]
        : _allTransactions.where((t) {
            return t.merchantOrPayee.toLowerCase().contains(q) ||
                t.categoryName.toLowerCase().contains(q) ||
                t.originalAmount.toString().contains(q);
          }).take(5).toList();

    final totalMatches = matchedAssets.length +
        matchedDebts.length +
        matchedScenarios.length +
        matchedGoals.length +
        matchedEnvelopes.length +
        matchedTransactions.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          color: ZivaTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZivaTheme.gold400.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: ZivaTheme.borderCard)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: ZivaTheme.gold400, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      style: const TextStyle(fontSize: 16, color: ZivaTheme.textPrimary, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Search transactions, assets, envelopes, debts...',
                        hintStyle: TextStyle(color: ZivaTheme.textMuted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _query = val),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20, color: ZivaTheme.textMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ZivaTheme.bgCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ZivaTheme.borderCard),
                    ),
                    child: const Text('ESC', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Search Results Feed
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ZivaTheme.gold400))
                  : _query.isEmpty
                      ? _buildSearchHints()
                      : totalMatches == 0
                          ? Center(
                              child: Text(
                                'No matching records found for "$_query"',
                                style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 13),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (matchedAssets.isNotEmpty) ...[
                                  _buildSectionHeader('ASSETS & HOLDINGS', Icons.account_balance_rounded, ZivaTheme.gold400),
                                  ...matchedAssets.map((a) => _buildAssetResultItem(a)),
                                  const SizedBox(height: 12),
                                ],
                                if (matchedDebts.isNotEmpty) ...[
                                  _buildSectionHeader('DEBTS & CREDIT SETTLEMENTS', Icons.handshake_rounded, ZivaTheme.emerald400),
                                  ...matchedDebts.map((d) => _buildDebtResultItem(d)),
                                  const SizedBox(height: 12),
                                ],
                                if (matchedScenarios.isNotEmpty) ...[
                                  _buildSectionHeader('FINANCIAL SCENARIOS (SANDBOX)', Icons.science_rounded, ZivaTheme.gold400),
                                  ...matchedScenarios.map((s) => _buildScenarioResultItem(s)),
                                  const SizedBox(height: 12),
                                ],
                                if (matchedGoals.isNotEmpty) ...[
                                  _buildSectionHeader('STRATEGIC GOALS (PERSONAL CFO)', Icons.psychology_rounded, Colors.tealAccent),
                                  ...matchedGoals.map((g) => _buildGoalResultItem(g)),
                                  const SizedBox(height: 12),
                                ],
                                if (matchedEnvelopes.isNotEmpty) ...[
                                  _buildSectionHeader('BUDGET ENVELOPES', Icons.mail_rounded, Colors.purpleAccent),
                                  ...matchedEnvelopes.map((e) => _buildEnvelopeResultItem(e)),
                                  const SizedBox(height: 12),
                                ],
                                if (matchedTransactions.isNotEmpty) ...[
                                  _buildSectionHeader('LEDGER TRANSACTIONS', Icons.receipt_long_rounded, Colors.blueAccent),
                                  ...matchedTransactions.map((t) => _buildTransactionResultItem(t)),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetResultItem(AssetModel asset) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigateToTab?.call(1); // Tab 1 is Assets
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ZivaTheme.gold400.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.account_balance_rounded, size: 14, color: ZivaTheme.gold400),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text('${asset.categoryLabel} • ${asset.location}', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                ],
              ),
            ),
            Text(
              'R ${asset.currentValueZar.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: ZivaTheme.gold400, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtResultItem(DebtModel debt) {
    final isOwedByMe = debt.direction == DebtDirection.owedByMe;
    final themeColor = isOwedByMe ? ZivaTheme.rose400 : ZivaTheme.emerald400;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigateToTab?.call(2); // Tab 2 is Ledger
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Icon(isOwedByMe ? Icons.arrow_outward_rounded : Icons.call_received_rounded, size: 14, color: themeColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(debt.counterparty, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text('${isOwedByMe ? 'Liability (I Owe)' : 'Receivable'} • ${debt.typeLabel}', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                ],
              ),
            ),
            Text(
              'R ${debt.currentOutstandingBalanceZar.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvelopeResultItem(EnvelopeModel env) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigateToTab?.call(0); // Command Center
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Row(
          children: [
            const Icon(Icons.markunread_mailbox_rounded, size: 16, color: Colors.purpleAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(env.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text('Planned: R ${env.plannedAmountZar.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                ],
              ),
            ),
            Text(
              'R ${env.currentBalanceZar.toStringAsFixed(0)} Left',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioResultItem(ScenarioModel scenario) {
    final result = scenario.runSimulation();
    final isPositive = result.projectedNetWorthDeltaZar >= 0;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigateToTab?.call(3); // Tab 3 is Scenarios
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ZivaTheme.gold400.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.science_rounded, size: 14, color: ZivaTheme.gold400),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scenario.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text(scenario.description.isNotEmpty ? scenario.description : 'What-if sandbox scenario', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(
              '${isPositive ? '+' : ''}R ${result.projectedNetWorthDeltaZar.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: isPositive ? ZivaTheme.emerald400 : ZivaTheme.rose400, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalResultItem(StrategicGoalModel goal) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigateToTab?.call(5); // Tab 5 is Strategic Goals
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.psychology_rounded, size: 14, color: Colors.tealAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text('${goal.intent.name.toUpperCase()} • Priority: ${goal.priority.name.toUpperCase()}', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                ],
              ),
            ),
            Text(
              'R ${goal.targetAmountZar.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionResultItem(TransactionModel tx) {
    final isExpense = tx.originalAmount < 0;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigateToTab?.call(2); // Ledger
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Row(
          children: [
            Icon(isExpense ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                size: 14, color: isExpense ? ZivaTheme.rose400 : ZivaTheme.emerald400),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.merchantOrPayee, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text('${tx.categoryName} • ${tx.transactionDate}', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                ],
              ),
            ),
            Text(
              'R ${tx.reportingAmountZar.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isExpense ? ZivaTheme.rose400 : ZivaTheme.emerald400,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHints() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search_rounded, size: 54, color: ZivaTheme.gold400),
          SizedBox(height: 12),
          Text('Instant Multi-Domain Search', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary)),
          SizedBox(height: 6),
          Text(
            'Type to search across assets, envelopes, debts, or ledger entries',
            style: TextStyle(fontSize: 12, color: ZivaTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
