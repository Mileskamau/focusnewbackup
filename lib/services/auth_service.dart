import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _userKey = 'focus_user';
  static const _tokenKey = 'focus_token';
  static const _quickLoginPinKey = 'focus_quick_login_pin';
  static const _quickLoginBiometricKey = 'focus_quick_login_biometric';

  String? _userId;
  String? _username;
  String? _userRole;

  Future<void> init() async {
    final userStr = await _storage.read(key: _userKey);
    if (userStr != null) {
      try {
        final userData = jsonDecode(userStr) as Map<String, dynamic>;
        _userId = userData['id']?.toString();
        _username = userData['name']?.toString() ?? userData['username']?.toString();
        _userRole = userData['role']?.toString() ?? AppConstants.roleCashier;
      } catch (_) {
        _userId = '1';
        _username = 'current';
        _userRole = AppConstants.roleCashier;
      }
    }
  }

  Future<void> login({
    required String username,
    required String role,
    String userId = '1',
    String? displayName,
    String? token,
  }) async {
    final userData = {
      'id': userId,
      'username': username,
      'name': (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : username,
      'role': role,
    };
    await _storage.write(key: _userKey, value: jsonEncode(userData));
    await _storage.write(key: _tokenKey, value: token ?? 'session_$userId');
    _userId = userId;
    _username = userData['name'];
    _userRole = role;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _userId = null;
    _username = null;
    _userRole = null;
  }

  String? getUserId() => _userId;
  String? getUserName() => _username;
  String? getUserRole() => _userRole;
  FlutterSecureStorage getSecureStorage() => _storage;
}
