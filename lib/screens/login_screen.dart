import 'dart:async';
import 'dart:convert';

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
  static const String _baseUrlHistoryKey = 'api_base_url_history';
  static const String _companyCacheKey = 'company_cache_by_base_url';
  static const String _companyIdKey = 'selected_company_id';
  static const String _companyNameKey = 'selected_company_name';
  static const String _companyCodeKey = 'selected_company_code';

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _adminUserController = TextEditingController();
  final TextEditingController _adminPassController = TextEditingController();
  final GlobalKey<FormState> _adminFormKey = GlobalKey<FormState>();
  Timer? _baseUrlDebounce;
  bool rememberMe = false;
  bool _isLoading = false;
  bool _isLoadingCompanies = false;
  String? _errorMessage;

  String? selectedOutlet;
  String? selectedCashier;
  _CompanyOption? _selectedCompany;
  final List<String> outlets = ['PAPA PILLAYR'];
  final List<String> counter = ['PPS COUNTER 1'];
  final List<String> counter2 = ['Cashier 1', 'Cashier 2'];
  List<_CompanyOption> _companies = const [];
  String _activeBaseUrl = '';
  int _companyLoadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _initializeLoginConfiguration();
  }

  Future<void> _initializeLoginConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = _normalizeBaseUrl(await ApiService().getSavedBaseUrl());
    final selectedCompanyId = prefs.getString(_companyIdKey);

    _activeBaseUrl = savedBaseUrl;
    _baseUrlController.text = savedBaseUrl;

    if (selectedCompanyId != null) {
      final savedCompanyName = prefs.getString(_companyNameKey) ?? '';
      final savedCompanyCode = prefs.getString(_companyCodeKey) ?? '';
      _selectedCompany = _CompanyOption(
        id: selectedCompanyId,
        name: savedCompanyName,
        code: savedCompanyCode,
      );
    }

    if (mounted) {
      setState(() {});
    }

    await _loadCompanies();
  }

  String _normalizeBaseUrl(String value) {
    final normalized = value.trim();
    if (normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<void> _saveBaseUrlHistory(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_baseUrlHistoryKey) ?? <String>[];
    history.removeWhere((item) => item == baseUrl);
    history.insert(0, baseUrl);
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }
    await prefs.setStringList(_baseUrlHistoryKey, history);
  }

  Future<void> _cacheCompaniesForBaseUrl(
    String baseUrl,
    List<_CompanyOption> companies,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawCache = prefs.getString(_companyCacheKey);
    Map<String, dynamic> cache = <String, dynamic>{};

    if (rawCache != null && rawCache.isNotEmpty) {
      try {
        cache = Map<String, dynamic>.from(jsonDecode(rawCache) as Map);
      } catch (_) {
        cache = <String, dynamic>{};
      }
    }

    cache[baseUrl] = companies.map((company) => company.toMap()).toList();
    await prefs.setString(_companyCacheKey, jsonEncode(cache));
  }

  Future<List<_CompanyOption>> _getCachedCompaniesForBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final rawCache = prefs.getString(_companyCacheKey);
    if (rawCache == null || rawCache.isEmpty) {
      return const [];
    }

    try {
      final cache = Map<String, dynamic>.from(jsonDecode(rawCache) as Map);
      final cachedCompanies = cache[baseUrl];
      if (cachedCompanies is! List) {
        return const [];
      }

      return cachedCompanies
          .map((item) => _CompanyOption.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadCompanies({String? baseUrl}) async {
    final targetBaseUrl = _normalizeBaseUrl(baseUrl ?? _baseUrlController.text);
    if (targetBaseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _companies = const [];
        _selectedCompany = null;
        _isLoadingCompanies = false;
        _errorMessage = null;
      });
      return;
    }

    final requestId = ++_companyLoadRequestId;
    setState(() {
      _isLoadingCompanies = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedCompanyId = prefs.getString(_companyIdKey);
      await ApiService().setBaseUrl(targetBaseUrl);
      final companies = (await ApiService().getCompanies())
          .map((item) => _CompanyOption.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      await _cacheCompaniesForBaseUrl(targetBaseUrl, companies);

      _CompanyOption? matchedCompany = _selectedCompany;
      if (selectedCompanyId != null) {
        for (final company in companies) {
          if (company.id == selectedCompanyId) {
            matchedCompany = company;
            break;
          }
        }
      }

      if (!mounted || requestId != _companyLoadRequestId) return;
      setState(() {
        _companies = companies;
        _selectedCompany = matchedCompany;
        _isLoadingCompanies = false;
        _errorMessage = null;
        _activeBaseUrl = targetBaseUrl;
      });
    } on ApiException catch (e) {
      final cachedCompanies = await _getCachedCompaniesForBaseUrl(targetBaseUrl);
      if (!mounted || requestId != _companyLoadRequestId) return;
      if (cachedCompanies.isNotEmpty) {
        setState(() {
          _companies = cachedCompanies;
          _selectedCompany = cachedCompanies.any(
                  (company) => company.id == _selectedCompany?.id)
              ? _selectedCompany
              : null;
          _isLoadingCompanies = false;
          _errorMessage = null;
          _activeBaseUrl = targetBaseUrl;
        });
        return;
      }

      setState(() {
        _companies = const [];
        _isLoadingCompanies = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      final cachedCompanies = await _getCachedCompaniesForBaseUrl(targetBaseUrl);
      if (!mounted || requestId != _companyLoadRequestId) return;
      if (cachedCompanies.isNotEmpty) {
        setState(() {
          _companies = cachedCompanies;
          _selectedCompany = cachedCompanies.any(
                  (company) => company.id == _selectedCompany?.id)
              ? _selectedCompany
              : null;
          _isLoadingCompanies = false;
          _errorMessage = null;
          _activeBaseUrl = targetBaseUrl;
        });
        return;
      }

      setState(() {
        _companies = const [];
        _isLoadingCompanies = false;
        _errorMessage = 'Unable to load companies';
      });
    }
  }

  Future<void> _handleBaseUrlChanged({bool force = false}) async {
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    if (baseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _activeBaseUrl = '';
        _companies = const [];
        _selectedCompany = null;
        _errorMessage = null;
        _isLoadingCompanies = false;
      });
      return;
    }

    if (!force && baseUrl == _activeBaseUrl) {
      return;
    }

    await ApiService().setBaseUrl(baseUrl);
    await _saveBaseUrlHistory(baseUrl);

    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      _selectedCompany = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_companyIdKey);
    await prefs.remove(_companyNameKey);
    await prefs.remove(_companyCodeKey);

    await _loadCompanies(baseUrl: baseUrl);
  }

  void _onBaseUrlInputChanged(String _) {
    _baseUrlDebounce?.cancel();
    _baseUrlDebounce = Timer(
      const Duration(milliseconds: 700),
      () => _handleBaseUrlChanged(),
    );
  }

  Future<void> _saveSelectedCompany(_CompanyOption company) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyIdKey, company.id);
    await prefs.setString(_companyNameKey, company.name);
    await prefs.setString(_companyCodeKey, company.code);
  }

  Future<void> handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);

    if (username.isEmpty) {
      _showSnackBar('Please enter username');
      return;
    }
    if (password.isEmpty) {
      _showSnackBar('Please enter password');
      return;
    }
    if (baseUrl.isEmpty) {
      _showSnackBar('Please enter base URL');
      return;
    }
    if (_selectedCompany == null) {
      _showSnackBar('Please select a company');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService().setBaseUrl(baseUrl);
      await _saveBaseUrlHistory(baseUrl);

      final loginData = await ApiService().login(
        username: username,
        password: password,
        companyId: _selectedCompany!.id,
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

      if (!mounted) return;

      _showSnackBar(
        'Login successful. Welcome $displayName.',
        backgroundColor: Colors.green.shade600,
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message.isNotEmpty
            ? e.message
            : 'Incorrect username or password';
      });
      _showSnackBar(_errorMessage!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to login. Please try again.';
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

  @override
  void dispose() {
    _baseUrlDebounce?.cancel();
    usernameController.dispose();
    passwordController.dispose();
    _baseUrlController.dispose();
    _adminUserController.dispose();
    _adminPassController.dispose();
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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Enhanced Logo Container with soft shadow
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

                // Welcome Section with subtle divider and enhanced typography
                ModernWelcomeSection(scale: scale),
                SizedBox(height: 18 * scale),

                // Form Container with subtle card effect (no scroll, just visual grouping)
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
                          onChanged: (value) => setState(() => selectedOutlet = value),
                          icon: Icons.store_outlined,
                          scale: scale,
                        ),
                        SizedBox(height: 12 * scale),

                        ModernOptionalDropdown(
                          hint: 'Counter',
                          value: selectedCashier,
                          items: counter,
                          onChanged: (value) => setState(() => selectedCashier = value),
                          icon: Icons.point_of_sale_outlined,
                          scale: scale,
                        ),
                        SizedBox(height: 12 * scale),

                        _CompactBaseUrlField(
                          controller: _baseUrlController,
                          scale: scale,
                          isLoading: _isLoadingCompanies,
                          onChanged: _onBaseUrlInputChanged,
                          onSubmitted: (_) => _handleBaseUrlChanged(force: true),
                        ),
                        SizedBox(height: 12 * scale),

                        _ModernCompanyDropdown(
                          companies: _companies,
                          selectedCompany: _selectedCompany,
                          isLoading: _isLoadingCompanies,
                          scale: scale,
                          onChanged: (company) async {
                            if (company == null) return;
                            await _saveSelectedCompany(company);
                            if (!mounted) return;
                            setState(() => _selectedCompany = company);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 18 * scale),

                // Login button & loading / error area
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
                        Icon(Icons.error_outline, color: Colors.redAccent, size: 14 * scale),
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

                // Footer version
                ModernFooter(scale: scale),
                SizedBox(height: 12 * scale),
              ],
            ),
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

  const ModernOptionalDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
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
          icon: Icon(icon, color: Colors.grey.shade500, size: 22 * scale),
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.grey.shade600,
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
                  color: Colors.black87,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
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

class _CompactBaseUrlField extends StatelessWidget {
  const _CompactBaseUrlField({
    required this.controller,
    required this.scale,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final double scale;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: Colors.grey.shade500, size: 22 * scale),
          SizedBox(width: 12 * scale),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: TextStyle(
                fontSize: 16.5 * scale,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Base URL',
                hintStyle: TextStyle(
                  fontSize: 16.5 * scale,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (isLoading)
            SizedBox(
              height: 20 * scale,
              width: 20 * scale,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade400),
              ),
            )
          else
            Icon(
              Icons.cloud_done_outlined,
              color: Colors.grey.shade400,
              size: 20 * scale,
            ),
          SizedBox(width: 6 * scale),
        ],
      ),
    );
  }
}

class _ModernCompanyDropdown extends StatelessWidget {
  const _ModernCompanyDropdown({
    required this.companies,
    required this.selectedCompany,
    required this.isLoading,
    required this.scale,
    required this.onChanged,
  });

  final List<_CompanyOption> companies;
  final _CompanyOption? selectedCompany;
  final bool isLoading;
  final double scale;
  final ValueChanged<_CompanyOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.apartment_rounded, color: Colors.grey.shade500, size: 22 * scale),
          SizedBox(width: 12 * scale),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_CompanyOption>(
                value: companies.any((company) => company.id == selectedCompany?.id)
                    ? selectedCompany
                    : null,
                isExpanded: true,
                icon: isLoading
                    ? SizedBox(
                        height: 20 * scale,
                        width: 20 * scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade400),
                        ),
                      )
                    : Icon(Icons.keyboard_arrow_down_rounded, size: 24 * scale),
                hint: Text(
                  isLoading ? 'Loading companies...' : 'Select company',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16.5 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: companies.map((company) {
                  return DropdownMenuItem<_CompanyOption>(
                    value: company,
                    child: Text(
                      '${company.code} - ${company.name}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: isLoading ? null : onChanged,
              ),
            ),
          ),
        ],
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
