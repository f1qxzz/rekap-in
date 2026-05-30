import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../api/api_client.dart';
import '../storage/token_store.dart';

class OfflineQueue {
  OfflineQueue({required this.tokenStore});

  final TokenStore tokenStore;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'attendance_offline.sqlite');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_queue (
            id TEXT PRIMARY KEY,
            payload_encrypted TEXT NOT NULL,
            created_at_local TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            last_status TEXT NOT NULL DEFAULT 'PENDING',
            last_error TEXT,
            synced_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _tryAddColumn(
            db,
            "ALTER TABLE offline_queue ADD COLUMN last_status TEXT NOT NULL DEFAULT 'PENDING'",
          );
          await _tryAddColumn(
            db,
            'ALTER TABLE offline_queue ADD COLUMN last_error TEXT',
          );
          await _tryAddColumn(
            db,
            'ALTER TABLE offline_queue ADD COLUMN synced_at TEXT',
          );
        }
      },
    );
    return _db!;
  }

  Future<int> pendingCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM offline_queue WHERE synced = 0'),
    );
    return result ?? 0;
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final count = await pendingCount();
    if (count >= 5) {
      throw Exception(
          'Antrean offline penuh (maksimal 5). Hapus antrean lama atau sinkronisasi terlebih dahulu.');
    }

    final db = await database;
    await db.insert('offline_queue', {
      'id': payload['sessionId'] as String,
      'payload_encrypted': await _encrypt(payload),
      'created_at_local': DateTime.now().toIso8601String(),
      'synced': 0,
      'last_status': 'PENDING',
      'last_error': null,
      'synced_at': null,
    });
  }

  Future<List<Map<String, dynamic>>> entries({int limit = 50}) async {
    final db = await database;
    return db.query(
      'offline_queue',
      orderBy: 'created_at_local DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> pendingPayloads() async {
    final db = await database;
    final rows = await db.query(
      'offline_queue',
      where: 'synced = 0',
      orderBy: 'created_at_local ASC',
      limit: 5,
    );

    final payloads = <Map<String, dynamic>>[];
    for (final row in rows) {
      payloads.add(await _decrypt(row['payload_encrypted'] as String));
    }
    return payloads;
  }

  Future<void> sync(ApiClient apiClient) async {
    final db = await database;
    final rows = await db.query(
      'offline_queue',
      where: 'synced = 0',
      orderBy: 'created_at_local ASC',
      limit: 5,
    );
    if (rows.isEmpty) return;

    final ids = rows.map((row) => row['id'] as String).toList();
    final payloads = <Map<String, dynamic>>[];
    for (final row in rows) {
      payloads.add(await _decrypt(row['payload_encrypted'] as String));
    }

    await _markRows(db, ids, status: 'SYNCING');

    Map<String, dynamic> result;
    try {
      result = await apiClient.syncOffline(payloads);
    } catch (error) {
      await _markRows(
        db,
        ids,
        status: 'FAILED',
        error: ApiClient.errorMessage(
          error,
          fallback: 'Sinkronisasi gagal. Coba lagi nanti.',
        ),
      );
      rethrow;
    }

    // Backend mengembalikan 'results' atau 'data' berisi status per entri
    final items = (result['results'] ?? result['data']) as List<dynamic>? ?? [];
    final syncedAt = DateTime.now().toIso8601String();
    if (items.isEmpty) {
      // Jika backend tidak mengembalikan detail, anggap semua berhasil
      await db.update(
        'offline_queue',
        {
          'synced': 1,
          'last_status': 'SYNCED',
          'last_error': null,
          'synced_at': syncedAt,
        },
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
      return;
    }

    final touchedIds = <String>{};
    for (final item in items) {
      if (item is! Map) continue;
      final status = item['status'] as String? ?? '';
      final sessionId =
          item['sessionId'] as String? ?? item['id'] as String? ?? '';
      if (sessionId.isEmpty) continue;
      touchedIds.add(sessionId);
      if ((status == 'SYNCED' || status == 'DUPLICATE_REVIEW') &&
          sessionId.isNotEmpty) {
        await db.update(
          'offline_queue',
          {
            'synced': 1,
            'last_status': status,
            'last_error': null,
            'synced_at': syncedAt,
          },
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      } else {
        await db.update(
          'offline_queue',
          {
            'last_status': status.isEmpty ? 'FAILED' : status,
            'last_error': item['message']?.toString(),
          },
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      }
    }

    final untouchedIds = ids.where((id) => !touchedIds.contains(id)).toList();
    if (untouchedIds.isNotEmpty) {
      await _markRows(db, untouchedIds, status: 'PENDING');
    }
  }

  Future<String> _encrypt(Map<String, dynamic> payload) async {
    final encrypter = await _encrypter();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(jsonEncode(payload), iv: iv);
    return jsonEncode({
      'iv': iv.base64,
      'value': encrypted.base64,
    });
  }

  Future<Map<String, dynamic>> _decrypt(String value) async {
    final data = jsonDecode(value) as Map<String, dynamic>;
    final encrypter = await _encrypter();
    final decrypted = encrypter.decrypt64(
      data['value'] as String,
      iv: enc.IV.fromBase64(data['iv'] as String),
    );
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  Future<enc.Encrypter> _encrypter() async {
    var key = await tokenStore.offlineEncryptionKey();
    if (key == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = base64Encode(bytes);
      await tokenStore.saveOfflineEncryptionKey(key);
    }
    return enc.Encrypter(enc.AES(enc.Key.fromBase64(key)));
  }

  static Future<void> _tryAddColumn(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {
      // Kolom bisa sudah ada jika database sempat di-upgrade sebagian.
    }
  }

  static Future<void> _markRows(
    Database db,
    List<String> ids, {
    required String status,
    String? error,
  }) async {
    if (ids.isEmpty) return;
    await db.update(
      'offline_queue',
      {
        'last_status': status,
        'last_error': error,
      },
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }
}
