import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin_placeholder_screen.dart';
import 'screens/collect_screen.dart';
import 'screens/complete_screen.dart';
import 'screens/login_screen.dart';
import 'screens/low_stock_screen.dart';
import 'screens/patient_screen.dart';
import 'screens/prepare_screen.dart';
import 'screens/problem_reports_screen.dart';
import 'screens/review_screen.dart';
import 'screens/supervisor_login_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/supplies_screen.dart';
import 'services/auth_state.dart';
import 'widgets/admin_shell.dart';

/// All screens and their URLs. Signed-out users always land on /login
/// (or stay on /supervisor/login).
GoRouter buildRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth, // re-check the redirect when someone signs in or out
    redirect: (context, state) {
      final onLogin = state.matchedLocation == '/login' || state.matchedLocation == '/supervisor/login';
      if (!auth.isSignedIn && !onLogin) return '/login';
      // The dashboard is for supervisors only; a nurse goes back to her own start.
      if (_isDashboard(state.matchedLocation) && auth.user?.isSupervisor != true) return '/patient';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/supervisor/login', builder: (context, state) => const SupervisorLoginScreen()),
      GoRoute(path: '/supervisor', redirect: (context, state) => adminNavItems.first.path),
      // The dashboard pages share one AdminShell, so the sidebar stays while the page changes.
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/supervisor/problems', builder: (context, state) => const ProblemReportsScreen()),
          GoRoute(path: '/supervisor/stock', builder: (context, state) => const StockScreen()),
          GoRoute(path: '/supervisor/low-stock', builder: (context, state) => const LowStockScreen()),
          for (final path in ['/supervisor/log', '/supervisor/reports'])
            GoRoute(path: path, builder: (context, state) => const AdminPlaceholderScreen()),
        ],
      ),
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
      GoRoute(
        path: '/complete/:orderId',
        redirect: _requireOrderId,
        builder: (context, state) => CompleteScreen(orderId: _orderId(state)!),
      ),
    ],
  );
}

/// Any supervisor dashboard page (but not its public sign in page).
bool _isDashboard(String location) =>
    location == '/supervisor' || (location.startsWith('/supervisor/') && location != '/supervisor/login');

/// The order id in the URL, or null if it is not a number.
int? _orderId(GoRouterState state) => int.tryParse(state.pathParameters['orderId'] ?? '');

/// A broken order URL goes back to the start of a request.
String? _requireOrderId(BuildContext context, GoRouterState state) => _orderId(state) == null ? '/patient' : null;
