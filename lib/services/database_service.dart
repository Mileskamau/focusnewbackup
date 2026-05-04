import 'package:hive/hive.dart';
import 'package:focus_swiftbill/models/product.dart';
import 'package:focus_swiftbill/models/customer.dart';
import 'package:focus_swiftbill/models/cart_item.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class DatabaseService {
  static const Set<String> _seedProductIds = {
    'p1',
    'p2',
    'p3',
    'p4',
    'p5',
    'p6',
    'p7',
    'p8',
  };

  static late Box<Product> _productsBox;
  static late Box<Customer> _customersBox;
  static late Box<CartItem> _cartBox;          // default cart (used by Billing screen)
  static late Box<Order> _ordersBox;
  static late Box<Order> _pendingBillsBox;
  static late Box<Map> _settingsBox;
  static late Box<Order> _heldOrdersBox;

  // Cache for additional cart boxes (e.g., sales_cart)
  static final Map<String, Box<CartItem>> _customCartBoxes = {};

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(ProductAdapter().typeId)) {
      Hive.registerAdapter(ProductAdapter());
    }
    if (!Hive.isAdapterRegistered(CartItemAdapter().typeId)) {
      Hive.registerAdapter(CartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(OrderAdapter().typeId)) {
      Hive.registerAdapter(OrderAdapter());
    }
    if (!Hive.isAdapterRegistered(CustomerAdapter().typeId)) {
      Hive.registerAdapter(CustomerAdapter());
    }

    _productsBox = await Hive.openBox<Product>('products');
    _customersBox = await Hive.openBox<Customer>('customers');
    _cartBox = await Hive.openBox<CartItem>('cart');          // default cart box
    _ordersBox = await Hive.openBox<Order>('orders');
    _pendingBillsBox = await Hive.openBox<Order>('pending_bills');
    _settingsBox = await Hive.openBox<Map>('settings');
    _heldOrdersBox = await Hive.openBox<Order>('held_orders');

    if (_looksLikeSeedProducts()) {
      await _productsBox.clear();
    }
  }

  static Box<Order> getPendingBills() {
    return Hive.box<Order>('pending_bills');
  }

  static Future<void> replaceProducts(Iterable<Product> products) async {
    final productMap = <String, Product>{};
    for (final product in products) {
      if (product.id.trim().isEmpty || product.name.trim().isEmpty) {
        continue;
      }
      productMap[product.id] = product;
    }

    await _productsBox.clear();
    if (productMap.isNotEmpty) {
      await _productsBox.putAll(productMap);
    }
  }

  static Box<Product> getProducts() => _productsBox;
  static Box<Customer> getCustomers() => _customersBox;
  
  /// Default cart box (used by Billing screen)
  static Box<CartItem> getCart() => _cartBox;
  
  /// Get a custom cart box by name (e.g., 'sales_cart').
  /// Boxes are cached after first open.
  static Future<Box<CartItem>> getCartBox(String name) async {
    if (_customCartBoxes.containsKey(name)) {
      return _customCartBoxes[name]!;
    }
    final box = await Hive.openBox<CartItem>(name);
    _customCartBoxes[name] = box;
    return box;
  }

  static Box<Order> getOrders() => _ordersBox;
  static Box<Order> getPendingOrders() => _pendingBillsBox;
  static Box<Map> getSettings() => _settingsBox;
  static Box<Order> getHeldOrders() => _heldOrdersBox;

  static List<Product> getTopSellingProducts({int limit = 5}) {
    final orders = _ordersBox.values.toList();
    final Map<String, int> salesCount = {};
    
    for (var order in orders) {
      if (order.status == AppConstants.statusCompleted) {
        for (var item in order.items) {
          final productId = item.product.id;
          salesCount[productId] = (salesCount[productId] ?? 0) + item.quantity;
        }
      }
    }
    
    final products = _productsBox.values.toList();
    products.sort((a, b) {
      final aCount = salesCount[a.id] ?? 0;
      final bCount = salesCount[b.id] ?? 0;
      return bCount.compareTo(aCount);
    });
    
    return products.take(limit).toList();
  }

  static void clearAll() {
    _productsBox.clear();
    _customersBox.clear();
    _cartBox.clear();
    _ordersBox.clear();
    _pendingBillsBox.clear();
    _settingsBox.clear();
    _heldOrdersBox.clear();
    // Also clear any custom cart boxes
    for (var box in _customCartBoxes.values) {
      box.clear();
    }
    _customCartBoxes.clear();
  }

  static bool _looksLikeSeedProducts() {
    if (_productsBox.isEmpty || _productsBox.length > _seedProductIds.length) {
      return false;
    }

    return _productsBox.keys.every((key) => _seedProductIds.contains(key.toString()));
  }
}
