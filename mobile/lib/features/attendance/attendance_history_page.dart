import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/glass_widgets.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late DateTime _month;
  String? _status;
  List<dynamic> _rows = [];
  bool _loading = true;
  bool _exporting = false;

  static const _statuses = [
    null,
    'HADIR',
    'TERLAMBAT',
    'REVIEW',
    'DITOLAK',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.apiClient.attendanceHistory(
        month: DateFormat('yyyy-MM').format(_month),
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _rows = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _refresh();
  }

  void _changeStatus(String? value) {
    setState(() {
      _status = value;
    });
    _refresh();
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = List<dynamic>.from(_rows);
      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data untuk diexport.')),
        );
        return;
      }

      final monthStr = DateFormat('yyyy-MM').format(_month);
      final buffer = StringBuffer();
      buffer.writeln('Tanggal,Jam Masuk,Jam Pulang,Status,Lokasi');

      for (final item in data) {
        final map = item as Map<String, dynamic>;
        final ts = map['timestamp'] as String? ?? '';
        final date = ts.isNotEmpty
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(ts).toLocal())
            : '-';
        final time = ts.isNotEmpty
            ? DateFormat('HH:mm').format(DateTime.parse(ts).toLocal())
            : '-';
        final type = map['type'] as String? ?? '-';
        final status = map['status'] as String? ?? '-';
        final lat = (map['lat'] as num?)?.toStringAsFixed(4) ?? '-';
        final lng = (map['lng'] as num?)?.toStringAsFixed(4) ?? '-';

        if (type == 'MASUK') {
          buffer.writeln('$date,$time,,$status,"$lat, $lng"');
        } else {
          buffer.writeln('$date,,$time,$status,"$lat, $lng"');
        }
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/riwayat-$monthStr.csv');
      await file.writeAsString(buffer.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV tersimpan: ${file.path}'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(e, fallback: 'Export gagal.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvasFor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceFor(context),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Riwayat Absensi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _loading || _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.download_rounded, size: 22),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MonthNavigator(
              month: _month,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            const SizedBox(height: 12),
            _StatusFilterChips(
              statuses: _statuses,
              selected: _status,
              onChanged: _changeStatus,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_rows.isEmpty)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceFor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.lineFor(context).withValues(alpha: 0.4),
                  ),
                ),
                child: EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  message: _status == null
                      ? 'Riwayat bulan ini masih kosong'
                      : 'Tidak ada riwayat untuk filter $_status',
                  description:
                      'Absensi yang sudah dikirim ke server akan muncul di sini lengkap dengan waktu, lokasi, foto, dan status review.',
                  accentColor:
                      _status == null ? AppTheme.primary : AppTheme.info,
                  highlights: const [
                    'Tarik layar ke bawah untuk memuat ulang data terbaru.',
                    'Gunakan filter status jika ingin mengecek izin, cuti, atau data yang perlu review.',
                    'Tombol ekspor aktif setelah ada data pada bulan yang dipilih.',
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final row in _rows)
                    _HistoryCard(
                      apiClient: widget.apiClient,
                      item: row,
                      onTap: () =>
                          _showHistoryDetail(context, widget.apiClient, row),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppTheme.lineFor(context).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: onPrevious,
            icon: Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primarySurface,
              foregroundColor: AppTheme.primary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM', 'id_ID').format(month),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
                Text(
                  DateFormat('yyyy').format(month),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedFor(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: onNext,
            icon: Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primarySurface,
              foregroundColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.statuses,
    required this.selected,
    required this.onChanged,
  });

  final List<String?> statuses;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = statuses[index];
          final isSelected = status == selected;
          final label = status ?? 'Semua';
          final color = status == null ? AppTheme.primary : _chipColor(status);

          return FilterChip(
            selected: isSelected,
            label: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.inkFor(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            backgroundColor: AppTheme.surfaceFor(context),
            selectedColor: color,
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : AppTheme.lineFor(context).withValues(alpha: 0.6),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onSelected: (_) => onChanged(status),
          );
        },
      ),
    );
  }

  Color _chipColor(String status) {
    switch (status) {
      case 'HADIR':
        return AppTheme.success;
      case 'TERLAMBAT':
        return AppTheme.warning;
      case 'IZIN':
      case 'CUTI':
        return AppTheme.info;
      case 'REVIEW':
        return AppTheme.warning;
      case 'DITOLAK':
        return AppTheme.danger;
      default:
        return AppTheme.primary;
    }
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.apiClient,
    required this.item,
    required this.onTap,
  });

  final ApiClient apiClient;
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? '-';
    final type = item['type'] as String? ?? '-';
    final meta = StatusMeta.fromAttendance(status);
    final anomaly = item['anomalyFlag'] == true;
    final ts = item['timestamp'] as String? ?? '';
    final date = ts.isNotEmpty
        ? DateFormat('dd MMM yyyy', 'id_ID')
            .format(DateTime.parse(ts).toLocal())
        : '-';
    final time = ts.isNotEmpty
        ? DateFormat('HH:mm').format(DateTime.parse(ts).toLocal())
        : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.lineFor(context).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              type,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          StatusBadge(
                            text: status,
                            color: meta.color,
                            compact: true,
                          ),
                          const SizedBox(width: 6),
                          if (anomaly)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.warningSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.warning,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppTheme.mutedLightFor(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: TextStyle(
                              color: AppTheme.mutedFor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppTheme.mutedLightFor(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            time,
                            style: TextStyle(
                              color: AppTheme.mutedFor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jarak ${_formatNumber(item['distanceM'])} m, akurasi ${_formatNumber(item['accuracy'])} m',
                        style: TextStyle(
                          color: AppTheme.mutedLightFor(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.mutedLightFor(context), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatNumber(Object? value) {
  if (value == null) return '-';
  final parsed = num.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return parsed.toStringAsFixed(0);
}

void _showHistoryDetail(
  BuildContext context,
  ApiClient apiClient,
  Map<String, dynamic> item,
) {
  final status = item['status'] as String? ?? '-';
  final type = item['type'] as String? ?? '-';
  final ts = item['timestamp'] as String? ?? '';
  final meta = StatusMeta.fromAttendance(status);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceFor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lineFor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$type - $status',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (ts.isNotEmpty)
                        Text(
                          formatDateTime(ts),
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          if (item['photoUrl'] != null && item['photoUrl'] != '')
            _AttendancePhoto(
              apiClient: apiClient,
              photoUrl: item['photoUrl'].toString(),
              attendanceId: item['id']?.toString(),
            ),
            const SizedBox(height: 16),
            _DetailRow(
                label: 'Jarak', value: '${_formatNumber(item['distanceM'])} m'),
            _DetailRow(
                label: 'Akurasi', value: '${_formatNumber(item['accuracy'])} m'),
            if (item['anomalyFlag'] == true)
              _DetailRow(
                  label: 'Anomali',
                  value: item['anomalyReason']?.toString() ?? '-'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendancePhoto extends StatefulWidget {
  const _AttendancePhoto({
    required this.apiClient,
    required this.photoUrl,
    this.attendanceId,
  });

  final ApiClient apiClient;
  final String photoUrl;
  final String? attendanceId;

  @override
  State<_AttendancePhoto> createState() => _AttendancePhotoState();
}

class _AttendancePhotoState extends State<_AttendancePhoto> {
  late Future<Uint8List?> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = _loadPhoto();
  }

  Future<Uint8List?> _loadPhoto() async {
    if (widget.attendanceId != null) {
      final bytes = await widget.apiClient.attendancePhotoById(widget.attendanceId!);
      if (bytes != null) return bytes;
    }
    return widget.apiClient.attendancePhotoBytes(widget.photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _photoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.lineLightFor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const SizedBox.shrink();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.lineLightFor(context),
                child:
                    const Center(child: Icon(Icons.broken_image_rounded)),
              ),
            ),
          ),
        );
      },
    );
  }
}
