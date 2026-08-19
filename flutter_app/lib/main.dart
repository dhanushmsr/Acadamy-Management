import 'dart:async';
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

class _ActmacAppState extends State<ActmacApp> with WidgetsBindingObserver {
  late final ApiClient _apiClient = ApiClient();
  late final AuthState _authState = AuthState(_apiClient);
  late final GoRouter _router = buildRouter(_authState);

  // Inactivity timeout duration (e.g. 30 minutes of no user interaction)
  static const Duration _inactivityTimeout = Duration(minutes: 30);
  Timer? _inactivityTimer;
  DateTime? _lastBackgroundedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authState.initSession();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  /// Resets the inactivity timer whenever user interaction is detected.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_authState.isLoggedIn) {
      _inactivityTimer = Timer(_inactivityTimeout, _handleInactivityTimeout);
    }
  }

  void _handleInactivityTimeout() {
    if (_authState.isLoggedIn) {
      debugPrint('[Session] Auto-logging out due to inactivity');
      _authState.autoLogoutDueToInactivity();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // App went to background
      _lastBackgroundedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground
      if (_lastBackgroundedTime != null && _authState.isLoggedIn) {
        final elapsed = DateTime.now().difference(_lastBackgroundedTime!);
        // If away for more than 15 minutes, auto-logout
        if (elapsed > const Duration(minutes: 15)) {
          debugPrint('[Session] Auto-logging out after returning from background');
          _authState.autoLogoutDueToInactivity();
        }
      }
      _resetInactivityTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<AuthState>.value(value: _authState),
      ],
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetInactivityTimer(),
        onPointerMove: (_) => _resetInactivityTimer(),
        child: MaterialApp.router(
          title: 'AcD-Man',
          theme: AppTheme.light(),
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

