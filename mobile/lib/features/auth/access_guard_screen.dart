import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/ziva_theme.dart';
import '../../services/biometric_service.dart';

/// AccessGuardScreen - Executive PIN & Biometric Passcode Gate
/// Secures the Live environment against unauthorized access to financial records.
/// Features responsive breakpoint:
/// - Desktop (>= 800px): Standard keyboard text/password entry with Enter key submission
/// - Mobile (< 800px): Touch-friendly 4-digit keypad
class AccessGuardScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AccessGuardScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<AccessGuardScreen> createState() => _AccessGuardScreenState();
}

class _AccessGuardScreenState extends State<AccessGuardScreen> with SingleTickerProviderStateMixin {
  static const String _masterPin = String.fromEnvironment('ZIVA_ACCESS_PIN', defaultValue: '2026');
  String _enteredPin = '';
  String? _errorMessage;
  bool _isAuthenticatingBiometrics = false;
  bool _isPasswordVisible = false;

  late final TextEditingController _desktopPasscodeController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _desktopPasscodeController = TextEditingController();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _desktopPasscodeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    HapticFeedback.lightImpact();
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _desktopPasscodeController.text = _enteredPin;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _verifyEnteredPin(_enteredPin);
      }
    }
  }

  void _onDelete() {
    HapticFeedback.selectionClick();
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _desktopPasscodeController.text = _enteredPin;
        _errorMessage = null;
      });
    }
  }

  void _verifyEnteredPin(String pin) {
    if (pin == _masterPin) {
      HapticFeedback.mediumImpact();
      widget.onAuthenticated();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'Invalid Passcode. Access Denied.';
        _enteredPin = '';
        _desktopPasscodeController.clear();
      });
    }
  }

  Future<void> _attemptBiometricUnlock() async {
    if (kIsWeb) {
      // Biometrics on web automatically bypasses in staging/demo
      widget.onAuthenticated();
      return;
    }

    setState(() => _isAuthenticatingBiometrics = true);
    final success = await BiometricService.instance.authenticate(
      reason: 'Authenticate to access Ziva Finance Executive Terminal',
    );
    if (mounted) {
      setState(() => _isAuthenticatingBiometrics = false);
      if (success) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = 'Biometric verification failed.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaging = AppEnvironment.isStaging;
    final accentColor = AppEnvironment.accentColor;

    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;
            final contentMaxWidth = isDesktop ? 440.0 : 380.0;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Environment Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppEnvironment.badgeBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppEnvironment.badgeBorderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isStaging ? Icons.science_outlined : Icons.shield_outlined,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppEnvironment.badgeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ziva Finance Logo / Shield
                      Container(
                        width: isDesktop ? 84 : 76,
                        height: isDesktop ? 84 : 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: isDesktop ? 38 : 34,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      const Text(
                        'ZIVA FINANCE',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.0,
                          color: ZivaTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isStaging
                            ? 'Sandbox Security Terminal'
                            : (isDesktop ? 'Executive Financial Terminal • Desktop Access' : 'Executive Financial Terminal Access'),
                        style: TextStyle(
                          fontSize: 13,
                          color: ZivaTheme.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Error Message Display
                      SizedBox(
                        height: 22,
                        child: _errorMessage != null
                            ? Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: ZivaTheme.rose400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // RESPONSIVE INPUT FIELD:
                      // Desktop mode: Standard masked TextFormField with keyboard and Enter submission
                      // Mobile mode: 4-dot indicator with touch keypad
                      if (isDesktop)
                        _buildDesktopPasswordInput(accentColor)
                      else
                        _buildMobileKeypadSection(accentColor),

                      const SizedBox(height: 24),

                      // Staging Quick Unlock Bypass
                      if (isStaging)
                        OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            widget.onAuthenticated();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppEnvironment.accentColor.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(Icons.bolt, color: AppEnvironment.accentColor, size: 18),
                          label: Text(
                            'Instant Sandbox Bypass (Staging Demo)',
                            style: TextStyle(
                              color: AppEnvironment.accentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// MODE A: DESKTOP MASKED TEXT PASSWORD INPUT (>= 800px)
  Widget _buildDesktopPasswordInput(Color accentColor) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _shakeAnimation.value *
                (_shakeController.value > 0 ? (_shakeController.value % 0.2 > 0.1 ? 1 : -1) : 0),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: ZivaTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage != null ? ZivaTheme.rose500 : ZivaTheme.borderCard,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextFormField(
                  controller: _desktopPasscodeController,
                  autofocus: true,
                  obscureText: !_isPasswordVisible,
                  obscuringCharacter: '•',
                  style: const TextStyle(
                    color: ZivaTheme.textPrimary,
                    fontSize: 18,
                    letterSpacing: 4.0,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.go,
                  onChanged: (val) {
                    setState(() {
                      _enteredPin = val;
                      _errorMessage = null;
                    });
                  },
                  onFieldSubmitted: (val) => _verifyEnteredPin(val.trim()),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter Passcode',
                    hintStyle: TextStyle(
                      color: ZivaTheme.textMuted.withValues(alpha: 0.5),
                      fontSize: 14,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: Icon(Icons.key_rounded, color: accentColor, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: ZivaTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _isPasswordVisible = !_isPasswordVisible);
                      },
                      tooltip: _isPasswordVisible ? 'Hide passcode' : 'Show passcode',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Unlock Terminal Button
              ElevatedButton.icon(
                onPressed: () => _verifyEnteredPin(_desktopPasscodeController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZivaTheme.gold500,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text(
                  'Unlock Terminal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 10),

              // Enter key hint & Biometric option
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_return_rounded, size: 12, color: ZivaTheme.textMuted),
                      SizedBox(width: 4),
                      Text(
                        'Press Enter to submit',
                        style: TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _attemptBiometricUnlock,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fingerprint_rounded, size: 14, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          'Face ID / Touch ID',
                          style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// MODE B: MOBILE 4-DOT & KEYPAD SECTION (< 800px)
  Widget _buildMobileKeypadSection(Color accentColor) {
    return Column(
      children: [
        // 4-Digit Passcode Dots
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _shakeAnimation.value *
                    (_shakeController.value > 0 ? (_shakeController.value % 0.2 > 0.1 ? 1 : -1) : 0),
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: isFilled ? accentColor : ZivaTheme.textSecondary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Touch Keypad
        _buildKeypad(accentColor),
      ],
    );
  }

  Widget _buildKeypad(Color accentColor) {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        const SizedBox(height: 14),
        _buildKeyRow(['4', '5', '6']),
        const SizedBox(height: 14),
        _buildKeyRow(['7', '8', '9']),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left Action: Biometrics
            _buildActionKey(
              icon: Icons.fingerprint_rounded,
              onTap: _attemptBiometricUnlock,
              color: accentColor,
            ),
            // Center Action: 0
            _buildNumberKey('0'),
            // Right Action: Delete / Backspace
            _buildActionKey(
              icon: Icons.backspace_outlined,
              onTap: _onDelete,
              color: ZivaTheme.textSecondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberKey(d)).toList(),
    );
  }

  Widget _buildNumberKey(String digit) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ZivaTheme.bgSurface.withValues(alpha: 0.6),
          border: Border.all(
            color: ZivaTheme.borderCard.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: ZivaTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Center(
          child: _isAuthenticatingBiometrics && icon == Icons.fingerprint_rounded
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
