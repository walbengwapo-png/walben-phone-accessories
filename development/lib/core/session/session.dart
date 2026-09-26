import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserSession {
  const UserSession({required this.user, this.reseller});
  final Map<String, dynamic> user;
  final Map<String, dynamic>? reseller;
  String get role =>
      '${user['role'] ?? user['user_role'] ?? 'customer'}'.toLowerCase();
  String get resellerStatus =>
      '${reseller?['status'] ?? user['reseller_status'] ?? ''}'.toLowerCase();
  bool get isAdmin => role == 'admin' || role == 'administrator';
  bool get isApprovedReseller => resellerStatus == 'approved';
  String get name =>
      '${user['full_name'] ?? user['name'] ?? user['email'] ?? 'Account'}';
}

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  Future<String?> accessToken() => _storage.read(key: _accessKey);
  Future<String?> refreshToken() => _storage.read(key: _refreshKey);
  Future<void> save(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
