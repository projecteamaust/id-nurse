import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'services/api_service.dart';
import 'services/auth_state.dart';
import 'services/mock_api_service.dart';
import 'theme/app_theme.dart';

void main() {
  // The only place that decides which ApiService is used.
  // When the backend is ready, MockApiService is swapped for RealApiService here.
  runApp(IdNurseApp(api: MockApiService()));
}

class IdNurseApp extends StatefulWidget {
  final ApiService api;

  const IdNurseApp({super.key, required this.api});

  @override
  State<IdNurseApp> createState() => _IdNurseAppState();
}

class _IdNurseAppState extends State<IdNurseApp> {
  final _auth = AuthState();
  late final GoRouter _router = buildRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: widget.api),
        ChangeNotifierProvider<AuthState>.value(value: _auth),
      ],
      child: MaterialApp.router(
        title: 'ID Nurse',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: _router,
      ),
    );
  }
}
