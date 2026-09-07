import 'package:flutter/material.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/url_anchor_helper.dart';

/// DesktopSidebar - Widescreen Left Navigation Sidebar for Executive Command Center
class DesktopSidebar extends StatelessWidget {
  final int currentTabIndex;
  final ValueChanged<int> onTabSelected;
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback? onSecretAdminTrigger;

  const DesktopSidebar({
    super.key,
    required this.currentTabIndex,
    required this.onTabSelected,
    this.selectedCurrency = 'ZAR',
    required this.onCurrencyChanged,
    this.onSecretAdminTrigger,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: ZivaTheme.bgSurface,
        border: Border(right: BorderSide(color: ZivaTheme.borderCard)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: GestureDetector(
              onTap: onSecretAdminTrigger,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ZivaTheme.gold500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Icon(Icons.diamond_outlined, color: ZivaTheme.gold400, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ZIVA FINANCE',
                          style: TextStyle(
                            color: ZivaTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'COMMAND CENTER',
                          style: TextStyle(
                            color: ZivaTheme.gold400,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Environment Pill Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppEnvironment.badgeBgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppEnvironment.badgeBorderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: AppEnvironment.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppEnvironment.badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppEnvironment.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Currency Switcher Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPORTING CURRENCY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: ZivaTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['ZAR', 'USD', 'ZiG'].map((curr) {
                    final isSelected = selectedCurrency == curr;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onCurrencyChanged(curr),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? ZivaTheme.gold500 : ZivaTheme.bgCore,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? ZivaTheme.gold500 : ZivaTheme.borderCard,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            curr,
                            style: TextStyle(
                              color: isSelected ? Colors.black : ZivaTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: ZivaTheme.borderCard, height: 1),
          const SizedBox(height: 12),

          // NAVIGATION BUTTONS: Scrollable middle section
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DEDICATED HOME / COMMAND CENTER BUTTON (PERSISTENT & VISUALLY DISTINCT)
                  _buildSidebarNavButton(
                    icon: Icons.dashboard_rounded,
                    label: 'Command Center (Home)',
                    badge: 'HOME',
                    isActive: currentTabIndex == 0,
                    isHomeButton: true,
                    onTap: () {
                      setUrlAnchor('#command-center');
                      onTabSelected(0);
                    },
                  ),

                  // 2. ASSET REGISTRY & MANAGER
                  _buildSidebarNavButton(
                    icon: Icons.account_balance_rounded,
                    label: 'Asset Registry & Manager',
                    badge: 'VALUATION',
                    isActive: currentTabIndex == 1,
                    onTap: () {
                      setUrlAnchor('#assets');
                      onTabSelected(1);
                    },
                  ),

                  // 3. DEBT & CREDIT LEDGER
                  _buildSidebarNavButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Debt & Credit Ledger',
                    badge: 'SPLITWISE',
                    isActive: currentTabIndex == 2,
                    onTap: () {
                      setUrlAnchor('#ledger');
                      onTabSelected(2);
                    },
                  ),

                  // 4. SCENARIO PLANNER (SANDBOX)
                  _buildSidebarNavButton(
                    icon: Icons.science_rounded,
                    label: 'Scenario Planner',
                    badge: 'SANDBOX',
                    isActive: currentTabIndex == 3,
                    onTap: () {
                      setUrlAnchor('#scenarios');
                      onTabSelected(3);
                    },
                  ),

                  // 5. TAX RESERVE AUTOMATION
                  _buildSidebarNavButton(
                    icon: Icons.shield_outlined,
                    label: 'Tax Reserve Automation',
                    badge: 'AUTO',
                    isActive: currentTabIndex == 4,
                    onTap: () {
                      setUrlAnchor('#tax-automation');
                      onTabSelected(4);
                    },
                  ),

                  // 6. STRATEGIC INSIGHTS & GOALS
                  _buildSidebarNavButton(
                    icon: Icons.psychology_rounded,
                    label: 'Strategic Insights & Goals',
                    badge: 'AI CFO',
                    isActive: currentTabIndex == 5,
                    onTap: () {
                      setUrlAnchor('#goals');
                      onTabSelected(5);
                    },
                  ),

                  // 7. SYSTEM SETTINGS & PROOF OF DEPLOYMENT
                  _buildSidebarNavButton(
                    icon: Icons.tune_rounded,
                    label: 'System Settings & OTA',
                    isActive: currentTabIndex == 6,
                    onTap: () {
                      setUrlAnchor('#settings');
                      onTabSelected(6);
                    },
                  ),
                ],
              ),
            ),
          ),

          // BigQuery Warehouse Status Telemetry Widget
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZivaTheme.bgCore,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BIGQUERY CONNECTED',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'live-budget-tracker-507418',
                  style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Region: africa-south1 (ZA) • Zero Latency',
                  style: TextStyle(color: ZivaTheme.textMuted, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavButton({
    required IconData icon,
    required String label,
    String? badge,
    required bool isActive,
    bool isHomeButton = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? (isHomeButton ? ZivaTheme.gold500.withValues(alpha: 0.15) : ZivaTheme.gold500.withValues(alpha: 0.10))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? (isHomeButton ? ZivaTheme.gold400.withValues(alpha: 0.6) : ZivaTheme.gold500.withValues(alpha: 0.3))
              : Colors.transparent,
          width: isHomeButton && isActive ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isActive ? ZivaTheme.gold400 : ZivaTheme.textMuted,
            size: 20,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isActive ? ZivaTheme.textPrimary : ZivaTheme.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          trailing: badge != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? ZivaTheme.gold500 : ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isActive ? Colors.black : ZivaTheme.gold400,
                    ),
                  ),
                )
              : (isActive
                  ? Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: ZivaTheme.gold400,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
