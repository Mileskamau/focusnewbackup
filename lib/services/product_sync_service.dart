import 'package:flutter/foundation.dart';
import 'package:focus_swiftbill/models/product.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductSyncResult {
  const ProductSyncResult({
    required this.productCount,
    required this.usedRemoteData,
  });

  final int productCount;
  final bool usedRemoteData;
}

enum ProductCatalogSource {
  defaultCatalog,
  sellerPriceBook,
}

class ProductSyncService {
  ProductSyncService._internal();

  static final ProductSyncService _instance = ProductSyncService._internal();
  factory ProductSyncService() => _instance;

  static const String _lastProductsSyncKey = 'products_last_sync_at';
  static const String _lastSellerPriceBookSyncKey = 'seller_price_book_last_sync_at';
  static const Duration syncInterval = Duration(hours: 6);
  static const int pageSize = 20;

  Future<ProductSyncResult> ensureProductsLoaded({
    bool forceRefresh = false,
    ProductCatalogSource source = ProductCatalogSource.defaultCatalog,
  }) async {
    final productsBox = DatabaseService.getProducts();
    final shouldRefresh = forceRefresh ||
        productsBox.isEmpty ||
        await _isSyncDue(_syncKeyFor(source));

    if (!shouldRefresh) {
      return ProductSyncResult(
        productCount: productsBox.length,
        usedRemoteData: false,
      );
    }

    try {
      final rawProducts = source == ProductCatalogSource.sellerPriceBook
          ? await ApiService().getSellerPriceBookProducts()
          : await ApiService().getProducts();
      final products = _mapProducts(rawProducts);

      if (products.isNotEmpty) {
        await DatabaseService.replaceProducts(products);
        await _setLastSyncTime(_syncKeyFor(source), DateTime.now());
        return ProductSyncResult(
          productCount: products.length,
          usedRemoteData: true,
        );
      }

      if (productsBox.isNotEmpty) {
        return ProductSyncResult(
          productCount: productsBox.length,
          usedRemoteData: false,
        );
      }

      throw ApiException(
        message: 'No products were returned from the API',
        code: -1,
      );
    } catch (error, stackTrace) {
      debugPrint('Product sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (productsBox.isNotEmpty) {
        return ProductSyncResult(
          productCount: productsBox.length,
          usedRemoteData: false,
        );
      }
      rethrow;
    }
  }

  String _syncKeyFor(ProductCatalogSource source) {
    return source == ProductCatalogSource.sellerPriceBook
        ? _lastSellerPriceBookSyncKey
        : _lastProductsSyncKey;
  }

  Future<bool> _isSyncDue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return true;
    }

    final lastSyncTime = DateTime.tryParse(raw);
    if (lastSyncTime == null) {
      return true;
    }

    return DateTime.now().difference(lastSyncTime) >= syncInterval;
  }

  Future<void> _setLastSyncTime(String key, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, time.toIso8601String());
  }

  List<Product> _mapProducts(List<dynamic> rawProducts) {
    final products = <String, Product>{};

    for (final item in rawProducts) {
      if (item is! Map) continue;

      try {
        final product = Product.fromApiMap(Map<String, dynamic>.from(item));
        if (product.id.trim().isEmpty || product.name.trim().isEmpty) {
          continue;
        }
        products[product.id] = product;
      } catch (error) {
        debugPrint('Skipping product row due to mapping error: $error');
      }
    }

    return products.values.toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  }
}
