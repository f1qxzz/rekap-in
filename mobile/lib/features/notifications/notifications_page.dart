import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/glass_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.apiClient.notifications();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (_marking || item['read'] == true || !mounted) return;
    setState(() => _marking = true);
    try {
      await widget.apiClient.markNotificationRead(item['id'] as String);
      await _refresh();
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_marking || !mounted) return;
    setState(() => _marking = true);
    try {
      await widget.apiClient.markAllNotificationsRead();
      await _refresh();
    } finally {
      if (mounted) setState(() => _marking = false);
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
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Tandai semua dibaca',
            onPressed: _marking ? null : _markAllRead,
            icon: Icon(Icons.done_all_rounded, size: 22),
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
            : _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 36),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceFor(context),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppTheme.lineFor(context)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: EmptyState(
                          icon: Icons.notifications_none_rounded,
                          message: 'Inbox sedang bersih',
                          description:
                              'Notifikasi approval, perubahan status izin, review HR, dan sinkronisasi akan masuk ke sini saat ada aktivitas baru.',
                          accentColor: AppTheme.info,
                          actionLabel: 'Cek Lagi',
                          onAction: _refresh,
                          highlights: const [
                            'Badge di footer otomatis muncul saat ada notifikasi belum dibaca.',
                            'Ketuk notifikasi untuk menandainya sudah dibaca.',
                            'Approval penting tetap mengikuti data server, bukan cache lokal.',
                          ],
                        ),
                      ),
                    ],
                  )
                : (() {
                    final unreadCount =
                        _items.where((n) => n['read'] != true).length;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        if (unreadCount > 0) ...[
                          PremiumInsightCard(
                            icon: Icons.notifications_active_rounded,
                            title: '$unreadCount notifikasi belum dibaca',
                            description:
                                'Ketuk notifikasi untuk menandai satu per satu, atau gunakan tombol centang ganda di atas.',
                            accentColor: AppTheme.primary,
                            trailing: IconButton(
                              tooltip: 'Tandai semua dibaca',
                              onPressed: _marking ? null : _markAllRead,
                              icon: Icon(Icons.done_all_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (int i = 0; i < _items.length; i++)
                          _NotificationCard(
                            item: _items[i] as Map<String, dynamic>,
                            onTap: _marking
                                ? null
                                : () => _markRead(
                                      _items[i] as Map<String, dynamic>,
                                    ),
                          ),
                      ],
                    );
                  })(),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final read = item['read'] == true;
    final type = item['type'] as String? ?? '';
    final iconData = _iconForType(type);
    final iconColor = _colorForType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: read
            ? AppTheme.surfaceFor(context)
            : AppTheme.primarySurfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: read
              ? AppTheme.lineFor(context).withValues(alpha: 0.5)
              : AppTheme.primary.withValues(alpha: 0.12),
        ),
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
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: read
                        ? AppTheme.canvasFor(context)
                        : iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconData,
                    color: read ? AppTheme.mutedFor(context) : iconColor,
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
                              item['title'] as String? ?? '-',
                              style: TextStyle(
                                fontWeight:
                                    read ? FontWeight.w600 : FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (!read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['body'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.mutedFor(context),
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatDateTime(item['createdAt']),
                        style: TextStyle(
                          color: AppTheme.mutedLightFor(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'LEAVE_REQUEST':
        return Icons.event_note_rounded;
      case 'LEAVE_APPROVED':
        return Icons.check_circle_rounded;
      case 'LEAVE_REJECTED':
        return Icons.cancel_rounded;
      case 'LEAVE_HR_REVIEW':
        return Icons.pending_actions_rounded;
      case 'ACCOUNT_APPROVAL':
        return Icons.person_add_rounded;
      case 'CHECK_IN_REMINDER':
        return Icons.alarm_rounded;
      case 'MISSING_CHECK_IN':
      case 'EMPLOYEE_MISSING_CHECK_IN':
        return Icons.location_off_rounded;
      case 'OVERTIME_ESCALATED':
        return Icons.more_time_rounded;
      case 'LEAVE_ESCALATED':
        return Icons.escalator_warning_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'LEAVE_REQUEST':
        return AppTheme.info;
      case 'LEAVE_APPROVED':
        return AppTheme.success;
      case 'LEAVE_REJECTED':
        return AppTheme.danger;
      case 'LEAVE_HR_REVIEW':
        return AppTheme.warning;
      case 'ACCOUNT_APPROVAL':
        return AppTheme.primary;
      case 'CHECK_IN_REMINDER':
        return AppTheme.primaryDark;
      case 'MISSING_CHECK_IN':
      case 'EMPLOYEE_MISSING_CHECK_IN':
        return AppTheme.danger;
      case 'OVERTIME_ESCALATED':
        return AppTheme.warning;
      case 'LEAVE_ESCALATED':
        return AppTheme.info;
      default:
        return AppTheme.muted;
    }
  }
}
