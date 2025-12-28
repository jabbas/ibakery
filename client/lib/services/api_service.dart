import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:js_interop';

@JS('window.API_URL')
external String? get _jsApiUrl;

String get baseUrl => _jsApiUrl ?? 'https://marta.jabbas.eu/api';
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: baseUrl));
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

  Future<List<Map<String, dynamic>>> getActiveOffers() async {
    final response = await _dio.get('/offers/active');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> getOffer(String id) async {
    final response = await _dio.get('/offers/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/orders', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getOrder(String id) async {
    final response = await _dio.get('/orders/$id');
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getPickupPoints() async {
    final response = await _dio.get('/pickup-points', queryParameters: {'active_only': true});
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<String> getBackendVersion() async {
    try {
      final response = await _dio.get('/version');
      return response.data['version'] ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }
}
