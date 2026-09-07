import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../models/debt_model.dart';
import '../../../services/sqlite_service.dart';

class DebtCreditSummaryWidget extends StatefulWidget {
  final VoidCallback onNavigateToLedger;

  const DebtCreditSummaryWidget({
    super.key,
    required this.onNavigateToLedger,
  });

  @override
  State<DebtCreditSummaryWidget> createState() => _DebtCreditSummaryWidgetState();
}

class _DebtCreditSummaryWidgetState extends State<DebtCreditSummaryWidget> {
  List<DebtModel> _debts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    try {
      final debts = await SqliteService.instance.getDebts();
      if (mounted) {
        setState(() {
          _debts = debts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _debts = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: ZivaTheme.gold400, strokeWidth: 2),
        ),
      );
    }

    final payables = _debts
        .where((d) => d.direction == DebtDirection.owedByMe && !d.isPaidOff)
        .fold<double>(0.0, (sum, d) => sum + d.currentOutstandingBalanceZar);

    final receivables = _debts
        .where((d) => d.direction == DebtDirection.owedToMe && !d.isPaidOff)
        .fold<double>(0.0, (sum, d) => sum + d.currentOutstandingBalanceZar);

    final netPosition = receivables - payables;

    final activeDebts = _debts
        .where((d) => !d.isPaidOff)
        .toList()
      ..sort((a, b) => b.currentOutstandingBalanceZar.compareTo(a.currentOutstandingBalanceZar));

    final previewDebts = activeDebts.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: ZivaTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZivaTheme.borderCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZivaTheme.emerald400.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZivaTheme.emerald400.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.handshake_rounded, color: ZivaTheme.emerald400, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEBT & CREDIT LEDGER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ZivaTheme.emerald400,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activeDebts.length} Active Positions • Splitwise Settlement Core',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ZivaTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: widget.onNavigateToLedger,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: ZivaTheme.gold400),
                label: const Text(
                  'Open Ledger',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ZivaTheme.gold400,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: ZivaTheme.gold400.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final cards = [
                _buildMetricTile(
                  label: 'LIABILITIES (I OWE)',
                  amount: payables,
                  subtitle: 'Direct Outflows Pending',
                  color: ZivaTheme.rose400,
                  icon: Icons.arrow_outward_rounded,
                ),
                _buildMetricTile(
                  label: 'RECEIVABLES (OWED ME)',
                  amount: receivables,
                  subtitle: 'Incoming Inflow Claims',
                  color: ZivaTheme.emerald400,
                  icon: Icons.call_received_rounded,
                ),
                _buildMetricTile(
                  label: 'NET SETTLEMENT POSITION',
                  amount: netPosition,
                  subtitle: netPosition >= 0 ? 'Net Receivable Surplus' : 'Net Obligation Deficit',
                  color: netPosition >= 0 ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                  icon: Icons.balance_rounded,
                  prefix: netPosition >= 0 ? '+ ' : '- ',
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList(),
                );
              }

              return Row(
                children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          const Divider(color: ZivaTheme.borderCard, height: 1),
          const SizedBox(height: 14),

          // Active Debts Preview
          const Text(
            'ACTIVE SETTLEMENT CLAIMS & OBLIGATIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ZivaTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          Column(
            children: previewDebts.map((debt) {
              final isOwedByMe = debt.direction == DebtDirection.owedByMe;
              final indicatorColor = isOwedByMe ? ZivaTheme.rose400 : ZivaTheme.emerald400;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZivaTheme.borderCard.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: indicatorColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOwedByMe ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                        color: indicatorColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  debt.counterparty,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: ZivaTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: indicatorColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOwedByMe ? 'I OWE' : 'OWED TO ME',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: indicatorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${debt.typeLabel} • ${debt.dueDate != null ? 'Due ${debt.dueDate!.toIso8601String().substring(0, 10)}' : 'No expiry'} • ${debt.repayments.length} settlements',
                            style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R ${debt.currentOutstandingBalanceZar.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: indicatorColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Orig: R ${debt.originalPrincipalZar.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required double amount,
    required String subtitle,
    required Color color,
    required IconData icon,
    String prefix = '',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ZivaTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$prefix R ${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
