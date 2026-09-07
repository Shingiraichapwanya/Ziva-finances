import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/predictive_cashflow_model.dart';
import '../../../services/sqlite_service.dart';

class PredictiveCashFlowAlertCard extends StatelessWidget {
  final VoidCallback? onOpenAutoPilot;

  const PredictiveCashFlowAlertCard({
    super.key,
    this.onOpenAutoPilot,
  });

  @override
  Widget build(BuildContext context) {
    final projection = SqliteService.instance.calculatePredictiveCashFlowProjections(horizonDays: 30);
    final alerts = projection.alerts;

    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryAlert = alerts.first;
    final isCritical = primaryAlert.severity == AlertSeverity.critical;
    final alertColor = isCritical ? ZivaTheme.rose400 : ZivaTheme.gold400;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alertColor.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZivaTheme.bgSurface,
            alertColor.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: alertColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCritical ? Icons.warning_rounded : Icons.info_outline_rounded,
                        color: alertColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'EARLY WARNING RADAR (30-DAY)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${primaryAlert.daysUntilBreach} DAYS TO CRUNCH',
                  style: TextStyle(color: alertColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            primaryAlert.headline,
            style: const TextStyle(
              color: ZivaTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            primaryAlert.explanation,
            style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Tactical Phase Three Mitigations
          if (primaryAlert.suggestedMitigations.isNotEmpty) ...[
            const Text(
              'RECOMMENDED TACTICAL MITIGATIONS (PERSONAL CFO):',
              style: TextStyle(color: ZivaTheme.gold400, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
            ),
            const SizedBox(height: 6),
            ...primaryAlert.suggestedMitigations.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right_rounded, color: ZivaTheme.gold400, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(m, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(
                'Projected Min Liquidity: ${CurrencyFormatter.formatZar(projection.projectedLiquidZar)}',
                style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              if (onOpenAutoPilot != null)
                TextButton.icon(
                  onPressed: onOpenAutoPilot,
                  icon: const Icon(Icons.auto_mode_rounded, size: 14, color: ZivaTheme.gold400),
                  label: const Text('Open Auto Pilot Radar', style: TextStyle(color: ZivaTheme.gold400, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
