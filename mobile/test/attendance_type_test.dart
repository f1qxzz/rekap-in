import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_mobile/features/attendance/attendance_flow_page.dart';

void main() {
  group('AttendanceType', () {
    test('masuk has correct apiValue', () {
      expect(AttendanceType.masuk.apiValue, 'MASUK');
    });

    test('pulang has correct apiValue', () {
      expect(AttendanceType.pulang.apiValue, 'PULANG');
    });

    test('lembur has correct apiValue', () {
      expect(AttendanceType.lembur.apiValue, 'LEMBUR');
    });

    test('each type has a non-empty label', () {
      for (final type in AttendanceType.values) {
        expect(type.label.isNotEmpty, true);
      }
    });

    test('each type has an icon', () {
      for (final type in AttendanceType.values) {
        expect(type.icon, isNotNull);
      }
    });
  });
}
