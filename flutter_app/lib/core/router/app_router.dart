import 'package:go_router/go_router.dart';

import '../../features/academy_workspace/academy_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/super_admin/super_admin_shell.dart';
import '../auth/auth_state.dart';

/// This is the whole "unified login" mechanic in code: one login screen,
/// and after that succeeds, `role` decides which shell you land in.
/// Nothing else about the login differs between a super admin and an
/// academy admin.
GoRouter buildRouter(AuthState authState) {
  return GoRouter(
    refreshListenable: authState,
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = authState.isLoggedIn;
      final onLoginPage = state.matchedLocation == '/login';

      if (!loggedIn) return onLoginPage ? null : '/login';
      if (onLoginPage) {
        return authState.role == UserRole.superAdmin ? '/admin' : '/academy';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const SuperAdminShell()),
      GoRoute(path: '/academy', builder: (context, state) => const AcademyShell()),
    ],
  );
}
