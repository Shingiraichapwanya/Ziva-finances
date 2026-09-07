import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../models/envelope_model.dart';
import '../../models/tax_automation_model.dart';
import '../../services/sqlite_service.dart';

class TaxAutomationScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const TaxAutomationScreen({super.key, this.onBackToDashboard});

  @override
  State<TaxAutomationScreen> createState() => _TaxAutomationScreenState();
}

class _TaxAutomationScreenState extends State<TaxAutomationScreen> {
  final SqliteService _sqlite = SqliteService.instance;
  late TaxAutomationConfig _config;
  late TaxReserveStatus _status;
  List<TaxSkimRecord> _skims = [];
  List<EnvelopeModel> _envelopes = [];
  bool _isLoading = true;

  // Form edit state
  late bool _enabled;
  late double _taxRate;
  late String _targetEnvelopeId;
  late TaxRuleType _ruleType;
  late double _threshold;
  late String _jurisdiction;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final config = _sqlite.getTaxConfig();
    final status = _sqlite.calculateTaxReserveStatus();
    final skims = _sqlite.getTaxSkimRecords();
    final envelopes = await _sqlite.getEnvelopes();
    if (!mounted) return;

    setState(() {
      _config = config;
      _status = status;
      _skims = skims;
      _envelopes = envelopes;

      _enabled = config.enabled;
      _taxRate = config.defaultTaxRatePercent;
      _targetEnvelopeId = config.targetEnvelopeId;
      _ruleType = config.ruleType;
      _threshold = config.minimumThresholdZar;
      _jurisdiction = config.jurisdictionContext;
      _isLoading = false;
    });
  }

  Future<void> _saveRules() async {
    final targetEnv = _envelopes.firstWhere(
      (e) => e.categoryId == _targetEnvelopeId,
      orElse: () => _envelopes.first,
    );

    final updated = _config.copyWith(
      enabled: _enabled,
      defaultTaxRatePercent: _taxRate,
      targetEnvelopeId: _targetEnvelopeId,
      targetEnvelopeName: targetEnv.categoryName,
      ruleType: _ruleType,
      minimumThresholdZar: _threshold,
      jurisdictionContext: _jurisdiction,
    );

    await _sqlite.saveTaxConfig(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: ZivaTheme.emerald400, size: 18),
              SizedBox(width: 8),
              Text('Tax Automation rules saved! Next qualifying inflow will be skimmed automatically.'),
            ],
          ),
          backgroundColor: ZivaTheme.bgSurface,
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: ZivaTheme.bgCore,
        body: Center(child: CircularProgressIndicator(color: ZivaTheme.gold400)),
      );
    }

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
                  Icon(Icons.shield_outlined, size: 14, color: ZivaTheme.gold400),
                  SizedBox(width: 6),
                  Text('AUTOMATION ENGINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tax Reserve Automation',
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
            // 4 Telemetry KPI Cards
            _buildTelemetrySection(),
            const SizedBox(height: 24),

            // Rule Configuration Card & Audit Log
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildRuleConfigCard()),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: _buildAuditLogCard()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildRuleConfigCard(),
                    const SizedBox(height: 20),
                    _buildAuditLogCard(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySection() {
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
              const Text(
                'TAX RESERVE ADEQUACY & LIQUIDITY TELEMETRY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _status.isQuarterAdequate
                      ? ZivaTheme.emerald400.withValues(alpha: 0.15)
                      : ZivaTheme.rose400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      _status.isQuarterAdequate ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 12,
                      color: _status.isQuarterAdequate ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _status.isQuarterAdequate ? 'RESERVES ADEQUATE (${_status.adequacyRatioPercent.toInt()}%)' : 'RESERVE GAP DETECTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _status.isQuarterAdequate ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: ZivaTheme.borderCard, height: 1),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTelemetryTile(
                  'CURRENT TAX RESERVE',
                  'R ${_status.currentTaxReserveZar.toStringAsFixed(0)}',
                  ZivaTheme.emerald400,
                  'Allocated in ${_config.targetEnvelopeName}',
                ),
              ),
              Expanded(
                child: _buildTelemetryTile(
                  'YTD TAX SKIMMED',
                  'R ${_status.ytdTaxReservedZar.toStringAsFixed(0)}',
                  ZivaTheme.gold400,
                  'Automated from inflows',
                ),
              ),
              Expanded(
                child: _buildTelemetryTile(
                  'Q3 ESTIMATED LIABILITY',
                  'R ${_status.currentQuarterEstimatedLiabilityZar.toStringAsFixed(0)}',
                  ZivaTheme.textPrimary,
                  'Quarterly SARS obligation',
                ),
              ),
              Expanded(
                child: _buildTelemetryTile(
                  'ANNUAL TAX LIABILITY (EST.)',
                  'R ${_status.estimatedAnnualTaxObligationZar.toStringAsFixed(0)}',
                  ZivaTheme.textMuted,
                  'Based on R195.4k/mo run-rate',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile(String title, String value, Color color, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 10.5, color: ZivaTheme.textMuted), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildRuleConfigCard() {
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
              const Text(
                'SKIMMING RULES & JURISDICTION',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
              ),
              Switch(
                value: _enabled,
                activeThumbColor: ZivaTheme.gold500,
                onChanged: (val) => setState(() => _enabled = val),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Jurisdiction Selector
          DropdownButtonFormField<String>(
            initialValue: _jurisdiction,
            dropdownColor: ZivaTheme.bgSurface,
            decoration: const InputDecoration(
              labelText: 'Tax Jurisdiction & Authority',
              filled: true,
              fillColor: ZivaTheme.bgCard,
            ),
            items: const [
              DropdownMenuItem(value: 'South Africa (SARS)', child: Text('South Africa (SARS - Individual/Corp)')),
              DropdownMenuItem(value: 'Zimbabwe (ZIMRA)', child: Text('Zimbabwe (ZIMRA - Multi-Currency)')),
              DropdownMenuItem(value: 'Custom International', child: Text('Custom International Standard')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _jurisdiction = val);
            },
          ),
          const SizedBox(height: 14),

          // Default Tax Rate Slider
          Row(
            children: [
              const SizedBox(
                width: 140,
                child: Text('Default Skim Rate:', style: TextStyle(fontSize: 12, color: ZivaTheme.textSecondary)),
              ),
              Expanded(
                child: Slider(
                  value: _taxRate,
                  min: 10.0,
                  max: 45.0,
                  divisions: 35,
                  activeColor: ZivaTheme.gold400,
                  onChanged: (val) => setState(() => _taxRate = val),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${_taxRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: ZivaTheme.gold400, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Target Envelope
          if (_envelopes.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _targetEnvelopeId,
              dropdownColor: ZivaTheme.bgSurface,
              decoration: const InputDecoration(
                labelText: 'Target Tax Reserve Envelope',
                filled: true,
                fillColor: ZivaTheme.bgCard,
              ),
              items: _envelopes.map((e) {
                return DropdownMenuItem(value: e.categoryId, child: Text('${e.categoryName} (R ${e.currentBalanceZar.toStringAsFixed(0)})'));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _targetEnvelopeId = val);
              },
            ),
          const SizedBox(height: 14),

          // Rule Type Segmented Selector
          const Text('INFLOW FILTER RULE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All Inflows'),
                selected: _ruleType == TaxRuleType.allIncome,
                selectedColor: ZivaTheme.gold400.withValues(alpha: 0.2),
                onSelected: (val) => setState(() => _ruleType = TaxRuleType.allIncome),
              ),
              ChoiceChip(
                label: const Text('Above Threshold'),
                selected: _ruleType == TaxRuleType.aboveThreshold,
                selectedColor: ZivaTheme.gold400.withValues(alpha: 0.2),
                onSelected: (val) => setState(() => _ruleType = TaxRuleType.aboveThreshold),
              ),
              ChoiceChip(
                label: const Text('Specific Sources Only'),
                selected: _ruleType == TaxRuleType.specificSources,
                selectedColor: ZivaTheme.gold400.withValues(alpha: 0.2),
                onSelected: (val) => setState(() => _ruleType = TaxRuleType.specificSources),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Save Rules Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveRules,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save & Activate Automation Rules'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZivaTheme.gold500,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogCard() {
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
              const Text(
                'HISTORICAL AUDIT LOG (SMART SKIMS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
              ),
              Text('${_skims.length} Records', style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),

          if (_skims.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No automated skims recorded yet', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
              ),
            )
          else
            ..._skims.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ZivaTheme.gold400.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, size: 16, color: ZivaTheme.gold400),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.sourceDescription, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('Inflow: R ${s.grossIncomeZar.toStringAsFixed(0)} • Rate: ${s.taxRateAppliedPercent}%', style: const TextStyle(fontSize: 10.5, color: ZivaTheme.textMuted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('+R ${s.skimmedTaxAmountZar.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: ZivaTheme.emerald400, fontFamily: 'monospace')),
                          const SizedBox(height: 2),
                          Text('${s.timestamp.month}/${s.timestamp.day}', style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
