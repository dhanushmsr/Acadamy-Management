import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/auth/api_client.dart';
import 'core/auth/auth_state.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ActmacApp());
}

class ActmacApp extends StatefulWidget {
  const ActmacApp({super.key});

  @override
  State<ActmacApp> createState() => _ActmacAppState();
}

class _ActmacAppState extends State<ActmacApp> {
  // Created once per app lifetime - the router is NOT rebuilt on every
  // frame, it just listens to _authState via refreshListenable and
  // re-evaluates its redirect rule whenever login/logout happens.
  // _apiClient is shared with _authState (not a separate instance) so
  // that once AuthState.login() sets the auth token, every other screen
  // reading ApiClient via Provider gets an already-authenticated client.
  late final ApiClient _apiClient = ApiClient();
  late final AuthState _authState = AuthState(_apiClient);
  late final GoRouter _router = buildRouter(_authState);

  @override
  void initState() {
    super.initState();
    _authState.initSession();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<AuthState>.value(value: _authState),
      ],
      child: MaterialApp.router(
        title: 'AcD-Man',
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
