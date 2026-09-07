import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../services/sqlite_service.dart';

class TaxReserveStatusWidget extends StatelessWidget {
  final VoidCallback onOpenTaxManager;

  const TaxReserveStatusWidget({super.key, required this.onOpenTaxManager});

  @override
  Widget build(BuildContext context) {
    final status = SqliteService.instance.calculateTaxReserveStatus();
    final isAdequate = status.isQuarterAdequate;
    final progressFraction = (status.adequacyRatioPercent / 100.0).clamp(0.0, 1.0);

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
                    Icon(Icons.shield_outlined, color: ZivaTheme.gold400, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TAX RESERVE TELEMETRY',
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
                  color: isAdequate ? ZivaTheme.emerald400.withValues(alpha: 0.15) : ZivaTheme.rose400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAdequate ? 'ADEQUATE (${status.adequacyRatioPercent.toInt()}%)' : 'RESERVE GAP',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isAdequate ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CURRENT RESERVES', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    'R ${status.currentTaxReserveZar.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ZivaTheme.emerald400, fontFamily: 'monospace'),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Q3 ESTIMATED DUE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    'R ${status.currentQuarterEstimatedLiabilityZar.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ZivaTheme.textPrimary, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 6,
              backgroundColor: ZivaTheme.bgCore,
              valueColor: AlwaysStoppedAnimation<Color>(isAdequate ? ZivaTheme.emerald400 : ZivaTheme.rose400),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenTaxManager,
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Configure Skimming Rules & SARS Reserve'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZivaTheme.textSecondary,
                side: const BorderSide(color: ZivaTheme.borderCard),
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
