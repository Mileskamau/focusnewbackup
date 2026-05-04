import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/contact.dart' as flutter_contacts;
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:focus_swiftbill/services/product_sync_service.dart';
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
import 'package:flutter_contacts/flutter_contacts.dart'; // Updated contacts package
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
  final ScrollController _productsScrollController = ScrollController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<CartItem> _cart = [];
  Map<String, CartItem> _cartMap = {};
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  int _cartItemCount = 0;
  double _cartTotal = 0;
  final ValueNotifier<int> _cartVersion = ValueNotifier<int>(0);

  // Scanner service – use local instance (no Provider needed)
  late ScannerService _scannerService;
  String? _activeScanner;
  StreamSubscription<String>? _barcodeSubscription;
  bool _isCameraScannerOpen = false;

  // Customer selection state
  List<Map<String, String>> _members = [];
  Map<String, String>? _selectedMember;
  // Removed unused _customerSearchController

  bool _isProcessing = false;
  bool _isLoadingProducts = true;
  bool _isRefreshingProducts = false;
  int _visibleProductCount = ProductSyncService.pageSize;
  Timer? _productSyncTimer;
  final Map<String, ProductStockInfo> _productStockInfoById = {};
  final Set<String> _loadingProductStockIds = <String>{};

  // Dedicated cart box for Sales Orders screen
  late Box<CartItem> _salesCartBox;
  bool _isSalesCartBoxReady = false;   // <-- flag for safe clearing

  @override
  void initState() {
    super.initState();
    _initSalesCartBox();
    _productsScrollController.addListener(_onProductsScroll);
    _initializeProducts();
    _loadCart();
    _searchController.addListener(_filterProducts);
    _session.resetTimer();
    _initScannerService();
    _loadMembers().then((_) => _ensureMockMembers());
  }

  Future<void> _initSalesCartBox() async {
    // Use a separate box for sales orders (isolated from billing screen)
    _salesCartBox = await DatabaseService.getCartBox('sales_cart');
    _isSalesCartBoxReady = true;       // <-- mark as ready
  }

  Future<void> _initScannerService() async {
    _scannerService = ScannerService(); // local instance
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
    // ✅ Clear the dedicated sales cart when leaving the screen
    if (_isSalesCartBoxReady) {
      try {
        _salesCartBox.clear();
      } catch (e) {
        debugPrint('Error clearing sales cart: $e');
      }
    }

    // Clear in‑memory cart as well (optional, but clean)
    _cart.clear();
    _cartMap.clear();

    _barcodeSubscription?.cancel();
    _searchController.dispose();
    _memberNameController.dispose();
    _memberPhoneController.dispose();
    // _customerSearchController.dispose() removed
    _productSyncTimer?.cancel();
    _productsScrollController
      ..removeListener(_onProductsScroll)
      ..dispose();
    _scannerService.dispose();
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
      final result = await ProductSyncService().ensureProductsLoaded();
      if (result.usedRemoteData && mounted) {
        await _loadProducts();
      }
    } catch (_) {
      // Preserve cached products if background sync fails.
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
      _visibleProductCount = (_visibleProductCount + ProductSyncService.pageSize)
          .clamp(0, _filteredProducts.length);
    });
    _fetchVisibleProductStockInfo();
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
          : filteredProducts.length < ProductSyncService.pageSize
              ? filteredProducts.length
              : ProductSyncService.pageSize;
    });
    _fetchVisibleProductStockInfo();
  }

  Future<void> _fetchVisibleProductStockInfo({bool forceRefresh = false}) async {
    final idsToLoad = <String>[];
    for (final product in _visibleProducts) {
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
      final stockInfo = await ApiService().getStockInformationByProductIds(
        idsToLoad,
      );
      if (!mounted) return;
      setState(() {
        _productStockInfoById.addAll(stockInfo);
        for (final product in _products) {
          final liveInfo = stockInfo[product.id];
          if (liveInfo == null) continue;
          product.stockQty = liveInfo.availableStockQty;
          if (liveInfo.avgRate > 0) {
            product.price = liveInfo.avgRate;
          }
        }
        for (final item in _cart) {
          final liveInfo = stockInfo[item.product.id];
          if (liveInfo == null) continue;
          item.product.stockQty = liveInfo.availableStockQty;
          if (liveInfo.avgRate > 0) {
            item.product.price = liveInfo.avgRate;
          }
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
        final result = await ProductSyncService().ensureProductsLoaded(
          forceRefresh: forceRefresh,
        );
        if (forceRefresh && mounted) {
          final message = result.usedRemoteData
              ? 'Products refreshed successfully'
              : 'Products are already up to date';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$message (${result.productCount} items available)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } on ApiException catch (e) {
        if (forceRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (_) {
        if (forceRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to refresh products right now'),
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
    // Ensure _salesCartBox is initialized
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
    _cartTotal = _cart.fold(0, (sum, item) => sum + item.total);
    _cartVersion.value++;
  }

  int _availableStockQty(Product product) {
    return _productStockInfoById[product.id]?.availableStockQty ??
        product.stockQty;
  }

  double _effectiveUnitPrice(Product product) {
    final livePrice = _productStockInfoById[product.id]?.avgRate ?? 0;
    return livePrice > 0 ? livePrice : product.price;
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

  Future<void> _addToCart(Product product) async {
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

  // ---------- Customer / Member management ----------
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

  // NEW METHOD: Add from Contacts dialog (using flutter_contacts)
  Future<void> _showAddFromContactsDialog() async {
  // Check current permission status
  PermissionStatus status = await Permission.contacts.status;

  // If permanently denied, guide user to settings and stop
  if (status.isPermanentlyDenied) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Contacts permission is permanently denied. Please enable it in Settings.'),
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

  // Request permission (system dialog will appear if not yet asked or denied once)
  if (!await FlutterContacts.requestPermission(readonly: true)) {
    // If after request it's still denied (possibly user denied again)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission to access contacts denied.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  // Fetch contacts
  List<flutter_contacts.Contact> contacts;
  try {
    contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load contacts: $e')),
      );
    }
    return;
  }

  // Filter to those with a display name and at least one phone number
  final validContacts = contacts.where((c) {
    return c.displayName.isNotEmpty && c.phones.isNotEmpty;
  }).toList();

  if (validContacts.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No contacts with phone numbers found.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  // Local state for the dialog
  final Set<flutter_contacts.Contact> selectedContacts = {};
  String searchQuery = '';

  // Show dialog
  await showDialog<Set<flutter_contacts.Contact>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = searchQuery.isEmpty
              ? validContacts
              : validContacts
                  .where((c) => c.displayName
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()))
                  .toList();

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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
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
                              final isSelected =
                                  selectedContacts.contains(contact);

                              return CheckboxListTile(
                                title: Text(contact.displayName,
                                    style: const TextStyle(fontSize: 14)),
                                subtitle: Text(phone,
                                    style: const TextStyle(fontSize: 12)),
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
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
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
          SnackBar(
            content: Text('Added $added customer(s) from contacts.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted && added == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No new customers added. All selected contacts are already members.'),
            behavior: SnackBarBehavior.floating,
          ),
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

  // ---------- Create order directly (no payment) ----------
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
    } on TimeoutException {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyyMMdd').format(now);
      final timestamp = now.millisecondsSinceEpoch % 100000;
      orderNumber = 'ORD-$dateKey-TIMEOUT-${timestamp.toString().padLeft(5, '0')}';
    }

    final userId = _auth.getUserId();
    final userName = _auth.getUserName();
    final userRole = _auth.getUserRole();
    final customerName = _selectedMember!['name']!;

    final subtotal = _cartTotal;
    final tax = subtotal * AppConstants.taxRate;
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

    // Clear the sales cart after order is placed
    await _salesCartBox.clear();
    _cart.clear();
    _cartMap.clear();
    _updateTotals();   // updates _cartVersion, _cartItemCount, _cartTotal
    if (mounted) setState(() {});   // refresh UI

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderNumber saved for $customerName'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Notify OrdersScreen to refresh its list
      Provider.of<OrdersProvider>(context, listen: false).refreshOrders();

      // Switch to Orders tab (index 2) and return to main screen
      Provider.of<NavigationProvider>(context, listen: false).setIndex(2);
      Navigator.pop(context);
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
    final lineTotal = unitPrice * cartQty;

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
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
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
                      '${AppConstants.currencySymbol}${unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qty: ${stockInfo != null ? _formatProductMetric(stockInfo.quantity) : '$availableStock'}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: inStock ? Colors.grey.shade700 : Colors.red.shade300,
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
                    if (cartQty > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          Text('${AppConstants.currencySymbol}${lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green)),
                        ],
                      ),
                    ],
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
  final taxRate = AppConstants.taxRate;
  final taxPercent = (taxRate * 100).toInt();
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
              Text('Cart ($_cartItemCount)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.close),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
              ),
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
                      Icon(Icons.shopping_cart_outlined,
                          size: 48, color: Colors.grey),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.inventory_2,
                              size: 20, color: AppTheme.primaryOrange),
                        ),
                        title: Text(
                          item.product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${AppConstants.currencySymbol}${item.product.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 18),
                              onPressed: () => _removeFromCart(item.product),
                              color: Colors.red,
                            ),
                            Text('${item.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 18),
                              onPressed: () => _addToCart(item.product),
                              color: AppTheme.primaryOrange,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // ✅ Wrap bottom container with SafeArea to avoid system navigation overlap
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 13)),
                    Text(
                      '${AppConstants.currencySymbol}${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tax ($taxPercent%)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${AppConstants.currencySymbol}${(_cartTotal * taxRate).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      '${AppConstants.currencySymbol}${(_cartTotal * (1 + taxRate)).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryOrange),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
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

  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final isStandalone = ModalRoute.of(context)?.settings.name == '/salesorders';

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (_activeScanner != null && _activeScanner != ScannerService.camera) {
          _scannerService.handleKeyEvent(event);
        }
        return KeyEventResult.handled;
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
                        displayStringForOption: (option) =>
                          '${option['name'] ?? ''}  •  ${option['phone'] ?? ''}',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return _members;
                          return _members.where((member) =>
                              member['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                              member['phone']!.contains(textEditingValue.text)).toList();
                        },
                        onSelected: (Map<String, String> selection) {
                          setState(() {
                            _selectedMember = selection;
                            // No need to manually set controller text; Autocomplete handles it
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
                                        // Clear the Autocomplete's internal controller
                                        textEditingController.clear();
                                        // Refocus to show the options list again
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
                    // NEW BUTTON: Add from Contacts
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
    );
  }
}
