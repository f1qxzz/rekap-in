import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

typedef NotificationCallback = void Function(RemoteMessage message);

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static String? _cachedToken;
  static NotificationCallback? _onForegroundMessage;
  static NotificationCallback? _onNotificationTap;

  static Future<void> initialize({
    NotificationCallback? onForegroundMessage,
    NotificationCallback? onNotificationTap,
  }) async {
    _onForegroundMessage = onForegroundMessage;
    _onNotificationTap = onNotificationTap;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _cachedToken = await _messaging.getToken();
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _cachedToken = token;
      });
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (_) {
      // Firebase belum dikonfigurasi - skip silently.
    }
  }

  static Future<String?> token() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    try {
      _cachedToken = await _messaging.getToken();
      return _cachedToken;
    } catch (_) {
      return null;
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    _onForegroundMessage?.call(message);
  }

  static void _handleNotificationTap(RemoteMessage message) {
    _onNotificationTap?.call(message);
  }
}
