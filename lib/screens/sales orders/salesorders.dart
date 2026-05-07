import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/contact.dart' as flutter_contacts;
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:focus_swiftbill/services/session_service.dart';
import 'package:focus_swiftbill/services/scanner_service.dart';
import 'package:focus_swiftbill/models/product.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:focus_swiftbill/models/cart_item.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:focus_swiftbill/screens/camera_scanner/camera_scanner_screen.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:focus_swiftbill/providers/orders_provider.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final AuthService _auth = AuthService();
  final SessionService _session = SessionService();
  final TextEditingController _searchController = TextEditingController();
  final Uuid _uuid = const Uuid();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _memberPhoneController = TextEditingController();

  // Dio instance for API calls
  final Dio _apiDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<CartItem> _cart = [];
  Map<String, CartItem> _cartMap = {};
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  int _cartItemCount = 0;
  double _cartSubtotal = 0;
  double _cartTaxTotal = 0;
  double _cartGrandTotal = 0;
  final ValueNotifier<int> _cartVersion = ValueNotifier<int>(0);

  // Scanner service – use local instance (no Provider needed)
  late ScannerService _scannerService;
  String? _activeScanner;
  StreamSubscription<String>? _barcodeSubscription;
  bool _isCameraScannerOpen = false;

  // Customer selection state
  List<Map<String, String>> _members = [];
  Map<String, String>? _selectedMember;

  bool _isProcessing = false;
  bool _isLoadingProducts = true;

  // Dedicated cart box for Sales Orders screen
  late Box<CartItem> _salesCartBox;
  bool _isSalesCartBoxReady = false;

  // Pagination + lazy pricing
  static const int _productsPageSize = 20;
  int _visibleProductCount = _productsPageSize;
  final ScrollController _productsScrollController = ScrollController();

  // Helper constants
  static const String _companyIdKey = 'selected_company_id';
  static const int _priceDetailsBatchSize = 12;
  final Set<String> _loadingProductPriceIds = <String>{};

  @override
  void initState() {
    super.initState();
    _initSalesCartBox();
    _productsScrollController.addListener(_onProductsScroll);
    _loadProducts();
    _loadCart();
    _searchController.addListener(_filterProducts);
    _session.resetTimer();
    _initScannerService();
    _loadMembers().then((_) => _ensureMockMembers());
  }

  void _onProductsScroll() {
    if (!_productsScrollController.hasClients) return;
    if (_visibleProductCount >= _filteredProducts.length) return;
    final pos = _productsScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() {
    if (_visibleProductCount >= _filteredProducts.length) return;
    setState(() {
      _visibleProductCount = (_visibleProductCount + _productsPageSize)
          .clamp(0, _filteredProducts.length);
    });
    unawaited(_fetchVisibleProductPricing(_filteredProducts));
  }

  Future<void> _initSalesCartBox() async {
    _salesCartBox = await DatabaseService.getCartBox('sales_cart');
    _isSalesCartBoxReady = true;
  }

  Future<void> _initScannerService() async {
    _scannerService = ScannerService();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeScanner = prefs.getString('last_scanner');
    });
    _barcodeSubscription = _scannerService.barcodeStream.listen((barcode) {
      if (mounted) {
        _handleBarcodeScanned(barcode);
      }
    });
  }

  @override
  void dispose() {
    if (_isSalesCartBoxReady) {
      try {
        _salesCartBox.clear();
      } catch (e) {
        debugPrint('Error clearing sales cart: $e');
      }
    }
    _cart.clear();
    _cartMap.clear();
    _barcodeSubscription?.cancel();
    _searchController.dispose();
    _memberNameController.dispose();
    _memberPhoneController.dispose();
    _productsScrollController
      ..removeListener(_onProductsScroll)
      ..dispose();
    _scannerService.dispose();
    super.dispose();
  }

  // ==================== API HELPERS (same as billing_screen) ====================

  String _trimTrailingSlash(String value) {
    final normalized = value.trim();
    if (normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _billingApiRootFromBaseUrl(String baseUrl) {
    final normalizedBaseUrl = _trimTrailingSlash(baseUrl);
    final lower = normalizedBaseUrl.toLowerCase();
    const marker = '/focus8api';
    final markerIndex = lower.indexOf(marker);
    final hostRoot = markerIndex >= 0
        ? normalizedBaseUrl.substring(0, markerIndex)
        : normalizedBaseUrl;
    return '$hostRoot/pillayrpos/api/products';
  }

  Future<String> _getSelectedCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString(_companyIdKey)?.trim() ?? '';
    if (companyId.isEmpty) {
      throw Exception('No company selected');
    }
    return companyId;
  }

  Future<String> _getBillingApiRoot() async {
    final savedBaseUrl = await ApiService().getSavedBaseUrl();
    final normalizedBaseUrl = _trimTrailingSlash(savedBaseUrl);
    if (normalizedBaseUrl.isEmpty) {
      throw Exception('Missing base URL');
    }
    return _billingApiRootFromBaseUrl(normalizedBaseUrl);
  }

  List<Map<String, dynamic>> _extractBillingRows(dynamic responseData) {
    if (responseData is Map) {
      final rows = responseData['datalist'];
      if (rows is List) {
        return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      }
    }
    return const [];
  }

  int _parseIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _parseDoubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<List<Product>> _fetchProductsFromApi() async {
    final companyId = await _getSelectedCompanyId();
    final apiRoot = await _getBillingApiRoot();
    final response = await _apiDio.get(
      '$apiRoot/productmaster',
      queryParameters: {'compid': companyId},
    );

    final rows = _extractBillingRows(response.data);
    return rows
        .map(_mapBillingProductRow)
        .where((p) => p.id.trim().isNotEmpty && p.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Product _mapBillingProductRow(Map<String, dynamic> row) {
    final rawQty = _parseIntValue(row['Qty']);
    final stockAvailability =
        row['StockAvailability']?.toString().trim().toLowerCase() == 'yes';
    final normalizedQty = rawQty > 0 ? rawQty : (stockAvailability ? 1 : 0);
    final barcode = row['barcode']?.toString().trim() ?? '';
    final itemCode = row['itemcode']?.toString().trim() ?? '';

    return Product(
      id: row['Id']?.toString() ?? '',
      name: row['product']?.toString().trim() ?? '',
      barcode: barcode.isNotEmpty ? barcode : itemCode,
      price: 0,
      costPrice: 0,
      stockQty: normalizedQty,
      category: 'General',
      isActive: true,
      taxRate: 0,
      currencyCode: '',
    );
  }

  Future<_BillingPriceDetails?> _fetchProductPriceDetails({
    required String apiRoot,
    required String companyId,
    required String itemId,
  }) async {
    final response = await _apiDio.get(
      '$apiRoot/sellingmaster',
      queryParameters: {
        'compid': companyId,
        'itemid': itemId,
      },
    );
    final rows = _extractBillingRows(response.data);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return _BillingPriceDetails(
      price: _parseDoubleValue(row['SellingPrice']),
      taxRate: _parseDoubleValue(row['tax']),
      currencyCode: row['currency']?.toString().trim() ?? '',
    );
  }

  Future<void> _fetchVisibleProductPricing(List<Product> products) async {
    if (products.isEmpty || _visibleProductCount == 0) return;

    final visible =
        products.take(_visibleProductCount.clamp(0, products.length)).toList();
    final productsToLoad = visible.where((p) {
      if (p.id.trim().isEmpty) return false;
      if (_loadingProductPriceIds.contains(p.id)) return false;
      // Skip if already loaded
      return p.price <= 0 && p.currencyCode.trim().isEmpty && p.taxRate <= 0;
    }).toList();

    if (productsToLoad.isEmpty) return;

    String companyId;
    String apiRoot;
    try {
      companyId = await _getSelectedCompanyId();
      apiRoot = await _getBillingApiRoot();
    } catch (e) {
      debugPrint('Pricing prerequisites missing: $e');
      return;
    }

    _loadingProductPriceIds.addAll(productsToLoad.map((p) => p.id));
    try {
      for (var i = 0; i < productsToLoad.length; i += _priceDetailsBatchSize) {
        final batch =
            productsToLoad.skip(i).take(_priceDetailsBatchSize).toList();
        final results = await Future.wait(batch.map((product) async {
          try {
            final details = await _fetchProductPriceDetails(
              apiRoot: apiRoot,
              companyId: companyId,
              itemId: product.id,
            );
            return MapEntry(product.id, details);
          } catch (e) {
            debugPrint('Error loading price for ${product.id}: $e');
            return MapEntry<String, _BillingPriceDetails?>(product.id, null);
          }
        }));

        if (!mounted) return;
        setState(() {
          for (final entry in results) {
            if (entry.value == null) continue;
            for (final p in _products) {
              if (p.id == entry.key) {
                p.price = entry.value!.price;
                p.taxRate = entry.value!.taxRate;
                p.currencyCode = entry.value!.currencyCode;
                break;
              }
            }
          }
        });
      }
    } finally {
      _loadingProductPriceIds.removeAll(productsToLoad.map((p) => p.id));
    }
  }

  // ==================== PRODUCT LOADING (replaced) ====================

  int _availableStockQty(Product product) => product.stockQty;

  int _compareProductsByAvailability(Product a, Product b) {
    final aInStock = _availableStockQty(a) > 0;
    final bInStock = _availableStockQty(b) > 0;
    if (aInStock != bInStock) {
      return aInStock ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final apiProducts = await _fetchProductsFromApi();
      apiProducts.sort(_compareProductsByAvailability);

      if (!mounted) return;
      setState(() {
        _products = apiProducts;
        _filteredProducts = apiProducts;
        _categories = ['All'];
        _visibleProductCount = apiProducts.length < _productsPageSize
            ? apiProducts.length
            : _productsPageSize;
        _isLoadingProducts = false;
      });

      // Lazy-load pricing only for the first visible page; the rest loads on scroll.
      unawaited(_fetchVisibleProductPricing(apiProducts));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    final filtered = _products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(query) ||
          p.barcode.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort(_compareProductsByAvailability);

    setState(() {
      _filteredProducts = filtered;
      _visibleProductCount = filtered.isEmpty
          ? 0
          : (filtered.length < _productsPageSize
              ? filtered.length
              : _productsPageSize);
    });
    unawaited(_fetchVisibleProductPricing(filtered));
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filterProducts();
    });
  }

  // ==================== CART METHODS (unchanged except totals) ====================

  Future<void> _loadCart() async {
    await _initSalesCartBox();
    setState(() {
      _cart = _salesCartBox.values.toList();
      _buildCartMap();
      _updateTotals();
    });
  }

  void _buildCartMap() {
    _cartMap = {};
    for (var item in _cart) {
      _cartMap[item.product.id] = item;
    }
  }

  void _updateTotals() {
    _cartItemCount = _cart.fold(0, (sum, item) => sum + item.quantity);
    _cartSubtotal = _cart.fold(0, (sum, item) => sum + item.total);
    _cartTaxTotal = _cart.fold(0, (sum, item) => sum + (item.total * item.product.taxRate / 100));
    _cartGrandTotal = _cartSubtotal + _cartTaxTotal;
    _cartVersion.value++;
  }

  // Helper to ensure price/tax are loaded before adding to cart
  Future<void> _ensureProductPricingLoaded(Product product) async {
    if (product.price > 0) return;
    try {
      final companyId = await _getSelectedCompanyId();
      final apiRoot = await _getBillingApiRoot();
      final details = await _fetchProductPriceDetails(
        apiRoot: apiRoot,
        companyId: companyId,
        itemId: product.id,
      );
      if (details != null && mounted) {
        setState(() {
          product.price = details.price;
          product.taxRate = details.taxRate;
          product.currencyCode = details.currencyCode;
        });
        unawaited(DatabaseService.getProducts().put(product.id, product));
      }
    } catch (e) {
      debugPrint('Error loading price for ${product.id} on add: $e');
    }
  }

  Future<void> _addToCart(Product product) async {
    await _ensureProductPricingLoaded(product);
    final existingIdx = _cart.indexWhere((c) => c.product.id == product.id);
    CartItem newItem;

    if (existingIdx >= 0) {
      final current = _cart[existingIdx];
      if (current.quantity >= product.stockQty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only ${product.stockQty} in stock'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
        return;
      }
      newItem = CartItem(
        product: product,
        quantity: current.quantity + 1,
        discount: current.discount,
      );
      _cart[existingIdx] = newItem;
      _cartMap[product.id] = newItem;
    } else {
      if (product.stockQty <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Out of stock'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      newItem = CartItem(product: product, quantity: 1, discount: 0);
      _cart.add(newItem);
      _cartMap[product.id] = newItem;
    }

    await _salesCartBox.put(product.id, newItem);
    _updateTotals();
    if (mounted) {
      setState(() {});
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _removeFromCart(Product product) async {
    final idx = _cart.indexWhere((c) => c.product.id == product.id);
    if (idx < 0) return;

    setState(() {
      final current = _cart[idx];
      if (current.quantity > 1) {
        _cart[idx] = CartItem(
          product: product,
          quantity: current.quantity - 1,
          discount: current.discount,
        );
        _cartMap[product.id] = _cart[idx];
      } else {
        _cart.removeAt(idx);
        _cartMap.remove(product.id);
      }
      _updateTotals();
    });

    if (idx < _cart.length) {
      final updatedItem = _cart[idx];
      await _salesCartBox.put(product.id, updatedItem);
    } else {
      await _salesCartBox.delete(product.id);
    }

    if (mounted) {
      HapticFeedback.lightImpact();
    }
  }

  int getCartQuantity(Product product) {
    return _cartMap[product.id]?.quantity ?? 0;
  }

  void _handleBarcodeScanned(String barcode) {
    if (_isCameraScannerOpen) return;
    _addProductByBarcode(barcode);
  }

  Future<void> _addProductByBarcode(String barcode) async {
    try {
      final product = _products.firstWhere((p) => p.barcode == barcode);
      await _addToCart(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${product.name}'),
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product not found: $barcode'),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getScannerDisplayName() {
    if (_activeScanner == null) return 'None';
    if (_activeScanner == ScannerService.camera) return 'Camera';
    if (_activeScanner!.startsWith(ScannerService.bluetoothPrefix)) return 'Bluetooth';
    if (_activeScanner == ScannerService.usb) return 'USB';
    if (_activeScanner!.startsWith(ScannerService.wifiPrefix)) return 'Wi-Fi';
    return _activeScanner!;
  }

  Future<void> _openCameraScanner() async {
    if (!mounted) return;
    setState(() => _isCameraScannerOpen = true);
    final result = await Navigator.pushNamed(
      context,
      '/camera_scanner',
      arguments: {'title': 'Scan Product Barcode'},
    );
    setState(() => _isCameraScannerOpen = false);
    if (result is String && result.isNotEmpty) {
      await _addProductByBarcode(result);
    }
  }

  // ---------- Customer / Member management (unchanged) ----------
  Future<void> _loadMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? rawList = prefs.getStringList('members');
    if (rawList == null) {
      _members = [];
      return;
    }
    try {
      _members = rawList.map((jsonStr) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v.toString()));
      }).toList();
    } catch (e) {
      _members = [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _ensureMockMembers() async {
    if (_members.isNotEmpty) return;
    await _saveMember('John Doe', '0712345678');
    await _saveMember('Jane Smith', '0723456789');
    await _saveMember('Acme Corp', '0734567890');
    await _loadMembers();
    if (mounted) setState(() {});
  }

  Future<void> _showAddMemberDialog() async {
    _memberNameController.clear();
    _memberPhoneController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 4,
        title: Column(
          children: [
            Icon(Icons.person_add_alt_1, color: AppTheme.primaryOrange, size: 36),
            const SizedBox(height: 8),
            const Text(
              'Add Customer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: _memberNameController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter name',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryOrange, size: 20),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: _memberPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter phone number',
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryOrange, size: 20),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () {
              final name = _memberNameController.text.trim();
              final phone = _memberPhoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              _saveMember(name, phone);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer added successfully'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      ),
    );
  }

  Future<void> _showAddFromContactsDialog() async {
    PermissionStatus status = await Permission.contacts.status;
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contacts permission is permanently denied. Please enable it in Settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission to access contacts denied.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    List<flutter_contacts.Contact> contacts;
    try {
      contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load contacts: $e')));
      }
      return;
    }
    final validContacts = contacts.where((c) => c.displayName.isNotEmpty && c.phones.isNotEmpty).toList();
    if (validContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts with phone numbers found.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    final Set<flutter_contacts.Contact> selectedContacts = {};
    String searchQuery = '';
    await showDialog<Set<flutter_contacts.Contact>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = searchQuery.isEmpty
                ? validContacts
                : validContacts.where((c) => c.displayName.toLowerCase().contains(searchQuery.toLowerCase())).toList();
            return AlertDialog(
              title: const Text('Select Contacts'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No contacts match'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (ctx, idx) {
                                final contact = filtered[idx];
                                final phone = contact.phones.first.number;
                                final isSelected = selectedContacts.contains(contact);
                                return CheckboxListTile(
                                  title: Text(contact.displayName, style: const TextStyle(fontSize: 14)),
                                  subtitle: Text(phone, style: const TextStyle(fontSize: 12)),
                                  value: isSelected,
                                  onChanged: (bool? checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selectedContacts.add(contact);
                                      } else {
                                        selectedContacts.remove(contact);
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, selectedContacts),
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result != null && result.isNotEmpty) {
        int added = 0;
        for (final contact in result) {
          final name = contact.displayName;
          final phone = contact.phones.first.number;
          if (phone.isEmpty) continue;
          final exists = _members.any((m) => m['phone'] == phone);
          if (!exists) {
            await _saveMember(name, phone);
            added++;
          }
        }
        if (mounted && added > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added $added customer(s) from contacts.'), behavior: SnackBarBehavior.floating),
          );
        } else if (mounted && added == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new customers added. All selected contacts are already members.'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    });
  }

  Future<void> _saveMember(String name, String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final membersJson = prefs.getStringList('members') ?? [];
      final memberId = _uuid.v4();
      final member = {'id': memberId, 'name': name, 'phone': phone};
      membersJson.add(jsonEncode(member));
      await prefs.setStringList('members', membersJson);
      await _loadMembers();
    } catch (e) {
      debugPrint('Error saving customer: $e');
    }
  }

  // ---------- Create order (updated tax calculation) ----------
  Future<void> _createOrder() async {
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer before placing order'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String orderNumber;
      try {
        orderNumber = await Order.generateOrderNumber().timeout(const Duration(seconds: 10));
        // Override ORD prefix with SRO for sales orders
        if (orderNumber.startsWith('ORD-')) {
          orderNumber = 'SRO' + orderNumber.substring(3);
        }
      } on TimeoutException {
        final now = DateTime.now();
        final dateKey = DateFormat('yyyyMMdd').format(now);
        final timestamp = now.millisecondsSinceEpoch % 100000;
        orderNumber = 'SRO-$dateKey-TIMEOUT-${timestamp.toString().padLeft(5, '0')}';
      }

      final userId = _auth.getUserId();
      final userName = _auth.getUserName();
      final userRole = _auth.getUserRole();
      final customerName = _selectedMember!['name']!;

      final subtotal = _cartSubtotal;
      final tax = _cartTaxTotal;
      final total = subtotal + tax;

      final order = Order(
        id: _uuid.v4(),
        orderNumber: orderNumber,
        userId: userId ?? 'unknown',
        userName: userName ?? 'Unknown',
        userRole: userRole ?? AppConstants.roleCashier,
        items: List.from(_cart),
        subtotal: subtotal,
        tax: tax,
        total: total,
        paymentMethod: 'Pending',
        status: AppConstants.statusCompleted,
        createdAt: DateTime.now(),
        synced: false,
      );

      final ordersBox = DatabaseService.getOrders();
      await ordersBox.put(order.id, order);

      final productsBox = DatabaseService.getProducts();
      for (var item in _cart) {
        final product = productsBox.get(item.product.id);
        if (product != null) {
          product.stockQty -= item.quantity;
          if (product.stockQty < 0) product.stockQty = 0;
          await productsBox.put(product.id, product);
        }
      }

      await _salesCartBox.clear();
      _cart.clear();
      _cartMap.clear();
      _updateTotals();
      if (mounted) setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $orderNumber saved for $customerName'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        Provider.of<OrdersProvider>(context, listen: false).refreshOrders();
        Provider.of<NavigationProvider>(context, listen: false).setIndex(2);
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
          (route) => false,
          arguments: 2,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ==================== UI BUILDERS (unchanged except minor total display) ====================

  Color _getStockColor(int stockQty) {
    if (stockQty == 0) return Colors.grey;
    if (stockQty <= 3) return Colors.red;
    if (stockQty <= 8) return Colors.orange;
    if (stockQty <= 15) return Colors.blue;
    return Colors.green;
  }

  String _formatPercentage(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String get _currencyLabel {
    for (final item in _cart) {
      final code = item.product.currencyCode.trim();
      if (code.isNotEmpty) return code;
    }
    for (final product in _products) {
      final code = product.currencyCode.trim();
      if (code.isNotEmpty) return code;
    }
    return AppConstants.currencySymbol;
  }

  Widget _buildProductCard(Product product) {
    final inStock = product.stockQty > 0;
    final cartQty = getCartQuantity(product);
    final canAdd = inStock && cartQty < product.stockQty;
    final lineTotal = product.price * cartQty;

    return GestureDetector(
      onTap: () {
        if (canAdd) {
          _addToCart(product);
        } else if (!inStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product.name} out of stock'), behavior: SnackBarBehavior.floating),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: inStock ? Colors.grey.shade300 : Colors.red.shade200, width: 1),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: inStock
                        ? [_getStockColor(product.stockQty).withOpacity(0.1), _getStockColor(product.stockQty).withOpacity(0.04)]
                        : [Colors.grey.shade100, Colors.grey.shade50],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.inventory_2, size: 30, color: _getStockColor(product.stockQty).withOpacity(0.35)),
                    ),
                    if (!inStock)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
                          child: Center(
                            child: Text('SOLD OUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5)),
                          ),
                        ),
                      ),
                    if (inStock && product.stockQty <= 5)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.orange.shade300, width: 0.5),
                          ),
                          child: Text('L${product.stockQty}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, height: 1.15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currencyLabel}${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${product.stockQty}',
                      style: TextStyle(
                        color: inStock ? Colors.grey.shade700 : Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (cartQty > 0)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _removeFromCart(product),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.remove, size: 14, color: Colors.red),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 20, height: 20),
                        if (cartQty > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2), width: 0.5),
                            ),
                            child: Text('$cartQty', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange)),
                          )
                        else
                          const Text('0', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                        if (canAdd)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _addToCart(product),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(color: AppTheme.primaryOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.add, size: 14, color: AppTheme.primaryOrange),
                              ),
                            ),
                          )
                        else if (!inStock)
                          const Icon(Icons.block, size: 14, color: Colors.grey)
                        else
                          const SizedBox(width: 20, height: 20),
                      ],
                    ),
                    
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (context, scrollController) => ValueListenableBuilder<int>(
          valueListenable: _cartVersion,
          builder: (context, _, __) => _buildCartSheetBody(scrollController),
        ),
      ),
    );
  }

  Widget _buildCartSheetBody(ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cart ($_cartItemCount)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(icon: const Icon(Icons.close), visualDensity: VisualDensity.compact, onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Cart is empty'),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      final lineTotal = item.product.price * item.quantity;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.inventory_2, size: 20, color: AppTheme.primaryOrange),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            height: 1.25,
                                          ),
                                          softWrap: true,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${_currencyLabel}${item.product.price.toStringAsFixed(2)} • Tax ${_formatPercentage(item.product.taxRate)}%',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _removeFromCart(item.product),
                                          borderRadius: BorderRadius.circular(24),
                                          child: const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: Icon(Icons.remove, size: 16, color: Colors.red),
                                          ),
                                        ),
                                        Container(
                                          constraints: const BoxConstraints(minWidth: 30),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _addToCart(item.product),
                                          borderRadius: BorderRadius.circular(24),
                                          child: const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: Icon(Icons.add, size: 16, color: AppTheme.primaryOrange),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_currencyLabel}${lineTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppTheme.primaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(fontSize: 13)),
                      Text('${_currencyLabel}${_cartSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('${_currencyLabel}${_cartTaxTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        '${_currencyLabel}${_cartGrandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cart.isNotEmpty && !_isProcessing
                          ? () {
                              Navigator.pop(context);
                              _createOrder();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : const Text('Proceed Order', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToDashboard() {
    final navProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    navProvider.setIndex(0);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
      arguments: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final isStandalone = ModalRoute.of(context)?.settings.name == '/salesorders';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToDashboard();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (_activeScanner != null &&
              _activeScanner != ScannerService.camera) {
            _scannerService.handleKeyEvent(event);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Customer selector row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Autocomplete<Map<String, String>>(
                        displayStringForOption: (option) => '${option['name'] ?? ''}  •  ${option['phone'] ?? ''}',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return _members;
                          return _members.where((member) =>
                              member['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                              member['phone']!.contains(textEditingValue.text)).toList();
                        },
                        onSelected: (Map<String, String> selection) {
                          setState(() {
                            _selectedMember = selection;
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onSubmitted: (value) => onFieldSubmitted(),
                            decoration: InputDecoration(
                              hintText: _selectedMember != null
                                  ? '${_selectedMember!['name']}  •  ${_selectedMember!['phone']}'
                                  : 'Search or select customer',
                              prefixIcon: Icon(
                                _selectedMember != null ? Icons.person : Icons.person_outline,
                                size: 18,
                                color: _selectedMember != null ? AppTheme.primaryOrange : Colors.grey,
                              ),
                              suffixIcon: _selectedMember != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        textEditingController.clear();
                                        focusNode.requestFocus();
                                        setState(() {
                                          _selectedMember = null;
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(Icons.person_add, size: 20, color: AppTheme.primaryOrange),
                      tooltip: 'Add new customer',
                      onPressed: _showAddMemberDialog,
                    ),
                    IconButton(
                      icon: Icon(Icons.contacts, size: 20, color: AppTheme.primaryOrange),
                      tooltip: 'Add from Contacts',
                      onPressed: _showAddFromContactsDialog,
                    ),
                  ],
                ),
              ),
              // Search / scan row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search or scan',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.filter_list, size: 20),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Container(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _categories.map((cat) {
                                    return FilterChip(
                                      label: Text(cat, style: const TextStyle(fontSize: 10.5)),
                                      selected: _selectedCategory == cat,
                                      onSelected: (selected) {
                                        setState(() => _selectedCategory = cat);
                                        _filterProducts();
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (_activeScanner != null && _activeScanner != ScannerService.camera)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.scanner, size: 11, color: AppTheme.primaryOrange),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _getScannerDisplayName(),
                            style: TextStyle(fontSize: 10, color: AppTheme.primaryOrange, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                        ? const Center(child: Text('No products found'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 600;
                              final crossAxisCount = isWide ? 4 : 3;
                              final childAspectRatio = isWide ? 0.60 : 0.70;
                              final hPad = isWide ? 14.0 : 12.0;
                              final visibleCount = _visibleProductCount
                                  .clamp(0, _filteredProducts.length);
                              final hasMore =
                                  visibleCount < _filteredProducts.length;
                              return GridView.builder(
                                controller: _productsScrollController,
                                padding: EdgeInsets.symmetric(horizontal: hPad),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: visibleCount + (hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= visibleCount) {
                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Loading more',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return _buildProductCard(_filteredProducts[index]);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCart,
          backgroundColor: AppTheme.primaryOrange,
          icon: const Icon(Icons.shopping_cart, size: 18),
          label: Text('Place Order ($_cartItemCount)', style: const TextStyle(fontSize: 13)),
        ),
        bottomNavigationBar: isStandalone
            ? NavigationBar(
                selectedIndex: navigationProvider.currentIndex,
                onDestinationSelected: (index) {
                  navigationProvider.setIndex(index);
                  Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: index);
                },
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Billing'),
                  NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Sales Orders'),
                  NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Receipts'),
                ],
              )
            : null,
        ),
      ),
    );
  }
}

class _BillingPriceDetails {
  const _BillingPriceDetails({
    required this.price,
    required this.taxRate,
    required this.currencyCode,
  });

  final double price;
  final double taxRate;
  final String currencyCode;
}