import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class TokenStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_json';
  static const _offlineKeyKey = 'offline_key';
  static const _deviceIdKey = 'device_id';
  static const _onboardingSeenPrefix = 'onboarding_seen_';
  static const _apiBaseUrlKey = 'api_base_url';
  static const _themeKey = 'theme_mode';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> accessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> refreshToken() => _storage.read(key: _refreshTokenKey);

  Future<bool> hasRefreshToken() async {
    final token = await refreshToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveUserJson(String value) =>
      _storage.write(key: _userKey, value: value);

  Future<String?> userJson() => _storage.read(key: _userKey);

  Future<String?> currentUserId() async {
    final raw = await userJson();
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final id = decoded['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  Future<bool> hasSeenOnboarding() async {
    final userId = await currentUserId();
    if (userId == null) return false;
    final value = await _storage.read(key: '$_onboardingSeenPrefix$userId');
    return value == 'true';
  }

  Future<void> markOnboardingSeen() async {
    final userId = await currentUserId();
    if (userId == null) return;
    await _storage.write(key: '$_onboardingSeenPrefix$userId', value: 'true');
  }

  Future<String?> offlineEncryptionKey() => _storage.read(key: _offlineKeyKey);

  Future<void> saveOfflineEncryptionKey(String value) =>
      _storage.write(key: _offlineKeyKey, value: value);

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  Future<String?> apiBaseUrl() => _storage.read(key: _apiBaseUrlKey);

  Future<void> saveApiBaseUrl(String value) =>
      _storage.write(key: _apiBaseUrlKey, value: value);

  Future<ThemeMode> loadThemeMode() async {
    final value = await _storage.read(key: _themeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _storage.write(key: _themeKey, value: value);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
