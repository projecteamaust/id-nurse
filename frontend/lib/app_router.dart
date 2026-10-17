import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/collect_screen.dart';
import 'screens/login_screen.dart';
import 'screens/patient_screen.dart';
import 'screens/prepare_screen.dart';
import 'screens/review_screen.dart';
import 'screens/supplies_screen.dart';
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
      GoRoute(path: '/supplies', builder: (context, state) => const SuppliesScreen()),
      GoRoute(path: '/review', builder: (context, state) => const ReviewScreen()),
      GoRoute(
        path: '/prepare/:orderId',
        redirect: _requireOrderId,
        builder: (context, state) => PrepareScreen(orderId: _orderId(state)!),
      ),
      GoRoute(
        path: '/collect/:orderId',
        redirect: _requireOrderId,
        builder: (context, state) => CollectScreen(orderId: _orderId(state)!),
      ),
    ],
  );
}

/// The order id in the URL, or null if it is not a number.
int? _orderId(GoRouterState state) => int.tryParse(state.pathParameters['orderId'] ?? '');

/// A broken order URL goes back to the start of a request.
String? _requireOrderId(BuildContext context, GoRouterState state) => _orderId(state) == null ? '/patient' : null;
