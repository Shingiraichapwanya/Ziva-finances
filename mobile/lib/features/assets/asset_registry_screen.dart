import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/asset_model.dart';
import '../../models/debt_model.dart';
import '../../services/sqlite_service.dart';

class AssetRegistryScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const AssetRegistryScreen({super.key, this.onBackToDashboard});

  @override
  State<AssetRegistryScreen> createState() => _AssetRegistryScreenState();
}

class _AssetRegistryScreenState extends State<AssetRegistryScreen> {
  final SqliteService _sqlite = SqliteService.instance;
  List<AssetModel> _assets = [];
  List<DebtModel> _availableDebts = [];
  bool _isLoading = true;
  String _typeFilter = 'ALL'; // ALL, TANGIBLE, INTANGIBLE
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    final assets = await _sqlite.getAssets();
    final debts = await _sqlite.getDebts();
    if (mounted) {
      setState(() {
        _assets = assets;
        _availableDebts = debts;
        _isLoading = false;
      });
    }
  }

  List<AssetModel> get _filteredAssets {
    return _assets.where((a) {
      if (_typeFilter == 'TANGIBLE' && a.type != AssetType.tangible) return false;
      if (_typeFilter == 'INTANGIBLE' && a.type != AssetType.intangible) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = a.name.toLowerCase().contains(q);
        final matchCat = a.categoryLabel.toLowerCase().contains(q);
        final matchLoc = a.location.toLowerCase().contains(q);
        final matchReg = a.registrationNumber.toLowerCase().contains(q);
        if (!matchName && !matchCat && !matchLoc && !matchReg) return false;
      }
      return true;
    }).toList();
  }

  double get _totalGrossValuation =>
      _assets.fold<double>(0.0, (sum, a) => sum + a.currentValueZar);

  double get _totalNetBookValue =>
      _assets.fold<double>(0.0, (sum, a) => sum + a.netBookValueZar);

  double get _totalNetWorthContribution =>
      _assets.fold<double>(0.0, (sum, a) => sum + a.effectiveNetWorthContributionZar);

  int get _tangibleCount =>
      _assets.where((a) => a.type == AssetType.tangible).length;

  int get _intangibleCount =>
      _assets.where((a) => a.type == AssetType.intangible).length;

  Future<void> _toggleNetWorth(AssetModel asset, bool include) async {
    final updated = asset.copyWith(includeInNetWorth: include);
    await _sqlite.saveAsset(updated);
    await _loadAssets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            include
                ? '${asset.name} included in Portfolio Net Worth.'
                : '${asset.name} excluded from Portfolio Net Worth.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteAsset(AssetModel asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZivaTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ZivaTheme.borderCard),
        ),
        title: const Text('Delete Asset Record', style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently remove "${asset.name}" from your portfolio registry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.rose500),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _sqlite.deleteAsset(asset.id);
      await _loadAssets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${asset.name} from Asset Registry.')),
        );
      }
    }
  }

  void _openAssetFormModal([AssetModel? existing]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssetFormSheet(
        existing: existing,
        availableDebts: _availableDebts,
        onSaved: (asset) async {
          await _sqlite.saveAsset(asset);
          await _loadAssets();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: ZivaTheme.gold400, size: 20),
            SizedBox(width: 10),
            Text(
              'ASSET REGISTRY & VALUATION SUITE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 15),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAssets,
            icon: const Icon(Icons.refresh_rounded, color: ZivaTheme.textSecondary),
            tooltip: 'Refresh Asset Telemetry',
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _openAssetFormModal(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Register Asset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZivaTheme.gold500,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ZivaTheme.gold400))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP EXECUTIVE TELEMETRY KPI CARDS
                  _buildExecutiveMetricsRow(),
                  const SizedBox(height: 20),

                  // 2. SEARCH & FILTER TOOLBAR
                  _buildToolbar(),
                  const SizedBox(height: 16),

                  // 3. ASSETS GRID / LIST
                  if (_filteredAssets.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: ZivaTheme.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZivaTheme.borderCard),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 40, color: ZivaTheme.textMuted),
                          const SizedBox(height: 12),
                          const Text('No assets match the active search/filter criteria.',
                              style: TextStyle(color: ZivaTheme.textSecondary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('Tap "Register Asset" to record a new tangible or intangible asset.',
                              style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openAssetFormModal(),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Register First Asset'),
                            style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 1200 ? 3 : (constraints.maxWidth >= 760 ? 2 : 1);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 310,
                          ),
                          itemCount: _filteredAssets.length,
                          itemBuilder: (context, idx) {
                            return _buildAssetCard(_filteredAssets[idx]);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildExecutiveMetricsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;
        final cards = [
          _buildMetricCard(
            title: 'PORTFOLIO ASSETS GROSS VALUE',
            amount: _totalGrossValuation,
            subtitle: '${_assets.length} Total Registered Assets',
            accentColor: ZivaTheme.gold400,
            icon: Icons.account_balance_rounded,
          ),
          _buildMetricCard(
            title: 'TOTAL NET BOOK VALUE (NBV)',
            amount: _totalNetBookValue,
            subtitle: 'Depreciated Acquisition Baseline',
            accentColor: ZivaTheme.cyan400,
            icon: Icons.auto_graph_rounded,
          ),
          _buildMetricCard(
            title: 'NET WORTH CONTRIBUTION',
            amount: _totalNetWorthContribution,
            subtitle: 'My Equity Share (Net of Debt)',
            accentColor: ZivaTheme.emerald400,
            icon: Icons.verified_user_rounded,
          ),
          _buildMetricCard(
            title: 'ASSET CLASS DIVERSIFICATION',
            customValue: '$_tangibleCount Tangible • $_intangibleCount Intangible',
            subtitle: 'Physical & Digital Holdings',
            accentColor: Colors.purpleAccent,
            icon: Icons.pie_chart_outline_rounded,
          ),
        ];

        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 14),
            Expanded(child: cards[1]),
            const SizedBox(width: 14),
            Expanded(child: cards[2]),
            const SizedBox(width: 14),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    double? amount,
    String? customValue,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: ZivaTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            customValue ?? CurrencyFormatter.formatAmount(amount ?? 0.0, currency: 'ZAR'),
            style: TextStyle(
              fontSize: customValue != null ? 14 : 18,
              fontWeight: FontWeight.w900,
              color: customValue != null ? ZivaTheme.textPrimary : accentColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: ZivaTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Row(
        children: [
          // Filter Pills
          Row(
            children: [
              _buildFilterPill('ALL', 'All Assets (${_assets.length})'),
              const SizedBox(width: 8),
              _buildFilterPill('TANGIBLE', 'Tangible ($_tangibleCount)'),
              const SizedBox(width: 8),
              _buildFilterPill('INTANGIBLE', 'Intangible ($_intangibleCount)'),
            ],
          ),
          const SizedBox(width: 16),
          // Search Input
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: ZivaTheme.bgCore,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZivaTheme.borderCard),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: ZivaTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(fontSize: 12, color: ZivaTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search by asset name, deed, plate, platform...',
                        hintStyle: TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _searchQuery = ''),
                      child: const Icon(Icons.clear_rounded, size: 14, color: ZivaTheme.textMuted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String filterKey, String label) {
    final isSelected = _typeFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ZivaTheme.gold500 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? ZivaTheme.gold500 : ZivaTheme.borderCard),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.black : ZivaTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAssetCard(AssetModel asset) {
    final isTangible = asset.type == AssetType.tangible;
    final typeColor = isTangible ? ZivaTheme.gold400 : ZivaTheme.cyan400;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: asset.includeInNetWorth ? ZivaTheme.borderCard : ZivaTheme.borderCard.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Row 1: Header (Name, Category Icon, Popup Menu)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                ),
                child: Icon(_getCategoryIcon(asset.category), size: 20, color: typeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ZivaTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            asset.categoryLabel,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: typeColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          asset.ownershipType == OwnershipType.solo
                              ? 'Solo 100%'
                              : 'Joint (${asset.myOwnershipPercentage.toStringAsFixed(0)}% Me)',
                          style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: ZivaTheme.textMuted),
                color: ZivaTheme.bgSurface,
                onSelected: (val) {
                  if (val == 'edit') _openAssetFormModal(asset);
                  if (val == 'delete') _deleteAsset(asset);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: ZivaTheme.gold400),
                        SizedBox(width: 8),
                        Text('Edit Asset', style: TextStyle(fontSize: 12, color: ZivaTheme.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: ZivaTheme.rose400),
                        SizedBox(width: 8),
                        Text('Delete Asset', style: TextStyle(fontSize: 12, color: ZivaTheme.rose400)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Row 2: Values (Current Valuation, NBV, Net Worth Share)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZivaTheme.bgCore,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CURRENT VALUATION', style: TextStyle(fontSize: 9, color: ZivaTheme.textMuted, fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyFormatter.formatAmount(asset.currentValueZar, currency: 'ZAR'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: ZivaTheme.textPrimary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('NET WORTH SHARE', style: TextStyle(fontSize: 9, color: ZivaTheme.textMuted, fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyFormatter.formatAmount(asset.effectiveNetWorthContributionZar, currency: 'ZAR'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: asset.includeInNetWorth ? ZivaTheme.emerald400 : ZivaTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Row 3: Details & Depreciation Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (asset.depreciationMethod != DepreciationMethod.none) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Depreciation (${asset.depreciationMethod.name}):',
                      style: const TextStyle(fontSize: 9, color: ZivaTheme.textMuted),
                    ),
                    Text(
                      'NBV R ${asset.netBookValueZar.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ZivaTheme.cyan400),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: asset.acquisitionCostZar > 0
                        ? (asset.accumulatedDepreciationZar / asset.acquisitionCostZar).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: ZivaTheme.bgCore,
                    valueColor: const AlwaysStoppedAnimation<Color>(ZivaTheme.cyan400),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (asset.registrationNumber.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 12, color: ZivaTheme.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        asset.registrationNumber,
                        style: const TextStyle(fontSize: 10, color: ZivaTheme.textSecondary, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (asset.linkedLiabilityName != null && asset.linkedLiabilityName!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 12, color: ZivaTheme.rose400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Debt: ${asset.linkedLiabilityName} (R ${asset.linkedLiabilityAmountZar.toStringAsFixed(0)})',
                        style: const TextStyle(fontSize: 10, color: ZivaTheme.rose400, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Row 4: Net Worth Toggle Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    asset.includeInNetWorth ? Icons.check_circle_rounded : Icons.cancel_outlined,
                    size: 14,
                    color: asset.includeInNetWorth ? ZivaTheme.emerald400 : ZivaTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    asset.includeInNetWorth ? 'Included in Net Worth' : 'Excluded from Net Worth',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: asset.includeInNetWorth ? ZivaTheme.emerald400 : ZivaTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Switch(
                value: asset.includeInNetWorth,
                activeTrackColor: ZivaTheme.emerald400,
                onChanged: (val) => _toggleNetWorth(asset, val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(AssetCategory category) {
    switch (category) {
      case AssetCategory.realEstate:
        return Icons.apartment_rounded;
      case AssetCategory.vehicle:
        return Icons.directions_car_rounded;
      case AssetCategory.equipment:
        return Icons.computer_rounded;
      case AssetCategory.cashEquivalent:
        return Icons.savings_rounded;
      case AssetCategory.investment:
        return Icons.trending_up_rounded;
      case AssetCategory.ipPatent:
        return Icons.lightbulb_rounded;
      case AssetCategory.brandDomain:
        return Icons.public_rounded;
      case AssetCategory.digitalAsset:
        return Icons.currency_bitcoin_rounded;
      case AssetCategory.other:
        return Icons.category_rounded;
    }
  }
}

/// Modal Form for Creating and Editing Assets
class _AssetFormSheet extends StatefulWidget {
  final AssetModel? existing;
  final List<DebtModel> availableDebts;
  final ValueChanged<AssetModel> onSaved;

  const _AssetFormSheet({
    this.existing,
    required this.availableDebts,
    required this.onSaved,
  });

  @override
  State<_AssetFormSheet> createState() => _AssetFormSheetState();
}

class _AssetFormSheetState extends State<_AssetFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _currentValueController;
  late TextEditingController _costController;
  late TextEditingController _locationController;
  late TextEditingController _regController;
  late TextEditingController _docRefController;
  late TextEditingController _myOwnershipController;
  late TextEditingController _usefulLifeController;
  late TextEditingController _depRateController;
  late TextEditingController _notesController;

  late AssetType _type;
  late AssetCategory _category;
  late DepreciationMethod _depMethod;
  late OwnershipType _ownershipType;
  late DateTime _acquisitionDate;
  late bool _includeInNetWorth;
  String? _linkedLiabilityId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _currentValueController = TextEditingController(text: e != null ? e.currentValueZar.toStringAsFixed(2) : '');
    _costController = TextEditingController(text: e != null ? e.acquisitionCostZar.toStringAsFixed(2) : '');
    _locationController = TextEditingController(text: e?.location ?? '');
    _regController = TextEditingController(text: e?.registrationNumber ?? '');
    _docRefController = TextEditingController(text: e?.documentationReference ?? '');
    _myOwnershipController = TextEditingController(text: e != null ? e.myOwnershipPercentage.toStringAsFixed(0) : '100');
    _usefulLifeController = TextEditingController(text: e != null ? e.usefulLifeYears.toStringAsFixed(1) : '5.0');
    _depRateController = TextEditingController(text: e != null ? e.depreciationRatePercent.toStringAsFixed(1) : '0.0');
    _notesController = TextEditingController(text: e?.notes ?? '');

    _type = e?.type ?? AssetType.tangible;
    _category = e?.category ?? AssetCategory.realEstate;
    _depMethod = e?.depreciationMethod ?? DepreciationMethod.none;
    _ownershipType = e?.ownershipType ?? OwnershipType.solo;
    _acquisitionDate = e?.acquisitionDate ?? DateTime.now();
    _includeInNetWorth = e?.includeInNetWorth ?? true;
    _linkedLiabilityId = e?.linkedLiabilityId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentValueController.dispose();
    _costController.dispose();
    _locationController.dispose();
    _regController.dispose();
    _docRefController.dispose();
    _myOwnershipController.dispose();
    _usefulLifeController.dispose();
    _depRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final currentVal = double.tryParse(_currentValueController.text.trim()) ?? 0.0;
    final cost = double.tryParse(_costController.text.trim()) ?? currentVal;
    final myOwnership = (double.tryParse(_myOwnershipController.text.trim()) ?? 100.0).clamp(0.0, 100.0);
    final partnerOwnership = 100.0 - myOwnership;
    final usefulLife = double.tryParse(_usefulLifeController.text.trim()) ?? 5.0;
    final depRate = double.tryParse(_depRateController.text.trim()) ?? 0.0;

    DebtModel? linkedDebt;
    if (_linkedLiabilityId != null) {
      final match = widget.availableDebts.where((d) => d.id == _linkedLiabilityId).toList();
      if (match.isNotEmpty) linkedDebt = match.first;
    }

    final asset = AssetModel(
      id: widget.existing?.id ?? 'ASSET_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: _type,
      category: _category,
      currentValueZar: currentVal,
      acquisitionCostZar: cost,
      acquisitionDate: _acquisitionDate,
      depreciationMethod: _depMethod,
      usefulLifeYears: usefulLife,
      depreciationRatePercent: depRate,
      location: _locationController.text.trim(),
      registrationNumber: _regController.text.trim(),
      documentationReference: _docRefController.text.trim(),
      ownershipType: _ownershipType,
      myOwnershipPercentage: myOwnership,
      partnerOwnershipPercentage: partnerOwnership,
      linkedLiabilityId: linkedDebt?.id,
      linkedLiabilityName: linkedDebt?.counterparty,
      linkedLiabilityAmountZar: linkedDebt?.currentOutstandingBalanceZar ?? 0.0,
      notes: _notesController.text.trim(),
      includeInNetWorth: _includeInNetWorth,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSaved(asset);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: ZivaTheme.gold500, width: 2)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: ZivaTheme.gold400, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      widget.existing != null ? 'Edit Asset Record' : 'Register New Portfolio Asset',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ZivaTheme.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: ZivaTheme.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ZivaTheme.borderCard),

          // Scrollable Form Fields
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Classification
                    const Text('ASSET CLASSIFICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<AssetType>(
                            initialValue: _type,
                            decoration: const InputDecoration(labelText: 'Asset Nature'),
                            items: const [
                              DropdownMenuItem(value: AssetType.tangible, child: Text('Tangible (Physical)')),
                              DropdownMenuItem(value: AssetType.intangible, child: Text('Intangible (Digital/IP)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _type = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: DropdownButtonFormField<AssetCategory>(
                            initialValue: _category,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: AssetCategory.values.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat.name));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _category = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Core Details
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Asset Name (e.g. Camps Bay Penthouse, Porsche 911 GT3)'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Asset name is required' : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currentValueController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Current Valuation (ZAR)', prefixText: 'R '),
                            validator: (val) => val == null || double.tryParse(val.trim()) == null ? 'Valid value required' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Original Cost (ZAR)', prefixText: 'R '),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Ownership & Liabilities
                    const Text('OWNERSHIP & FINANCING STRUCTURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<OwnershipType>(
                            initialValue: _ownershipType,
                            decoration: const InputDecoration(labelText: 'Ownership Type'),
                            items: const [
                              DropdownMenuItem(value: OwnershipType.solo, child: Text('Solo Holding (100%)')),
                              DropdownMenuItem(value: OwnershipType.joint, child: Text('Joint Holding')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _ownershipType = val;
                                  if (val == OwnershipType.solo) _myOwnershipController.text = '100';
                                });
                              }
                            },
                          ),
                        ),
                        if (_ownershipType == OwnershipType.joint) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _myOwnershipController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'My Equity %', suffixText: '%'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Linked Debt selector
                    DropdownButtonFormField<String?>(
                      initialValue: _linkedLiabilityId,
                      decoration: const InputDecoration(labelText: 'Linked Financed Liability (Optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Unencumbered)')),
                        ...widget.availableDebts.map((d) {
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text('${d.counterparty} - R ${d.currentOutstandingBalanceZar.toStringAsFixed(0)}'),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _linkedLiabilityId = val),
                    ),
                    const SizedBox(height: 20),

                    // Section 4: Depreciation & Valuation Method
                    const Text('DEPRECIATION & USEFUL LIFE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<DepreciationMethod>(
                            initialValue: _depMethod,
                            decoration: const InputDecoration(labelText: 'Depreciation Method'),
                            items: const [
                              DropdownMenuItem(value: DepreciationMethod.none, child: Text('None / Appreciating')),
                              DropdownMenuItem(value: DepreciationMethod.straightLine, child: Text('Straight Line')),
                              DropdownMenuItem(value: DepreciationMethod.reducingBalance, child: Text('Reducing Balance')),
                              DropdownMenuItem(value: DepreciationMethod.amortization, child: Text('Amortization')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _depMethod = val);
                            },
                          ),
                        ),
                        if (_depMethod != DepreciationMethod.none) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _usefulLifeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Useful Life (Years)'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 5: Identification & Physical Context
                    const Text('LOCATION & DOCUMENTATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(labelText: 'Location / Custody Site'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _regController,
                            decoration: const InputDecoration(labelText: 'Reg / Plate / Patent / Deed ID'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _docRefController,
                      decoration: const InputDecoration(labelText: 'Insurance Policy # / Contract Reference'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Strategic Notes & Appraisals'),
                    ),
                    const SizedBox(height: 16),

                    // Net Worth Toggle
                    SwitchListTile(
                      title: const Text('Include in Net Worth Calculations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Toggles whether this equity feeds into your executive consolidated net worth', style: TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                      value: _includeInNetWorth,
                      activeTrackColor: ZivaTheme.emerald400,
                      onChanged: (val) => setState(() => _includeInNetWorth = val),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          widget.existing != null ? 'Save Asset Changes' : 'Register Asset in Portfolio',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold500, foregroundColor: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
