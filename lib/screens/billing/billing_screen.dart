import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:focus_swiftbill/services/session_service.dart';
import 'package:focus_swiftbill/services/scanner_service.dart';
import 'package:focus_swiftbill/models/product.dart';
import 'package:focus_swiftbill/models/cart_item.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scanner_selection_dialog.dart';
import 'package:focus_swiftbill/screens/camera_scanner/camera_scanner_screen.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';

class BillingScreen extends StatefulWidget {
  BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  static const String _companyIdKey = 'selected_company_id';
  static const int _productsPageSize = 20;
  static const int _priceDetailsBatchSize = 12;

  final AuthService _auth = AuthService();
  final SessionService _session = SessionService();
  final TextEditingController _searchController = TextEditingController();
  final Uuid _uuid = const Uuid();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _memberPhoneController = TextEditingController();
  final ScrollController _productsScrollController = ScrollController();
  final Dio _billingApiDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  // Focus node for RawKeyboardListener (hardware scanner)
  final FocusNode _keyboardFocusNode = FocusNode();

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
  Timer? _productSyncTimer;
  bool _isLoadingProducts = true;
  bool _isRefreshingProducts = false;
  int _visibleProductCount = _productsPageSize;
  static const int _stockInfoBatchSize = 100;
  final Map<String, ProductStockInfo> _productStockInfoById = {};
  final Set<String> _loadingProductStockIds = <String>{};
  final Set<String> _loadingProductPriceIds = <String>{};

  ScannerService? _scannerService;
  String? _activeScanner;
  StreamSubscription<String>? _barcodeSubscription;
  bool _isCameraScannerOpen = false;

  NavigationProvider? _navigationProvider;

  @override
  void initState() {
    super.initState();
    _productsScrollController.addListener(_onProductsScroll);
    _initializeProducts();
    _loadCart();
    _searchController.addListener(_filterProducts);
    _session.resetTimer();
    _initScannerService();

    // Listen to tab changes (Billing tab is index 1)
    try {
      _navigationProvider = context.read<NavigationProvider>();
      _navigationProvider!.addListener(_onNavigationChanged);
    } catch (_) {}

    // Request focus for RawKeyboardListener so it captures hardware events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  void _onNavigationChanged() {
    if (_navigationProvider!.currentIndex != 1 && _cart.isNotEmpty) {
      _clearCart();
    }
  }

  Future<void> _clearCart() async {
    final cartBox = DatabaseService.getCart();
    await cartBox.clear();
    _cart.clear();
    _cartMap.clear();
    _updateTotals();
    if (mounted) setState(() {});
  }

  Future<void> _initScannerService() async {
    _scannerService = Provider.of<ScannerService>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeScanner = prefs.getString('last_scanner');
    });
    _barcodeSubscription = _scannerService!.barcodeStream.listen((barcode) {
      if (mounted) {
        _handleBarcodeScanned(barcode);
      }
    });
  }

  @override
  void dispose() {
    _navigationProvider?.removeListener(_onNavigationChanged);

    final cartBox = DatabaseService.getCart();
    cartBox.clear();

    _barcodeSubscription?.cancel();
    _searchController.dispose();
    _memberNameController.dispose();
    _memberPhoneController.dispose();
    _productSyncTimer?.cancel();
    _productsScrollController
      ..removeListener(_onProductsScroll)
      ..dispose();
    _keyboardFocusNode.dispose(); // dispose focus node
    super.dispose();
  }

  Future<void> _initializeProducts() async {
    await _loadProducts(syncWithApi: true);
    _startProductSyncSchedule();
  }

  void _startProductSyncSchedule() {
    _productSyncTimer?.cancel();
    _productSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _syncProductsIfDue();
    });
  }

  Future<void> _syncProductsIfDue() async {
    try {
      await _loadProducts(syncWithApi: true);
    } catch (_) {
      // Keep cached products on scheduled sync failure.
    }
  }

  void _onProductsScroll() {
    if (!_productsScrollController.hasClients || !_hasMoreProducts) {
      return;
    }

    final position = _productsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() {
    if (!_hasMoreProducts) return;
    setState(() {
      _visibleProductCount = (_visibleProductCount + _productsPageSize)
          .clamp(0, _filteredProducts.length);
    });
    unawaited(_fetchVisibleProductPricing(_filteredProducts));
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    final filteredProducts = _products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(query) ||
          p.barcode.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort(_compareProductsByAvailability);

    setState(() {
      _filteredProducts = filteredProducts;
      _visibleProductCount = filteredProducts.isEmpty
          ? 0
          : filteredProducts.length < _productsPageSize
              ? filteredProducts.length
              : _productsPageSize;
    });
    unawaited(_fetchVisibleProductPricing(filteredProducts));
  }

  Future<void> _fetchProductStockInfo(
    List<Product> products, {
    bool forceRefresh = false,
  }) async {
    final idsToLoad = <String>[];
    for (final product in products) {
      final productId = product.id.trim();
      if (productId.isEmpty || _loadingProductStockIds.contains(productId)) {
        continue;
      }
      if (!forceRefresh && _productStockInfoById.containsKey(productId)) {
        continue;
      }
      idsToLoad.add(productId);
    }

    if (idsToLoad.isEmpty) {
      return;
    }

    if (forceRefresh) {
      for (final productId in idsToLoad) {
        _productStockInfoById.remove(productId);
      }
    }

    _loadingProductStockIds.addAll(idsToLoad);
    try {
      final stockInfo = <String, ProductStockInfo>{};
      for (var index = 0; index < idsToLoad.length; index += _stockInfoBatchSize) {
        final batch = idsToLoad
            .skip(index)
            .take(_stockInfoBatchSize)
            .toList();
        final batchStockInfo = await ApiService().getStockInformationByProductIds(
          batch,
        );
        stockInfo.addAll(batchStockInfo);
      }
      if (!mounted) return;
      setState(() {
        _productStockInfoById.addAll(stockInfo);
        for (final product in _products) {
          final liveInfo = stockInfo[product.id];
          if (liveInfo == null) continue;
          product.stockQty = liveInfo.availableStockQty;
        }
        for (final item in _cart) {
          final liveInfo = stockInfo[item.product.id];
          if (liveInfo == null) continue;
          item.product.stockQty = liveInfo.availableStockQty;
        }
        _sortProductsByAvailability();
        _updateTotals();
      });
    } catch (error) {
      debugPrint('Unable to load stock information: $error');
    } finally {
      _loadingProductStockIds.removeAll(idsToLoad);
    }
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filterProducts();
    });
  }

  Future<void> _loadProducts({bool syncWithApi = false, bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (_products.isEmpty || forceRefresh) {
          _isLoadingProducts = true;
        }
      });
    }

    if (syncWithApi || forceRefresh) {
      try {
        final products = await _fetchBillingProductsFromApi();
        await DatabaseService.replaceProducts(products);
        if (forceRefresh && mounted) {
          final message = products.isNotEmpty
              ? 'Products refreshed successfully'
              : 'No products were returned';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$message (${products.length} items available)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (forceRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyBillingLoadError(e)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }

    final box = DatabaseService.getProducts();
    final categories = box.values
        .where((p) => p.isActive)
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    categories.insert(0, 'All');
    final products = box.values
        .where((p) => p.isActive)
        .toList()
      ..sort(_compareProductsByAvailability);

    if (!mounted) return;
    setState(() {
      _products = products;
      _categories = categories;
      _isLoadingProducts = false;
      if (forceRefresh) {
        _productStockInfoById.clear();
        _loadingProductPriceIds.clear();
      }
    });
    _filterProducts();
  }

  Future<void> _refreshProducts() async {
    if (_isRefreshingProducts) return;
    setState(() => _isRefreshingProducts = true);
    await _loadProducts(syncWithApi: true, forceRefresh: true);
    if (mounted) {
      setState(() => _isRefreshingProducts = false);
    }
  }

  Future<void> _loadCart() async {
    final box = DatabaseService.getCart();
    setState(() {
      _cart = box.values.toList();
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
    _cartTaxTotal = _cart.fold(0, (sum, item) => sum + _itemTaxAmount(item));
    _cartGrandTotal = _cartSubtotal + _cartTaxTotal;
    _cartVersion.value++;
  }

  int _availableStockQty(Product product) {
    return _productStockInfoById[product.id]?.availableStockQty ??
        product.stockQty;
  }

  double _effectiveUnitPrice(Product product) {
    return product.price;
  }

  double _productTaxRate(Product product) {
    return product.taxRate < 0 ? 0 : product.taxRate;
  }

  double _itemTaxAmount(CartItem item) {
    return item.total * (_productTaxRate(item.product) / 100);
  }

  String _formatPercentage(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  int _compareProductsByAvailability(Product a, Product b) {
    final aInStock = _availableStockQty(a) > 0;
    final bInStock = _availableStockQty(b) > 0;
    if (aInStock != bInStock) {
      return aInStock ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void _sortProductsByAvailability() {
    _products.sort(_compareProductsByAvailability);
    _filteredProducts.sort(_compareProductsByAvailability);
  }

  String _formatProductMetric(num value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String get _currencyLabel {
    for (final item in _cart) {
      final code = item.product.currencyCode.trim();
      if (code.isNotEmpty) {
        return code;
      }
    }
    for (final product in _products) {
      final code = product.currencyCode.trim();
      if (code.isNotEmpty) {
        return code;
      }
    }
    return AppConstants.currencySymbol;
  }

  String _friendlyBillingLoadError(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('company')) {
      return 'Select a company before loading products.';
    }
    if (message.toLowerCase().contains('base url')) {
      return 'Set the API URL before loading products.';
    }
    return 'Unable to load billing products right now.';
  }

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

  Future<List<Product>> _fetchBillingProductsFromApi() async {
    final companyId = await _getSelectedCompanyId();
    final apiRoot = await _getBillingApiRoot();
    final response = await _billingApiDio.get(
      '$apiRoot/productmaster',
      queryParameters: {'compid': companyId},
    );

    final rows = _extractBillingRows(response.data);
    final products = rows
        .map(_mapBillingProductRow)
        .where((product) => product.id.trim().isNotEmpty && product.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return products;
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
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _parseDoubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Product _mapBillingProductRow(Map<String, dynamic> row) {
    final rawQty = _parseIntValue(row['Qty']);
    final stockAvailability = row['StockAvailability']?.toString().trim().toLowerCase() == 'yes';
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

  Future<void> _fetchVisibleProductPricing(
    List<Product> products, {
    bool forceRefresh = false,
  }) async {
    if (products.isEmpty || _visibleProductCount == 0) {
      return;
    }

    final visibleProducts =
        products.take(_visibleProductCount.clamp(0, products.length)).toList();
    final productsToLoad = visibleProducts.where((product) {
      if (product.id.trim().isEmpty || _loadingProductPriceIds.contains(product.id)) {
        return false;
      }
      if (forceRefresh) {
        return true;
      }
      return product.price <= 0 && product.currencyCode.trim().isEmpty && product.taxRate <= 0;
    }).toList();

    if (productsToLoad.isEmpty) {
      return;
    }

    try {
      final companyId = await _getSelectedCompanyId();
      final apiRoot = await _getBillingApiRoot();
      _loadingProductPriceIds.addAll(productsToLoad.map((product) => product.id));

      final updates = <String, _BillingPriceDetails>{};
      for (var index = 0; index < productsToLoad.length; index += _priceDetailsBatchSize) {
        final batch = productsToLoad.skip(index).take(_priceDetailsBatchSize).toList();
        final batchResults = await Future.wait(
          batch.map((product) async {
            final details = await _fetchProductPriceDetails(
              apiRoot: apiRoot,
              companyId: companyId,
              itemId: product.id,
            );
            return MapEntry(product.id, details);
          }),
        );
        for (final entry in batchResults) {
          if (entry.value != null) {
            updates[entry.key] = entry.value!;
          }
        }
      }

      if (updates.isEmpty || !mounted) {
        return;
      }

      final productsBox = DatabaseService.getProducts();
      setState(() {
        for (final product in _products) {
          final details = updates[product.id];
          if (details == null) continue;
          product.price = details.price;
          product.taxRate = details.taxRate;
          product.currencyCode = details.currencyCode;
          unawaited(productsBox.put(product.id, product));
        }

        for (final item in _cart) {
          final details = updates[item.product.id];
          if (details == null) continue;
          item.product.price = details.price;
          item.product.taxRate = details.taxRate;
          item.product.currencyCode = details.currencyCode;
        }

        _updateTotals();
      });
    } catch (error) {
      debugPrint('Unable to load billing product prices: $error');
    } finally {
      _loadingProductPriceIds.removeAll(productsToLoad.map((product) => product.id));
    }
  }

  Future<_BillingPriceDetails?> _fetchProductPriceDetails({
    required String apiRoot,
    required String companyId,
    required String itemId,
  }) async {
    final response = await _billingApiDio.get(
      '$apiRoot/sellingmaster',
      queryParameters: {
        'compid': companyId,
        'itemid': itemId,
      },
    );

    final rows = _extractBillingRows(response.data);
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return _BillingPriceDetails(
      price: _parseDoubleValue(row['SellingPrice']),
      taxRate: _parseDoubleValue(row['tax']),
      currencyCode: row['currency']?.toString().trim() ?? '',
    );
  }

  Future<void> _ensureProductPricingLoaded(Product product) async {
    final alreadyLoaded = product.price > 0 ||
        product.currencyCode.trim().isNotEmpty ||
        product.taxRate > 0;
    if (alreadyLoaded) {
      return;
    }

    try {
      final companyId = await _getSelectedCompanyId();
      final apiRoot = await _getBillingApiRoot();
      final details = await _fetchProductPriceDetails(
        apiRoot: apiRoot,
        companyId: companyId,
        itemId: product.id,
      );
      if (details == null) {
        return;
      }

      product.price = details.price;
      product.taxRate = details.taxRate;
      product.currencyCode = details.currencyCode;
      unawaited(DatabaseService.getProducts().put(product.id, product));
    } catch (error) {
      debugPrint('Unable to load product pricing for ${product.id}: $error');
    }
  }

  Future<void> _addToCart(Product product) async {
    await _ensureProductPricingLoaded(product);
    final cartBox = DatabaseService.getCart();
    final existingIdx = _cart.indexWhere((c) => c.product.id == product.id);
    final availableStock = _availableStockQty(product);
    final unitPrice = _effectiveUnitPrice(product);
    product
      ..stockQty = availableStock
      ..price = unitPrice;
    CartItem newItem;

    if (existingIdx >= 0) {
      final current = _cart[existingIdx];
      if (current.quantity >= availableStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only $availableStock in stock'),
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
      if (availableStock <= 0) {
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

    await cartBox.put(product.id, newItem);
    _updateTotals();
    if (mounted) {
      setState(() {});
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _removeFromCart(Product product) async {
    final cartBox = DatabaseService.getCart();
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
      await cartBox.put(product.id, updatedItem);
    } else {
      await cartBox.delete(product.id);
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
    final normalizedBarcode = barcode.trim();
    try {
      final product = _products.firstWhere(
        (p) =>
            p.barcode.trim() == normalizedBarcode ||
            p.id.trim() == normalizedBarcode,
      );
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
            content: Text('Product not found: $normalizedBarcode'),
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

  Future<void> _showScannerSelection() async {
    _isCameraScannerOpen = false;
    final result = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ScannerSelectionDialog(onScannerSelected: null),
    );
    if (result == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _activeScanner = prefs.getString('last_scanner');
      });
      if (_activeScanner == ScannerService.camera) {
        _openCameraScanner();
      }
    }
  }

  Future<void> _openCameraScanner() async {
  if (!mounted) return;
  setState(() => _isCameraScannerOpen = true);
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const CameraScannerScreen(title: 'Scan Product Barcode'),
    ),
  );
  setState(() => _isCameraScannerOpen = false);
  if (result is String && result.isNotEmpty) {
    await _addProductByBarcode(result);
  }
}
  Future<void> _showAddMemberDialog() async {
    _memberNameController.clear();
    _memberPhoneController.clear();

    final FocusNode nameFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameFocusNode.requestFocus();
    });

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppTheme.primaryOrange, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Add Member',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Member Name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _memberNameController,
              focusNode: nameFocusNode,
              decoration: InputDecoration(
                hintText: 'Enter full name',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryOrange, width: 1.5),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Phone Number',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _memberPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter mobile number',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryOrange, width: 1.5),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: Text(
                '* Both fields are required',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _memberNameController.text.trim();
              final phone = _memberPhoneController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              _saveMember(name, phone);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Member added successfully'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMember(String name, String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final membersJson = prefs.getStringList('members') ?? [];
      final memberId = _uuid.v4();
      final member = {'id': memberId, 'name': name, 'phone': phone};
      membersJson.add(member.toString());
      await prefs.setStringList('members', membersJson);
    } catch (e) {
      debugPrint('Error saving member: $e');
    }
  }

  Color _getStockColor(int stockQty) {
    if (stockQty == 0) return Colors.grey;
    if (stockQty <= 3) return Colors.red;
    if (stockQty <= 8) return Colors.orange;
    if (stockQty <= 15) return Colors.blue;
    return Colors.green;
  }

  bool get _hasMoreProducts => _visibleProductCount < _filteredProducts.length;

  List<Product> get _visibleProducts => _filteredProducts
      .take(_visibleProductCount.clamp(0, _filteredProducts.length))
      .toList();

  Widget _buildProductCard(Product product) {
    final stockInfo = _productStockInfoById[product.id];
    final availableStock = _availableStockQty(product);
    final unitPrice = _effectiveUnitPrice(product);
    final inStock = availableStock > 0;
    final cartQty = getCartQuantity(product);
    final canAdd = inStock && cartQty < availableStock;
    final taxLabel = _formatPercentage(_productTaxRate(product));

    return GestureDetector(
      onTap: () {
        if (canAdd) {
          _addToCart(product);
        } else if (!inStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${product.name} out of stock'), behavior: SnackBarBehavior.floating),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: inStock ? Colors.grey.shade300 : Colors.red.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
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
                        ? [_getStockColor(availableStock).withOpacity(0.1), _getStockColor(availableStock).withOpacity(0.04)]
                        : [Colors.grey.shade100, Colors.grey.shade50],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.inventory_2, size: 30, color: _getStockColor(availableStock).withOpacity(0.35)),
                    ),
                    if (!inStock)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          child: Center(
                            child: Text('SOLD OUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5)),
                          ),
                        ),
                      ),
                    if (inStock && availableStock <= 5)
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
                          child: Text('L$availableStock', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
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
                      '$_currencyLabel${unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: $availableStock',
                      style: TextStyle(
                        color: inStock ? Colors.grey.shade700 : Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    
                    
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
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey), SizedBox(height: 12), Text('Cart is empty')]))
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
                                          '$_currencyLabel${item.product.price.toStringAsFixed(2)} • Tax ${_formatPercentage(_productTaxRate(item.product))}%',
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
                                    '$_currencyLabel${lineTotal.toStringAsFixed(2)}',
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
                      Text('$_currencyLabel${_cartSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('$_currencyLabel${_cartTaxTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        '$_currencyLabel${_cartGrandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cart.isNotEmpty
                          ? () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/payment');
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Proceed to Payment', style: TextStyle(fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    // Use RawKeyboardListener to capture hardware scanner events even when TextField is focused
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: (RawKeyEvent event) {
        // Only handle hardware scanner events (not camera)
        if (_activeScanner != null && _activeScanner != ScannerService.camera) {
          // Forward the raw key event to ScannerService
          _scannerService?.handleRawKeyEvent(event);
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search or scan',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner, size: 18), onPressed: _openCameraScanner),
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
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: _showAddMemberDialog,
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
                      const SizedBox(width: 3),
                      InkWell(onTap: _showScannerSelection, child: Icon(Icons.edit, size: 11, color: AppTheme.primaryOrange)),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _refreshProducts,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 140),
                              Center(child: Text('No products found')),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 600;
                            final crossAxisCount = isWide ? 4 : 3;
                            final childAspectRatio = isWide ? 0.60 : 0.70;
                            final hPad = isWide ? 14.0 : 12.0;
                            return RefreshIndicator(
                              onRefresh: _refreshProducts,
                              child: GridView.builder(
                                controller: _productsScrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: hPad),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _visibleProducts.length + (_hasMoreProducts ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _visibleProducts.length) {
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
                                  return _buildProductCard(_visibleProducts[index]);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCart,
          backgroundColor: AppTheme.primaryOrange,
          icon: const Icon(Icons.shopping_cart, size: 18),
          label: Text('Cart ($_cartItemCount)', style: const TextStyle(fontSize: 13)),
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
