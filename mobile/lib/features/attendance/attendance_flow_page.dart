import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/camera/face_match_service.dart';
import '../../core/camera/selfie_capture_page.dart';
import '../../core/location/location_guard.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/offline/background_sync.dart';
import '../../core/security/device_integrity_service.dart';
import '../../core/security/photo_processor.dart';
import '../../core/widgets/glass_widgets.dart';

enum AttendanceType { masuk, pulang, lembur }

extension AttendanceTypeApi on AttendanceType {
  String get apiValue {
    switch (this) {
      case AttendanceType.masuk:
        return 'MASUK';
      case AttendanceType.pulang:
        return 'PULANG';
      case AttendanceType.lembur:
        return 'LEMBUR';
    }
  }

  String get label {
    switch (this) {
      case AttendanceType.masuk:
        return 'Absen Masuk';
      case AttendanceType.pulang:
        return 'Absen Pulang';
      case AttendanceType.lembur:
        return 'Absen Lembur';
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceType.masuk:
        return Icons.login_rounded;
      case AttendanceType.pulang:
        return Icons.logout_rounded;
      case AttendanceType.lembur:
        return Icons.access_time_rounded;
    }
  }
}

class AttendanceFlowPage extends StatefulWidget {
  const AttendanceFlowPage({
    required this.apiClient,
    required this.offlineQueue,
    required this.type,
    required this.user,
    required this.trainingMode,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineQueue offlineQueue;
  final AttendanceType type;
  final Map<String, dynamic> user;
  final bool trainingMode;

  @override
  State<AttendanceFlowPage> createState() => _AttendanceFlowPageState();
}

class _AttendanceFlowPageState extends State<AttendanceFlowPage> {
  final _locationGuard = LocationGuard();
  final _photoProcessor = PhotoProcessor();
  final _faceMatchService = FaceMatchService();
  final _deviceIntegrityService = DeviceIntegrityService();
  final _uuid = const Uuid();

  bool _busy = false;
  bool _disposed = false;
  String _status = 'Siap memulai';
  Position? _position;
  List<Map<String, dynamic>> _offices = [];

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  Future<void> _loadOffices() async {
    try {
      final data = await widget.apiClient.attendanceOffices();
      if (mounted) {
        setState(() => _offices = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      // Office data optional — map tetap jalan tanpa geofence
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _faceMatchService.close();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Memeriksa izin runtime';
    });

    try {
      await _ensurePermissions();
      setState(() => _status = 'Mengambil GPS presisi');
      final position = await _locationGuard.currentPrecisePosition();
      setState(() => _position = position);
      final integrity = await _deviceIntegrityService.collectVerdict();

      final sessionId = _uuid.v4();
      final watermark = _watermarkLines(position, sessionId);
      setState(() => _status = 'Membuka kamera depan');
      final photo = await _captureWithPreview(watermark);
      if (photo == null) {
        setState(() => _status = 'Dibatalkan');
        return;
      }

      setState(() => _status = 'Memvalidasi wajah dan memproses foto');
      if (_disposed || !mounted) return;
      final face = await _faceMatchService.checkSelfie(photo.path);
      if (!face.faceDetected) {
        throw StateError('Wajah tidak terdeteksi. Ambil ulang foto.');
      }
      final processed = await _photoProcessor.process(
        path: photo.path,
        watermarkLines: watermark,
      );

      final payload = {
        'type': widget.type.apiValue,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'provider': Platform.isAndroid ? 'gps' : 'core_location',
        'gpsTimestamp': position.timestamp.toUtc().toIso8601String(),
        'photoBase64': base64Encode(processed.bytes),
        'photoHash': processed.sha256Hash,
        'faceMatchScore': face.similarityScore,
        'faceDetected': face.faceDetected,
        'deviceId': await widget.apiClient.tokenStore.deviceId(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'isMockLocationDetected': position.isMocked,
        'deviceIntegrity': integrity,
        'sessionId': sessionId,
      };

      if (widget.trainingMode) {
        setState(() => _status = 'Mode latihan selesai. Data tidak dikirim.');
        return;
      }

      final online = await _isOnline();
      if (online) {
        setState(() => _status = 'Mengirim absensi');
        await widget.apiClient.submitAttendance(payload);
        if (!mounted) return;
        setState(() => _status = 'Absensi berhasil disimpan');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _status = 'Offline. Menyimpan antrean lokal');
        await widget.offlineQueue.enqueue(payload);
        await triggerOneOffAttendanceSync();
        if (!mounted) return;
        setState(() => _status = 'Absensi tersimpan offline');
        if (!mounted) return;
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) setState(() => _status = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    final message = ApiClient.errorMessage(
      error,
      fallback: error.toString().replaceFirst('Bad state: ', '').trim(),
    );
    return message.replaceFirst('Exception: ', '').trim();
  }

  Future<void> _ensurePermissions() async {
    var camera = await Permission.camera.status;
    if (camera.isPermanentlyDenied) {
      if (!mounted) return;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Izin Kamera Diperlukan'),
          content: const Text(
            'Izin kamera sudah diblokir. Buka Pengaturan aplikasi untuk mengaktifkan kamera.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );
      if (openSettings == true) await openAppSettings();
      throw StateError('Izin kamera belum diberikan.');
    }

    camera = await Permission.camera.request();
    final notification = await Permission.notification.request();

    if (!camera.isGranted) {
      throw StateError('Izin kamera wajib. Buka Settings untuk mengaktifkan.');
    }
    if (!notification.isGranted) {
      throw StateError('Izin notifikasi wajib untuk reminder dan status sync.');
    }
  }

  Future<bool> _isOnline() async {
    try {
      final response = await widget.apiClient.health();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<XFile?> _captureWithPreview(List<String> watermarkLines) async {
    var attempts = 0;
    while (mounted && attempts < 5) {
      attempts++;
      if (!mounted) return null;
      final navigator = Navigator.of(context);
      final photo = await navigator.push<XFile>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SelfieCapturePage(watermarkLines: watermarkLines),
        ),
      );
      if (!mounted) return null;
      if (photo == null) return null;

      final usePhoto = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surfaceFor(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lineFor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Preview Foto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Pastikan wajah terlihat jelas.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedFor(context),
                    ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(photo.path),
                    fit: BoxFit.cover, height: 300),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Ambil Ulang'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: Icon(Icons.check_rounded, size: 18),
                      label: const Text('Gunakan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (usePhoto == true) return photo;
    }
    return null;
  }

  List<String> _watermarkLines(Position position, String sessionId) {
    final name = widget.user['name'] as String? ?? '-';
    final nip = widget.user['nip'] as String? ?? '-';
    final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return [
      '$name / $nip',
      time,
      '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      sessionId,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    return Scaffold(
      backgroundColor: AppTheme.canvasFor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceFor(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.type.label,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FlowStatusCard(
            status: _status,
            busy: _busy,
            completed: _status.contains('berhasil') ||
                _status.contains('selesai') ||
                _status.contains('tersimpan'),
          ),
          const SizedBox(height: 16),
          if (position != null)
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.lineFor(context).withValues(alpha: 0.6),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: 17,
                  ),
                  myLocationButtonEnabled: false,
                  myLocationEnabled: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('employee'),
                      position: LatLng(position.latitude, position.longitude),
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('accuracy'),
                      center: LatLng(position.latitude, position.longitude),
                      radius: position.accuracy,
                      strokeWidth: 2,
                      strokeColor: AppTheme.primary,
                      fillColor: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                    for (final office in _offices)
                      Circle(
                        circleId: CircleId('geo-${office['id']}'),
                        center: LatLng(
                          (office['latitude'] as num).toDouble(),
                          (office['longitude'] as num).toDouble(),
                        ),
                        radius: (office['radiusMeters'] as num).toDouble(),
                        strokeWidth: 2,
                        strokeColor: AppTheme.success.withValues(alpha: 0.6),
                        fillColor: AppTheme.success.withValues(alpha: 0.08),
                      ),
                  },
                ),
              ),
            )
          else
            const _Checklist(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryDark,
                    ),
                  )
                : Icon(widget.type.icon),
            label: Text(_busy ? 'Memproses...' : 'Mulai ${widget.type.label}'),
          ),
        ],
      ),
    );
  }
}

class _FlowStatusCard extends StatelessWidget {
  const _FlowStatusCard({
    required this.status,
    required this.busy,
    required this.completed,
  });

  final String status;
  final bool busy;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? AppTheme.success
        : _failed(status)
            ? AppTheme.danger
            : busy
                ? AppTheme.info
                : AppTheme.primary;
    final icon = completed
        ? Icons.check_circle_rounded
        : _failed(status)
            ? Icons.error_outline_rounded
            : busy
                ? Icons.sync_rounded
                : Icons.play_circle_rounded;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    busy ? 'Sedang Diproses' : 'Status Absensi',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.mutedFor(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
                  ProcessStepper(
                    steps: const ['Izin', 'GPS', 'Foto', 'Kirim'],
                    activeIndex: _stepIndex(status, busy, completed),
                    activeColor: color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _failed(String value) {
    return !busy &&
        !completed &&
        value != 'Siap memulai' &&
        value != 'Dibatalkan';
  }

  int _stepIndex(String value, bool busy, bool completed) {
    if (completed) return 3;
    if (value.contains('foto') || value.contains('wajah')) return 2;
    if (value.contains('GPS') || value.contains('lokasi')) return 1;
    if (busy) return 0;
    return 0;
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.camera_alt_rounded, 'Kamera depan dan watermark'),
      (Icons.gps_fixed_rounded, 'GPS presisi, akurasi maksimal 50m'),
      (Icons.block_rounded, 'Fake GPS diblokir'),
      (Icons.face_rounded, 'Wajah harus terdeteksi'),
      (Icons.sync_rounded, 'Offline queue jika internet putus'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.lineFor(context).withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.task_alt_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checklist sebelum kirim',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Semua pemeriksaan berjalan berurutan saat tombol mulai ditekan.',
                        style: TextStyle(
                          color: AppTheme.mutedFor(context),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.$1, size: 18, color: AppTheme.primary),
                ),
                title: Text(
                  item.$2,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _descriptionFor(item.$1),
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontSize: 12,
                  ),
                ),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }

  String _descriptionFor(IconData icon) {
    if (icon == Icons.camera_alt_rounded) {
      return 'Foto hanya diproses untuk bukti absensi dan watermark.';
    }
    if (icon == Icons.gps_fixed_rounded) {
      return 'Koordinat dikirim bersama akurasi GPS perangkat.';
    }
    if (icon == Icons.block_rounded) {
      return 'Indikasi lokasi palsu ditandai untuk review server.';
    }
    if (icon == Icons.face_rounded) {
      return 'Selfie harus menampilkan wajah yang jelas.';
    }
    return 'Jika offline, data masuk antrean lokal terenkripsi.';
  }
}
