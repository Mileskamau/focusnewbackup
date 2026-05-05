import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSettingScreen extends StatefulWidget {
  const AdminSettingScreen({super.key});

  @override
  State<AdminSettingScreen> createState() => _AdminSettingScreenState();
}

class _AdminSettingScreenState extends State<AdminSettingScreen> {
  static const String _baseUrlHistoryKey = 'api_base_url_history';
  static const String _companyCacheKey = 'company_cache_by_base_url';
  static const String _companyIdKey = 'selected_company_id';
  static const String _companyNameKey = 'selected_company_name';
  static const String _companyCodeKey = 'selected_company_code';

  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _baseUrlDebounce;

  List<_CompanyOption> _companies = const [];
  String _searchQuery = '';
  String _activeBaseUrl = '';
  _CompanyOption? _selectedCompany;
  bool _isLoadingCompanies = false;
  bool _isUrlDirty = false;
  bool _isSaving = false;
  String? _errorMessage;
  int _companyLoadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _initializeSetup();
  }

  String _normalizeBaseUrl(String value) {
    final normalized = value.trim();
    if (normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<void> _initializeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = _normalizeBaseUrl(await ApiService().getSavedBaseUrl());
    final selectedCompanyId = prefs.getString(_companyIdKey);

    _baseUrlController.text = savedBaseUrl;

    if (selectedCompanyId != null && selectedCompanyId.isNotEmpty) {
      _selectedCompany = _CompanyOption(
        id: selectedCompanyId,
        name: prefs.getString(_companyNameKey) ?? '',
        code: prefs.getString(_companyCodeKey) ?? '',
      );
    }

    if (!mounted) return;
    setState(() {
      _activeBaseUrl = savedBaseUrl;
      _isUrlDirty = false;
      _errorMessage = null;
    });

    if (savedBaseUrl.isEmpty) {
      return;
    }

    await _loadCompanies(baseUrl: savedBaseUrl);
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
    final requestId = ++_companyLoadRequestId;

    if (targetBaseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _companies = const [];
        _selectedCompany = null;
        _activeBaseUrl = '';
        _isLoadingCompanies = false;
        _isUrlDirty = false;
        _errorMessage = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingCompanies = true;
      _errorMessage = null;
    });

    try {
      await ApiService().setBaseUrl(targetBaseUrl);

      final companies = (await ApiService().getCompanies())
          .map((item) => _CompanyOption.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      await _cacheCompaniesForBaseUrl(targetBaseUrl, companies);
      await _saveBaseUrlHistory(targetBaseUrl);

      _CompanyOption? matchedCompany;
      if (_selectedCompany != null) {
        for (final company in companies) {
          if (company.id == _selectedCompany!.id) {
            matchedCompany = company;
            break;
          }
        }
      }

      if (!mounted || requestId != _companyLoadRequestId) return;
      setState(() {
        _companies = companies;
        _selectedCompany = matchedCompany;
        _activeBaseUrl = targetBaseUrl;
        _isLoadingCompanies = false;
        _isUrlDirty = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      final cachedCompanies = await _getCachedCompaniesForBaseUrl(targetBaseUrl);
      if (!mounted || requestId != _companyLoadRequestId) return;

      if (cachedCompanies.isNotEmpty) {
        setState(() {
          _companies = cachedCompanies;
          _selectedCompany = cachedCompanies.any(
            (company) => company.id == _selectedCompany?.id,
          )
              ? _selectedCompany
              : null;
          _activeBaseUrl = targetBaseUrl;
          _isLoadingCompanies = false;
          _isUrlDirty = false;
          _errorMessage = null;
        });
        return;
      }

      setState(() {
        _companies = const [];
        _isLoadingCompanies = false;
        _isUrlDirty = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      final cachedCompanies = await _getCachedCompaniesForBaseUrl(targetBaseUrl);
      if (!mounted || requestId != _companyLoadRequestId) return;

      if (cachedCompanies.isNotEmpty) {
        setState(() {
          _companies = cachedCompanies;
          _selectedCompany = cachedCompanies.any(
            (company) => company.id == _selectedCompany?.id,
          )
              ? _selectedCompany
              : null;
          _activeBaseUrl = targetBaseUrl;
          _isLoadingCompanies = false;
          _isUrlDirty = false;
          _errorMessage = null;
        });
        return;
      }

      setState(() {
        _companies = const [];
        _isLoadingCompanies = false;
        _isUrlDirty = false;
        _errorMessage = 'Unable to load companies for this API URL.';
      });
    }
  }

  void _onBaseUrlChanged(String value) {
    final normalized = _normalizeBaseUrl(value);
    _baseUrlDebounce?.cancel();

    if (mounted) {
      setState(() {
        _errorMessage = null;
        if (normalized.isEmpty) {
          _companies = const [];
          _selectedCompany = null;
          _isUrlDirty = false;
          return;
        }

        if (normalized != _activeBaseUrl) {
          _companies = const [];
          _selectedCompany = null;
          _isUrlDirty = true;
        }
      });
    }

    if (normalized.isEmpty) {
      return;
    }

    _baseUrlDebounce = Timer(
      const Duration(milliseconds: 700),
      () => _loadCompanies(baseUrl: normalized),
    );
  }

  Future<void> _triggerImmediateLoad() async {
    _baseUrlDebounce?.cancel();
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    if (baseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _companies = const [];
        _selectedCompany = null;
        _isUrlDirty = false;
      });
      return;
    }

    if (baseUrl != _activeBaseUrl && mounted) {
      setState(() {
        _companies = const [];
        _selectedCompany = null;
        _isUrlDirty = true;
      });
    }

    await _loadCompanies(baseUrl: baseUrl);
  }

  Future<void> _saveSetup() async {
    final company = _selectedCompany;
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);

    if (baseUrl.isEmpty) {
      _showSnackBar('Please enter the API URL.');
      return;
    }

    if (baseUrl != _activeBaseUrl) {
      _showSnackBar('Please wait for companies to finish refreshing.');
      return;
    }

    if (_isLoadingCompanies || _isUrlDirty) {
      _showSnackBar('Companies are still loading for this API URL.');
      return;
    }

    if (company == null) {
      _showSnackBar('Please select a company first.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await ApiService().setBaseUrl(baseUrl);
      await _saveBaseUrlHistory(baseUrl);
      await prefs.setString(_companyIdKey, company.id);
      await prefs.setString(_companyNameKey, company.name);
      await prefs.setString(_companyCodeKey, company.code);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      _showSnackBar(
        'Setup saved for ${company.name}.',
        backgroundColor: const Color(0xFF1E8E5A),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showSnackBar('Unable to save setup.');
    }
  }

  List<_CompanyOption> get _filteredCompanies {
    if (_searchQuery.isEmpty) return _companies;

    final query = _searchQuery.toLowerCase();
    return _companies.where((company) {
      return company.name.toLowerCase().contains(query) ||
          company.code.toLowerCase().contains(query) ||
          company.id.toLowerCase().contains(query);
    }).toList();
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.black87}) {
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
    _baseUrlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredCompanies = _filteredCompanies;
    final previewBaseUrl = _normalizeBaseUrl(_baseUrlController.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Setup'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D3B66), Color(0xFF1D6FA5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connection Setup',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedCompany?.name ?? 'Select the API URL and company',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              icon: Icons.link_rounded,
                              label: previewBaseUrl.isNotEmpty
                                  ? previewBaseUrl
                                  : 'API URL not set',
                            ),
                            _InfoChip(
                              icon: Icons.badge_outlined,
                              label: _selectedCompany?.code ?? 'Company pending',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'API URL',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _baseUrlController,
                          keyboardType: TextInputType.url,
                          onChanged: _onBaseUrlChanged,
                          onSubmitted: (_) => _triggerImmediateLoad(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.link_rounded),
                            hintText: 'http://your-server/focus8API',
                            suffixIcon: _isLoadingCompanies
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : _activeBaseUrl.isNotEmpty && !_isUrlDirty
                                    ? const Icon(Icons.cloud_done_outlined)
                                    : const Icon(Icons.sync_rounded),
                            filled: true,
                            fillColor: const Color(0xFFF6F8FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AutoLoadStatusCard(
                          isLoading: _isLoadingCompanies,
                          isDirty: _isUrlDirty,
                          activeBaseUrl: previewBaseUrl.isNotEmpty
                              ? previewBaseUrl
                              : _activeBaseUrl,
                          companyCount: _companies.length,
                          errorMessage: _errorMessage,
                          onRetry: _triggerImmediateLoad,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by company name or code',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Select Company',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${filteredCompanies.length} found',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingCompanies && _companies.isEmpty)
                          const _CompanyLoadingState()
                        else if (filteredCompanies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No companies available for the current API URL.'),
                          )
                        else
                          ...filteredCompanies.map(
                            (company) => RadioListTile<String>(
                              value: company.id,
                              groupValue: _selectedCompany?.id,
                              onChanged: (_) {
                                setState(() {
                                  _selectedCompany = company;
                                });
                              },
                              title: Text(
                                company.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text('Code ${company.code}'),
                              activeColor: const Color(0xFF0D3B66),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveSetup,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D3B66),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Setup'),
                  ),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoLoadStatusCard extends StatelessWidget {
  const _AutoLoadStatusCard({
    required this.isLoading,
    required this.isDirty,
    required this.activeBaseUrl,
    required this.companyCount,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final bool isDirty;
  final String activeBaseUrl;
  final int companyCount;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color accentColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (isLoading) {
      backgroundColor = const Color(0xFFEAF2FB);
      accentColor = const Color(0xFF0D3B66);
      icon = Icons.sync_rounded;
      title = 'Refreshing companies automatically';
      subtitle = 'Checking the server and updating the company list in place.';
    } else if (isDirty) {
      backgroundColor = const Color(0xFFFFF4E5);
      accentColor = const Color(0xFFB26A00);
      icon = Icons.edit_road_rounded;
      title = 'URL changed';
      subtitle = 'Pause typing for a moment and companies will reload on their own.';
    } else if (errorMessage != null && activeBaseUrl.isNotEmpty) {
      backgroundColor = const Color(0xFFFDECEC);
      accentColor = const Color(0xFFB3261E);
      icon = Icons.cloud_off_rounded;
      title = 'Could not refresh companies';
      subtitle = 'Check the API URL or retry the connection.';
    } else if (activeBaseUrl.isNotEmpty && companyCount > 0) {
      backgroundColor = const Color(0xFFE9F7EF);
      accentColor = const Color(0xFF1E8E5A);
      icon = Icons.check_circle_outline_rounded;
      title = 'Companies ready';
      subtitle = '$companyCount companies loaded from the current server.';
    } else {
      backgroundColor = const Color(0xFFF3F4F6);
      accentColor = const Color(0xFF5F6368);
      icon = Icons.info_outline_rounded;
      title = 'Enter your API URL';
      subtitle = 'The company list will appear automatically once the server responds.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          else
            Icon(icon, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: accentColor.withOpacity(0.86),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isLoading && errorMessage != null && activeBaseUrl.isNotEmpty)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _CompanyLoadingState extends StatelessWidget {
  const _CompanyLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Column(
        children: List.generate(
          4,
          (index) => Container(
            height: 68,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}
