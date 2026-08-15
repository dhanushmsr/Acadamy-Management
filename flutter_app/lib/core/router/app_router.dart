import 'package:go_router/go_router.dart';

import '../../features/academy_workspace/academy_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/super_admin/super_admin_shell.dart';
import '../../features/tournaments/public_tournament_screen.dart';
import '../auth/auth_state.dart';

GoRouter buildRouter(AuthState authState) {
  return GoRouter(
    refreshListenable: authState,
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = authState.isLoggedIn;
      final onLoginPage = state.matchedLocation == '/login';
      final isPublicTournamentPage = state.matchedLocation.startsWith('/tournament');

      if (!loggedIn) {
        if (onLoginPage || isPublicTournamentPage) return null;
        return '/login';
      }
      if (onLoginPage) {
        return authState.role == UserRole.superAdmin ? '/admin' : '/academy';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const SuperAdminShell()),
      GoRoute(path: '/academy', builder: (context, state) => const AcademyShell()),
      GoRoute(
        path: '/tournament/:id',
        builder: (context, state) => PublicTournamentScreen(
          tournamentId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
