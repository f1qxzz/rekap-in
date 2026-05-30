import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../storage/token_store.dart';

class RealtimeService {
  RealtimeService({
    required this.apiClient,
    required this.tokenStore,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _disposed = false;
  int _retryCount = 0;
  static const _maxRetries = 20;
  static const _baseDelay = 2;
  static const _maxDelay = 120;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void connect() {
    if (_connecting || _disposed) return;
    _connecting = true;
    _retryCount = 0;
    _startListening();
  }

  void _startListening() {
    if (_disposed) return;
    final baseUrl = apiClient.dio.options.baseUrl;
    final baseUri = Uri.parse(baseUrl);
    final eventsUri = baseUri.resolve('/events');
    final httpUri = eventsUri.replace(scheme: 'http');
    _connectSSE(httpUri);
  }

  Future<void> _connectSSE(Uri uri) async {
    if (_disposed) return;

    try {
      final raw = await tokenStore.userJson();
      final user = (raw != null && raw.isNotEmpty)
          ? (jsonDecode(raw) as Map<String, dynamic>)
          : <String, dynamic>{};
      final role = (user['role'] ?? 'KARYAWAN').toString();
      final userId = (user['id'] ?? '').toString();

      final request = await apiClient.dio.getUri<dynamic>(
        uri.replace(queryParameters: {'role': role, 'userId': userId}),
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          responseType: ResponseType.plain,
        ),
      );

      _retryCount = 0;
      final response = request.data;
      if (response is String) {
        _parseSSEData(response);
      }
    } catch (e) {
      if (!_disposed) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _retryCount >= _maxRetries) return;
    _retryCount++;
    final delaySec = (_baseDelay * (1 << (_retryCount - 1))).clamp(0, _maxDelay);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      _connecting = false;
      if (!_disposed) connect();
    });
  }

  void _parseSSEData(String rawData) {
    final lines = rawData.split('\n');
    for (final line in lines) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        if (jsonStr.isEmpty) continue;
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          _eventController.add(data);
        } catch (_) {}
      }
    }
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _eventController.close();
  }
}
