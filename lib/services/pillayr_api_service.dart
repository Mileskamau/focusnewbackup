import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PillayrApiService {
  static final PillayrApiService _instance = PillayrApiService._internal();
  factory PillayrApiService() => _instance;
  PillayrApiService._internal();

  late Dio _dio;
  bool _isInitialized = false;

  // Base URL – derived from environment, removing /focus8API if present.
  String get baseUrl {
    try {
      final envBase = dotenv.env['API_BASE_URL'];
      if (envBase != null && envBase.isNotEmpty) {
        String cleaned = envBase;
        if (cleaned.endsWith('/focus8API')) {
          cleaned = cleaned.substring(0, cleaned.length - 10);
        }
        return cleaned;
      }
    } catch (_) {}
    // Fallback – change to your server IP
    return 'http://192.168.100.15';
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _isInitialized = true;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    await init();
    final response = await _dio.get(path);
    return _handleResponse(response);
  }

  dynamic _handleResponse(Response response) {
    final data = response.data;
    if (data is Map && data['result'] == 0) {
      throw Exception(data['message'] ?? 'API request failed');
    }
    return data;
  }

  /// Fetch product list for a given company ID.
  /// Returns list of maps with fields: Id, product, itemcode, barcode, StockAvailability, Qty.
  Future<List<dynamic>> getProductMaster(int compId) async {
    final url = '$baseUrl/pillayrpos/api/products/productmaster?compid=$compId';
    final data = await _get(url);
    return data['datalist'] as List<dynamic>? ?? [];
  }

  /// Fetch selling price and tax for a specific product.
  Future<Map<String, double>> getProductSellingPrice(int compId, int itemId) async {
    final url = '$baseUrl/pillayrpos/api/products/sellingmaster?compid=$compId&itemid=$itemId';
    final data = await _get(url);
    final list = data['datalist'] as List<dynamic>?;
    if (list == null || list.isEmpty) {
      return {'price': 0.0, 'tax': 0.0};
    }
    final item = list.first as Map;
    return {
      'price': (item['SellingPrice'] as num?)?.toDouble() ?? 0.0,
      'tax': (item['tax'] as num?)?.toDouble() ?? 0.0,
    };
  }
}