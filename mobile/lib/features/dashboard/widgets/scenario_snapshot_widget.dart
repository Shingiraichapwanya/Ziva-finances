import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../services/sqlite_service.dart';

class ScenarioSnapshotWidget extends StatelessWidget {
  final VoidCallback onOpenPlanner;

  const ScenarioSnapshotWidget({super.key, required this.onOpenPlanner});

  @override
  Widget build(BuildContext context) {
    final scenarios = SqliteService.instance.getScenarios();
    final active = scenarios.isNotEmpty ? scenarios.first : null;

    if (active == null) {
      return const SizedBox.shrink();
    }

    final sim = active.runSimulation(
      initialNetWorthZar: SqliteService.instance.calculateConsolidatedNetWorthZar(liquidAccountsTotalZar: 1845000.0),
      baseMonthlyInflowZar: 195400.0,
      baseMonthlyOutflowZar: 88200.0,
      initialEmergencyBufferZar: 145000.0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.science_rounded, color: ZivaTheme.gold400, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SCENARIO SANDBOX SNAPSHOT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ZivaTheme.gold400,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ZivaTheme.gold400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${active.horizonMonths}M HORIZON',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: ZivaTheme.gold400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            active.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            active.description,
            style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NET WORTH DELTA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${sim.projectedNetWorthDeltaZar >= 0 ? '+' : ''}R ${sim.projectedNetWorthDeltaZar.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: sim.projectedNetWorthDeltaZar >= 0 ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RESILIENCY SCORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${sim.resiliencyScorePercent.toInt()}% Strong',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: ZivaTheme.emerald400,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenPlanner,
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Open Sandbox & Stress Test'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZivaTheme.gold400,
                side: BorderSide(color: ZivaTheme.gold400.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
