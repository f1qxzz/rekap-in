import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/glass_widgets.dart';

class OfflineSyncPage extends StatefulWidget {
  const OfflineSyncPage({
    required this.apiClient,
    required this.offlineQueue,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineQueue offlineQueue;

  @override
  State<OfflineSyncPage> createState() => _OfflineSyncPageState();
}

class _OfflineSyncPageState extends State<OfflineSyncPage> {
  List<Map<String, dynamic>> _entries = [];
  int _pending = 0;
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final entries = await widget.offlineQueue.entries();
    final pending = await widget.offlineQueue.pendingCount();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _syncNow() async {
    if (_syncing || !mounted) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      await widget.offlineQueue.sync(widget.apiClient);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi selesai.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ApiClient.errorMessage(
          error,
          fallback: 'Sinkronisasi offline gagal.',
        );
      });
      await _refresh();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvasFor(context),
      appBar: AppBar(
        title: const Text('Sinkronisasi Offline'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _syncing ? null : _refresh,
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 260),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  PremiumInsightCard(
                    icon: Icons.sync_rounded,
                    title: '$_pending antrean menunggu',
                    description:
                        'Data offline disimpan terenkripsi dan dikirim saat server kembali terhubung.',
                    accentColor:
                        _pending > 0 ? AppTheme.primary : AppTheme.success,
                    trailing: IconButton(
                      tooltip: 'Sinkronkan sekarang',
                      onPressed: _syncing || _pending == 0 ? null : _syncNow,
                      icon: _syncing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.cloud_sync_rounded),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_entries.isEmpty)
                    EmptyState(
                      icon: Icons.fact_check_outlined,
                      message: 'Belum ada antrean offline',
                      description:
                          'Saat absensi dibuat tanpa koneksi, statusnya akan muncul di sini.',
                      accentColor: AppTheme.info,
                      actionLabel: 'Cek Lagi',
                      onAction: _refresh,
                    )
                  else
                    for (final entry in _entries) ...[
                      _OfflineEntryCard(entry: entry),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
      ),
    );
  }
}

class _OfflineEntryCard extends StatelessWidget {
  const _OfflineEntryCard({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final status = entry['last_status']?.toString() ?? 'PENDING';
    final color = _statusColor(status);
    final synced = entry['synced'] == 1;
    final createdAt = formatDateTime(entry['created_at_local']);
    final syncedAt = formatDateTime(entry['synced_at']);
    final error = entry['last_error']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppTheme.lineFor(context).withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              synced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry['id']?.toString() ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  syncedAt == '-'
                      ? 'Dibuat $createdAt'
                      : 'Dibuat $createdAt - Sinkron $syncedAt',
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (error != null && error.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SYNCED':
      case 'DUPLICATE_REVIEW':
        return AppTheme.success;
      case 'FAILED':
        return AppTheme.danger;
      case 'SYNCING':
        return AppTheme.primary;
      default:
        return AppTheme.info;
    }
  }
}
