import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../services/sqlite_service.dart';
import '../ledger/quick_entry_sheet.dart';

class QuickAddFab extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onDataMutated;

  const QuickAddFab({
    super.key,
    this.onNavigateToTab,
    this.onDataMutated,
  });

  void _showQuickAddOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: ZivaTheme.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ZivaTheme.borderCard,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'EXECUTIVE QUICK ADD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ZivaTheme.gold400,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select an action to record instantaneously',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
            ),
            const SizedBox(height: 20),

            // Option 1: Log Transaction
            _buildOptionTile(
              context: ctx,
              title: 'Log Transaction',
              subtitle: 'NLP entry, receipt scan, or manual ledger debit/credit',
              icon: Icons.receipt_long_rounded,
              color: ZivaTheme.gold400,
              onTap: () {
                Navigator.pop(ctx);
                _openQuickEntry(context);
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Fund / Top-up Envelope
            _buildOptionTile(
              context: ctx,
              title: 'Fund / Reallocate Envelope',
              subtitle: 'Allocate planned capital to budget envelopes',
              icon: Icons.markunread_mailbox_rounded,
              color: Colors.purpleAccent,
              onTap: () {
                Navigator.pop(ctx);
                _openEnvelopeFundingDialog(context);
              },
            ),
            const SizedBox(height: 10),

            // Option 3: Record Debt / Credit
            _buildOptionTile(
              context: ctx,
              title: 'Record Debt or Receivable',
              subtitle: 'Track liability owed by me or receivable claim owed to me',
              icon: Icons.handshake_rounded,
              color: ZivaTheme.emerald400,
              onTap: () {
                Navigator.pop(ctx);
                onNavigateToTab?.call(2); // Ledger tab
              },
            ),
            const SizedBox(height: 10),

            // Option 4: Register New Asset
            _buildOptionTile(
              context: ctx,
              title: 'Register New Asset',
              subtitle: 'Tangible property, vehicle, IP, brand, or crypto vault',
              icon: Icons.account_balance_rounded,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(ctx);
                onNavigateToTab?.call(1); // Assets tab
              },
            ),
            const SizedBox(height: 10),

            // Option 5: New Sandbox Scenario
            _buildOptionTile(
              context: ctx,
              title: 'New Sandbox Scenario',
              subtitle: 'What-if financial modeling, major purchase simulation & stress-test',
              icon: Icons.science_rounded,
              color: ZivaTheme.gold400,
              onTap: () {
                Navigator.pop(ctx);
                onNavigateToTab?.call(3); // Scenarios tab
              },
            ),
            const SizedBox(height: 10),

            // Option 6: Set Strategic Goal (Personal CFO)
            _buildOptionTile(
              context: ctx,
              title: 'Set Strategic Goal (AI CFO)',
              subtitle: 'Natural language target for emergency fund, debt paydown, or major asset',
              icon: Icons.psychology_rounded,
              color: Colors.tealAccent,
              onTap: () {
                Navigator.pop(ctx);
                onNavigateToTab?.call(5); // Goals tab
              },
            ),
            const SizedBox(height: 10),

            // Option 7: Upload Deposit Slip (OCR)
            _buildOptionTile(
              context: ctx,
              title: 'Scan Deposit Slip (OCR)',
              subtitle: 'Handwritten bank deposit slip scanner & field extractor',
              icon: Icons.document_scanner_rounded,
              color: Colors.amberAccent,
              onTap: () {
                Navigator.pop(ctx);
                onNavigateToTab?.call(6); // Auto Pilot tab
              },
            ),
            const SizedBox(height: 10),

            // Option 8: Scan Workspace Emails
            _buildOptionTile(
              context: ctx,
              title: 'Scan Workspace Emails',
              subtitle: 'Trigger real-time Gmail financial document scan & ingestion',
              icon: Icons.mark_email_read_rounded,
              color: ZivaTheme.cyan400,
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scanning Google Workspace emails for financial docs...'),
                    backgroundColor: ZivaTheme.bgCard,
                  ),
                );
                await SqliteService.instance.scanGoogleWorkspaceEmails(manualTrigger: true);
                onDataMutated?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Workspace email scan complete. Transactions ingested!'),
                      backgroundColor: ZivaTheme.emerald400,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickEntry(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickEntryBottomSheet(
        onTransactionLogged: (newTx) {
          onDataMutated?.call();
        },
      ),
    );
  }

  void _openEnvelopeFundingDialog(BuildContext context) async {
    final envelopes = await SqliteService.instance.getEnvelopes();
    if (!context.mounted || envelopes.isEmpty) return;

    String selectedEnvId = envelopes.first.categoryId;
    final amountCtrl = TextEditingController(text: '5000');

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ZivaTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Fund Budget Envelope', style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedEnvId,
                dropdownColor: ZivaTheme.bgSurface,
                decoration: const InputDecoration(labelText: 'Target Envelope', filled: true, fillColor: ZivaTheme.bgCard),
                items: envelopes.map((env) {
                  return DropdownMenuItem<String>(
                    value: env.categoryId,
                    child: Text('${env.categoryName} (R ${env.remainingAmountZar.toStringAsFixed(0)} left)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedEnvId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount to Add (ZAR)',
                  prefixText: 'R ',
                  filled: true,
                  fillColor: ZivaTheme.bgCard,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold400, foregroundColor: Colors.black),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt > 0) {
                  await SqliteService.instance.topUpEnvelope(selectedEnvId, amt);
                  if (ctx.mounted) Navigator.pop(ctx);
                  onDataMutated?.call();
                }
              },
              child: const Text('Fund Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ZivaTheme.textMuted.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showQuickAddOptions(context),
      backgroundColor: ZivaTheme.gold500,
      foregroundColor: Colors.black,
      elevation: 6,
      tooltip: 'Quick Add (+)',
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }
}
