import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ------------------------------
// Main Login Screen Widget (Modern, Fit to Screen, No Scroll)
// ------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _companyIdKey = 'selected_company_id';
  static const String _companyNameKey = 'selected_company_name';
  static const String _companyCodeKey = 'selected_company_code';

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final Dio _loginLookupDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );
  bool _isLoading = false;
  bool _isLoadingSetup = true;
  bool _isLoadingOutletMappings = false;
  String? _errorMessage;
  String? _outletMappingMessage;
  Timer? _usernameLookupDebounce;

  String? selectedOutlet;
  String? selectedCashier;
  List<String> outlets = [];
  List<String> counter = [];
  List<_OutletCounterMapping> _outletMappings = [];
  String _configuredBaseUrl = '';
  String _configuredCompanyName = '';
  String _configuredCompanyCode = '';

  @override
  void initState() {
    super.initState();
    usernameController.addListener(_onUsernameChanged);
    _loadSavedConfiguration();
  }

  Future<void> _loadSavedConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = _normalizeBaseUrl(await ApiService().getSavedBaseUrl());
    final savedCredentials = await AuthService().getSavedLoginCredentials();
    if (!mounted) return;
    setState(() {
      _configuredBaseUrl = savedBaseUrl;
      _configuredCompanyName = prefs.getString(_companyNameKey)?.trim() ?? '';
      _configuredCompanyCode = prefs.getString(_companyCodeKey)?.trim() ?? '';
      _isLoadingSetup = false;
      if (savedCredentials != null) {
        if (usernameController.text.trim().isEmpty) {
          usernameController.text = savedCredentials.username;
        }
        if (passwordController.text.isEmpty) {
          passwordController.text = savedCredentials.password;
        }
      }
    });
    _scheduleOutletLookup();
  }

  String _normalizeBaseUrl(String value) {
    final normalized = value.trim();
    if (normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<void> _openSetupScreen() async {
    await Navigator.pushNamed(context, '/settings');
    await _loadSavedConfiguration();
  }

  void _onUsernameChanged() {
    if (mounted) {
      setState(() {
        _outletMappings = [];
        outlets = [];
        counter = [];
        selectedOutlet = null;
        selectedCashier = null;
        _outletMappingMessage = usernameController.text.trim().isEmpty
            ? null
            : 'Checking outlet access...';
      });
    }
    _scheduleOutletLookup();
  }

  void _scheduleOutletLookup() {
    _usernameLookupDebounce?.cancel();
    _usernameLookupDebounce = Timer(
      const Duration(milliseconds: 450),
      _loadOutletCounterMappingsForCurrentUser,
    );
  }

  bool get _requiresOutletSelection => _outletMappings.isNotEmpty;
  bool get _isOutletDropdownEnabled => !_isLoadingOutletMappings && outlets.isNotEmpty;
  bool get _isCounterDropdownEnabled =>
      !_isLoadingOutletMappings && selectedOutlet != null && counter.isNotEmpty;

  Future<void> _loadOutletCounterMappingsForCurrentUser() async {
    final username = usernameController.text.trim();
    if (username.isEmpty) {
      if (!mounted) return;
      setState(() {
        _outletMappings = [];
        outlets = [];
        counter = [];
        selectedOutlet = null;
        selectedCashier = null;
        _isLoadingOutletMappings = false;
        _outletMappingMessage = null;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString(_companyIdKey)?.trim() ?? '';
    final baseUrl = _normalizeBaseUrl(await ApiService().getSavedBaseUrl());

    if (companyId.isEmpty || baseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _outletMappings = [];
        outlets = [];
        counter = [];
        selectedOutlet = null;
        selectedCashier = null;
        _isLoadingOutletMappings = false;
        _outletMappingMessage = null;
      });
      return;
    }

    if (!await _hasNetworkConnection()) {
      if (!mounted) return;
      setState(() {
        _isLoadingOutletMappings = false;
        _outletMappings = [];
        outlets = [];
        counter = [];
        selectedOutlet = null;
        selectedCashier = null;
        _outletMappingMessage = 'Outlet and counter will load when you are back online.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingOutletMappings = true;
      _outletMappingMessage = 'Checking outlet access...';
      _outletMappings = [];
      outlets = [];
      counter = [];
      selectedOutlet = null;
      selectedCashier = null;
    });

    try {
      final response = await _loginLookupDio.get(
        '${_pillayrProductsApiRoot(baseUrl)}/alloutlets',
        queryParameters: {
          'compid': companyId,
          'loginname': "'$username'",
        },
      );

      if (username != usernameController.text.trim()) {
        return;
      }

      final responseData = response.data;
      final datalist = responseData is Map && responseData['datalist'] is List
          ? (responseData['datalist'] as List)
          : const [];

      final mappings = datalist
          .whereType<Map>()
          .map((row) => _OutletCounterMapping.fromMap(Map<String, dynamic>.from(row)))
          .where((mapping) => mapping.outlet.isNotEmpty && mapping.counter.isNotEmpty)
          .toList();

      final uniqueOutlets = mappings
          .map((mapping) => mapping.outlet)
          .toSet()
          .toList()
        ..sort();

      if (!mounted) return;
      setState(() {
        _outletMappings = mappings;
        outlets = uniqueOutlets;
        counter = [];
        selectedOutlet = null;
        selectedCashier = null;
        _isLoadingOutletMappings = false;
        _outletMappingMessage = mappings.isEmpty
            ? 'This username is not mapped to any outlet or counter. You can still sign in.'
            : 'Select your outlet and counter to continue.';
      });
    } catch (_) {
      if (username != usernameController.text.trim() || !mounted) {
        return;
      }

      setState(() {
        _outletMappings = [];
        outlets = [];
        counter = [];
        selectedOutlet = null;
        selectedCashier = null;
        _isLoadingOutletMappings = false;
        _outletMappingMessage =
            'We could not load outlet access right now. You can still sign in if no mapping is required.';
      });
    }
  }

  String _pillayrProductsApiRoot(String baseUrl) {
    final lower = baseUrl.toLowerCase();
    const marker = '/focus8api';
    final markerIndex = lower.indexOf(marker);
    final root = markerIndex >= 0 ? baseUrl.substring(0, markerIndex) : baseUrl;
    return '$root/pillayrpos/api/products';
  }

  void _handleOutletChanged(String? value) {
    final nextCounters = value == null
        ? <String>[]
        : _outletMappings
            .where((mapping) => mapping.outlet == value)
            .map((mapping) => mapping.counter)
            .toSet()
            .toList()
          ..sort();

    setState(() {
      selectedOutlet = value;
      selectedCashier = null;
      counter = nextCounters;
    });
  }

  Future<void> handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = _normalizeBaseUrl(await ApiService().getSavedBaseUrl());
    final companyId = prefs.getString(_companyIdKey)?.trim();
    final companyName = prefs.getString(_companyNameKey)?.trim() ?? '';

    if (username.isEmpty) {
      _showSnackBar('Enter your username to continue.');
      return;
    }
    if (password.isEmpty) {
      _showSnackBar('Enter your password to continue.');
      return;
    }
    if (baseUrl.isEmpty) {
      _showSnackBar('Open Settings and add the API URL before signing in.');
      return;
    }
    if (companyId == null || companyId.isEmpty) {
      _showSnackBar('Open Settings and choose a company before signing in.');
      return;
    }
    if (_requiresOutletSelection && selectedOutlet == null) {
      _showSnackBar('Select your outlet before signing in.');
      return;
    }
    if (_requiresOutletSelection && selectedCashier == null) {
      _showSnackBar('Select your counter before signing in.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService().setBaseUrl(baseUrl);

      if (!await _hasNetworkConnection()) {
        final signedInOffline = await _attemptOfflineLogin(
          username: username,
          password: password,
          companyId: companyId,
        );
        if (signedInOffline || !mounted) {
          return;
        }

        setState(() {
          _errorMessage =
              'wrong username or password';
        });
        _showSnackBar(_errorMessage!);
        return;
      }

      final loginData = await ApiService().login(
        username: username,
        password: password,
        companyId: companyId,
      );

      final loginId = loginData['iLoginId']?.toString() ?? username;
      final loginName = loginData['LoginName']?.toString().trim();
      final employeeName = loginData['EmployeeName']?.toString().trim();
      final sessionId = loginData['fSessionId']?.toString();
      final displayName = (employeeName != null && employeeName.isNotEmpty)
          ? employeeName
          : (loginName != null && loginName.isNotEmpty ? loginName : username);

      await AuthService().login(
        username: username,
        role: AppConstants.roleCashier,
        userId: loginId,
        displayName: displayName,
        token: sessionId,
      );
      await AuthService().saveOfflineLoginCredentials(
        username: username,
        password: password,
        companyId: companyId,
        companyName: companyName,
        role: AppConstants.roleCashier,
        userId: loginId,
        displayName: displayName,
      );

      if (!mounted) return;

      _showSnackBar(
        companyName.isNotEmpty
            ? 'Welcome back, $displayName. You are now signed in to $companyName.'
            : 'Welcome back, $displayName. You are now signed in.',
        backgroundColor: Colors.green.shade600,
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } on ApiException catch (e) {
      if (_canUseOfflineLogin(e)) {
        final signedInOffline = await _attemptOfflineLogin(
          username: username,
          password: password,
          companyId: companyId,
        );
        if (signedInOffline) {
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyLoginErrorMessage(e);
      });
      _showSnackBar(_errorMessage!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No server connection!!';
      });
      _showSnackBar(_errorMessage!);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _hasNetworkConnection() async {
    final dynamic result = await Connectivity().checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }

  Future<bool> _attemptOfflineLogin({
    required String username,
    required String password,
    required String companyId,
  }) async {
    final offlineLogin = await AuthService().tryOfflineLogin(
      username: username,
      password: password,
      companyId: companyId,
    );

    if (offlineLogin == null) {
      return false;
    }

    if (!mounted) {
      return true;
    }

    _showSnackBar(
      offlineLogin.companyName.isNotEmpty
          ? 'You are offline, but we signed you in with the saved ${offlineLogin.companyName} account. Welcome back, ${offlineLogin.displayName}.'
          : 'You are offline, but we signed you in with the details saved on this device. Welcome back, ${offlineLogin.displayName}.',
      backgroundColor: Colors.green.shade600,
    );
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) {
      return true;
    }
    Navigator.pushReplacementNamed(context, '/main');
    return true;
  }

  bool _canUseOfflineLogin(ApiException error) {
    if (error.code == -1) {
      return true;
    }

    final message = error.message.toLowerCase();
    return message.contains('internet') ||
        message.contains('network') ||
        message.contains('timeout') ||
        message.contains('reach the server') ||
        message.contains('offline');
  }

  String _friendlyLoginErrorMessage(ApiException error) {
    if (_canUseOfflineLogin(error)) {
      return 'You are offline right now. Use the same saved username and password to sign in, or reconnect to the internet and try again.';
    }

    final message = error.message.trim();
    if (message.isEmpty) {
      return 'We could not sign you in right now. Please try again.';
    }

    return message;
  }

  @override
  void dispose() {
    _usernameLookupDebounce?.cancel();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Enhanced scale factor that ensures perfect fit while maintaining readability.
  double _scaleFactor(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Base design reference: 780px height.
    // Adjusted range for better readability (0.72 - 0.92) and safety for small devices.
    double scale = (screenHeight / 780).clamp(0.72, 0.92);
    // Slight adjustment for very wide screens to prevent oversized elements.
    if (screenWidth > 600) scale = scale.clamp(0.72, 0.88);
    return scale;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFactor(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.08; // Slightly increased for breathing room

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFEF9F0), // Soft warm peach
              const Color(0xFFFFFFFF), // Pure white at bottom
              const Color(0xFFF5F2ED), // Subtle warm grey
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8 * scale,
                  horizontalPadding,
                  0,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    _LoginSettingsButton(
                      scale: scale,
                      onTap: _openSetupScreen,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.12,
                        alignment: Alignment.center,
                        child: Hero(
                          tag: 'app_logo',
                          child: Container(
                            padding: EdgeInsets.all(4 * scale),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/logo2-removebg-preview.png',
                              height: 76 * scale,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      ModernWelcomeSection(scale: scale),
                      SizedBox(height: 18 * scale),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28 * scale),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12 * scale),
                          child: Column(
                            children: [
                              ModernTextField(
                                controller: usernameController,
                                hintText: 'Username',
                                icon: Icons.person_outline_rounded,
                                isPassword: false,
                                scale: scale,
                              ),
                              SizedBox(height: 12 * scale),
                              ModernTextField(
                                controller: passwordController,
                                hintText: 'Password',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                scale: scale,
                              ),
                              SizedBox(height: 12 * scale),
                              ModernOptionalDropdown(
                                hint: 'Outlet',
                                value: selectedOutlet,
                                items: outlets,
                                onChanged: _handleOutletChanged,
                                icon: Icons.store_outlined,
                                scale: scale,
                                enabled: _isOutletDropdownEnabled,
                              ),
                              SizedBox(height: 12 * scale),
                              ModernOptionalDropdown(
                                hint: 'Counter',
                                value: selectedCashier,
                                items: counter,
                                onChanged: (value) => setState(() => selectedCashier = value),
                                icon: Icons.point_of_sale_outlined,
                                scale: scale,
                                enabled: _isCounterDropdownEnabled,
                              ),
                              if (_outletMappingMessage != null) ...[
                                SizedBox(height: 8 * scale),
                                Row(
                                  children: [
                                    if (_isLoadingOutletMappings)
                                      SizedBox(
                                        height: 14 * scale,
                                        width: 14 * scale,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.orange.shade600,
                                          ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        _requiresOutletSelection
                                            ? Icons.info_outline
                                            : Icons.check_circle_outline,
                                        color: Colors.grey.shade600,
                                        size: 14 * scale,
                                      ),
                                    SizedBox(width: 8 * scale),
                                    Expanded(
                                      child: Text(
                                        _outletMappingMessage!,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12.5 * scale,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              SizedBox(height: 12 * scale),
                              _LoginSetupSummary(
                                scale: scale,
                                isLoading: _isLoadingSetup,
                                baseUrl: _configuredBaseUrl,
                                companyName: _configuredCompanyName,
                                companyCode: _configuredCompanyCode,
                                onTap: _openSetupScreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 18 * scale),
                      ModernLoginButton(
                        onPressed: _isLoading ? () {} : handleLogin,
                        scale: scale,
                      ),
                      SizedBox(height: 10 * scale),
                      if (_isLoading)
                        Center(
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 400),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: SizedBox(
                                  height: 24 * scale,
                                  width: 24 * scale,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.orange.shade600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else if (_errorMessage != null)
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 6 * scale),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 14 * scale,
                              ),
                              SizedBox(width: 8 * scale),
                              Flexible(
                                child: Text(
                                  _errorMessage!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.redAccent.shade700,
                                    fontSize: 13 * scale,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(height: 24 * scale),
                      ModernFooter(scale: scale),
                      SizedBox(height: 12 * scale),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================
// Enhanced Modern UI Components
// ========================

class ModernWelcomeSection extends StatelessWidget {
  final double scale;
  const ModernWelcomeSection({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28 * scale,
              height: 3 * scale,
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(6 * scale),
              ),
            ),
            SizedBox(width: 10 * scale),
            
          ],
        ),
        SizedBox(height: 8 * scale),
        Text(
          'Welcome Back!',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 26 * scale,
            letterSpacing: -0.5,
            color: Colors.black87,
            height: 1.1,
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          'Sign in to continue to your workspace',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 15 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final double scale;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.isPassword,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(
          fontSize: 16.5 * scale,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 22 * scale),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 16.5 * scale,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18 * scale),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18 * scale),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18 * scale),
            borderSide: BorderSide(color: Colors.orange.shade400, width: 1.8),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: 14 * scale,
            horizontal: 16 * scale,
          ),
        ),
      ),
    );
  }
}

class ModernOptionalDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final IconData icon;
  final double scale;
  final bool enabled;

  const ModernOptionalDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.scale,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(
          color: enabled ? Colors.grey.shade200 : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          icon: Icon(
            icon,
            color: enabled ? Colors.grey.shade500 : Colors.grey.shade400,
            size: 22 * scale,
          ),
          hint: Text(
            hint,
            style: TextStyle(
              color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
              fontSize: 16.5 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
          items: [null, ...items].map((item) {
            return DropdownMenuItem<String?>(
              value: item,
              child: Text(
                item ?? hint,
                style: TextStyle(
                  color: enabled ? Colors.black87 : Colors.grey.shade500,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class ModernLoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double scale;

  const ModernLoginButton({
    super.key,
    required this.onPressed,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * scale),
        gradient: LinearGradient(
          colors: [Colors.orange.shade500, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18 * scale),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'LOGIN',
              style: TextStyle(
                fontSize: 17 * scale,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8 * scale),
            Icon(Icons.arrow_forward_rounded, size: 18 * scale),
          ],
        ),
      ),
    );
  }
}

class ModernFooter extends StatelessWidget {
  final double scale;
  const ModernFooter({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Focus SwiftBill • Version 1.0.0',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 11.5 * scale,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LoginSettingsButton extends StatelessWidget {
  const _LoginSettingsButton({
    required this.scale,
    required this.onTap,
  });

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(18 * scale),
      child: InkWell(
        borderRadius: BorderRadius.circular(18 * scale),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12 * scale),
          child: Icon(
            Icons.settings_rounded,
            size: 22 * scale,
            color: const Color(0xFF0D3B66),
          ),
        ),
      ),
    );
  }
}

class _LoginSetupSummary extends StatelessWidget {
  const _LoginSetupSummary({
    required this.scale,
    required this.isLoading,
    required this.baseUrl,
    required this.companyName,
    required this.companyCode,
    required this.onTap,
  });

  final double scale;
  final bool isLoading;
  final String baseUrl;
  final String companyName;
  final String companyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBaseUrl = baseUrl.isNotEmpty;
    final hasCompany = companyName.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(18 * scale),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14 * scale),
        child: isLoading
            ? Row(
                children: [
                  
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                ],
              ),
      ),
    );
  }
}

class _CompanyOption {
  const _CompanyOption({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  factory _CompanyOption.fromMap(Map<String, dynamic> map) {
    return _CompanyOption(
      id: map['CompanyId']?.toString() ?? '',
      name: map['CompanyName']?.toString() ?? '',
      code: map['CompanyCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'CompanyId': id,
      'CompanyName': name,
      'CompanyCode': code,
    };
  }
}

class _OutletCounterMapping {
  const _OutletCounterMapping({
    required this.outlet,
    required this.counter,
  });

  final String outlet;
  final String counter;

  factory _OutletCounterMapping.fromMap(Map<String, dynamic> map) {
    return _OutletCounterMapping(
      outlet: map['outlet']?.toString().trim() ?? '',
      counter: map['countername']?.toString().trim() ?? '',
    );
  }
}
