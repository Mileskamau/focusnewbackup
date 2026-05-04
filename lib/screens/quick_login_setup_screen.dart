import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';

class QuickLoginSetupScreen extends StatefulWidget {
  const QuickLoginSetupScreen({super.key});

  @override
  State<QuickLoginSetupScreen> createState() => _QuickLoginSetupScreenState();
}

class _QuickLoginSetupScreenState extends State<QuickLoginSetupScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isPinSet = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
  }

  Future<void> _checkExistingPin() async {
    final storedPin = await _secureStorage.read(key: 'user_pin');
    setState(() {
      _isPinSet = storedPin != null;
    });
  }

  void _showPinSetupDialog() {
    _showPinDialog(
      title: 'Create PIN',
      subtitle: 'Create a 6-digit PIN for quick login access',
      isConfirmStep: false,
      onPinEntered: (pin) async {
        if (mounted) Navigator.of(context).pop();
        _showPinDialog(
          title: 'Confirm PIN',
          subtitle: 'Re-enter your PIN to confirm',
          isConfirmStep: true,
          onPinEntered: (confirmPin) async {
            if (pin == confirmPin) {
              await _secureStorage.write(key: 'user_pin', value: confirmPin);
              setState(() => _isPinSet = true);
              _showSuccessSnackBar('PIN set successfully!');
              if (mounted) Navigator.of(context).pop();
            } else {
              if (mounted) Navigator.of(context).pop();
              _showErrorSnackBar('PINs do not match. Try again.');
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) _showPinSetupDialog();
              });
            }
          },
        );
      },
    );
  }

  Future<void> _clearPin() async {
    await _secureStorage.delete(key: 'user_pin');
    setState(() => _isPinSet = false);
    _showSuccessSnackBar('PIN cleared');
  }

  void _showPinDialog({
    required String title,
    required String subtitle,
    required bool isConfirmStep,
    required Function(String pin) onPinEntered,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isConfirmStep,
      builder: (context) => _PinSetupDialog(
        title: title,
        subtitle: subtitle,
        onPinEntered: onPinEntered,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryOrange),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quick Login Setup',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure your quick login preferences',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: _isPinSet
                    ? const LinearGradient(
                        colors: [Color(0xFF00BFA5), Color(0xFF00E676)],
                      )
                    : const LinearGradient(
                        colors: [AppTheme.primaryOrange, AppTheme.primaryLightOrange],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPinSet ? Icons.check_circle : Icons.pin,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isPinSet ? 'PIN is Active' : 'Setup PIN',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPinSet
                        ? 'Your 6-digit PIN is configured and ready to use'
                        : 'Create a 6-digit PIN for quick access to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isPinSet ? _clearPin : _showPinSetupDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _isPinSet ? 'Remove PIN' : 'Set PIN',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC0C0C0), Color(0xFFE0E0E0)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Biometric Authentication',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use Face ID or Fingerprint for faster login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Configured automatically on Quick Login',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Skip setup',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String pin) onPinEntered;

  const _PinSetupDialog({
    required this.title,
    required this.subtitle,
    required this.onPinEntered,
  });

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
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
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [1, 2, 3]
                    .map((n) => _buildNumberButton(n))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [4, 5, 6]
                    .map((n) => _buildNumberButton(n))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [7, 8, 9]
                    .map((n) => _buildNumberButton(n))
                    .toList(),
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
