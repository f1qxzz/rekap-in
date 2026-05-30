import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/token_store.dart';

class ApiClient {
  static String get defaultBaseUrl {
    final env = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;
    // Default to localhost which works for web and physical devices
    // For Android emulators use a dart-define override (10.0.2.2).
    return 'http://localhost:8080/api';
  }

  Completer<bool>? _refreshLock;

  ApiClient({required this.tokenStore})
      : dio = Dio(
          BaseOptions(
            baseUrl: defaultBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStore.accessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (_shouldRefresh(error)) {
            final refreshed = await _refreshWithLock();
            if (refreshed) {
              final token = await tokenStore.accessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              error.requestOptions.extra['authRetry'] = true;
              final retry = await dio.fetch(error.requestOptions);
              return handler.resolve(retry);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore tokenStore;
  final Dio dio;

  bool _shouldRefresh(DioException error) {
    if (error.response?.statusCode != 401) return false;
    if (error.requestOptions.extra['authRetry'] == true) return false;

    final path = error.requestOptions.path;
    const publicAuthPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/refresh',
      '/auth/logout',
      '/auth/verify-email',
      '/auth/resend-verification',
      '/auth/password-reset/request',
      '/auth/password-reset/confirm',
    ];
    return !publicAuthPaths.any(path.startsWith);
  }

  void setBaseUrl(String value) {
    dio.options.baseUrl = value.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Future<bool> _refreshWithLock() async {
    if (_refreshLock != null) return _refreshLock!.future;
    _refreshLock = Completer<bool>();
    try {
      final result = await refreshAccessToken();
      _refreshLock!.complete(result);
      return result;
    } catch (_) {
      _refreshLock!.complete(false);
      return false;
    } finally {
      _refreshLock = null;
    }
  }

  static String errorMessage(
    Object error, {
    required String fallback,
  }) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errorBody = data['error'];
        if (errorBody is Map && errorBody['message'] is String) {
          return errorBody['message'] as String;
        }
        if (data['message'] is String) return data['message'] as String;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Koneksi ke server gagal. Periksa backend atau jaringan.';
      }
    }
    return fallback;
  }

  Future<void> login(
    String email,
    String password, {
    String? fcmToken,
  }) async {
    final response = await dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'deviceId': await tokenStore.deviceId(),
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      },
    );
    await tokenStore.saveTokens(
      accessToken: response.data['accessToken'] as String,
      refreshToken: response.data['refreshToken'] as String,
    );
    await tokenStore.saveUserJson(jsonEncode(response.data['user']));
  }

  Future<void> logout() async {
    final refresh = await tokenStore.refreshToken();
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await dio.post('/auth/logout', data: {'refreshToken': refresh});
      }
    } finally {
      await tokenStore.clear();
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String nip,
    required String password,
    String? phone,
  }) async {
    final response = await dio.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'nip': nip,
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await dio.post(
      '/auth/password-reset/request',
      data: {'email': email.trim()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await dio.post(
      '/auth/password-reset/confirm',
      data: {
        'token': token.trim(),
        'newPassword': newPassword,
      },
    );
  }

  Future<bool> refreshAccessToken() async {
    final refresh = await tokenStore.refreshToken();
    if (refresh == null) return false;

    try {
      final response =
          await dio.post('/auth/refresh', data: {'refreshToken': refresh});
      await tokenStore.saveTokens(
        accessToken: response.data['accessToken'] as String,
        refreshToken: refresh,
      );
      return true;
    } catch (_) {
      await tokenStore.clear();
      return false;
    }
  }

  Future<Map<String, dynamic>> me() async {
    final response = await dio.get('/auth/me');
    return response.data['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> todayStatus() async {
    final response = await dio.get('/attendance/today');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> attendanceHistory(
      {String? month, String? status}) async {
    final response = await dio.get(
      '/attendance/history',
      queryParameters: {'month': month, 'status': status}
        ..removeWhere((key, value) => value == null),
    );
    return response.data['data'] as List<dynamic>;
  }

  Future<Response<dynamic>> health() {
    final base = Uri.parse(dio.options.baseUrl);
    return dio.getUri(base.replace(path: '/health'));
  }

  Future<String> uploadDocument({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final response = await dio.post(
      '/storage/documents',
      data: {
        'fileName': fileName,
        'mimeType': mimeType,
        'fileBase64': base64Encode(bytes),
      },
    );
    return response.data['documentUrl'] as String;
  }

  Future<Map<String, dynamic>> submitAttendance(
      Map<String, dynamic> payload) async {
    final response = await dio.post('/attendance/clock', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncOffline(
      List<Map<String, dynamic>> entries) async {
    final response =
        await dio.post('/attendance/offline-sync', data: {'entries': entries});
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> leaveMine() async {
    final response = await dio.get('/leave-requests/mine');
    return response.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> leavePending() async {
    final response = await dio.get('/leave-requests/pending');
    return response.data['data'] as List<dynamic>;
  }

  Future<void> createLeave(Map<String, dynamic> payload) async {
    await dio.post('/leave-requests', data: payload);
  }

  Future<Map<String, dynamic>> leaveBalance() async {
    final response = await dio.get('/leave-requests/balance');
    return response.data as Map<String, dynamic>;
  }

  Future<void> approveLeave({
    required String id,
    required String status,
    required bool approved,
    String? comment,
  }) async {
    final path = status == 'MENUNGGU_HR'
        ? '/leave-requests/$id/hr-approval'
        : '/leave-requests/$id/manager-approval';
    await dio.post(
      path,
      data: {
        'action': approved ? 'APPROVE' : 'REJECT',
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
  }

  Future<List<dynamic>> adminAnomalies() async {
    final response = await dio.get('/admin/anomalies');
    return response.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> adminUsers() async {
    final response = await dio.get('/admin/users');
    return response.data['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> adminSummary() async {
    final response = await dio.get('/admin/summary');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<List<dynamic>> adminDepartments() async {
    final response = await dio.get('/admin/departments');
    return response.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> adminHolidays() async {
    final response = await dio.get('/admin/holidays');
    return response.data['data'] as List<dynamic>;
  }

  Future<void> createAdminUser(Map<String, dynamic> payload) async {
    await dio.post('/admin/users', data: payload);
  }

  Future<void> updateAdminUser(String id, Map<String, dynamic> payload) async {
    await dio.patch('/admin/users/$id', data: payload);
  }

  Future<void> createDepartment(String name) async {
    await dio.post('/admin/departments', data: {'name': name});
  }

  Future<void> updateDepartment(String id, String name) async {
    await dio.patch('/admin/departments/$id', data: {'name': name});
  }

  Future<void> deleteDepartment(String id) async {
    await dio.delete('/admin/departments/$id');
  }

  Future<void> createShift(Map<String, dynamic> payload) async {
    await dio.post('/admin/shifts', data: payload);
  }

  Future<void> updateShift(String id, Map<String, dynamic> payload) async {
    await dio.patch('/admin/shifts/$id', data: payload);
  }

  Future<void> deleteShift(String id) async {
    await dio.delete('/admin/shifts/$id');
  }

  Future<void> createOffice(Map<String, dynamic> payload) async {
    await dio.post('/admin/offices', data: payload);
  }

  Future<void> updateOffice(String id, Map<String, dynamic> payload) async {
    await dio.patch('/admin/offices/$id', data: payload);
  }

  Future<void> deleteOffice(String id) async {
    await dio.delete('/admin/offices/$id');
  }

  Future<void> createHoliday(Map<String, dynamic> payload) async {
    await dio.post('/admin/holidays', data: payload);
  }

  Future<void> updateHoliday(String id, Map<String, dynamic> payload) async {
    await dio.patch('/admin/holidays/$id', data: payload);
  }

  Future<void> deleteHoliday(String id) async {
    await dio.delete('/admin/holidays/$id');
  }

  Future<List<dynamic>> adminShifts() async {
    final response = await dio.get('/admin/shifts');
    return response.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> adminOffices() async {
    final response = await dio.get('/admin/offices');
    return response.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> adminLeaveBalances({int? year}) async {
    final response = await dio.get(
      '/admin/leave-balances',
      queryParameters: {'year': year}
        ..removeWhere((key, value) => value == null),
    );
    return response.data['data'] as List<dynamic>;
  }

  Future<void> createLeaveBalance(Map<String, dynamic> payload) async {
    await dio.post('/admin/leave-balances', data: payload);
  }

  Future<void> updateLeaveBalance(
      String id, Map<String, dynamic> payload) async {
    await dio.patch('/admin/leave-balances/$id', data: payload);
  }

  Future<void> deleteLeaveBalance(String id) async {
    await dio.delete('/admin/leave-balances/$id');
  }

  Future<List<dynamic>> attendanceOffices() async {
    final response = await dio.get('/attendance/offices');
    return response.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> adminAuditLogs() async {
    final response = await dio.get('/admin/audit-logs');
    return response.data['data'] as List<dynamic>;
  }

  Future<void> approveUser({
    required String id,
    required bool approved,
    String? reason,
  }) async {
    await dio.patch(
      '/admin/users/$id/approve',
      data: {
        'approved': approved,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> reviewAnomaly({
    required String id,
    required String action,
    required String notes,
  }) async {
    await dio.patch(
      '/admin/anomalies/$id/review',
      data: {'action': action, 'notes': notes},
    );
  }

  Future<List<dynamic>> payrollSummary({required String month}) async {
    final response = await dio.get(
      '/attendance/summary',
      queryParameters: {'month': month},
    );
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> lockPayrollMonth({required String month}) async {
    final response =
        await dio.post('/payroll/lock-month', data: {'month': month});
    return response.data as Map<String, dynamic>;
  }

  Future<String> downloadReport({
    required String month,
    required String format,
  }) async {
    final response = await dio.get<List<int>>(
      '/reports/export',
      queryParameters: {'month': month, 'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/absensi-$month.$format');
    await file.writeAsBytes(response.data ?? const []);
    return file.path;
  }

  Future<Map<String, dynamic>> reportsAnalytics({String? month}) async {
    final response = await dio.get(
      '/reports/analytics',
      queryParameters: {'month': month},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> notifications() async {
    final response = await dio.get('/notifications');
    return response.data['data'] as List<dynamic>;
  }

  Future<void> markNotificationRead(String id) async {
    await dio.patch('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await dio.patch('/notifications/read-all');
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    final response = await dio.patch('/auth/me', data: data);
    final user = response.data['user'] as Map<String, dynamic>;
    await tokenStore.saveUserJson(jsonEncode(user));
    return user;
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await dio.post('/auth/change-password', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  Future<String?> signedPhotoUrl(String? photoUrl) async {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    final response = await dio.get(
      '/storage/photos/signed-url',
      queryParameters: {'photoUrl': photoUrl},
    );
    final url = response.data['url'] as String?;
    if (url == null || url.startsWith('http')) return url;
    final base = Uri.parse(dio.options.baseUrl);
    return base.replace(path: url).toString();
  }

  Future<Uint8List?> attendancePhotoBytes(String? photoUrl) async {
    final url = await signedPhotoUrl(photoUrl);
    if (url == null || url.isEmpty) return null;
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  Future<Uint8List?> attendancePhotoById(String attendanceId) async {
    try {
      final response = await dio.get<List<int>>(
        '/attendance/$attendanceId/photo',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      return bytes == null ? null : Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }
}
