import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../storage/token_store.dart';
import 'offline_queue.dart';

const attendanceSyncTask = 'attendance_offline_sync';

@pragma('vm:entry-point')
void attendanceCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != attendanceSyncTask) return true;

    final tokenStore = TokenStore();
    final hasSession = await tokenStore.hasRefreshToken();
    if (!hasSession) return true;

    final apiClient = ApiClient(tokenStore: tokenStore);
    final storedBaseUrl = await tokenStore.apiBaseUrl();
    if (storedBaseUrl != null && storedBaseUrl.isNotEmpty) {
      apiClient.setBaseUrl(storedBaseUrl);
    }
    final queue = OfflineQueue(tokenStore: tokenStore);
    await queue.sync(apiClient);
    return true;
  });
}

Future<void> initializeBackgroundSync() async {
  await Workmanager().initialize(attendanceCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    attendanceSyncTask,
    attendanceSyncTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

Future<void> triggerOneOffAttendanceSync() {
  return Workmanager().registerOneOffTask(
    '${attendanceSyncTask}_${DateTime.now().millisecondsSinceEpoch}',
    attendanceSyncTask,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
