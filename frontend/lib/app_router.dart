import 'package:go_router/go_router.dart';

import 'screens/login_screen.dart';
import 'screens/patient_screen.dart';
import 'services/auth_state.dart';

/// All screens and their URLs. Signed-out users always land on /login.
GoRouter buildRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth, // re-check the redirect when someone signs in or out
    redirect: (context, state) {
      final onLogin = state.matchedLocation == '/login';
      if (!auth.isSignedIn && !onLogin) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/patient', builder: (context, state) => const PatientScreen()),
    ],
  );
}
