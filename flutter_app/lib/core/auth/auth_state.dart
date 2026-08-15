import 'package:flutter/foundation.dart';

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

/// Holds the current login state. go_router listens to this (via
/// ChangeNotifier) to decide whether to show the login screen, the
/// Super Admin Console, or the Academy Workspace. This is the client-side
/// half of the unified login - see app_router.dart for the routing rules.
class AuthState extends ChangeNotifier {
  final ApiClient _api;

  AuthState(this._api);

  String? _token;
  UserRole? _role;
  String? _academyId;

  bool get isLoggedIn => _token != null;
  UserRole? get role => _role;
  String? get academyId => _academyId;

  Future<void> login(String email, String password) async {
    final response = await _api.login(email, password);
    _token = response['access_token'] as String;
    _role = roleFromString(response['role'] as String);
    _academyId = response['academy_id'] as String?;
    _api.setToken(_token!);
    notifyListeners();
  }

  void logout() {
    _token = null;
    _role = null;
    _academyId = null;
    _api.setToken(null);
    notifyListeners();
  }
}
