import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class QuickLoginScreen extends StatefulWidget {
  final String username;
  final String userRole;

  const QuickLoginScreen({
    super.key,
    required this.username,
    required this.userRole,
  });

  @override
  State<QuickLoginScreen> createState() => _QuickLoginScreenState();
}

class _QuickLoginScreenState extends State<QuickLoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _biometricAvailable = false;
  bool _isPinSet = false;
  String? _biometricType;

  @override
  void initState() {
    super.initState();
    _initializeAuthMethods();
  }

  Future<void> _initializeAuthMethods() async {
    final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final bool isDeviceSupported = await _localAuth.isDeviceSupported();

    if (canCheckBiometrics && isDeviceSupported) {
      try {
        final List<BiometricType> availableBiometrics =
            await _localAuth.getAvailableBiometrics();

        if (availableBiometrics.isNotEmpty) {
          setState(() {
            _biometricAvailable = true;
            _biometricType = availableBiometrics.first == BiometricType.fingerprint
                ? 'Fingerprint'
                : availableBiometrics.first == BiometricType.face
                    ? 'Face ID'
                    : 'Biometric';
          });
        }
      } catch (e) {
        debugPrint('Error checking biometrics: $e');
      }
    }

    final storedPin = await _secureStorage.read(key: 'user_pin');
    setState(() {
      _isPinSet = storedPin != null;
    });
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason:
            'Scan your ${_biometricType?.toLowerCase() ?? 'biometric'} to log in quickly',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        _onAuthSuccess();
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      _showErrorSnackBar('Biometric authentication failed');
    }
  }

  void _onPinSelected() {
    if (_isPinSet) {
      _showPinDialog(
        title: 'Enter PIN',
        subtitle: 'Enter your 6-digit PIN to login',
        isNewPin: false,
        onPinEntered: (pin) async {
          final storedPin = await _secureStorage.read(key: 'user_pin');
          if (storedPin == pin) {
            _onAuthSuccess();
          } else {
            _showErrorSnackBar('Incorrect PIN');
          }
        },
      );
    } else {
      _showPinDialog(
        title: 'Create PIN',
        subtitle: 'Create a 6-digit PIN for quick login',
        isNewPin: true,
        onPinEntered: (pin) async {
          // Show confirmation dialog
          if (mounted) Navigator.of(context).pop();
          _showPinConfirmationDialog(firstPin: pin);
        },
      );
    }
  }

  void _showPinConfirmationDialog({required String firstPin}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinEntryDialog(
        title: 'Confirm PIN',
        subtitle: 'Re-enter your PIN to confirm',
        onPinEntered: (confirmPin) async {
        if (firstPin == confirmPin) {
          await _secureStorage.write(key: 'user_pin', value: confirmPin);
          setState(() => _isPinSet = true);
          _showSuccessSnackBar('PIN set successfully!');
          _onAuthSuccess();
        } else {
          if (mounted) Navigator.of(context).pop();
          _showErrorSnackBar('PINs do not match. Try again.');
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _onPinSelected();
            }
          });
        }
        },
      ),
    );
  }

  void _showPinDialog({
    required String title,
    required String subtitle,
    required bool isNewPin,
    required Function(String pin) onPinEntered,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinEntryDialog(
        title: title,
        subtitle: subtitle,
        onPinEntered: onPinEntered,
      ),
    );
  }

  void _onAuthSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: AppTheme.primaryOrange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Authentication Successful!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back, ${widget.username}!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(); // close success dialog
        Navigator.of(context).pushReplacementNamed('/main', arguments: 0);
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back, color: AppTheme.primaryOrange),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Login',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark)),
                        Text('Choose your preferred method',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // User Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryOrange, AppTheme.primaryLightOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person,
                          size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.username,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          Text(widget.userRole,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Fingerprint Option
              if (_biometricAvailable)
                _buildAuthOptionCard(
                  icon: _biometricType == 'Face ID'
                      ? Icons.face
                      : Icons.fingerprint,
                  title: _biometricType ?? 'Biometric',
                  subtitle:
                      'Use your ${_biometricType?.toLowerCase() ?? 'biometric'}',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006D5B), Color(0xFF00BFA5)],
                  ),
                  onTap: _authenticateWithBiometric,
                ),

              if (_biometricAvailable) const SizedBox(height: 16),

              // PIN Option
              _buildAuthOptionCard(
                icon: Icons.pin,
                title: _isPinSet ? 'Use PIN' : 'Set PIN',
                subtitle: _isPinSet
                    ? '6-digit PIN for quick access'
                    : 'Create a 6-digit PIN',
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFE8C96B)],
                ),
                onTap: _onPinSelected,
              ),

              const Spacer(),

              // Skip for now
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/main');
                },
                child: Text('Skip for now',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 14)),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Colors.white.withOpacity(0.85))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.white.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}

class _PinEntryDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String pin) onPinEntered;

  const _PinEntryDialog({
    required this.title,
    required this.subtitle,
    required this.onPinEntered,
  });

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final int pinLength = 6;
  List<int> enteredPin = [];

  void _onDigitPressed(int digit) {
    if (enteredPin.length < pinLength) {
      setState(() {
        enteredPin.add(digit);
      });

      if (enteredPin.length == pinLength) {
        final pin = enteredPin.join();
        widget.onPinEntered(pin);
      }
    }
  }

  void _onBackspacePressed() {
    if (enteredPin.isNotEmpty) {
      setState(() {
        enteredPin.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.lock, size: 48, color: AppTheme.primaryOrange),
          const SizedBox(height: 24),
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 32),
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pinLength,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < enteredPin.length
                      ? AppTheme.primaryOrange
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Number pad
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumberButton(1),
                  _buildNumberButton(2),
                  _buildNumberButton(3),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumberButton(4),
                  _buildNumberButton(5),
                  _buildNumberButton(6),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumberButton(7),
                  _buildNumberButton(8),
                  _buildNumberButton(9),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 80),
                  _buildNumberButton(0),
                  _buildBackspaceButton(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNumberButton(int number) {
    return GestureDetector(
      onTap: () => _onDigitPressed(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryOrange.withOpacity(0.08),
          border: Border.all(
            color: AppTheme.primaryOrange.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text('$number',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark)),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _onBackspacePressed,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
        child: Icon(Icons.backspace_outlined,
            size: 28, color: Colors.grey.shade600),
      ),
    );
  }
}
