import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/storage/token_store.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/widgets/private_photo_avatar.dart';
import '../admin/admin_dashboard_page.dart';
import '../attendance/attendance_flow_page.dart';
import '../attendance/attendance_history_page.dart';
import '../auth/login_page.dart';
import '../leave/leave_page.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../reports/manager_reports_page.dart';
import '../settings/api_settings_page.dart';
import '../../core/widgets/rekapin_logo.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.apiClient,
    required this.tokenStore,
    required this.offlineQueue,
    this.onThemeChanged,
    this.trainingMode = false,
    super.key,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;
  final OfflineQueue offlineQueue;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final bool trainingMode;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _DashboardData? _data;
  bool _initialLoading = true;
  bool _isDarkMode = false;
  bool _actionBusy = false;
  String? _loadError;
  int _unreadNotificationCount = 0;
  RealtimeService? _realtime;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _refresh();
    _initRealtime();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _refreshDebounce?.cancel();
    _realtime?.dispose();
    super.dispose();
  }

  void _initRealtime() {
    _realtime = RealtimeService(
      apiClient: widget.apiClient,
      tokenStore: widget.tokenStore,
    );
    _realtimeSub = _realtime!.events.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString() ?? '';
      if (type.startsWith('attendance:') ||
          type.startsWith('leave:') ||
          type.startsWith('notification:')) {
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(seconds: 2), () {
          if (mounted) _refresh();
        });
      }
    });
    _realtime!.connect();
  }

  Future<_DashboardData> _load() async {
    final user = await widget.apiClient.me();
    final status = await widget.apiClient.todayStatus();
    final pendingOffline = await widget.offlineQueue.pendingCount();
    return _DashboardData(
      user: user,
      status: status,
      pendingOffline: pendingOffline,
    );
  }

  Future<void> _loadNotificationCount() async {
    try {
      final notifications = await widget.apiClient.notifications();
      final unread = notifications.where((n) => n['read'] != true).length;
      if (mounted) setState(() => _unreadNotificationCount = unread);
    } catch (e) {
      debugPrint('Failed to load notification count: $e');
    }
  }

  Future<void> _refresh() async {
    try {
      final newData = await _load();
      if (!mounted) return;
      setState(() {
        _data = newData;
        _initialLoading = false;
        _loadError = null;
      });
      await _loadNotificationCount();
    } catch (e) {
      if (!mounted) return;
      final hasSession = await widget.tokenStore.hasRefreshToken();
      if (!hasSession) {
        await _goToLogin();
        return;
      }
      setState(() {
        _initialLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          apiClient: widget.apiClient,
          tokenStore: widget.tokenStore,
          offlineQueue: widget.offlineQueue,
        ),
      ),
      (_) => false,
    );
  }

  void _showActionError(Object error, String fallback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ApiClient.errorMessage(error, fallback: fallback)),
      ),
    );
  }

  Future<void> _sync() async {
    if (_actionBusy || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await widget.offlineQueue.sync(widget.apiClient);
      await _refresh();
    } catch (error) {
      _showActionError(error, 'Sinkronisasi gagal. Cek koneksi dan coba lagi.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openApiSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApiSettingsPage(
          apiClient: widget.apiClient,
          tokenStore: widget.tokenStore,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _logout() async {
    if (_actionBusy || !mounted) return;
    setState(() => _actionBusy = true);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
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
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.dangerSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: AppTheme.danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keluar Akun?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Sesi login di perangkat ini akan dihapus.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedFor(context),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.dangerSurface,
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                        color: AppTheme.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Keluar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      if (mounted) setState(() => _actionBusy = false);
      return;
    }

    try {
      await widget.apiClient.logout();
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            apiClient: widget.apiClient,
            tokenStore: widget.tokenStore,
            offlineQueue: widget.offlineQueue,
          ),
        ),
        (_) => false,
      );
    } catch (error) {
      _showActionError(error, 'Logout gagal. Coba lagi.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openFooterDestination(int index, _DashboardData data) async {
    if (index == 0 || _actionBusy || !mounted) return;
    setState(() => _actionBusy = true);
    final role = data.user['role']?.toString() ?? 'KARYAWAN';
    final isAdmin = ['HR', 'SUPER_ADMIN'].contains(role);
    final isManager = role == 'MANAJER';

    Widget page;
    if (index == 1) {
      page = AttendanceHistoryPage(apiClient: widget.apiClient);
    } else if (index == 2) {
      page = LeavePage(apiClient: widget.apiClient, user: data.user);
    } else if (index == 3) {
      page = NotificationsPage(apiClient: widget.apiClient);
    } else if (index == 4) {
      page = ProfilePage(
        apiClient: widget.apiClient,
        tokenStore: widget.tokenStore,
        offlineQueue: widget.offlineQueue,
        user: data.user,
              );
    } else if (index == 5 && isAdmin) {
      page = AdminDashboardPage(apiClient: widget.apiClient);
    } else if (index == 5 && isManager) {
      page = ManagerReportsPage(apiClient: widget.apiClient);
    } else {
      page = ProfilePage(
        apiClient: widget.apiClient,
        tokenStore: widget.tokenStore,
        offlineQueue: widget.offlineQueue,
        user: data.user,
              );
    }

    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      if (mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openAttendanceFlow(
    AttendanceType type,
    _DashboardData data,
  ) async {
    if (_actionBusy || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttendanceFlowPage(
            apiClient: widget.apiClient,
            offlineQueue: widget.offlineQueue,
            type: type,
            user: data.user,
            trainingMode: widget.trainingMode,
          ),
        ),
      );
      if (mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isDarkMode != isDark) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isDarkMode = isDark); });
    final data = _data;
    final hasError = _loadError != null && data == null;
    return Scaffold(
      backgroundColor: AppTheme.canvasFor(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(context, data),
            if (hasError)
              SliverFillRemaining(
                child: _ErrorState(
                  baseUrl: widget.apiClient.dio.options.baseUrl,
                  onRetry: _refresh,
                  onOpenSettings: _openApiSettings,
                ),
              )
            else if (_initialLoading && data == null)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _SkeletonBox(height: 80, radius: 18),
                      const SizedBox(height: 16),
                      _SkeletonBox(height: 120, radius: 18),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _SkeletonBox(height: 100, radius: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _SkeletonBox(height: 100, radius: 18)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _SkeletonBox(height: 100, radius: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _SkeletonBox(height: 100, radius: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else if (data != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WelcomeHeader(
                        apiClient: widget.apiClient,
                        user: data.user,
                      ),
                      const SizedBox(height: 24),
                      if (widget.trainingMode) ...[
                        const _InfoBanner(
                          icon: Icons.school_rounded,
                          text:
                              'Mode latihan aktif. Data tersimpan lokal dan tidak dikirim ke server.',
                          tone: _BannerTone.info,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _TodayStatusCard(status: data.status),
                      const SizedBox(height: 20),
                      _PrimaryAttendanceAction(
                        status:
                            data.status['status'] as String? ?? 'BELUM_ABSEN',
                        busy: _actionBusy,
                        onClock: (type) => _openAttendanceFlow(type, data),
                      ),
                      if (data.pendingOffline > 0) ...[
                        const SizedBox(height: 12),
                        _InfoBanner(
                          icon: Icons.cloud_off_rounded,
                          text:
                              '${data.pendingOffline} absensi menunggu sinkronisasi.',
                          tone: _BannerTone.warning,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _OperationalSnapshotGrid(
                        user: data.user,
                        status: data.status,
                        pendingOffline: data.pendingOffline,
                      ),
                      const SizedBox(height: 32),
                      _SectionHeader(
                        title: 'Rekap Minggu Ini',
                        subtitle: 'Ringkasan kehadiran 7 hari terakhir.',
                      ),
                      const SizedBox(height: 16),
                      _WeeklySummary(status: data.status),
                      const SizedBox(height: 32),
                      _ShiftInfoCard(user: data.user),
                      const SizedBox(height: 32),
                      _SectionHeader(
                        title: 'Jadwal Pekan Ini',
                        subtitle: 'Kalender kerja Senin-Minggu.',
                      ),
                      const SizedBox(height: 16),
                      _CalendarPreview(status: data.status),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: data == null
          ? null
          : _FooterNavigation(
              role: data.user['role']?.toString() ?? 'KARYAWAN',
              unreadCount: _unreadNotificationCount,
              onSelected: _actionBusy
                  ? null
                  : (index) => _openFooterDestination(index, data),
            ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, _DashboardData? data) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.surfaceFor(context),
      surfaceTintColor: Colors.transparent,
      expandedHeight: 0,
      toolbarHeight: 68,
      title: Row(
        children: [
          const RekapInLogo(size: 46, showText: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTheme.brandName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        fontSize: 21,
                      ),
                ),
                if (data != null)
                  Text(
                    data.user['department'] is Map
                        ? (data.user['department']['name'] as String? ?? '')
                        : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedFor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (data != null) ...[
          IconButton(
            tooltip: 'Mode Gelap/Terang',
            onPressed: widget.onThemeChanged != null
                ? () { widget.onThemeChanged!(_isDarkMode ? ThemeMode.light : ThemeMode.dark); }
                : null,
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 22,
            ),
          ),
          IconButton(
            tooltip: 'Sinkronkan',
            onPressed: _actionBusy ? null : _sync,
            icon: Icon(Icons.sync_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: _actionBusy ? null : _logout,
            icon: Icon(Icons.logout_rounded, size: 22),
          ),
        ],
      ],
    );
  }
}

// ─────────────────── Footer Navigation ───────────────────

class _FooterNavigation extends StatelessWidget {
  const _FooterNavigation({
    required this.role,
    required this.onSelected,
    this.unreadCount = 0,
  });

  final String role;
  final ValueChanged<int>? onSelected;
  final int unreadCount;

  bool get _isAdmin => ['HR', 'SUPER_ADMIN'].contains(role);
  bool get _isManager => role == 'MANAJER';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: onSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Izin',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppTheme.dangerSurface,
              child: Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppTheme.dangerSurface,
              child: Icon(Icons.notifications_rounded),
            ),
            label: 'Notif',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Admin',
            ),
          if (_isManager)
            const NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded),
              label: 'Laporan',
            ),
        ],
      ),
    );
  }
}

// ─────────────────── Error State ───────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.baseUrl,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String baseUrl;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.dangerSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.danger,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gagal Memuat Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Server belum terhubung. Pastikan backend aktif dan URL API mengarah ke IP laptop.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedFor(context),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              baseUrl,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.mutedLightFor(context),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(150, 48),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: Icon(Icons.dns_outlined),
                  label: const Text('Atur Server'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(150, 48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Welcome Header ───────────────────

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.apiClient,
    required this.user,
  });

  final ApiClient apiClient;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? 'Karyawan';
    final role = user['role'] as String? ?? 'Karyawan';
    final photoUrl = user['photoUrl'] as String?;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'K';
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Selamat Pagi'
        : hour < 15
            ? 'Selamat Siang'
            : hour < 18
                ? 'Selamat Sore'
                : 'Selamat Malam';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: PrivatePhotoAvatar(
              apiClient: apiClient,
              initials: initials,
              photoUrl: photoUrl,
              size: 60,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedFor(context),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 118),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role.replaceAll('_', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMM', 'id_ID')
                            .format(DateTime.now()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.mutedFor(context),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Today Status Card ───────────────────

class _TodayStatusCard extends StatelessWidget {
  const _TodayStatusCard({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final meta = StatusMeta.fromDashboard(
      status['status'] as String? ?? 'BELUM_ABSEN',
    );
    final checkIn = _formatTime(
      status['checkInAt'] ??
          status['clockInAt'] ??
          (status['checkIn'] is Map ? status['checkIn']['timestamp'] : null),
    );
    final checkOut = _formatTime(
      status['checkOutAt'] ??
          status['clockOutAt'] ??
          (status['checkOut'] is Map ? status['checkOut']['timestamp'] : null),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            meta.color.withValues(alpha: 0.06),
            meta.color.withValues(alpha: 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: meta.color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: meta.color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Hari Ini',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppTheme.mutedFor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta.title ?? '',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: meta.color,
                              fontSize: 20,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              meta.description ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedFor(context),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TimePill(
                    label: 'Masuk',
                    value: checkIn ?? '--:--',
                    icon: Icons.login_rounded,
                    color: checkIn != null
                        ? AppTheme.success
                        : AppTheme.mutedFor(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePill(
                    label: 'Pulang',
                    value: checkOut ?? '--:--',
                    icon: Icons.logout_rounded,
                    color: checkOut != null
                        ? AppTheme.warning
                        : AppTheme.mutedFor(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _formatTime(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('HH:mm').format(parsed.toLocal());
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppTheme.lineFor(context).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.mutedFor(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
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

// ─────────────────── Primary Action ───────────────────

class _PrimaryAttendanceAction extends StatelessWidget {
  const _PrimaryAttendanceAction({
    required this.status,
    required this.onClock,
    required this.busy,
  });

  final String status;
  final ValueChanged<AttendanceType> onClock;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final canCheckIn = status == 'BELUM_ABSEN';
    final canCheckOut = status == 'SUDAH_MASUK';

    if (canCheckIn) {
      return Semantics(
        label: 'Tombol absen masuk',
        button: true,
        child: _GradientButton(
          onPressed: busy ? null : () => onClock(AttendanceType.masuk),
          icon: Icons.login_rounded,
          label: 'Absen Masuk',
          gradient: AppTheme.primaryGradient,
          shadowColor: AppTheme.primary,
        ),
      );
    }

    if (canCheckOut) {
      return Semantics(
        label: 'Tombol absen pulang',
        button: true,
        child: _GradientButton(
          onPressed: busy ? null : () => onClock(AttendanceType.pulang),
          icon: Icons.logout_rounded,
          label: 'Absen Pulang',
          gradient: AppTheme.warningGradient,
          shadowColor: AppTheme.warning,
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.successSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppTheme.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Absensi Hari Ini Selesai',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : () => onClock(AttendanceType.lembur),
          icon: Icon(Icons.access_time_rounded, size: 18),
          label: const Text('Absen Lembur'),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.gradient,
    required this.shadowColor,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Gradient gradient;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Opacity(
        opacity: onPressed == null ? 0.62 : 1,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: AppTheme.buttonSurfaceFor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.buttonBorderFor(context)),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppTheme.primaryDark, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────── Weekly Summary ───────────────────

class _OperationalSnapshotGrid extends StatelessWidget {
  const _OperationalSnapshotGrid({
    required this.user,
    required this.status,
    required this.pendingOffline,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic> status;
  final int pendingOffline;

  @override
  Widget build(BuildContext context) {
    final shift = user['shift'] is Map ? user['shift'] as Map : null;
    final shiftLabel = shift == null
        ? 'Belum diatur'
        : '${shift['startTime'] ?? '--:--'} - ${shift['endTime'] ?? '--:--'}';
    final syncLabel = pendingOffline > 0 ? '$pendingOffline antrean' : 'Aman';
    final syncCaption = pendingOffline > 0 ? 'Perlu sync' : 'Tidak ada antrean';
    final role = (user['role']?.toString() ?? 'KARYAWAN')
        .replaceAll('_', ' ')
        .replaceAll('SUPER ADMIN', 'Super Admin')
        .replaceAll('SUPER', 'Super')
        .replaceAll('ADMIN', 'Admin');

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: tileWidth,
              child: PremiumStatTile(
                icon: Icons.next_plan_rounded,
                label: 'Aksi Berikutnya',
                value: _nextAction(status['status']?.toString()),
                caption: _statusCaption(status),
                color: AppTheme.primary,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: PremiumStatTile(
                icon: Icons.schedule_rounded,
                label: 'Shift',
                value: shiftLabel,
                caption: shift?['name']?.toString() ?? 'Master data',
                color: AppTheme.info,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: PremiumStatTile(
                icon: Icons.cloud_sync_rounded,
                label: 'Sinkronisasi',
                value: syncLabel,
                caption: syncCaption,
                color: pendingOffline > 0 ? AppTheme.warning : AppTheme.success,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: PremiumStatTile(
                icon: Icons.badge_rounded,
                label: 'Role',
                value: role,
                caption: user['department'] is Map
                    ? user['department']['name']?.toString()
                    : 'Department',
                color: AppTheme.warning,
              ),
            ),
          ],
        );
      },
    );
  }

  String _nextAction(String? value) {
    switch (value) {
      case 'SUDAH_MASUK':
        return 'Pulang';
      case 'SUDAH_PULANG':
      case 'SELESAI':
        return 'Lembur';
      case 'ANOMALI':
        return 'Review';
      default:
        return 'Masuk';
    }
  }

  String _statusCaption(Map<String, dynamic> status) {
    final checkIn = status['checkInAt'] ?? status['clockInAt'];
    final checkOut = status['checkOutAt'] ?? status['clockOutAt'];
    if (checkOut != null) return 'Absensi lengkap';
    if (checkIn != null) return 'Masuk sudah tercatat';
    return 'Belum ada jam masuk';
  }
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final weekly = status['weeklySummary'];
    final items = [
      _SummaryItem(
        label: 'Hadir',
        value: _readSummary(weekly, 'hadir'),
        color: AppTheme.success,
        icon: Icons.check_circle_rounded,
      ),
      _SummaryItem(
        label: 'Terlambat',
        value: _readSummary(weekly, 'terlambat'),
        color: AppTheme.warning,
        icon: Icons.schedule_rounded,
      ),
      _SummaryItem(
        label: 'Izin',
        value: _readSummary(weekly, 'izin'),
        color: AppTheme.info,
        icon: Icons.event_available_rounded,
      ),
      _SummaryItem(
        label: 'Cuti',
        value: _readSummary(weekly, 'cuti'),
        color: AppTheme.primary,
        icon: Icons.beach_access_rounded,
      ),
    ];

    final total = items.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse(item.value) ?? 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        final grid = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _SummaryCard(item: item)),
          ],
        );

        if (total > 0) return grid;

        return Column(
          children: [
            grid,
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.infoSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.info.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      color: AppTheme.info,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rekap akan terisi otomatis setelah absensi, izin, atau cuti tercatat di server.',
                      style: TextStyle(
                        color: AppTheme.mutedFor(context),
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _readSummary(Object? weekly, String key) {
    if (weekly is Map && weekly[key] != null) return weekly[key].toString();
    return '0';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, size: 22, color: item.color),
          ),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: item.color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedFor(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Calendar Preview ───────────────────

class _CalendarPreview extends StatelessWidget {
  const _CalendarPreview({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (index) => start.add(Duration(days: index)));

    final todayStatus = status['status'] as String? ?? 'BELUM_ABSEN';
    final weekEntries = status['weekEntries'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(22),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Row(
          children: [
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Builder(
                    builder: (context) {
                      final isToday = _sameDate(day, today);
                      final entry = _entryForDay(weekEntries, day);
                      final attendanceStatus = entry?['status']?.toString() ??
                          (isToday ? todayStatus : null);
                      final hasCheckIn = entry?['checkInAt'] != null ||
                          entry?['clockInAt'] != null ||
                          (isToday &&
                              (status['checkInAt'] != null ||
                                  status['clockInAt'] != null));
                      final hasCheckOut = entry?['checkOutAt'] != null ||
                          entry?['clockOutAt'] != null ||
                          (isToday &&
                              (status['checkOutAt'] != null ||
                                  status['clockOutAt'] != null));
                      return _DayCell(
                        day: day,
                        selected: isToday,
                        isToday: isToday,
                        attendanceStatus: attendanceStatus,
                        hasCheckIn: hasCheckIn,
                        hasCheckOut: hasCheckOut,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _sameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Map<String, dynamic>? _entryForDay(Object? entries, DateTime day) {
    if (entries is! List) return null;
    final key = _dateKey(day);
    for (final item in entries) {
      if (item is! Map) continue;
      if (item['date'] == key) return Map<String, dynamic>.from(item);
    }
    return null;
  }

  String _dateKey(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    this.isToday = false,
    this.attendanceStatus,
    this.hasCheckIn = false,
    this.hasCheckOut = false,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final String? attendanceStatus;
  final bool hasCheckIn;
  final bool hasCheckOut;

  @override
  Widget build(BuildContext context) {
    final isWeekend = day.weekday == 6 || day.weekday == 7;
    final dayLabel = _shortDay(day.weekday);

    Color? dotColor;
    if (attendanceStatus == 'HADIR') dotColor = AppTheme.success;
    if (attendanceStatus == 'TERLAMBAT') dotColor = AppTheme.warning;
    if (attendanceStatus == 'SUDAH_MASUK') dotColor = AppTheme.info;
    if (attendanceStatus == 'SUDAH_PULANG' || attendanceStatus == 'SELESAI') {
      dotColor = AppTheme.success;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 72,
      decoration: BoxDecoration(
        gradient: selected ? AppTheme.primaryGradient : null,
        color: selected
            ? null
            : isWeekend
                ? AppTheme.danger.withValues(alpha: 0.03)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? Colors.transparent
              : isWeekend
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : AppTheme.lineFor(context).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayLabel,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: selected
                  ? Colors.white.withValues(alpha: 0.8)
                  : isWeekend
                      ? AppTheme.danger.withValues(alpha: 0.6)
                      : AppTheme.mutedFor(context),
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${day.day}',
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : isWeekend
                      ? AppTheme.danger.withValues(alpha: 0.8)
                      : AppTheme.inkFor(context),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          if (dotColor != null && !selected) ...[
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ] else
            const SizedBox(height: 9),
        ],
      ),
    );
  }

  String _shortDay(int weekday) {
    switch (weekday) {
      case 1:
        return 'Sen';
      case 2:
        return 'Sel';
      case 3:
        return 'Rab';
      case 4:
        return 'Kam';
      case 5:
        return 'Jum';
      case 6:
        return 'Sab';
      case 7:
        return 'Min';
      default:
        return '';
    }
  }
}

// ─────────────────── Shared Widgets ───────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedFor(context),
              ),
        ),
      ],
    );
  }
}

enum _BannerTone { info, warning }

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final color =
        tone == _BannerTone.warning ? AppTheme.warning : AppTheme.info;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.inkFor(context),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Shift Info Card ───────────────────

class _ShiftInfoCard extends StatelessWidget {
  const _ShiftInfoCard({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final shift = user['shift'];
    if (shift is! Map) return const SizedBox.shrink();

    final name = shift['name'] as String? ?? '-';
    final startTime = shift['startTime'] as String? ?? '-';
    final endTime = shift['endTime'] as String? ?? '-';
    final tolerance = shift['lateToleranceMinutes'] ?? 0;
    final workDays = shift['workDays'];
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.infoSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: AppTheme.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$startTime - $endTime, toleransi $tolerance mnt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mutedFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (workDays is List) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 0; i < dayNames.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: workDays.contains(i + 1)
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : AppTheme.danger.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: workDays.contains(i + 1)
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : AppTheme.danger.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        dayNames[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: workDays.contains(i + 1)
                              ? AppTheme.primary
                              : AppTheme.danger.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────── Data Models ───────────────────

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _DashboardData {
  const _DashboardData({
    required this.user,
    required this.status,
    required this.pendingOffline,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic> status;
  final int pendingOffline;
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.height, this.radius = 12});
  final double height;
  final double radius;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppTheme.lineFor(context).withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
