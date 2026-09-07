import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../models/strategic_goal_model.dart';
import '../../services/sqlite_service.dart';

class StrategicInsightsScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const StrategicInsightsScreen({super.key, this.onBackToDashboard});

  @override
  State<StrategicInsightsScreen> createState() => _StrategicInsightsScreenState();
}

class _StrategicInsightsScreenState extends State<StrategicInsightsScreen> {
  final SqliteService _sqlite = SqliteService.instance;
  final TextEditingController _promptCtrl = TextEditingController();
  List<StrategicGoalModel> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() => _isLoading = true);
    final goals = _sqlite.getStrategicGoals();
    setState(() {
      _goals = goals;
      _isLoading = false;
    });
  }

  Future<void> _generateStrategyFromPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;
    final goal = _sqlite.parseNaturalLanguageGoal(prompt.trim());
    await _sqlite.saveStrategicGoal(goal);
    _promptCtrl.clear();
    _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.psychology_rounded, color: ZivaTheme.gold400, size: 18),
            const SizedBox(width: 8),
            Text('Personal CFO generated strategy for "${goal.title}"!'),
          ],
        ),
        backgroundColor: ZivaTheme.bgSurface,
      ),
    );
  }

  Future<void> _deleteGoal(String id) async {
    await _sqlite.deleteStrategicGoal(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: ZivaTheme.bgCore,
        body: Center(child: CircularProgressIndicator(color: ZivaTheme.gold400)),
      );
    }

    final nextBestMove = _sqlite.getPersonalCfoNextBestMove();

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
                  Icon(Icons.psychology_rounded, size: 14, color: ZivaTheme.gold400),
                  SizedBox(width: 6),
                  Text('AI CFO ENGINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Strategic Insights & Goals',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZivaTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.onBackToDashboard != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: ZivaTheme.textMuted),
              onPressed: widget.onBackToDashboard,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Next Best Tactical Move Hero Banner
            _buildNextBestMoveHero(nextBestMove),
            const SizedBox(height: 20),

            // Natural Language Goal Input Bar
            _buildPromptInputBar(),
            const SizedBox(height: 24),

            // Goals Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVE STRATEGIC MILESTONES & ACTION PLANS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
                ),
                Text('${_goals.length} Goals Monitored', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 14),

            // Goals Cards
            if (_goals.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZivaTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZivaTheme.borderCard),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.flag_outlined, size: 36, color: ZivaTheme.textMuted),
                    SizedBox(height: 12),
                    Text('No strategic goals defined yet', style: TextStyle(color: ZivaTheme.textSecondary, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Type an ambition above to generate a tailored CFO action plan.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                  ],
                ),
              )
            else
              ..._goals.map((g) => _buildGoalCard(g)),
          ],
        ),
      ),
    );
  }

  Widget _buildNextBestMoveHero(StrategicRecommendation next) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZivaTheme.bgSurface,
            ZivaTheme.gold500.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: ZivaTheme.gold400, size: 18),
              SizedBox(width: 8),
              Text(
                'PERSONAL CFO HIGHEST-IMPACT RECOMMENDATION',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: ZivaTheme.gold400, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            next.statusNudge,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          if (next.actionSteps.isNotEmpty)
            Text(
              '• ${next.actionSteps.first}',
              style: const TextStyle(fontSize: 12.5, color: ZivaTheme.textSecondary),
            ),
          if (next.reallocationSuggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '• ${next.reallocationSuggestions.first}',
              style: const TextStyle(fontSize: 12.5, color: ZivaTheme.emerald400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NATURAL LANGUAGE GOAL DISPATCHER',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.gold400, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. "I want to build a R250,000 emergency fund in 18 months"',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: ZivaTheme.gold400),
                    filled: true,
                    fillColor: ZivaTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  onSubmitted: _generateStrategyFromPrompt,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _generateStrategyFromPrompt(_promptCtrl.text),
                icon: const Icon(Icons.psychology_rounded, size: 16),
                label: const Text('Generate Strategy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZivaTheme.gold500,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preset Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildPresetChip('Emergency Buffer (R250k / 18M)', 'I want to build a 6-month liquid emergency fund in 18 months'),
              _buildPresetChip('Zero Card Debt (R150k / 8M)', 'I want to pay off my Discovery Card debt of R150,000 completely in 8 months'),
              _buildPresetChip('De-risk to Treasury Bonds', 'Shift more capital into low-risk assets while keeping at least R100k liquid'),
              _buildPresetChip('Save for Fleet Vehicle', 'I want to save R450,000 for vehicle acquisition in 12 months'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String prompt) {
    return InkWell(
      onTap: () {
        _promptCtrl.text = prompt;
        _generateStrategyFromPrompt(prompt);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCore,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10.5, color: ZivaTheme.textMuted)),
      ),
    );
  }

  Widget _buildGoalCard(StrategicGoalModel goal) {
    final rec = goal.recommendation;
    final progress = goal.progressFraction;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZivaTheme.gold400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getGoalIcon(goal.intent), color: ZivaTheme.gold400, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Horizon: ${goal.targetHorizonMonths} Months • Target: ${goal.targetDate.month}/${goal.targetDate.year}',
                        style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getPriorityColor(goal.priority).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${goal.priority.name.toUpperCase()} PRIORITY',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _getPriorityColor(goal.priority)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: ZivaTheme.textMuted),
                onPressed: () => _deleteGoal(goal.id),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'R ${goal.currentAmountZar.toStringAsFixed(0)} achieved of R ${goal.targetAmountZar.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
              ),
              Text(
                '${goal.progressPercent.toInt()}% (${goal.remainingZar > 0 ? "R ${goal.remainingZar.toStringAsFixed(0)} left" : "Achieved!"})',
                style: const TextStyle(fontSize: 12, color: ZivaTheme.gold400, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: ZivaTheme.bgCore,
              valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? ZivaTheme.emerald400 : ZivaTheme.gold400),
            ),
          ),
          const SizedBox(height: 16),

          // Strategy Plan Container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ZivaTheme.bgCore,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CFO STRATEGY BLUEPRINT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                    Text(rec.statusNudge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.emerald400)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Recommended Monthly Contribution: R ${rec.recommendedMonthlyAllocationZar.toStringAsFixed(0)}/mo into ${rec.primaryTargetEnvelopeName}.',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                ...rec.actionSteps.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: ZivaTheme.gold400, fontWeight: FontWeight.bold)),
                          Expanded(child: Text(s, style: const TextStyle(fontSize: 11.5, color: ZivaTheme.textSecondary))),
                        ],
                      ),
                    )),
                if (rec.reallocationSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...rec.reallocationSuggestions.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.swap_horiz_rounded, size: 14, color: ZivaTheme.emerald400),
                            const SizedBox(width: 4),
                            Expanded(child: Text(r, style: const TextStyle(fontSize: 11.5, color: ZivaTheme.emerald400))),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getGoalIcon(GoalIntent intent) {
    switch (intent) {
      case GoalIntent.buildEmergencyReserve:
        return Icons.shield_outlined;
      case GoalIntent.payOffDebt:
        return Icons.credit_card_off_rounded;
      case GoalIntent.accumulatePurchase:
        return Icons.account_balance_rounded;
      case GoalIntent.deRiskPortfolio:
        return Icons.lock_clock_rounded;
      case GoalIntent.boostSavingsRate:
        return Icons.trending_up_rounded;
    }
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return ZivaTheme.rose400;
      case GoalPriority.medium:
        return ZivaTheme.gold400;
      case GoalPriority.low:
        return ZivaTheme.textMuted;
    }
  }
}
