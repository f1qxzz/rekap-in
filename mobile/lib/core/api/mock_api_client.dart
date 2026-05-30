import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

class MockApiClient extends ApiClient {
  MockApiClient({required super.tokenStore}) {
    _init();
  }

  final _uuid = const Uuid();
  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _attendances = [];
  final List<Map<String, dynamic>> _notifications = [];
  final List<Map<String, dynamic>> _leaveRequests = [];
  final List<Map<String, dynamic>> _leaveBalances = [];
  final List<Map<String, dynamic>> _departments = [];
  final List<Map<String, dynamic>> _shifts = [];
  final List<Map<String, dynamic>> _offices = [];
  final List<Map<String, dynamic>> _holidays = [];
  final Map<String, Uint8List> _uploadedFiles = {};
  final Map<String, String> _passwordResetTokens = {};

  void _init() {
    final createdAt = DateTime.now().toUtc().toIso8601String();

    _departments.addAll([
      {'id': 'd-hr', 'name': 'HR', 'createdAt': createdAt},
      {'id': 'd-ops', 'name': 'Operasional', 'createdAt': createdAt},
    ]);

    _shifts.add({
      'id': 's-pagi',
      'name': 'Shift Pagi',
      'startTime': '08:00',
      'endTime': '17:00',
      'workDays': [1, 2, 3, 4, 5],
      'lateToleranceMinutes': 10,
    });

    _offices.add({
      'id': 'o-hq',
      'name': 'Kantor Pusat',
      'latitude': -6.2,
      'longitude': 106.816666,
      'radiusMeters': 100,
    });

    _users.addAll([
      {
        'id': 'u-super',
        'name': 'Super Admin',
        'email': 'superadmin@rekapin.local',
        'nip': 'f1qxzz',
        'phone': '',
        'role': 'SUPER_ADMIN',
        'departmentId': 'd-hr',
        'department': _departments[0],
        'shiftId': 's-pagi',
        'shift': _shifts[0],
        'directManagerId': null,
        'isApproved': true,
        'isActive': true,
        'emailVerified': true,
        'password': 'f1qxzz',
        'createdAt': createdAt,
      },
      {
        'id': 'u-hr',
        'name': 'HR',
        'email': 'hr@rekapin.local',
        'nip': 'hr',
        'phone': '',
        'role': 'HR',
        'departmentId': 'd-hr',
        'department': _departments[0],
        'shiftId': 's-pagi',
        'shift': _shifts[0],
        'directManagerId': 'u-super',
        'isApproved': true,
        'isActive': true,
        'emailVerified': true,
        'password': 'hr123',
        'createdAt': createdAt,
      },
      {
        'id': 'u-manajer',
        'name': 'Manajer',
        'email': 'manajer@rekapin.local',
        'nip': 'manajer',
        'phone': '',
        'role': 'MANAJER',
        'departmentId': 'd-ops',
        'department': _departments[1],
        'shiftId': 's-pagi',
        'shift': _shifts[0],
        'directManagerId': 'u-super',
        'isApproved': true,
        'isActive': true,
        'emailVerified': true,
        'password': 'manajer123',
        'createdAt': createdAt,
      },
      {
        'id': 'u-karyawan',
        'name': 'Karyawan',
        'email': 'karyawan@rekapin.local',
        'nip': 'karyawan',
        'phone': '',
        'role': 'KARYAWAN',
        'departmentId': 'd-ops',
        'department': _departments[1],
        'shiftId': 's-pagi',
        'shift': _shifts[0],
        'directManagerId': 'u-manajer',
        'isApproved': true,
        'isActive': true,
        'emailVerified': true,
        'password': 'karyawan123',
        'createdAt': createdAt,
      },
    ]);

    final year = DateTime.now().year;
    for (final user in _users) {
      _leaveBalances.add({
        'id': _uuid.v4(),
        'userId': user['id'],
        'year': year,
        'annualQuota': 12,
        'used': 0,
        'remaining': 12,
        'user': _userPublic(user),
        'createdAt': createdAt,
      });
    }
  }

  Map<String, dynamic> _userPublic(Map<String, dynamic> u) {
    return {
      'id': u['id'],
      'name': u['name'],
      'email': u['email'],
      'nip': u['nip'],
      'phone': u['phone'],
      'role': u['role'],
      'departmentId': u['departmentId'],
      'department': u['department'],
      'shiftId': u['shiftId'],
      'shift': u['shift'],
      'directManagerId': u['directManagerId'],
      'isApproved': u['isApproved'],
      'isActive': u['isActive'],
      'photoUrl': u['photoUrl'],
      'createdAt': u['createdAt'],
    };
  }

  Map<String, dynamic>? _currentUser;

  Future<Map<String, dynamic>> _getUser() async {
    if (_currentUser != null) return _currentUser!;
    final raw = await tokenStore.userJson();
    if (raw != null) {
      _currentUser = jsonDecode(raw) as Map<String, dynamic>;
      return _currentUser!;
    }
    return _userPublic(_users.firstWhere((u) => u['role'] == 'KARYAWAN'));
  }

  @override
  Future<void> login(
    String email,
    String password, {
    String? fcmToken,
  }) async {
    final idf = email.toLowerCase();
    final user = _users.firstWhere(
      (u) =>
          (u['email'] as String).toLowerCase() == idf ||
          (u['nip'] as String).toLowerCase() == idf,
      orElse: () => {},
    );
    if (user.isEmpty || user['password'] != password) {
      throw Exception('Email atau password salah');
    }
    if (user['isApproved'] != true) {
      throw Exception('Akun belum di-approve oleh HR.');
    }

    final access = 'mock-access-${user['id']}';
    final refresh = 'mock-refresh-${user['id']}';
    await tokenStore.saveTokens(accessToken: access, refreshToken: refresh);
    final public = _userPublic(user);
    await tokenStore.saveUserJson(jsonEncode(public));
    _currentUser = public;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    await tokenStore.clear();
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    final user = _users.firstWhere(
      (u) => (u['email'] as String).toLowerCase() == normalized,
      orElse: () => {},
    );
    if (user.isNotEmpty) {
      final token = 'mock-reset-${_uuid.v4()}';
      _passwordResetTokens[token] = normalized;
      return {
        'message': 'Jika akun terdaftar, instruksi reset password dikirim.',
        'reset': {'token': token},
      };
    }
    return {
      'message': 'Jika akun terdaftar, instruksi reset password dikirim.',
    };
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    final email = _passwordResetTokens.remove(token.trim());
    if (email == null) throw Exception('Token reset tidak valid.');
    if (newPassword.length < 8) {
      throw Exception('Password baru minimal 8 karakter.');
    }
    final user = _users.firstWhere(
      (u) => (u['email'] as String).toLowerCase() == email,
      orElse: () => {},
    );
    if (user.isEmpty) throw Exception('User tidak ditemukan.');
    user['password'] = newPassword;
  }

  @override
  Future<bool> refreshAccessToken() async {
    final rt = await tokenStore.refreshToken();
    if (rt == null) return false;
    await tokenStore.saveTokens(
        accessToken: 'mock-access-refreshed', refreshToken: rt);
    return true;
  }

  @override
  Future<Map<String, dynamic>> me() async => _getUser();

  @override
  Future<Map<String, dynamic>> todayStatus() async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final todays = _attendances.where((a) {
      if (a['userId'] != uid) return false;
      final t = DateTime.tryParse(a['timestamp'] ?? '');
      if (t == null) return false;
      final local = t.toLocal();
      return local.isAfter(start) && local.isBefore(end);
    }).toList();

    final masuk = todays.where((a) => a['type'] == 'MASUK').toList();
    final pulang = todays.where((a) => a['type'] == 'PULANG').toList();

    final weekly = _buildWeeklySummary(uid);
    final weekEntries = _buildWeekEntries(uid);

    if (masuk.isNotEmpty && pulang.isNotEmpty) {
      return {
        'status': 'SUDAH_PULANG',
        'checkInAt': masuk.first['timestamp'],
        'checkOutAt': pulang.first['timestamp'],
        'weeklySummary': weekly,
        'weekEntries': weekEntries,
      };
    }
    if (masuk.isNotEmpty) {
      return {
        'status': 'SUDAH_MASUK',
        'checkInAt': masuk.first['timestamp'],
        'weeklySummary': weekly,
        'weekEntries': weekEntries,
      };
    }
    return {
      'status': 'BELUM_ABSEN',
      'weeklySummary': weekly,
      'weekEntries': weekEntries,
    };
  }

  Map<String, dynamic> _buildWeeklySummary(String uid) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekAttendances = _attendances.where((a) {
      if (a['userId'] != uid || a['type'] != 'MASUK') return false;
      final t = DateTime.tryParse(a['timestamp'] ?? '');
      if (t == null) return false;
      return t.toLocal().isAfter(weekStart);
    }).toList();

    int hadir = 0, terlambat = 0, izin = 0, cuti = 0;
    for (final a in weekAttendances) {
      final status = a['status'] as String? ?? '';
      if (status == 'HADIR') hadir++;
      if (status == 'TERLAMBAT') terlambat++;
      if (status == 'IZIN') izin++;
      if (status == 'CUTI') cuti++;
    }
    return {
      'hadir': hadir,
      'terlambat': terlambat,
      'izin': izin,
      'cuti': cuti,
    };
  }

  List<Map<String, dynamic>> _buildWeekEntries(String uid) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final weekStart = startOfToday.subtract(Duration(days: now.weekday - 1));
    final entries = List.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      return <String, dynamic>{'date': _dateKey(day)};
    });

    for (final attendance in _attendances.where((a) => a['userId'] == uid)) {
      final parsed =
          DateTime.tryParse(attendance['timestamp']?.toString() ?? '');
      if (parsed == null) continue;
      final key = _dateKey(parsed.toLocal());
      final entry = entries.firstWhere(
        (item) => item['date'] == key,
        orElse: () => <String, dynamic>{},
      );
      if (entry.isEmpty) continue;
      if (attendance['type'] == 'MASUK') {
        entry['status'] = attendance['status'];
        entry['checkInAt'] = attendance['timestamp'];
      }
      if (attendance['type'] == 'PULANG') {
        entry['checkOutAt'] = attendance['timestamp'];
        entry['status'] ??= 'HADIR';
      }
    }

    return entries;
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  Future<List<dynamic>> attendanceHistory(
      {String? month, String? status}) async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    var rows = _attendances.where((a) => a['userId'] == uid).toList();
    if (month != null && month.isNotEmpty) {
      rows = rows
          .where((a) => (a['timestamp'] ?? '').toString().startsWith(month))
          .toList();
    }
    if (status != null) {
      rows = rows.where((a) => a['status'] == status).toList();
    }
    rows.sort((a, b) => (b['timestamp'] ?? '')
        .toString()
        .compareTo((a['timestamp'] ?? '').toString()));
    return rows;
  }

  @override
  Future<Response<dynamic>> health() async {
    return Response(requestOptions: RequestOptions(path: '/'), statusCode: 200);
  }

  @override
  Future<String> uploadDocument({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_uuid.v4()}-$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes);
    final url = 'local://$path';
    _uploadedFiles[url] = Uint8List.fromList(bytes);
    return url;
  }

  @override
  Future<Map<String, dynamic>> submitAttendance(
      Map<String, dynamic> payload) async {
    final user = await _getUser();
    final rec = Map<String, dynamic>.from(payload);
    rec['id'] = _uuid.v4();
    rec['userId'] = user['id'];
    rec['timestamp'] =
        payload['timestamp'] ?? DateTime.now().toUtc().toIso8601String();
    rec['status'] = 'HADIR';
    rec['distanceM'] = 15;
    _attendances.add(rec);
    return rec;
  }

  @override
  Future<Map<String, dynamic>> syncOffline(
      List<Map<String, dynamic>> entries) async {
    final results = <Map<String, dynamic>>[];
    for (final e in entries) {
      final item = Map<String, dynamic>.from(e);
      item['id'] = _uuid.v4();
      item['userId'] = (await _getUser())['id'];
      _attendances.add(item);
      results.add({
        'sessionId': item['sessionId'] ?? item['id'],
        'status': 'SYNCED',
      });
    }
    return {'synced': true, 'count': entries.length, 'results': results};
  }

  // ── Leave ──

  @override
  Future<List<dynamic>> leaveMine() async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    return _leaveRequests.where((l) => l['userId'] == uid).toList()
      ..sort((a, b) => (b['createdAt'] ?? '')
          .toString()
          .compareTo((a['createdAt'] ?? '').toString()));
  }

  @override
  Future<List<dynamic>> leavePending() async {
    final user = await _getUser();
    final role = user['role'] as String? ?? '';
    final uid = user['id'] as String? ?? '';

    if (['HR', 'SUPER_ADMIN'].contains(role)) {
      // HR & SUPER_ADMIN lihat semua yang pending
      return _leaveRequests
          .where((l) =>
              l['status'] == 'MENUNGGU_MANAJER' ||
              l['status'] == 'MENUNGGU_HR' ||
              l['status'] == 'ESKALASI')
          .toList();
    }

    if (role == 'MANAJER') {
      // Manajer hanya lihat yang MENUNGGU_MANAJER dari bawahannya
      final subordinateIds = _users
          .where((u) => u['directManagerId'] == uid)
          .map((u) => u['id'] as String)
          .toList();
      return _leaveRequests
          .where((l) =>
              l['status'] == 'MENUNGGU_MANAJER' &&
              subordinateIds.contains(l['userId']))
          .toList();
    }

    return [];
  }

  @override
  Future<void> createLeave(Map<String, dynamic> payload) async {
    final user = await _getUser();
    final rec = Map<String, dynamic>.from(payload);
    rec['id'] = _uuid.v4();
    rec['userId'] = user['id'];
    rec['user'] = _userPublic(user);
    rec['status'] = 'MENUNGGU_MANAJER';
    rec['createdAt'] = DateTime.now().toIso8601String();
    _leaveRequests.add(rec);

    // Notifikasi ke manajer langsung
    final managerId = user['directManagerId'] as String?;
    if (managerId != null) {
      _notifications.add({
        'id': _uuid.v4(),
        'userId': managerId,
        'type': 'LEAVE_REQUEST',
        'title': 'Pengajuan izin baru',
        'body':
            '${user['name']} mengajukan ${(payload['type'] ?? '').toString().toLowerCase()}.',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<Map<String, dynamic>> leaveBalance() async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    final now = DateTime.now();
    final year = now.year;

    final approved = _leaveRequests.where((l) {
      if (l['userId'] != uid) return false;
      final status = l['status'] as String? ?? '';
      if (!status.contains('DISETUJUI') && !status.contains('APPROVE')) {
        return false;
      }
      final from = DateTime.tryParse(l['dateFrom'] ?? '');
      return from != null && from.year == year;
    }).toList();

    int cutiUsed = 0, sakitUsed = 0, izinUsed = 0;
    for (final l in approved) {
      final from = DateTime.tryParse(l['dateFrom'] ?? '');
      final to = DateTime.tryParse(l['dateTo'] ?? '');
      if (from == null || to == null) continue;
      final days = to.difference(from).inDays + 1;
      final type = (l['type'] as String? ?? '').toUpperCase();
      if (type.contains('CUTI')) cutiUsed += days;
      if (type.contains('SAKIT')) sakitUsed += days;
      if (type.contains('IZIN') || type.contains('DINAS')) izinUsed += days;
    }

    final balance = _leaveBalances.firstWhere(
      (item) => item['userId'] == uid && item['year'] == year,
      orElse: () => {},
    );
    final cutiTotal = balance['annualQuota'] as int? ?? 12;
    final cutiBalanceUsed = balance['used'] as int? ?? cutiUsed;

    return {
      'year': year,
      'cuti': {
        'total': cutiTotal,
        'used': cutiBalanceUsed,
        'remaining': cutiTotal - cutiBalanceUsed,
      },
      'sakit': {'total': -1, 'used': sakitUsed, 'remaining': -1},
      'izin': {'total': -1, 'used': izinUsed, 'remaining': -1},
    };
  }

  @override
  Future<void> approveLeave({
    required String id,
    required String status,
    required bool approved,
    String? comment,
  }) async {
    final item =
        _leaveRequests.firstWhere((l) => l['id'] == id, orElse: () => {});
    if (item.isEmpty) throw Exception('Pengajuan tidak ditemukan');

    final user = await _getUser();
    final role = user['role'] as String? ?? '';

    if (approved) {
      if (status == 'MENUNGGU_MANAJER') {
        // Cek apakah perlu HR approval (>3 hari)
        final dateFrom = DateTime.tryParse(item['dateFrom'] ?? '');
        final dateTo = DateTime.tryParse(item['dateTo'] ?? '');
        int days = 1;
        if (dateFrom != null && dateTo != null) {
          days = dateTo.difference(dateFrom).inDays + 1;
        }

        if (days > 3 && ['HR', 'SUPER_ADMIN'].contains(role)) {
          // HR bisa langsung approve
          item['status'] = 'DISETUJUI';
          item['hrApprovedAt'] = DateTime.now().toIso8601String();
          item['hrComment'] = comment;
        } else if (days > 3) {
          // Manajer approve, naik ke HR
          item['status'] = 'MENUNGGU_HR';
          item['managerApprovedAt'] = DateTime.now().toIso8601String();
          item['managerComment'] = comment;
          // Notifikasi HR
          for (final u in _users
              .where((u) => u['role'] == 'HR' || u['role'] == 'SUPER_ADMIN')) {
            _notifications.add({
              'id': _uuid.v4(),
              'userId': u['id'],
              'type': 'LEAVE_HR_REVIEW',
              'title': 'Butuh approval HR',
              'body': 'Pengajuan cuti $days hari menunggu approval kamu.',
              'read': false,
              'createdAt': DateTime.now().toIso8601String(),
            });
          }
        } else {
          // Langsung approve (≤3 hari)
          item['status'] = 'DISETUJUI';
          item['managerApprovedAt'] = DateTime.now().toIso8601String();
          item['managerComment'] = comment;
        }
      } else if (status == 'MENUNGGU_HR') {
        item['status'] = 'DISETUJUI';
        item['hrApprovedAt'] = DateTime.now().toIso8601String();
        item['hrComment'] = comment;
      }

      if (item['status'] == 'DISETUJUI') {
        _applyLeaveBalanceUsage(item);
      }

      // Notifikasi ke pemohon
      _notifications.add({
        'id': _uuid.v4(),
        'userId': item['userId'],
        'type': 'LEAVE_APPROVED',
        'title': 'Pengajuan disetujui',
        'body': 'Pengajuan ${item['type']} kamu sudah disetujui.',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } else {
      item['status'] = 'DITOLAK';
      item['rejectionReason'] = comment;
      _notifications.add({
        'id': _uuid.v4(),
        'userId': item['userId'],
        'type': 'LEAVE_REJECTED',
        'title': 'Pengajuan ditolak',
        'body': comment ?? 'Pengajuan ditolak.',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // ── Notifications ──

  void _applyLeaveBalanceUsage(Map<String, dynamic> item) {
    final type = (item['type'] as String? ?? '').toUpperCase();
    if (!type.contains('CUTI')) return;

    final from = DateTime.tryParse(item['dateFrom']?.toString() ?? '');
    final to = DateTime.tryParse(item['dateTo']?.toString() ?? '');
    if (from == null || to == null) return;

    final userId = item['userId'];
    final year = from.year;
    final days = to.difference(from).inDays + 1;
    final balance = _leaveBalances.firstWhere(
      (entry) => entry['userId'] == userId && entry['year'] == year,
      orElse: () => {},
    );
    if (balance.isEmpty) return;

    final annualQuota = balance['annualQuota'] as int? ?? 12;
    final used = (balance['used'] as int? ?? 0) + days;
    balance['used'] = used;
    balance['remaining'] = annualQuota - used;
  }

  @override
  Future<List<dynamic>> notifications() async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    return _notifications.where((n) => n['userId'] == uid).toList()
      ..sort((a, b) => (b['createdAt'] ?? '')
          .toString()
          .compareTo((a['createdAt'] ?? '').toString()));
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final n = _notifications.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (n.isNotEmpty) n['read'] = true;
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    for (final n in _notifications.where((x) => x['userId'] == uid)) {
      n['read'] = true;
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    final dbUser = _users.firstWhere((u) => u['id'] == uid, orElse: () => {});
    if (dbUser.isNotEmpty) {
      if (name != null) dbUser['name'] = name;
      if (phone != null) dbUser['phone'] = phone;
      if (photoUrl != null) dbUser['photoUrl'] = photoUrl;
    }
    if (name != null) user['name'] = name;
    if (phone != null) user['phone'] = phone;
    if (photoUrl != null) user['photoUrl'] = photoUrl;
    await tokenStore.saveUserJson(jsonEncode(user));
    return Map<String, dynamic>.from(user);
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await _getUser();
    final uid = user['id'] as String? ?? '';
    final dbUser = _users.firstWhere((u) => u['id'] == uid, orElse: () => {});
    if (dbUser.isEmpty) throw Exception('User tidak ditemukan');
    if (dbUser['password'] != oldPassword) {
      throw Exception('Password lama salah.');
    }
    if (newPassword.length < 8) {
      throw Exception('Password baru minimal 8 karakter.');
    }
    dbUser['password'] = newPassword;
  }

  // ── Admin ──

  @override
  Future<List<dynamic>> adminUsers() async => _users.map(_userPublic).toList();

  @override
  Future<Map<String, dynamic>> adminSummary() async {
    final todayKey = _dateKey(DateTime.now());
    return {
      'totalUsers': _users.length,
      'activeUsers': _users.where((u) => u['isActive'] == true).length,
      'activeEmployees': _users
          .where((u) => u['role'] == 'KARYAWAN' && u['isActive'] == true)
          .length,
      'pendingApproval': _users.where((u) => u['isApproved'] != true).length,
      'pendingLeaves':
          _leaveRequests.where((l) => l['status'] != 'APPROVED').length,
      'reviewAttendances':
          _attendances.where((a) => a['anomalyFlag'] == true).length,
      'activeOffices': _offices.length,
      'totalShifts': _shifts.length,
      'totalDepartments': _departments.length,
      'todayCheckIns': _attendances
          .where((a) =>
              a['type'] == 'MASUK' &&
              (a['timestamp'] ?? '').toString().startsWith(todayKey))
          .length,
    };
  }

  @override
  Future<List<dynamic>> adminDepartments() async => _departments;

  @override
  Future<List<dynamic>> adminShifts() async => _shifts;

  @override
  Future<List<dynamic>> adminOffices() async => _offices;

  @override
  Future<List<dynamic>> adminAnomalies() async =>
      _attendances.where((a) => a['anomalyFlag'] == true).toList();

  @override
  Future<List<dynamic>> adminHolidays() async => _holidays;

  @override
  Future<List<dynamic>> adminAuditLogs() async => [];

  @override
  Future<void> createAdminUser(Map<String, dynamic> payload) async {
    final rec = Map<String, dynamic>.from(payload);
    rec['id'] = _uuid.v4();
    rec['isApproved'] = true;
    rec['isActive'] = true;
    rec['emailVerified'] = true;
    rec['createdAt'] = DateTime.now().toIso8601String();
    _users.add(rec);
  }

  @override
  Future<void> updateAdminUser(String id, Map<String, dynamic> payload) async {
    final u = _users.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (u.isEmpty) throw Exception('User tidak ditemukan');
    u.addAll(payload);
  }

  @override
  Future<void> createDepartment(String name) async {
    _departments.add({
      'id': _uuid.v4(),
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateDepartment(String id, String name) async {
    final item =
        _departments.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (item.isEmpty) throw Exception('Department tidak ditemukan');
    item['name'] = name;
  }

  @override
  Future<void> deleteDepartment(String id) async {
    final used = _users.any((u) => u['departmentId'] == id);
    if (used) throw Exception('Department masih dipakai user');
    _departments.removeWhere((x) => x['id'] == id);
  }

  @override
  Future<void> createShift(Map<String, dynamic> payload) async {
    _shifts.add({'id': _uuid.v4(), ...payload});
  }

  @override
  Future<void> updateShift(String id, Map<String, dynamic> payload) async {
    final item = _shifts.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (item.isEmpty) throw Exception('Shift tidak ditemukan');
    item.addAll(payload);
  }

  @override
  Future<void> deleteShift(String id) async {
    final used = _users.any((u) => u['shiftId'] == id) ||
        _attendances.any((a) => a['shiftId'] == id);
    if (used) throw Exception('Shift masih dipakai user atau absensi');
    _shifts.removeWhere((x) => x['id'] == id);
  }

  @override
  Future<void> createOffice(Map<String, dynamic> payload) async {
    _offices.add({'id': _uuid.v4(), ...payload});
  }

  @override
  Future<void> updateOffice(String id, Map<String, dynamic> payload) async {
    final item = _offices.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (item.isEmpty) throw Exception('Lokasi kantor tidak ditemukan');
    item.addAll(payload);
  }

  @override
  Future<void> deleteOffice(String id) async {
    _offices.removeWhere((x) => x['id'] == id);
    for (final user in _users) {
      final offices = user['officeLocations'];
      if (offices is List) {
        offices.removeWhere((office) => office is Map && office['id'] == id);
      }
    }
  }

  @override
  Future<void> createHoliday(Map<String, dynamic> payload) async {
    _holidays.add({'id': _uuid.v4(), ...payload});
  }

  @override
  Future<void> updateHoliday(String id, Map<String, dynamic> payload) async {
    final item = _holidays.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (item.isEmpty) throw Exception('Hari libur tidak ditemukan');
    item.addAll(payload);
  }

  @override
  Future<void> deleteHoliday(String id) async {
    _holidays.removeWhere((x) => x['id'] == id);
  }

  @override
  Future<List<dynamic>> adminLeaveBalances({int? year}) async {
    return _leaveBalances.where((item) {
      return year == null || item['year'] == year;
    }).toList()
      ..sort((a, b) => '${b['year']}'.compareTo('${a['year']}'));
  }

  @override
  Future<void> createLeaveBalance(Map<String, dynamic> payload) async {
    final userId = payload['userId'];
    final year = payload['year'];
    final exists = _leaveBalances.any(
      (item) => item['userId'] == userId && item['year'] == year,
    );
    if (exists) throw Exception('Saldo cuti user untuk tahun ini sudah ada');
    final user = _users.firstWhere((u) => u['id'] == userId, orElse: () => {});
    if (user.isEmpty) throw Exception('User tidak ditemukan');
    final annualQuota = payload['annualQuota'] as int? ?? 12;
    final used = payload['used'] as int? ?? 0;
    if (used > annualQuota) {
      throw Exception('Cuti terpakai tidak boleh lebih besar dari kuota');
    }
    _leaveBalances.add({
      'id': _uuid.v4(),
      'userId': userId,
      'year': year,
      'annualQuota': annualQuota,
      'used': used,
      'remaining': annualQuota - used,
      'user': _userPublic(user),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateLeaveBalance(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final item =
        _leaveBalances.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (item.isEmpty) throw Exception('Saldo cuti tidak ditemukan');
    final annualQuota =
        payload['annualQuota'] as int? ?? item['annualQuota'] as int? ?? 12;
    final used = payload['used'] as int? ?? item['used'] as int? ?? 0;
    if (used > annualQuota) {
      throw Exception('Cuti terpakai tidak boleh lebih besar dari kuota');
    }
    item['annualQuota'] = annualQuota;
    item['used'] = used;
    item['remaining'] = annualQuota - used;
  }

  @override
  Future<void> deleteLeaveBalance(String id) async {
    _leaveBalances.removeWhere((x) => x['id'] == id);
  }

  @override
  Future<List<dynamic>> payrollSummary({required String month}) async {
    final results = <Map<String, dynamic>>[];
    for (final user in _users
        .where((u) => u['isApproved'] == true && u['role'] == 'KARYAWAN')) {
      final uid = user['id'] as String;
      final monthAttendances = _attendances.where((a) =>
          a['userId'] == uid &&
          (a['timestamp'] ?? '').toString().startsWith(month) &&
          a['type'] == 'MASUK');

      int hadir = 0, terlambat = 0, izin = 0, cuti = 0;
      for (final a in monthAttendances) {
        final s = a['status'] as String? ?? '';
        if (s == 'HADIR') hadir++;
        if (s == 'TERLAMBAT') terlambat++;
        if (s == 'IZIN') izin++;
        if (s == 'CUTI') cuti++;
      }

      results.add({
        'userId': user['name'],
        'totalHadir': hadir,
        'totalTerlambat': terlambat,
        'totalIzin': izin,
        'totalCuti': cuti,
        'totalLemburJam': 0,
      });
    }
    return results;
  }

  @override
  Future<Map<String, dynamic>> lockPayrollMonth({required String month}) async {
    return {
      'locked': true,
      'delivered': false,
      'reason': 'Webhook belum aktif'
    };
  }

  @override
  Future<String> downloadReport({
    required String month,
    required String format,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/absensi-$month.$format');
    await file.writeAsBytes(<int>[80, 75, 3, 4]);
    return file.path;
  }

  @override
  Future<Map<String, dynamic>> reportsAnalytics({String? month}) async {
    final now = DateTime.now();
    final selectedMonth =
        month ?? '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final rows = _attendances
        .where(
            (a) => (a['timestamp'] ?? '').toString().startsWith(selectedMonth))
        .toList();
    final totalEmployees = _users
        .where((u) => u['isActive'] == true && u['isApproved'] == true)
        .length;
    final byStatus = <String, int>{};
    final employeesWithAttendance = <String>{};
    final lateRanking = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final status = row['status']?.toString() ?? 'UNKNOWN';
      byStatus[status] = (byStatus[status] ?? 0) + 1;
      final userId = row['userId']?.toString();
      if (userId != null && (status == 'HADIR' || status == 'TERLAMBAT')) {
        employeesWithAttendance.add(userId);
      }
      if (userId != null && status == 'TERLAMBAT') {
        final user = _users.firstWhere(
          (u) => u['id'] == userId,
          orElse: () => {'nip': userId, 'name': userId},
        );
        final item = lateRanking.putIfAbsent(
          userId,
          () => {
            'nip': user['nip'],
            'name': user['name'],
            'count': 0,
          },
        );
        item['count'] = (item['count'] as int) + 1;
      }
    }

    return {
      'month': selectedMonth,
      'totalEmployees': totalEmployees,
      'totalAttendances': rows.length,
      'averageAttendanceRate': totalEmployees == 0
          ? 0
          : ((employeesWithAttendance.length / totalEmployees) * 100).round(),
      'anomalies': rows.where((row) => row['anomalyFlag'] == true).length,
      'byStatus': byStatus,
      'attendanceRate': rows.isEmpty
          ? 0
          : ((byStatus['HADIR'] ?? 0) + (byStatus['TERLAMBAT'] ?? 0)) /
              rows.length,
      'topLateEmployees': lateRanking.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int)),
    };
  }

  @override
  Future<void> approveUser({
    required String id,
    required bool approved,
    String? reason,
  }) async {
    final u = _users.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (u.isEmpty) throw Exception('User tidak ditemukan');
    u['isApproved'] = approved;
    _notifications.add({
      'id': _uuid.v4(),
      'userId': id,
      'type': 'ACCOUNT_APPROVAL',
      'title': approved ? 'Akun disetujui' : 'Akun dinonaktifkan',
      'body': approved
          ? 'Akun kamu sudah bisa digunakan untuk presensi.'
          : 'Akun kamu perlu ditinjau ulang HR.',
      'read': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> reviewAnomaly({
    required String id,
    required String action,
    required String notes,
  }) async {
    final a = _attendances.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (a.isEmpty) return;
    a['status'] = action == 'REJECT' ? 'DITOLAK' : 'HADIR';
    a['anomalyFlag'] = action == 'WARN';
    a['notes'] = notes;
  }

  @override
  Future<Uint8List?> attendancePhotoBytes(String? photoUrl) async {
    if (photoUrl == null) return null;
    final uploaded = _uploadedFiles[photoUrl];
    if (uploaded != null) return uploaded;
    return Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII='));
  }
}
