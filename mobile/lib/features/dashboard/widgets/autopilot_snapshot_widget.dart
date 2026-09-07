import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../models/deposit_slip_model.dart';
import '../../../models/email_transaction_proposal.dart';
import '../../../services/sqlite_service.dart';

class AutoPilotSnapshotWidget extends StatelessWidget {
  final VoidCallback onOpenAutoPilot;

  const AutoPilotSnapshotWidget({
    super.key,
    required this.onOpenAutoPilot,
  });

  @override
  Widget build(BuildContext context) {
    final proposals = SqliteService.instance.getEmailProposals();
    final pendingEmails = proposals.where((p) => p.status == ProposalStatus.pending).length;

    final slips = SqliteService.instance.getDepositSlips();
    final pendingSlips = slips.where((s) => s.status == DepositSlipStatus.readyForReview).length;

    final reconSummary = SqliteService.instance.getReconciliationSummary();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.auto_mode_rounded, color: ZivaTheme.gold400, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AUTO PILOT INGESTION & RECON',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ZivaTheme.emerald500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SYNC ACTIVE',
                  style: TextStyle(color: ZivaTheme.emerald400, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Email Queue',
                  value: '$pendingEmails Pending',
                  color: pendingEmails > 0 ? ZivaTheme.gold400 : ZivaTheme.emerald400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: 'Deposit Slips (OCR)',
                  value: '$pendingSlips Awaiting',
                  color: pendingSlips > 0 ? ZivaTheme.cyan400 : ZivaTheme.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: 'Reconciliation',
                  value: '${reconSummary.reconciliationRatePercent.toStringAsFixed(0)}% Matched',
                  color: ZivaTheme.emerald400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenAutoPilot,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Review Auto Pilot Pipeline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZivaTheme.gold500,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: ZivaTheme.bgCore,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
