import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';

// ── Date/Time Formatting ──

String formatDateTime(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '-';
  return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(parsed.toLocal());
}

String formatDate(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '-';
  return DateFormat('dd MMM yyyy', 'id_ID').format(parsed.toLocal());
}

String formatTime(Object? value) {
  if (value == null) return '--:--';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('HH:mm').format(parsed.toLocal());
}

String mimeTypeFromExtension(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}

String mimeTypeFromFileName(String? fileName) {
  final ext = (fileName ?? '').split('.').last.toLowerCase();
  return mimeTypeFromExtension(ext);
}

// ── Status Meta ──

class StatusMeta {
  const StatusMeta({
    required this.color,
    required this.icon,
    this.title,
    this.description,
  });

  final String? title;
  final String? description;
  final Color color;
  final IconData icon;

  factory StatusMeta.fromStatus(String status) =>
      StatusMeta.fromDashboard(status);

  factory StatusMeta.fromDashboard(String status) {
    switch (status) {
      case 'SUDAH_MASUK':
        return const StatusMeta(
          title: 'Sudah Masuk',
          description: 'Kehadiran masuk tercatat. Jangan lupa absen pulang.',
          color: AppTheme.info,
          icon: Icons.login_rounded,
        );
      case 'SELESAI':
      case 'SUDAH_PULANG':
        return const StatusMeta(
          title: 'Selesai',
          description: 'Absensi hari ini sudah lengkap. Sampai jumpa besok!',
          color: AppTheme.success,
          icon: Icons.check_circle_rounded,
        );
      case 'ANOMALI':
        return const StatusMeta(
          title: 'Perlu Review',
          description: 'Ada data yang perlu dicek oleh admin atau HR.',
          color: AppTheme.warning,
          icon: Icons.warning_amber_rounded,
        );
      default:
        return const StatusMeta(
          title: 'Belum Absen',
          description: 'Mulai dari cek lokasi, lalu ambil selfie bukti hadir.',
          color: AppTheme.primary,
          icon: Icons.schedule_rounded,
        );
    }
  }

  factory StatusMeta.fromAttendance(String status) {
    switch (status) {
      case 'HADIR':
        return const StatusMeta(
            color: AppTheme.success, icon: Icons.check_circle_rounded);
      case 'TERLAMBAT':
        return const StatusMeta(
            color: AppTheme.warning, icon: Icons.watch_later_rounded);
      case 'IZIN':
      case 'CUTI':
        return const StatusMeta(
            color: AppTheme.info, icon: Icons.event_available_rounded);
      case 'DITOLAK':
        return const StatusMeta(
            color: AppTheme.danger, icon: Icons.cancel_rounded);
      case 'REVIEW':
        return const StatusMeta(
            color: AppTheme.warning, icon: Icons.manage_search_rounded);
      default:
        return const StatusMeta(
            color: AppTheme.muted, icon: Icons.help_outline_rounded);
    }
  }

  static Color statusColor(String status) {
    return StatusMeta.fromAttendance(status).color;
  }
}

// ── Error State Widget ──

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.dangerSurfaceFor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedFor(context),
                    height: 1.5,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(140, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
