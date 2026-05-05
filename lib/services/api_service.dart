import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

int dateToInt(DateTime date) {
  return (date.year * 65536) + (date.month * 256) + date.day;
}

class ProductStockInfo {
  ProductStockInfo({
    required this.quantity,
    required this.internal,
    required this.alternateQuantity,
    required this.avgRate,
    required this.value,
  });

  final double quantity;
  final double internal;
  final double alternateQuantity;
  final double avgRate;
  final double value;

  int get availableStockQty => quantity < 0 ? 0 : quantity.toInt();

  factory ProductStockInfo.fromJson(Map<String, dynamic> json) {
    return ProductStockInfo(
      quantity: _asDouble(json['Quantity']),
      internal: _asDouble(json['Internal']),
      alternateQuantity: _asDouble(json['AlternateQuantity']),
      avgRate: _asDouble(json['AvgRate']),
      value: _asDouble(json['Value']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ApiService {
  static const String _baseUrlKey = 'api_base_url';
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  bool _isInitialized = false;
  String? _overrideBaseUrl;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _sessionKey = 'fSessionId';

  // Base URL from environment, with a safe fallback when dotenv is not loaded.
  String get baseUrl {
    if (_overrideBaseUrl != null && _overrideBaseUrl!.isNotEmpty) {
      return _overrideBaseUrl!;
    }
    try {
      final envBaseUrl = dotenv.env['API_BASE_URL'];
      if (envBaseUrl != null && envBaseUrl.isNotEmpty) {
        return envBaseUrl;
      }
    } catch (_) {
      // Fall through to the local API default when dotenv is unavailable.
    }
    return 'http://192.168.100.15/focus8API';
  }

  /// Initialize Dio with interceptors
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _overrideBaseUrl = prefs.getString(_baseUrlKey)?.trim();

    if (_isInitialized) {
      _dio.options.baseUrl = baseUrl;
      return;
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add session ID interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final sessionId = await _secureStorage.read(key: _sessionKey);
          if (sessionId != null && sessionId.isNotEmpty) {
            options.headers['fSessionId'] = sessionId;
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Unauthorized - clear session and redirect
            await _clearSession();
            // Could emit event to navigate to login
          }
          return handler.next(error);
        },
      ),
    );
    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  Future<void> setBaseUrl(String url) async {
    final normalizedUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();

    if (normalizedUrl.isEmpty) {
      await prefs.remove(_baseUrlKey);
      _overrideBaseUrl = null;
    } else {
      await prefs.setString(_baseUrlKey, normalizedUrl);
      _overrideBaseUrl = normalizedUrl;
    }

    if (_isInitialized) {
      _dio.options.baseUrl = baseUrl;
    }
  }

  Future<String> getSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_baseUrlKey)?.trim();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _overrideBaseUrl = savedUrl;
      return savedUrl;
    }
    return baseUrl;
  }

  /// Store session ID after successful login
  Future<void> _storeSessionId(String sessionId) async {
    await _secureStorage.write(key: _sessionKey, value: sessionId);
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: _sessionKey);
  }

  /// Get stored session ID
  Future<String?> getSessionId() async {
    return await _secureStorage.read(key: _sessionKey);
  }

  // ==================== AUTH ====================

  /// Login endpoint
  /// POST /login
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String companyId,
  }) async {
    try {
      await _ensureInitialized();
      final response = await _dio.post(
        '/login',
        data: {
          'data': [
            {
              'Username': username.trim(),
              'password': password,
              'CompanyId': companyId,
            },
          ],
          'result': 1,
          'message': '',
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw ApiException(
          message: 'We received an unexpected response while signing you in. Please try again.',
          code: -1,
        );
      }

      final result = data['result'];
      final rows = data['data'];
      if (result == 1 && rows is List && rows.isNotEmpty) {
        final loginData = Map<String, dynamic>.from(rows.first as Map);
        final sessionId = loginData['fSessionId']?.toString();
        if (sessionId != null) {
          await _storeSessionId(sessionId);
        }
        return loginData;
      }

      final message = data['message']?.toString().trim();
      throw ApiException(
        message: _friendlyLoginMessage(message),
        code: result is int ? result : -1,
        response: response,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw ApiException(
          message: 'The username or password you entered is incorrect.',
          code: e.response?.statusCode ?? -1,
          response: e.response,
        );
      }
      throw _handleDioError(e);
    }
  }

  // ==================== MASTERS ====================

  /// Get list of companies
  /// GET /List/Company
  Future<List<dynamic>> getCompanies() async {
    try {
      await _ensureInitialized();
      final response = await _dio.get('/List/Company');
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get products with optional filters
  /// GET /Screen/CoreMasters/Products
  Future<List<dynamic>> getProducts({
    String? search,
    String? category,
    String? barcode,
  }) async {
    try {
      await _ensureInitialized();
      final queryParameters = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParameters['search'] = search;
      if (category != null && category.isNotEmpty) queryParameters['category'] = category;
      if (barcode != null && barcode.isNotEmpty) queryParameters['barcode'] = barcode;

      final response = await _dio.get(
        '/Screen/CoreMasters/Products',
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get seller price book products
  /// GET /List/CoreMasters/SellerPriceBook
  Future<List<dynamic>> getSellerPriceBookProducts() async {
    try {
      await _ensureInitialized();
      final response = await _dio.get('/List/CoreMasters/SellerPriceBook');
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get product details by code
  /// GET /Screen/Masters/Core_Product/{code}
  Future<Map<String, dynamic>> getProductDetails(String code) async {
    try {
      final response = await _dio.get('/Screen/Masters/Core_Product/$code');
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get accounts (e.g., customers)
  /// GET /List/Masters/Core_Account
  Future<List<dynamic>> getAccounts({String? accountType}) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (accountType != null) queryParameters['accountType'] = accountType;

      final response = await _dio.get(
        '/List/Masters/Core_Account',
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ==================== TRANSACTIONS ====================

  /// Get sales orders with optional filters
  /// GET /List/Transactions/Sales Orders
  Future<List<dynamic>> getSalesOrders({
    int page = 1,
    String? period, // e.g., 'today', 'week', 'month'
    String? status,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
      };
      if (period != null) queryParameters['period'] = period;
      if (status != null) queryParameters['status'] = status;

      final response = await _dio.get(
        '/List/Transactions/Sales Orders',
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get single sales order details
  /// GET /Screen/Transactions/Sales Orders/{voucherNo}
  Future<Map<String, dynamic>> getSalesOrderDetails(String voucherNo) async {
    try {
      final response = await _dio.get('/Screen/Transactions/Sales Orders/$voucherNo');
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Create new sales order
  /// POST /Transactions/Sales Orders
  Future<Map<String, dynamic>> createSalesOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _dio.post('/Transactions/Sales Orders', data: orderData);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Delete (cancel) sales order
  /// DELETE /Transactions/Sales Orders/{voucherNo}
  Future<void> deleteSalesOrder(String voucherNo) async {
    try {
      await _dio.delete('/Transactions/Sales Orders/$voucherNo');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get live stock information for the provided products.
  /// The API response does not echo `product__id`, so we map rows back to the
  /// request order.
  Future<Map<String, ProductStockInfo>> getStockInformationByProductIds(
    List<String> productIds, {
    DateTime? date,
  }) async {
    try {
      await _ensureInitialized();
      final normalizedIds = productIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();

      if (normalizedIds.isEmpty) {
        return {};
      }

      final currentDate = date ?? DateTime.now();
      final dateId = dateToInt(
        DateTime(currentDate.year, currentDate.month, currentDate.day),
      );

      final response = await _dio.post(
        '/Transactions/Stock',
        data: {
          'data': normalizedIds
              .map(
                (productId) => {
                  'product__id': productId,
                  'Date__Id': dateId,
                },
              )
              .toList(),
        },
      );

      final rows = _handleResponse(response);
      if (rows is! List) {
        throw ApiException(
          message: 'Unexpected stock response from server',
          code: -1,
          response: response,
        );
      }

      final stockRows = rows
          .whereType<Map>()
          .map((row) => ProductStockInfo.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      final result = <String, ProductStockInfo>{};
      final itemCount = stockRows.length < normalizedIds.length
          ? stockRows.length
          : normalizedIds.length;

      for (var index = 0; index < itemCount; index++) {
        result[normalizedIds[index]] = stockRows[index];
      }

      return result;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ==================== DASHBOARD ====================

  /// Get dashboard alerts and approvals
  /// GET /Screen/Transactions/AlertApprovalCount
  Future<Map<String, dynamic>> getDashboardAlerts() async {
    try {
      final response = await _dio.get('/Screen/Transactions/AlertApprovalCount');
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get approvals list
  /// GET /Screen/Transactions/Approvals
  Future<List<dynamic>> getApprovals() async {
    try {
      final response = await _dio.get('/Screen/Transactions/Approvals');
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ==================== UTILITY ====================

  /// Get user preferences
  /// GET /utility/preferences
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await _dio.get('/utility/preferences');
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ==================== REPORTS ====================

  /// Get report data
  /// GET /Reports/pagedata?id=551
  Future<Map<String, dynamic>> getReportData({required int reportId, String? filters}) async {
    try {
      final queryParameters = <String, dynamic>{'id': reportId};
      if (filters != null) queryParameters['filters'] = filters;

      final response = await _dio.get(
        '/Reports/pagedata',
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ==================== HELPERS ====================

  /// Handle successful response
  dynamic _handleResponse(Response response) {
    final data = response.data;
    if (data is Map && data['result'] == 0) {
      throw ApiException(
        message: data['message'] ?? 'Request failed',
        code: data['result'],
      );
    }
    // Successful: return data field if exists, else full response
    if (data is Map && data.containsKey('data')) {
      return data['data'];
    }
    return data;
  }

  /// Handle Dio errors
  ApiException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        message: 'The server is taking too long to respond. Please try again.',
        code: -1,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return ApiException(
        message: 'We could not reach the server. Check your internet connection and try again.',
        code: -1,
      );
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      String message = 'Something went wrong while talking to the server.';

      if (data is Map) {
        message = _friendlyServerMessage(
          data['message']?.toString(),
          statusCode: statusCode,
        );
      } else if (data is String) {
        message = _friendlyServerMessage(data, statusCode: statusCode);
      } else {
        message = _friendlyServerMessage(null, statusCode: statusCode);
      }

      return ApiException(
        message: message,
        code: statusCode ?? -1,
        response: error.response,
      );
    } else {
      // No response (timeout, no connection)
      return ApiException(
        message: 'We could not reach the server. Check your internet connection and try again.',
        code: -1,
      );
    }
  }

  String _friendlyLoginMessage(String? message) {
    final normalized = message?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty ||
        normalized.contains('incorrect username or password') ||
        normalized.contains('invalid username') ||
        normalized.contains('invalid password')) {
      return 'The username or password you entered is incorrect.';
    }

    if (normalized.contains('company')) {
      return 'We could not sign you in for the selected company. Please check your settings and try again.';
    }

    return message!.trim();
  }

  String _friendlyServerMessage(String? message, {int? statusCode}) {
    final trimmedMessage = message?.trim();
    final normalized = trimmedMessage?.toLowerCase() ?? '';

    if (statusCode == 401 || statusCode == 403) {
      return 'Your session has expired. Please sign in again.';
    }
    if (statusCode == 404) {
      return 'We could not find what you requested.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'The server is having trouble right now. Please try again shortly.';
    }

    if (normalized.isEmpty) {
      return 'We could not complete your request right now. Please try again.';
    }
    if (normalized.contains('incorrect username or password')) {
      return 'The username or password you entered is incorrect.';
    }
    if (normalized.contains('timeout')) {
      return 'The server is taking too long to respond. Please try again.';
    }
    if (normalized.contains('network') || normalized.contains('internet')) {
      return 'We could not reach the server. Check your internet connection and try again.';
    }

    return trimmedMessage!;
  }
}

/// Custom API exception
class ApiException implements Exception {
  final String message;
  final int code;
  final Response? response;

  ApiException({
    required this.message,
    required this.code,
    this.response,
  });

  @override
  String toString() => 'ApiException(code: $code, message: $message)';
}
