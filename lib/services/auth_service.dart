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
  static const _sessionKey = 'fSessionId';
  static const _quickLoginPinKey = 'focus_quick_login_pin';
  static const _quickLoginBiometricKey = 'focus_quick_login_biometric';
  static const _savedUsernameKey = 'focus_saved_username';
  static const _savedPasswordKey = 'focus_saved_password';
  static const _savedCompanyIdKey = 'focus_saved_company_id';
  static const _savedCompanyNameKey = 'focus_saved_company_name';
  static const _savedDisplayNameKey = 'focus_saved_display_name';
  static const _savedUserIdKey = 'focus_saved_user_id';
  static const _savedUserRoleKey = 'focus_saved_user_role';

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

  Future<void> saveOfflineLoginCredentials({
    required String username,
    required String password,
    required String companyId,
    required String role,
    String? companyName,
    String? displayName,
    String? userId,
  }) async {
    await _storage.write(key: _savedUsernameKey, value: username.trim());
    await _storage.write(key: _savedPasswordKey, value: password);
    await _storage.write(key: _savedCompanyIdKey, value: companyId.trim());
    await _storage.write(key: _savedCompanyNameKey, value: companyName?.trim() ?? '');
    await _storage.write(
      key: _savedDisplayNameKey,
      value: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : username.trim(),
    );
    await _storage.write(key: _savedUserIdKey, value: userId?.trim() ?? username.trim());
    await _storage.write(key: _savedUserRoleKey, value: role.trim());
  }

  Future<SavedLoginCredentials?> getSavedLoginCredentials() async {
    final username = (await _storage.read(key: _savedUsernameKey))?.trim() ?? '';
    final password = await _storage.read(key: _savedPasswordKey) ?? '';
    final companyId = (await _storage.read(key: _savedCompanyIdKey))?.trim() ?? '';

    if (username.isEmpty || password.isEmpty || companyId.isEmpty) {
      return null;
    }

    final companyName = (await _storage.read(key: _savedCompanyNameKey))?.trim() ?? '';
    final displayName = (await _storage.read(key: _savedDisplayNameKey))?.trim() ?? username;
    final userId = (await _storage.read(key: _savedUserIdKey))?.trim() ?? username;
    final role =
        (await _storage.read(key: _savedUserRoleKey))?.trim() ?? AppConstants.roleCashier;

    return SavedLoginCredentials(
      username: username,
      password: password,
      companyId: companyId,
      companyName: companyName,
      displayName: displayName,
      userId: userId,
      role: role,
    );
  }

  Future<OfflineLoginResult?> tryOfflineLogin({
    required String username,
    required String password,
    required String companyId,
  }) async {
    final savedCredentials = await getSavedLoginCredentials();
    if (savedCredentials == null) {
      return null;
    }

    final normalizedUsername = username.trim().toLowerCase();
    final normalizedCompanyId = companyId.trim().toLowerCase();

    final isMatch = savedCredentials.username.toLowerCase() == normalizedUsername &&
        savedCredentials.password == password &&
        savedCredentials.companyId.toLowerCase() == normalizedCompanyId;

    if (!isMatch) {
      return null;
    }

    await login(
      username: savedCredentials.username,
      role: savedCredentials.role,
      userId: savedCredentials.userId,
      displayName: savedCredentials.displayName,
      token: 'offline_${savedCredentials.userId}',
    );

    return OfflineLoginResult(
      displayName: savedCredentials.displayName,
      companyName: savedCredentials.companyName,
    );
  }

  Future<void> logout({bool clearSavedCredentials = false}) async {
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionKey);
    if (clearSavedCredentials) {
      await _storage.delete(key: _savedUsernameKey);
      await _storage.delete(key: _savedPasswordKey);
      await _storage.delete(key: _savedCompanyIdKey);
      await _storage.delete(key: _savedCompanyNameKey);
      await _storage.delete(key: _savedDisplayNameKey);
      await _storage.delete(key: _savedUserIdKey);
      await _storage.delete(key: _savedUserRoleKey);
    }
    _userId = null;
    _username = null;
    _userRole = null;
  }

  String? getUserId() => _userId;
  String? getUserName() => _username;
  String? getUserRole() => _userRole;
  FlutterSecureStorage getSecureStorage() => _storage;
}

class SavedLoginCredentials {
  const SavedLoginCredentials({
    required this.username,
    required this.password,
    required this.companyId,
    required this.companyName,
    required this.displayName,
    required this.userId,
    required this.role,
  });

  final String username;
  final String password;
  final String companyId;
  final String companyName;
  final String displayName;
  final String userId;
  final String role;
}

class OfflineLoginResult {
  const OfflineLoginResult({
    required this.displayName,
    required this.companyName,
  });

  final String displayName;
  final String companyName;
}
