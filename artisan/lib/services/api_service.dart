import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:js_interop';

@JS('window.API_URL')
external String? get _jsApiUrl;

String get baseUrl => _jsApiUrl ?? 'http://localhost:8000/api';
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        // Handle token expiration
      }
      handler.next(error);
    },
  ));

  return dio;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});

final backendVersionProvider = FutureProvider<String>((ref) async {
  return ref.read(apiServiceProvider).getBackendVersion();
});

class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  // Units
  Future<List<Map<String, dynamic>>> getUnits() async {
    final response = await _dio.get('/units');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> createUnit(Map<String, dynamic> data) async {
    final response = await _dio.post('/units', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateUnit(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/units/$id', data: data);
    return response.data;
  }

  Future<void> deleteUnit(String id) async {
    await _dio.delete('/units/$id');
  }

  // Ingredients
  Future<List<Map<String, dynamic>>> getIngredients() async {
    final response = await _dio.get('/ingredients');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> createIngredient(Map<String, dynamic> data) async {
    final response = await _dio.post('/ingredients', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateIngredient(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/ingredients/$id', data: data);
    return response.data;
  }

  Future<void> deleteIngredient(String id) async {
    await _dio.delete('/ingredients/$id');
  }

  // Products
  Future<List<Map<String, dynamic>>> getProducts() async {
    final response = await _dio.get('/products');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final response = await _dio.post('/products', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/products/$id', data: data);
    return response.data;
  }

  Future<void> deleteProduct(String id) async {
    await _dio.delete('/products/$id');
  }

  // Offers
  Future<List<Map<String, dynamic>>> getOffers({bool activeOnly = false, bool includeCompleted = true}) async {
    final response = await _dio.get('/offers', queryParameters: {
      'active_only': activeOnly,
      'include_completed': includeCompleted,
    });
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> data) async {
    final response = await _dio.post('/offers', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateOffer(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/offers/$id', data: data);
    return response.data;
  }

  Future<void> deleteOffer(String id) async {
    await _dio.delete('/offers/$id');
  }

  Future<Map<String, dynamic>> getOfferSummary(String id) async {
    final response = await _dio.get('/offers/$id/summary');
    return response.data;
  }

  Future<Map<String, dynamic>> completeOffer(String id) async {
    final response = await _dio.post('/offers/$id/complete');
    return response.data;
  }

  Future<Map<String, dynamic>> generateRecurringOffers({int daysAhead = 14}) async {
    final response = await _dio.post('/offers/generate-recurring', queryParameters: {'days_ahead': daysAhead});
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getRecurringTemplates() async {
    final response = await _dio.get('/offers/recurring-templates');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // Orders
  Future<List<Map<String, dynamic>>> getOrders({String? offerId}) async {
    final params = offerId != null ? {'offer_id': offerId} : null;
    final response = await _dio.get('/orders', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> updateOrder(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/orders/$id', data: data);
    return response.data;
  }

  // Version
  Future<String> getBackendVersion() async {
    try {
      final response = await _dio.get('/version');
      return response.data['version'] ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  // Pickup Points
  Future<List<Map<String, dynamic>>> getPickupPoints() async {
    final response = await _dio.get('/pickup-points');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> createPickupPoint(Map<String, dynamic> data) async {
    final response = await _dio.post('/pickup-points', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updatePickupPoint(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/pickup-points/$id', data: data);
    return response.data;
  }

  Future<void> deletePickupPoint(String id) async {
    await _dio.delete('/pickup-points/$id');
  }
}
