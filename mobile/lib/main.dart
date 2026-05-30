import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/attendance_app.dart';
import 'core/offline/background_sync.dart';
import 'core/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initializeBackgroundSync();
  await PushNotificationService.initialize();
  runApp(const AttendanceApp());
}
