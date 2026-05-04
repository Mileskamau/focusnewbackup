import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:focus_swiftbill/screens/quick_login_screen.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class QuickLoginSettingsScreen extends StatefulWidget {
  const QuickLoginSettingsScreen({super.key});

  @override
  State<QuickLoginSettingsScreen> createState() => _QuickLoginSettingsScreenState();
}

class _QuickLoginSettingsScreenState extends State<QuickLoginSettingsScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _quickLoginEnabled = false;
  bool _biometricEnabled = false;
  bool _pinSet = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _storage.read(key: AppConstants.keyQuickLoginEnabled);
    final bio = await _storage.read(key: AppConstants.keyBiometricEnabled);
    final pin = await _storage.read(key: AppConstants.keyUserPin);
    setState(() {
      _quickLoginEnabled = enabled == 'true';
      _biometricEnabled = bio == 'true';
      _pinSet = pin != null;
    });
  }

  Future<void> _toggleQuickLogin(bool value) async {
    if (value && !_pinSet && !_biometricEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable PIN or Biometric first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _storage.write(key: AppConstants.keyQuickLoginEnabled, value: value ? 'true' : 'false');
    setState(() => _quickLoginEnabled = value);
  }

  Future<void> _clearQuickLogin() async {
    await _storage.delete(key: AppConstants.keyUserPin);
    await _storage.delete(key: AppConstants.keyBiometricEnabled);
    setState(() {
      _pinSet = false;
      _biometricEnabled = false;
      _quickLoginEnabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Login Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Quick Login Enabled'),
            subtitle: const Text('Use PIN or biometric for faster login'),
            value: _quickLoginEnabled,
            onChanged: _toggleQuickLogin,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.pin),
            title: const Text('PIN'),
            subtitle: Text(_pinSet ? 'PIN is set' : 'Not set'),
            trailing: _pinSet
                ? IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuickLoginScreen(
                            username: '',
                            userRole: '',
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Biometric'),
            subtitle: Text(_biometricEnabled ? 'Enabled' : 'Not enabled'),
          ),
          if (_pinSet || _biometricEnabled)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Disable Quick Login', style: TextStyle(color: Colors.red)),
              onTap: _clearQuickLogin,
            ),
        ],
      ),
    );
  }
}
