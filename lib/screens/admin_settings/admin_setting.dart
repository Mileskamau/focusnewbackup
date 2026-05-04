import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSettingScreen extends StatefulWidget {
  const AdminSettingScreen({super.key});

  @override
  State<AdminSettingScreen> createState() => _AdminSettingScreenState();
}

class _AdminSettingScreenState extends State<AdminSettingScreen> {
  static const String _companyIdKey = 'selected_company_id';
  static const String _companyNameKey = 'selected_company_name';
  static const String _companyCodeKey = 'selected_company_code';

  final TextEditingController _searchController = TextEditingController();

  List<_CompanyOption> _companies = const [];
  String _searchQuery = '';
  _CompanyOption? _selectedCompany;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString(_companyIdKey);
      final response = await ApiService().getCompanies();

      final companies = response
          .map((item) => _CompanyOption.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      _CompanyOption? selectedCompany;
      if (selectedId != null) {
        for (final company in companies) {
          if (company.id == selectedId) {
            selectedCompany = company;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _companies = companies;
        _selectedCompany = selectedCompany;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCompany() async {
    final company = _selectedCompany;
    if (company == null) {
      _showSnackBar('Please select a company first.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_companyIdKey, company.id);
      await prefs.setString(_companyNameKey, company.name);
      await prefs.setString(_companyCodeKey, company.code);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      _showSnackBar(
        '${company.name} has been set as the active company.',
        backgroundColor: const Color(0xFF1E8E5A),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showSnackBar('Unable to save company configuration.');
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredCompanies = _filteredCompanies;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Company Configuration'),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadCompanies,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
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
                              'Active Company',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedCompany?.name ?? 'No company selected',
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
                                  icon: Icons.badge_outlined,
                                  label: _selectedCompany?.code ?? 'Code pending',
                                ),
                                
                              ],
                            ),
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
                          hintText: 'Search by company name, code',
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
                            if (filteredCompanies.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No companies match your search.'),
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
                                  subtitle: Text(
                                    'Code ${company.code}  |',
                                  ),
                                  activeColor: const Color(0xFF0D3B66),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSaving ? null : _saveCompany,
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
                            : const Text('Save Company Configuration'),
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
