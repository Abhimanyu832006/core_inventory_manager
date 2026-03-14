import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import '../core/constants.dart';

class AuthService {
  final _client = ApiClient.instance;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    await _storage.write(key: AppConstants.tokenKey, value: data['access_token']);
    await _storage.write(key: AppConstants.userEmailKey, value: email);
    await _storage.write(key: AppConstants.userNameKey, value: data['name']);
    await _storage.write(key: AppConstants.userRoleKey, value: data['role']);
    return data;
  }

  Future<void> signup(String name, String email, String password) async {
    await _client.post('/auth/signup', data: {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<void> requestOtp(String email) async {
    await _client.post('/auth/otp/request', data: {'email': email});
  }

  Future<void> verifyOtp(String email, String otp, String newPassword) async {
    await _client.post('/auth/otp/verify', data: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    return token != null;
  }

  Future<String?> getUserName() => _storage.read(key: AppConstants.userNameKey);
  Future<String?> getUserEmail() => _storage.read(key: AppConstants.userEmailKey);
  Future<String?> getUserRole() => _storage.read(key: AppConstants.userRoleKey);
}
