import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

enum UserRole { superAdmin, academyAdmin, staff }

UserRole roleFromString(String value) {
  switch (value) {
    case 'super_admin':
      return UserRole.superAdmin;
    case 'staff':
      return UserRole.staff;
    default:
      return UserRole.academyAdmin;
  }
}

class AuthState extends ChangeNotifier {
  final ApiClient _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthState(this._api) {
    initSession();
  }

  String? _token;
  UserRole? _role;
  String? _academyId;

  bool get isLoggedIn => _token != null;
  UserRole? get role => _role;
  String? get academyId => _academyId;

  Future<void> initSession() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final roleStr = await _storage.read(key: 'auth_role');
      final academyId = await _storage.read(key: 'auth_academy_id');

      if (token != null && token.isNotEmpty && roleStr != null && roleStr.isNotEmpty) {
        _token = token;
        _role = roleFromString(roleStr);
        _academyId = academyId;
        _api.setToken(_token!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error reading secure storage session: $e');
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _api.login(email, password);
    _token = response['access_token'] as String;
    final roleStr = response['role'] as String;
    _role = roleFromString(roleStr);
    _academyId = response['academy_id'] as String?;
    _api.setToken(_token!);

    try {
      await _storage.write(key: 'auth_token', value: _token);
      await _storage.write(key: 'auth_role', value: roleStr);
      if (_academyId != null) {
        await _storage.write(key: 'auth_academy_id', value: _academyId);
      } else {
        await _storage.delete(key: 'auth_academy_id');
      }
    } catch (e) {
      debugPrint('Error writing session to storage: $e');
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _academyId = null;
    _api.setToken(null);

    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'auth_role');
      await _storage.delete(key: 'auth_academy_id');
    } catch (e) {
      debugPrint('Error clearing session from storage: $e');
    }

    notifyListeners();
  }
}
