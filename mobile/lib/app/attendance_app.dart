import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/api/mock_api_client.dart';
import '../core/offline/offline_queue.dart';
import '../core/storage/token_store.dart';
import '../features/auth/login_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../core/widgets/rekapin_logo.dart';
import 'app_theme.dart';

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late final TokenStore tokenStore;
  late final ApiClient apiClient;
  late final OfflineQueue offlineQueue;
  late final Future<bool> _ready;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    tokenStore = TokenStore();
    const useMock = bool.fromEnvironment('USE_MOCK_API', defaultValue: false);
    apiClient = useMock
        ? MockApiClient(tokenStore: tokenStore)
        : ApiClient(tokenStore: tokenStore);
    offlineQueue = OfflineQueue(tokenStore: tokenStore);
    _ready = _bootstrap();
  }

  Future<bool> _bootstrap() async {
    final storedBaseUrl = await tokenStore.apiBaseUrl();
    if (storedBaseUrl != null && storedBaseUrl.isNotEmpty) {
      apiClient.setBaseUrl(storedBaseUrl);
    }
    final stored = await tokenStore.loadThemeMode();
    if (mounted) setState(() => _themeMode = stored);
    return tokenStore.hasRefreshToken();
  }

  void _updateThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    tokenStore.saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTheme.brandName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: FutureBuilder<bool>(
        future: _ready,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              body: Center(
                child: RekapInLogo(size: 120, showText: true),
              ),
            );
          }
          if (snapshot.data == true) {
            return DashboardPage(
              apiClient: apiClient,
              tokenStore: tokenStore,
              offlineQueue: offlineQueue,
              onThemeChanged: _updateThemeMode,
            );
          }
          return LoginPage(
            apiClient: apiClient,
            tokenStore: tokenStore,
            offlineQueue: offlineQueue,
          );
        },
      ),
    );
  }
}
