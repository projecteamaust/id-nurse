import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'config.dart';
import 'services/api_service.dart';
import 'services/auth_state.dart';
import 'services/file_saver.dart';
import 'services/mock_api_service.dart';
import 'services/order_draft.dart';
import 'services/real_api_service.dart';
import 'theme/app_theme.dart';

void main() {
  // The only place that decides which ApiService is used (AppConfig.apiMode):
  // the real backend by default, or the built-in fake data with --dart-define=API_MODE=mock.
  final ApiService api =
      AppConfig.useMockApi ? MockApiService() : RealApiService(baseUrl: AppConfig.apiBaseUrl);
  runApp(IdNurseApp(api: api));
}

class IdNurseApp extends StatefulWidget {
  final ApiService api;

  /// Where exported files are saved. Null = the user's Downloads folder.
  final FileSaver? fileSaver;

  const IdNurseApp({super.key, required this.api, this.fileSaver});

  @override
  State<IdNurseApp> createState() => _IdNurseAppState();
}

class _IdNurseAppState extends State<IdNurseApp> {
  final _auth = AuthState();
  final _draft = OrderDraft();
  late final FileSaver _fileSaver = widget.fileSaver ?? DownloadsFileSaver();
  late final GoRouter _router = buildRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    _draft.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: widget.api),
        Provider<FileSaver>.value(value: _fileSaver),
        ChangeNotifierProvider<AuthState>.value(value: _auth),
        ChangeNotifierProvider<OrderDraft>.value(value: _draft),
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
