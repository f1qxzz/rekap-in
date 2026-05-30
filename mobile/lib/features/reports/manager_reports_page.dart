import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';

class ManagerReportsPage extends StatefulWidget {
  const ManagerReportsPage({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<ManagerReportsPage> createState() => _ManagerReportsPageState();
}

class _ManagerReportsPageState extends State<ManagerReportsPage> {
  late DateTime _month;
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.apiClient.reportsAnalytics(
        month: DateFormat('yyyy-MM').format(_month),
      );
      if (!mounted) return;
      setState(() {
        _analytics = data;
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
      _loading = true;
    });
    _refresh();
  }

  Future<void> _exportReport(String format) async {
    if (_exporting || !mounted) return;
    setState(() => _exporting = true);
    try {
      final month = DateFormat('yyyy-MM').format(_month);
      final path = await widget.apiClient.downloadReport(
        month: month,
        format: format,
      );
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.type == ResultType.done
                ? 'Laporan dibuka: $path'
                : 'Laporan tersimpan: $path',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(error, fallback: 'Export gagal.'),
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
          'Laporan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MonthSelector(
              month: _month,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_analytics == null)
              _ErrorCard(
                message: 'Gagal memuat data laporan',
                onRetry: _refresh,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnalyticsSummary(data: _analytics!),
                  const SizedBox(height: 14),
                  _ReportInsightCard(data: _analytics!, month: _month),
                  const SizedBox(height: 20),
                  const Text(
                    'Export Laporan',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ExportCard(
                    exporting: _exporting,
                    onExportCsv: () => _exportReport('csv'),
                    onExportXlsx: () => _exportReport('xlsx'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportInsightCard extends StatelessWidget {
  const _ReportInsightCard({required this.data, required this.month});

  final Map<String, dynamic> data;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final totalAttendances = data['totalAttendances'] as num? ?? 0;
    final totalEmployees = data['totalEmployees'] as num? ?? 0;
    final anomalies = data['anomalies'] as num? ?? 0;
    final empty = totalAttendances == 0 && totalEmployees == 0;
    final color = empty
        ? AppTheme.info
        : anomalies > 0
            ? AppTheme.warning
            : AppTheme.success;
    final title = empty
        ? 'Laporan belum punya aktivitas'
        : anomalies > 0
            ? 'Ada data yang perlu dicek'
            : 'Laporan siap direkap';
    final body = empty
        ? 'Data bulan ${DateFormat('MMMM yyyy', 'id_ID').format(month)} akan terisi setelah absensi, izin, atau cuti masuk dari server.'
        : anomalies > 0
            ? '$anomalies anomali perlu ditinjau sebelum laporan dikirim ke payroll.'
            : 'Semua ringkasan utama sudah tersedia untuk diekspor sebagai CSV atau Excel.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              empty
                  ? Icons.insights_rounded
                  : anomalies > 0
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
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

class _AnalyticsSummary extends StatelessWidget {
  const _AnalyticsSummary({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final totalEmployees = data['totalEmployees'] ?? 0;
    final totalAttendances = data['totalAttendances'] ?? 0;
    final averageAttendance = data['averageAttendanceRate'] ?? 0;
    final anomalies = data['anomalies'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.lineFor(context).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Analytics',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.people_rounded,
                  label: 'Karyawan',
                  value: '$totalEmployees',
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.fact_check_rounded,
                  label: 'Absensi',
                  value: '$totalAttendances',
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.percent_rounded,
                  label: 'Rata-rata',
                  value: '${(averageAttendance as num).toStringAsFixed(0)}%',
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Anomali',
                  value: '$anomalies',
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.exporting,
    required this.onExportCsv,
    required this.onExportXlsx,
  });

  final bool exporting;
  final VoidCallback onExportCsv;
  final VoidCallback onExportXlsx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          _ExportOption(
            icon: Icons.table_chart_rounded,
            title: 'Export CSV',
            subtitle: 'Format teks, ringan untuk spreadsheet',
            color: AppTheme.success,
            onTap: exporting ? null : onExportCsv,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              height: 1,
              color: AppTheme.lineFor(context).withValues(alpha: 0.3),
            ),
          ),
          _ExportOption(
            icon: Icons.description_rounded,
            title: 'Export Excel',
            subtitle: 'Format lengkap dengan tabel dan grafik',
            color: AppTheme.info,
            onTap: exporting ? null : onExportXlsx,
          ),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.mutedFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.mutedLightFor(context),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppTheme.danger,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
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
    );
  }
}
