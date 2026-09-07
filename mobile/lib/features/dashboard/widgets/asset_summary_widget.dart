import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../models/asset_model.dart';
import '../../../services/sqlite_service.dart';

class AssetSummaryWidget extends StatefulWidget {
  final VoidCallback onNavigateToAssets;

  const AssetSummaryWidget({
    super.key,
    required this.onNavigateToAssets,
  });

  @override
  State<AssetSummaryWidget> createState() => _AssetSummaryWidgetState();
}

class _AssetSummaryWidgetState extends State<AssetSummaryWidget> {
  List<AssetModel> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final assets = await SqliteService.instance.getAssets();
    if (mounted) {
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
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

    final totalGross = _assets.fold<double>(0.0, (sum, a) => sum + a.currentValueZar);
    final totalNetBook = _assets.fold<double>(0.0, (sum, a) => sum + a.netBookValueZar);
    final totalNetWorthContrib = _assets.fold<double>(0.0, (sum, a) => sum + a.effectiveNetWorthContributionZar);
    final tangibleCount = _assets.where((a) => a.type == AssetType.tangible).length;
    final intangibleCount = _assets.where((a) => a.type == AssetType.intangible).length;

    // Top 3 assets by current value
    final topAssets = List<AssetModel>.from(_assets)
      ..sort((a, b) => b.currentValueZar.compareTo(a.currentValueZar));
    final previewList = topAssets.take(3).toList();

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
                  color: ZivaTheme.gold400.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZivaTheme.gold400.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.account_balance_rounded, color: ZivaTheme.gold400, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ASSET REGISTRY & VALUATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ZivaTheme.gold400,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_assets.length} Active Holdings ($tangibleCount Tangible • $intangibleCount Intangible)',
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
                onPressed: widget.onNavigateToAssets,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: ZivaTheme.gold400),
                label: const Text(
                  'Manage Assets',
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
                  label: 'GROSS ASSET VALUE',
                  amount: totalGross,
                  subtitle: 'Fair Market Value',
                  color: ZivaTheme.gold400,
                  icon: Icons.pie_chart_outline_rounded,
                ),
                _buildMetricTile(
                  label: 'NET BOOK VALUE',
                  amount: totalNetBook,
                  subtitle: 'Less Acc. Depreciation',
                  color: ZivaTheme.textPrimary,
                  icon: Icons.auto_graph_rounded,
                ),
                _buildMetricTile(
                  label: 'NET WORTH CONTRIBUTION',
                  amount: totalNetWorthContrib,
                  subtitle: 'Equity Stake - Liab.',
                  color: ZivaTheme.emerald400,
                  icon: Icons.verified_user_rounded,
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

          // Top Holdings Preview
          const Text(
            'TOP PORTFOLIO HOLDINGS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ZivaTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          Column(
            children: previewList.map((asset) {
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
                        color: asset.type == AssetType.tangible
                            ? ZivaTheme.gold400.withValues(alpha: 0.12)
                            : ZivaTheme.emerald400.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        asset.type == AssetType.tangible ? Icons.home_work_rounded : Icons.lightbulb_outline_rounded,
                        color: asset.type == AssetType.tangible ? ZivaTheme.gold400 : ZivaTheme.emerald400,
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
                                  asset.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: ZivaTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!asset.includeInNetWorth) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ZivaTheme.textMuted.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OFF-NW',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${asset.categoryLabel} • ${asset.myOwnershipPercentage.toInt()}% Ownership',
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
                          'R ${asset.currentValueZar.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ZivaTheme.gold400,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Book: R ${asset.netBookValueZar.toStringAsFixed(0)}',
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
            'R ${amount.toStringAsFixed(0)}',
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
