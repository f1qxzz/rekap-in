import 'dart:io';

/// Verifies device integrity by checking for root/jailbreak indicators
/// and emulator characteristics.
///
/// NOTE: For production, integrate Google Play Integrity API (Android)
/// and Apple App Attest (iOS) for cryptographic device attestation.
/// This service provides basic client-side checks as a first line of defense.
class DeviceIntegrityService {
  Future<Map<String, dynamic>> collectVerdict() async {
    final isRootedOrJailbroken = await _looksRootedOrJailbroken();
    final isEmulator = await _isProbablyEmulator();
    final passed = !isRootedOrJailbroken && !isEmulator;

    return {
      'verdict': passed ? 'PASSED' : 'FAILED',
      'reason': passed
          ? 'Device checks passed'
          : isRootedOrJailbroken
              ? 'Root/jailbreak indicator found'
              : 'Running on emulator',
      'isEmulator': isEmulator,
      'isJailbrokenOrRooted': isRootedOrJailbroken,
      'elapsedRealtimeMs': DateTime.now().millisecondsSinceEpoch,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    };
  }

  Future<bool> _looksRootedOrJailbroken() async {
    final suspiciousPaths = Platform.isAndroid
        ? [
            '/system/app/Superuser.apk',
            '/sbin/su',
            '/system/bin/su',
            '/system/xbin/su',
            '/data/local/xbin/su',
            '/data/local/bin/su',
            '/system/sd/xbin/su',
            '/system/bin/failsafe/su',
            '/data/local/su',
          ]
        : [
            '/Applications/Cydia.app',
            '/Library/MobileSubstrate/MobileSubstrate.dylib',
            '/bin/bash',
            '/usr/sbin/sshd',
            '/etc/apt',
          ];

    for (final path in suspiciousPaths) {
      try {
        if (await File(path).exists() || await Directory(path).exists()) {
          return true;
        }
      } catch (_) {
        // Permission denied — expected on non-rooted devices
      }
    }

    return false;
  }

  Future<bool> _isProbablyEmulator() async {
    if (Platform.isAndroid) {
      final fingerprint = Platform.environment['ANDROID_FINGERPRINT'] ?? '';
      if (fingerprint.contains('generic') || fingerprint.contains('sdk')) {
        return true;
      }
      final model = Platform.environment['ANDROID_MODEL'] ?? '';
      if (model.toLowerCase().contains('sdk') ||
          model.toLowerCase().contains('emulator')) {
        return true;
      }
    }
    return false;
  }
}
