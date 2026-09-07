import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../services/sqlite_service.dart';

class NextBestMoveWidget extends StatelessWidget {
  final VoidCallback onViewAllGoals;

  const NextBestMoveWidget({super.key, required this.onViewAllGoals});

  @override
  Widget build(BuildContext context) {
    final next = SqliteService.instance.getPersonalCfoNextBestMove();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZivaTheme.gold400.withValues(alpha: 0.4)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: ZivaTheme.gold400, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI CFO: NEXT BEST MOVE',
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
                child: const Text(
                  'HIGH IMPACT',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: ZivaTheme.gold400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            next.statusNudge,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          if (next.actionSteps.isNotEmpty)
            Text(
              '• ${next.actionSteps.first}',
              style: const TextStyle(fontSize: 12, color: ZivaTheme.textSecondary),
            ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewAllGoals,
              icon: const Icon(Icons.psychology_rounded, size: 15),
              label: const Text('Open Goals & CFO Blueprint'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZivaTheme.gold400,
                side: BorderSide(color: ZivaTheme.gold400.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 8),
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
