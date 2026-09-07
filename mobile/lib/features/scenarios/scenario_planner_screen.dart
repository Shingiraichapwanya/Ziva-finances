import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../models/envelope_model.dart';
import '../../models/scenario_model.dart';
import '../../services/sqlite_service.dart';

class ScenarioPlannerScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const ScenarioPlannerScreen({super.key, this.onBackToDashboard});

  @override
  State<ScenarioPlannerScreen> createState() => _ScenarioPlannerScreenState();
}

class _ScenarioPlannerScreenState extends State<ScenarioPlannerScreen> {
  final SqliteService _sqlite = SqliteService.instance;
  List<ScenarioModel> _scenarios = [];
  List<EnvelopeModel> _envelopes = [];
  String? _selectedScenarioId;
  bool _isLoading = true;

  // Local stress test override sliders for live interactive sandbox tweaking
  double _tempInterestDelta = 0.0;
  double _tempIncomeReliability = 1.0;
  double _tempExpenseSpike = 1.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final scenarios = _sqlite.getScenarios();
    final envelopes = await _sqlite.getEnvelopes();
    if (!mounted) return;

    String? selected = _selectedScenarioId;
    if (selected == null || !scenarios.any((s) => s.id == selected)) {
      selected = scenarios.isNotEmpty ? scenarios.first.id : null;
    }

    ScenarioModel? active;
    if (selected != null) {
      active = scenarios.firstWhere((s) => s.id == selected, orElse: () => scenarios.first);
    }

    setState(() {
      _scenarios = scenarios;
      _envelopes = envelopes;
      _selectedScenarioId = selected;
      if (active != null) {
        _tempInterestDelta = active.stressTest.interestRateDeltaPercent;
        _tempIncomeReliability = active.stressTest.incomeReliabilityFactor;
        _tempExpenseSpike = active.stressTest.expenseSpikeFactor;
      }
      _isLoading = false;
    });
  }

  ScenarioModel? get _activeScenario {
    if (_scenarios.isEmpty || _selectedScenarioId == null) return null;
    final base = _scenarios.firstWhere(
      (s) => s.id == _selectedScenarioId,
      orElse: () => _scenarios.first,
    );
    // Apply local interactive stress test sliders
    return base.copyWith(
      stressTest: StressTestParameters(
        interestRateDeltaPercent: _tempInterestDelta,
        incomeReliabilityFactor: _tempIncomeReliability,
        expenseSpikeFactor: _tempExpenseSpike,
      ),
    );
  }

  void _selectScenario(String id) {
    final s = _scenarios.firstWhere((sc) => sc.id == id, orElse: () => _scenarios.first);
    setState(() {
      _selectedScenarioId = id;
      _tempInterestDelta = s.stressTest.interestRateDeltaPercent;
      _tempIncomeReliability = s.stressTest.incomeReliabilityFactor;
      _tempExpenseSpike = s.stressTest.expenseSpikeFactor;
    });
  }

  Future<void> _duplicateScenario(String id) async {
    final copy = await _sqlite.duplicateScenario(id);
    if (!mounted) return;
    if (copy != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated scenario: "${copy.title}"'),
          backgroundColor: ZivaTheme.bgSurface,
        ),
      );
      _loadData();
      _selectScenario(copy.id);
    }
  }

  Future<void> _archiveScenario(String id) async {
    await _sqlite.archiveScenario(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scenario archived'),
        backgroundColor: ZivaTheme.bgSurface,
      ),
    );
    _loadData();
  }

  void _showCommitConfirmationDialog(ScenarioModel scenario) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZivaTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ZivaTheme.gold400, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Commit Scenario to Live Warehouse',
                style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to transition scenario "${scenario.title}" from sandbox simulation into LIVE production.',
                style: const TextStyle(fontSize: 13, color: ZivaTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgCore,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZivaTheme.borderCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MUTATIONS TO BE APPLIED:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.gold400, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${scenario.oneTimeExpenses.length} One-Time Capital Outflows (-R ${scenario.totalOneTimeCapitalOutflowZar.toStringAsFixed(0)}) debited from linked envelopes.',
                      style: const TextStyle(fontSize: 12, color: ZivaTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• ${scenario.recurringChanges.length} Recurring Budget Allocations updated in BigQuery ledger.',
                      style: const TextStyle(fontSize: 12, color: ZivaTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Net Worth & Envelope Runways recalculated with optimistic UI instant dispatch.',
                      style: TextStyle(fontSize: 12, color: ZivaTheme.emerald400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'This action cannot be undone automatically. Live balances will update immediately.',
                style: TextStyle(fontSize: 11, color: ZivaTheme.rose400, fontWeight: FontWeight.w600),
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
              Navigator.pop(ctx);
              await _sqlite.applyScenarioToLive(scenario);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: ZivaTheme.emerald400, size: 18),
                        SizedBox(width: 8),
                        Text('Scenario committed to live ledger & BigQuery queue!'),
                      ],
                    ),
                    backgroundColor: ZivaTheme.bgSurface,
                  ),
                );
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZivaTheme.gold500,
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm & Commit Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNewScenarioDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int horizon = 12;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create New Sandbox Scenario', style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Scenario Title',
                    hintText: 'e.g. Move to New Office, Acquire Real Estate',
                    filled: true,
                    fillColor: ZivaTheme.bgCard,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description & Strategic Intent',
                    filled: true,
                    fillColor: ZivaTheme.bgCard,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Horizon:', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: horizon,
                        dropdownColor: ZivaTheme.bgSurface,
                        decoration: const InputDecoration(filled: true, fillColor: ZivaTheme.bgCard),
                        items: const [
                          DropdownMenuItem(value: 6, child: Text('6 Months')),
                          DropdownMenuItem(value: 12, child: Text('12 Months (1 Year)')),
                          DropdownMenuItem(value: 24, child: Text('24 Months (2 Years)')),
                          DropdownMenuItem(value: 36, child: Text('36 Months (3 Years)')),
                          DropdownMenuItem(value: 60, child: Text('60 Months (5 Years)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => horizon = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final newScenario = ScenarioModel(
                  id: 'SCENARIO_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  horizonMonths: horizon,
                  startDate: DateTime.now(),
                  status: ScenarioStatus.active,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await _sqlite.saveScenario(newScenario);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                _selectScenario(newScenario.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              child: const Text('Create Scenario'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog(ScenarioModel scenario) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String? selectedEnv = _envelopes.isNotEmpty ? _envelopes.first.categoryId : null;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add One-Time Capital Outflow', style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Expense Description', filled: true, fillColor: ZivaTheme.bgCard),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (ZAR)', prefixText: 'R ', filled: true, fillColor: ZivaTheme.bgCard),
              ),
              const SizedBox(height: 12),
              if (_envelopes.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedEnv,
                  dropdownColor: ZivaTheme.bgSurface,
                  decoration: const InputDecoration(labelText: 'Funding Source Envelope', filled: true, fillColor: ZivaTheme.bgCard),
                  items: _envelopes.map((e) {
                    return DropdownMenuItem(value: e.categoryId, child: Text('${e.categoryName} (R ${e.currentBalanceZar.toStringAsFixed(0)})'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedEnv = val);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (titleCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
                final expense = ScenarioExpense(
                  id: 'EXP_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  amountZar: amount,
                  sourceEnvelopeId: selectedEnv,
                  targetDate: DateTime.now(),
                );
                final updated = scenario.copyWith(
                  oneTimeExpenses: List<ScenarioExpense>.from(scenario.oneTimeExpenses)..add(expense),
                );
                await _sqlite.saveScenario(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              child: const Text('Add Outflow'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRecurringDialog(ScenarioModel scenario) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isIncome = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Monthly Recurring Change', style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Change Description', filled: true, fillColor: ZivaTheme.bgCard),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monthly Delta (ZAR)', prefixText: 'R ', filled: true, fillColor: ZivaTheme.bgCard),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('New Expense (-ZAR)'),
                    selected: !isIncome,
                    selectedColor: ZivaTheme.rose400.withValues(alpha: 0.2),
                    onSelected: (val) => setDialogState(() => isIncome = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('New Inflow (+ZAR)'),
                    selected: isIncome,
                    selectedColor: ZivaTheme.emerald400.withValues(alpha: 0.2),
                    onSelected: (val) => setDialogState(() => isIncome = true),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (titleCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
                final rec = ScenarioRecurringChange(
                  id: 'REC_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  monthlyDeltaZar: isIncome ? amount : -amount,
                  isIncome: isIncome,
                );
                final updated = scenario.copyWith(
                  recurringChanges: List<ScenarioRecurringChange>.from(scenario.recurringChanges)..add(rec),
                );
                await _sqlite.saveScenario(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
              child: const Text('Add Recurring Change'),
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
        body: Center(child: CircularProgressIndicator(color: ZivaTheme.gold400)),
      );
    }

    final active = _activeScenario;

    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        backgroundColor: ZivaTheme.bgSurface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ZivaTheme.gold500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_rounded, size: 14, color: ZivaTheme.gold400),
                  SizedBox(width: 6),
                  Text('FINANCIAL SANDBOX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Scenario Planner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZivaTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: ZivaTheme.gold400),
            tooltip: 'Create New Scenario',
            onPressed: _showNewScenarioDialog,
          ),
          if (widget.onBackToDashboard != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: ZivaTheme.textMuted),
              onPressed: widget.onBackToDashboard,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (active == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.science_outlined, size: 48, color: ZivaTheme.textMuted),
                  const SizedBox(height: 16),
                  const Text('No scenarios created yet', style: TextStyle(color: ZivaTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showNewScenarioDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Scenario'),
                    style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
                  ),
                ],
              ),
            );
          }

          // Compute simulation results
          final sim = active.runSimulation(
            initialNetWorthZar: _sqlite.calculateConsolidatedNetWorthZar(liquidAccountsTotalZar: 1845000.0),
            baseMonthlyInflowZar: 195400.0,
            baseMonthlyOutflowZar: 88200.0,
            initialEmergencyBufferZar: 145000.0,
          );

          final scenarioPicker = _buildScenarioPicker();

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Trajectory & Sandbox Canvas
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        scenarioPicker,
                        const SizedBox(height: 20),
                        _buildSimulationHeader(active, sim),
                        const SizedBox(height: 20),
                        _buildComparativeTrajectoryCard(sim),
                        const SizedBox(height: 20),
                        _buildStressTestEngineCard(active),
                      ],
                    ),
                  ),
                ),

                // Right Column: Configuration & Actions Drawer
                SizedBox(
                  width: 380,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: ZivaTheme.bgSurface,
                      border: Border(left: BorderSide(color: ZivaTheme.borderCard)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCommitActionCard(active, sim),
                          const SizedBox(height: 20),
                          _buildExpensesSection(active),
                          const SizedBox(height: 20),
                          _buildRecurringSection(active),
                          const SizedBox(height: 20),
                          _buildWarningsAndSafeguards(sim),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile View
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                scenarioPicker,
                const SizedBox(height: 16),
                _buildSimulationHeader(active, sim),
                const SizedBox(height: 16),
                _buildComparativeTrajectoryCard(sim),
                const SizedBox(height: 16),
                _buildStressTestEngineCard(active),
                const SizedBox(height: 16),
                _buildCommitActionCard(active, sim),
                const SizedBox(height: 16),
                _buildExpensesSection(active),
                const SizedBox(height: 16),
                _buildRecurringSection(active),
                const SizedBox(height: 16),
                _buildWarningsAndSafeguards(sim),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScenarioPicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _scenarios.map((s) {
          final isSelected = s.id == _selectedScenarioId;
          final isCommitted = s.status == ScenarioStatus.committed;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCommitted) ...[
                    const Icon(Icons.check_circle_rounded, size: 12, color: ZivaTheme.emerald400),
                    const SizedBox(width: 4),
                  ],
                  Text(s.title),
                ],
              ),
              selected: isSelected,
              selectedColor: ZivaTheme.gold400.withValues(alpha: 0.2),
              backgroundColor: ZivaTheme.bgSurface,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? ZivaTheme.gold400 : ZivaTheme.textMuted,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? ZivaTheme.gold400 : ZivaTheme.borderCard),
              ),
              onSelected: (_) => _selectScenario(s.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSimulationHeader(ScenarioModel scenario, ScenarioSimulationResult sim) {
    return Container(
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scenario.description.isNotEmpty ? scenario.description : 'Simulated over ${scenario.horizonMonths} months',
                      style: const TextStyle(fontSize: 12, color: ZivaTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scenario.status == ScenarioStatus.committed
                      ? ZivaTheme.emerald400.withValues(alpha: 0.15)
                      : ZivaTheme.gold400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  scenario.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: scenario.status == ScenarioStatus.committed ? ZivaTheme.emerald400 : ZivaTheme.gold400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: ZivaTheme.borderCard, height: 1),
          const SizedBox(height: 16),

          // 4 Metric Telemetry Strip
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'PROJECTED NET WORTH DELTA',
                  '${sim.projectedNetWorthDeltaZar >= 0 ? '+' : ''}R ${sim.projectedNetWorthDeltaZar.toStringAsFixed(0)}',
                  sim.projectedNetWorthDeltaZar >= 0 ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'NET MONTHLY CASH FLOW',
                  '${sim.monthlyCashFlowDeltaZar >= 0 ? '+' : ''}R ${sim.monthlyCashFlowDeltaZar.toStringAsFixed(0)}/mo',
                  sim.monthlyCashFlowDeltaZar >= 0 ? ZivaTheme.emerald400 : ZivaTheme.gold400,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'RESILIENCY SCORE',
                  '${sim.resiliencyScorePercent.toInt()}%',
                  sim.resiliencyScorePercent >= 75 ? ZivaTheme.emerald400 : ZivaTheme.gold400,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'BUFFER RUNWAY',
                  sim.bufferRunwayMonths > 60 ? '60+ mo' : '${sim.bufferRunwayMonths.toStringAsFixed(1)} mo',
                  sim.bufferRunwayMonths >= 6 ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildComparativeTrajectoryCard(ScenarioSimulationResult sim) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRAJECTORY PROJECTION: CURRENT VS SCENARIO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
              ),
              Row(
                children: [
                  _LegendDot(color: ZivaTheme.textMuted, label: 'Current Path'),
                  SizedBox(width: 12),
                  _LegendDot(color: ZivaTheme.gold400, label: 'Scenario Path'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Painter for Comparative Curve
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _ComparativeChartPainter(points: sim.trajectory),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressTestEngineCard(ScenarioModel scenario) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: ZivaTheme.gold400, size: 16),
              SizedBox(width: 8),
              Text(
                'STRESS TEST ENGINE (SENSITIVITY ANALYSIS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Interest Rate Shock Slider
          Row(
            children: [
              const SizedBox(
                width: 140,
                child: Text('Interest Shock:', style: TextStyle(fontSize: 12, color: ZivaTheme.textSecondary)),
              ),
              Expanded(
                child: Slider(
                  value: _tempInterestDelta,
                  min: 0.0,
                  max: 5.0,
                  divisions: 10,
                  activeColor: ZivaTheme.gold400,
                  onChanged: (val) => setState(() => _tempInterestDelta = val),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('+${_tempInterestDelta.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: ZivaTheme.textPrimary)),
              ),
            ],
          ),

          // Income Reliability Slider
          Row(
            children: [
              const SizedBox(
                width: 140,
                child: Text('Income Reliability:', style: TextStyle(fontSize: 12, color: ZivaTheme.textSecondary)),
              ),
              Expanded(
                child: Slider(
                  value: _tempIncomeReliability,
                  min: 0.60,
                  max: 1.0,
                  divisions: 8,
                  activeColor: ZivaTheme.emerald400,
                  onChanged: (val) => setState(() => _tempIncomeReliability = val),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${(_tempIncomeReliability * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: ZivaTheme.textPrimary)),
              ),
            ],
          ),

          // Operational Outflow Inflation Slider
          Row(
            children: [
              const SizedBox(
                width: 140,
                child: Text('Expense Inflation:', style: TextStyle(fontSize: 12, color: ZivaTheme.textSecondary)),
              ),
              Expanded(
                child: Slider(
                  value: _tempExpenseSpike,
                  min: 1.0,
                  max: 1.50,
                  divisions: 10,
                  activeColor: ZivaTheme.rose400,
                  onChanged: (val) => setState(() => _tempExpenseSpike = val),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('+${((_tempExpenseSpike - 1.0) * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: ZivaTheme.textPrimary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommitActionCard(ScenarioModel scenario, ScenarioSimulationResult sim) {
    final isCommitted = scenario.status == ScenarioStatus.committed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgCore,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCommitted ? ZivaTheme.emerald400 : ZivaTheme.gold500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCommitted ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                  color: isCommitted ? ZivaTheme.emerald400 : ZivaTheme.gold400, size: 16),
              const SizedBox(width: 8),
              Text(
                isCommitted ? 'SCENARIO COMMITTED TO LIVE' : 'SANDBOX EXECUTION GATE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isCommitted ? ZivaTheme.emerald400 : ZivaTheme.gold400,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCommitted
                ? 'This scenario has been written to the live BigQuery ledger. Envelopes and net worth reflect these numbers.'
                : 'Sandbox operates exclusively in memory. Live balances will NOT be altered until you tap Apply below.',
            style: const TextStyle(fontSize: 12, color: ZivaTheme.textMuted),
          ),
          const SizedBox(height: 14),
          if (!isCommitted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCommitConfirmationDialog(scenario),
                icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                label: const Text('Apply Scenario to Live Ledger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZivaTheme.gold500,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _duplicateScenario(scenario.id),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Duplicate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZivaTheme.textSecondary,
                    side: const BorderSide(color: ZivaTheme.borderCard),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.archive_outlined, size: 18, color: ZivaTheme.textMuted),
                tooltip: 'Archive Scenario',
                onPressed: () => _archiveScenario(scenario.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesSection(ScenarioModel scenario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ONE-TIME CAPITAL OUTFLOWS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary, letterSpacing: 0.5),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: ZivaTheme.gold400),
              onPressed: () => _showAddExpenseDialog(scenario),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (scenario.oneTimeExpenses.isEmpty)
          const Text('No upfront capital outlays configured', style: TextStyle(fontSize: 12, color: ZivaTheme.textMuted))
        else
          ...scenario.oneTimeExpenses.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgCore,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.title, style: const TextStyle(fontSize: 12, color: ZivaTheme.textPrimary), overflow: TextOverflow.ellipsis),
                    ),
                    Text('R ${e.amountZar.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: ZivaTheme.rose400)),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildRecurringSection(ScenarioModel scenario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MONTHLY RECURRING DELTAS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary, letterSpacing: 0.5),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: ZivaTheme.gold400),
              onPressed: () => _showAddRecurringDialog(scenario),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (scenario.recurringChanges.isEmpty)
          const Text('No recurring monthly alterations configured', style: TextStyle(fontSize: 12, color: ZivaTheme.textMuted))
        else
          ...scenario.recurringChanges.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgCore,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(r.title, style: const TextStyle(fontSize: 12, color: ZivaTheme.textPrimary), overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${r.monthlyDeltaZar >= 0 ? '+' : ''}R ${r.monthlyDeltaZar.toStringAsFixed(0)}/mo',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: r.monthlyDeltaZar >= 0 ? ZivaTheme.emerald400 : ZivaTheme.gold400,
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildWarningsAndSafeguards(ScenarioSimulationResult sim) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sim.strategicWarnings.isNotEmpty) ...[
          const Text(
            'STRESS TEST WARNINGS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ZivaTheme.rose400, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          ...sim.strategicWarnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: ZivaTheme.rose400),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w, style: const TextStyle(fontSize: 11.5, color: ZivaTheme.textSecondary))),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],
        const Text(
          'RECOMMENDED SAFEGUARDS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ZivaTheme.emerald400, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        ...sim.recommendedSafeguards.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: ZivaTheme.emerald400),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 11.5, color: ZivaTheme.textMuted))),
                ],
              ),
            )),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
      ],
    );
  }
}

class _ComparativeChartPainter extends CustomPainter {
  final List<SimulationPoint> points;

  _ComparativeChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final currPaint = Paint()
      ..color = ZivaTheme.textMuted.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final scenPaint = Paint()
      ..color = ZivaTheme.gold400
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final minVal = points.map((p) => p.scenarioNetWorthZar).reduce((a, b) => a < b ? a : b);
    final maxVal = points.map((p) => p.currentNetWorthZar).reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    final currPath = Path();
    final scenPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final yCurr = size.height - (((points[i].currentNetWorthZar - minVal) / range) * (size.height - 20) + 10);
      final yScen = size.height - (((points[i].scenarioNetWorthZar - minVal) / range) * (size.height - 20) + 10);

      if (i == 0) {
        currPath.moveTo(x, yCurr);
        scenPath.moveTo(x, yScen);
      } else {
        currPath.lineTo(x, yCurr);
        scenPath.lineTo(x, yScen);
      }

      // Draw point indicator
      canvas.drawCircle(Offset(x, yScen), 3.5, Paint()..color = ZivaTheme.gold400);
    }

    canvas.drawPath(currPath, currPaint);
    canvas.drawPath(scenPath, scenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
