import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthState {
  final String? token;
  final Map<String, dynamic>? user;

  AuthState({this.token, this.user});
}

class AuthNotifier extends AsyncNotifier<AuthState?> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<AuthState?> build() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      try {
        final dio = ref.read(dioProvider);
        final response = await dio.get('/auth/me');
        return AuthState(token: token, user: response.data);
      } catch (e) {
        await _storage.delete(key: 'access_token');
        return null;
      }
    }
    return null;
  }

  Future<bool> login(String email, String password) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': email,
          'password': password,
        }),
      );

      final token = response.data['access_token'];
      await _storage.write(key: 'access_token', value: token);

      // Fetch user info
      dio.options.headers['Authorization'] = 'Bearer $token';
      final userResponse = await dio.get('/auth/me');

      state = AsyncValue.data(AuthState(token: token, user: userResponse.data));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    state = const AsyncValue.data(null);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState?>(() {
  return AuthNotifier();
});
