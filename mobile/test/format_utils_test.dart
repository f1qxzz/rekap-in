import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:absensi_mobile/core/utils/format_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('formatDate', () {
    test('returns formatted date for valid ISO string', () {
      final result = formatDate('2026-05-28T10:30:00Z');
      expect(result, isNot(equals('-')));
      expect(result, contains('2026'));
    });

    test('returns dash for null', () {
      expect(formatDate(null), '-');
    });

    test('returns dash for invalid string', () {
      expect(formatDate('not-a-date'), '-');
    });
  });

  group('formatTime', () {
    test('returns formatted time for valid ISO string', () {
      final result = formatTime('2026-05-28T10:30:00Z');
      expect(result, isNot(equals('--:--')));
      expect(result, contains(':'));
    });

    test('returns --:-- for null', () {
      expect(formatTime(null), '--:--');
    });
  });

  group('formatDateTime', () {
    test('returns formatted datetime for valid ISO string', () {
      final result = formatDateTime('2026-05-28T10:30:00Z');
      expect(result, isNot(equals('-')));
    });

    test('returns dash for null', () {
      expect(formatDateTime(null), '-');
    });
  });

  group('StatusMeta', () {
    test('returns correct meta for BELUM_ABSEN', () {
      final meta = StatusMeta.fromStatus('BELUM_ABSEN');
      expect(meta.title, 'Belum Absen');
      expect(meta.color, isNotNull);
    });

    test('returns correct meta for SUDAH_MASUK', () {
      final meta = StatusMeta.fromStatus('SUDAH_MASUK');
      expect(meta.title, 'Sudah Masuk');
    });

    test('returns correct meta for SELESAI', () {
      final meta = StatusMeta.fromStatus('SELESAI');
      expect(meta.title, 'Selesai');
    });

    test('statusColor returns correct colors', () {
      expect(StatusMeta.statusColor('HADIR'), isNotNull);
      expect(StatusMeta.statusColor('TERLAMBAT'), isNotNull);
      expect(StatusMeta.statusColor('DITOLAK'), isNotNull);
    });
  });
}
