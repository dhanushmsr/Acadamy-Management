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

  /// Initializes session on app launch. Fresh launches start logged out on the
  /// login screen where cached device credentials will be pre-filled.
  Future<void> initSession() async {
    // Clear any previous raw session tokens so fresh app launch always begins
    // on the Login screen with pre-filled credentials.
    _token = null;
    _role = null;
    _academyId = null;
    _api.setToken(null);
    notifyListeners();
  }

  /// Retrieve cached username/email and password stored on this device.
  Future<Map<String, dynamic>> getSavedCredentials() async {
    try {
      final email = await _storage.read(key: 'saved_email');
      final password = await _storage.read(key: 'saved_password');
      final rememberStr = await _storage.read(key: 'remember_credentials');
      final remember = rememberStr == null ? true : (rememberStr == 'true');
      return {
        'email': email ?? '',
        'password': password ?? '',
        'remember': remember,
      };
    } catch (e) {
      debugPrint('Error reading saved credentials: $e');
      return {'email': '', 'password': '', 'remember': true};
    }
  }

  /// Save or remove credentials from local device cache.
  Future<void> saveCredentials(String email, String password, bool remember) async {
    try {
      if (remember) {
        await _storage.write(key: 'saved_email', value: email);
        await _storage.write(key: 'saved_password', value: password);
        await _storage.write(key: 'remember_credentials', value: 'true');
      } else {
        await _storage.delete(key: 'saved_email');
        await _storage.delete(key: 'saved_password');
        await _storage.write(key: 'remember_credentials', value: 'false');
      }
    } catch (e) {
      debugPrint('Error saving credentials to device: $e');
    }
  }

  /// Clears saved credentials completely.
  Future<void> clearSavedCredentials() async {
    try {
      await _storage.delete(key: 'saved_email');
      await _storage.delete(key: 'saved_password');
      await _storage.write(key: 'remember_credentials', value: 'false');
    } catch (e) {
      debugPrint('Error clearing saved credentials: $e');
    }
  }

  Future<void> login(String email, String password, {bool rememberCredentials = true}) async {
    final response = await _api.login(email, password);
    _token = response['access_token'] as String;
    final roleStr = response['role'] as String;
    _role = roleFromString(roleStr);
    _academyId = response['academy_id'] as String?;
    _api.setToken(_token!);

    // Save or clear credentials cache on device based on user preference
    await saveCredentials(email, password, rememberCredentials);

    notifyListeners();
  }

  /// User triggered logout
  Future<void> logout() async {
    _token = null;
    _role = null;
    _academyId = null;
    _api.setToken(null);

    notifyListeners();
  }

  /// Automatic logout when app is idle / inactive / backgrounded
  void autoLogoutDueToInactivity() {
    if (_token != null) {
      _token = null;
      _role = null;
      _academyId = null;
      _api.setToken(null);
      notifyListeners();
    }
  }
}

