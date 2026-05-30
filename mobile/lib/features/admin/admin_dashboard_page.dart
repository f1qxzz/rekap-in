import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/widgets/text_prompt_sheet.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  _AdminData? _data;
  bool _initialLoading = true;
  bool _busy = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<_AdminData> _loadData() async {
    final values = await Future.wait<dynamic>([
      widget.apiClient.adminUsers(),
      widget.apiClient.adminShifts(),
      widget.apiClient.adminOffices(),
      widget.apiClient.adminAnomalies(),
      widget.apiClient.leavePending(),
      widget.apiClient.adminSummary(),
    ]);
    return _AdminData(
      users: values[0] as List<dynamic>,
      shifts: values[1] as List<dynamic>,
      offices: values[2] as List<dynamic>,
      anomalies: values[3] as List<dynamic>,
      pendingLeaves: values[4] as List<dynamic>,
      summary: Map<String, dynamic>.from(values[5] as Map),
    );
  }

  Future<void> _refresh() async {
    try {
      final newData = await _loadData();
      if (!mounted) return;
      setState(() {
        _data = newData;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
    }
  }

  Future<void> _downloadReport() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final month = DateFormat('yyyy-MM').format(DateTime.now());
      final path = await widget.apiClient.downloadReport(
        month: month,
        format: 'xlsx',
      );
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.type == ResultType.done
                ? 'Report dibuka: $path'
                : 'Report tersimpan: $path',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(
              error,
              fallback: 'Export gagal. Cek data dan koneksi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewAnomaly(
    Map<String, dynamic> item,
    String action,
  ) async {
    if (_busy || !mounted) return;
    final notes = await showTextPromptSheet(
      context,
      title: action == 'REJECT'
          ? 'Alasan penolakan'
          : action == 'WARN'
              ? 'Catatan peringatan'
              : 'Catatan approval',
      initialValue: action == 'APPROVE' ? 'Disetujui dari aplikasi mobile' : '',
      isRequired: action != 'APPROVE',
    );
    if (notes == null || _busy || !mounted) return;

    setState(() => _busy = true);
    try {
      await _executeReviewAnomaly(item, action, notes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(error, fallback: 'Review anomali gagal.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _executeReviewAnomaly(
      Map<String, dynamic> item, String action, String notes) async {
    await widget.apiClient.reviewAnomaly(
      id: item['id'] as String,
      action: action,
      notes: notes.isEmpty ? 'Disetujui dari aplikasi mobile' : notes,
    );
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review anomali berhasil disimpan.')),
    );
  }

  Future<void> _open(Widget page) async {
    if (_navigating || _busy || !mounted) return;
    setState(() => _navigating = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      if (mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin / HR'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: (_busy || _navigating) ? null : _refresh,
            icon: Icon(Icons.refresh_rounded, size: 22),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _initialLoading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _data == null
                ? ListView(
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.dangerSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.danger,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Gagal memuat data admin',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Tarik ke bawah untuk mencoba lagi.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.mutedFor(context)),
                        ),
                      ),
                    ],
                  )
                : _buildContent(_data!),
      ),
    );
  }

  Widget _buildContent(_AdminData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetricsGrid(data: data),
        const SizedBox(height: 16),
        if (data.unapprovedUsers.isNotEmpty || data.pendingLeaves.isNotEmpty)
          _OperationalAlerts(data: data)
        else
          const _LivelyEmptyCard(
            icon: Icons.verified_rounded,
            title: 'Operasional aman',
            description:
                'Tidak ada akun baru atau izin yang menunggu tindakan saat ini.',
            accentColor: AppTheme.success,
            highlights: [
              'Tetap cek menu admin untuk menjaga master data tetap rapi.',
              'Audit log akan mencatat perubahan penting dari admin.',
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'Menu Admin',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _AdminMenu(
          busy: _busy || _navigating,
          onUsers: () => _open(_UsersPage(apiClient: widget.apiClient)),
          onShifts: () => _open(
            _SimpleDataPage(
              title: 'Shift dan Rotasi',
              loader: widget.apiClient.adminShifts,
              emptyText: 'Belum ada shift.',
              itemBuilder: _shiftTile,
              onAdd: (context) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _ShiftFormPage(apiClient: widget.apiClient),
                ),
              ),
              onEdit: (context, item) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _ShiftFormPage(
                    apiClient: widget.apiClient,
                    item: item,
                  ),
                ),
              ),
              onDelete: (item) =>
                  widget.apiClient.deleteShift(item['id'] as String),
            ),
          ),
          onOffices: () => _open(
            _SimpleDataPage(
              title: 'Lokasi Kantor',
              loader: widget.apiClient.adminOffices,
              emptyText: 'Belum ada lokasi kantor.',
              itemBuilder: _officeTile,
              onAdd: (context) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _OfficeFormPage(apiClient: widget.apiClient),
                ),
              ),
              onEdit: (context, item) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _OfficeFormPage(
                    apiClient: widget.apiClient,
                    item: item,
                  ),
                ),
              ),
              onDelete: (item) =>
                  widget.apiClient.deleteOffice(item['id'] as String),
            ),
          ),
          onDepartments: () => _open(
            _SimpleDataPage(
              title: 'Department',
              loader: widget.apiClient.adminDepartments,
              emptyText: 'Belum ada department.',
              itemBuilder: _departmentTile,
              onAdd: (context) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      _DepartmentFormPage(apiClient: widget.apiClient),
                ),
              ),
              onEdit: (context, item) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _DepartmentFormPage(
                    apiClient: widget.apiClient,
                    item: item,
                  ),
                ),
              ),
              onDelete: (item) =>
                  widget.apiClient.deleteDepartment(item['id'] as String),
            ),
          ),
          onHolidays: () => _open(
            _SimpleDataPage(
              title: 'Hari Libur',
              loader: widget.apiClient.adminHolidays,
              emptyText: 'Belum ada hari libur.',
              itemBuilder: _holidayTile,
              onAdd: (context) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _HolidayFormPage(apiClient: widget.apiClient),
                ),
              ),
              onEdit: (context, item) => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _HolidayFormPage(
                    apiClient: widget.apiClient,
                    item: item,
                  ),
                ),
              ),
              onDelete: (item) =>
                  widget.apiClient.deleteHoliday(item['id'] as String),
            ),
          ),
          onLeaveBalances: () => _open(
            _LeaveBalancesPage(apiClient: widget.apiClient),
          ),
          onAudit: () => _open(
            _SimpleDataPage(
              title: 'Audit Log',
              loader: widget.apiClient.adminAuditLogs,
              emptyText: 'Belum ada audit log.',
              itemBuilder: _auditTile,
            ),
          ),
          onExport: _downloadReport,
          onPayroll: () => _open(
            _PayrollSummaryPage(apiClient: widget.apiClient),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Review Anomali',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (data.anomalies.isEmpty)
          const _LivelyEmptyCard(
            icon: Icons.shield_outlined,
            title: 'Tidak ada anomali',
            description:
                'Absensi yang dicurigai fake GPS, duplikat, atau di luar radius akan masuk ke area review ini.',
            accentColor: AppTheme.info,
            highlights: [
              'Keputusan final tetap tersimpan sebagai audit log.',
              'Gunakan refresh jika baru saja ada absensi dari lapangan.',
            ],
          )
        else
          for (final item in data.anomalies)
            _AnomalyTile(
              item: item as Map<String, dynamic>,
              busy: _busy,
              onApprove: () => _reviewAnomaly(item, 'APPROVE'),
              onWarn: () => _reviewAnomaly(item, 'WARN'),
              onReject: () => _reviewAnomaly(item, 'REJECT'),
            ),
      ],
    );
  }

  Widget _shiftTile(Map<String, dynamic> item) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.infoSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.schedule_rounded, color: AppTheme.info, size: 20),
      ),
      title: Text(item['name'] as String? ?? '-',
          style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${item['startTime'] ?? '-'} - ${item['endTime'] ?? '-'}',
        style: TextStyle(color: AppTheme.mutedFor(context)),
      ),
      trailing: Text(
        '${item['lateToleranceMinutes'] ?? 0} menit',
        style: TextStyle(
          color: AppTheme.mutedFor(context),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _officeTile(Map<String, dynamic> item) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.successSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Icon(Icons.location_on_outlined, color: AppTheme.success, size: 20),
      ),
      title: Text(item['name'] as String? ?? '-',
          style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
        style: TextStyle(color: AppTheme.mutedFor(context)),
      ),
      trailing: Text(
        item['isActive'] == false
            ? 'Nonaktif'
            : '${item['radiusMeters'] ?? '-'} m',
        style: TextStyle(
          color: item['isActive'] == false ? AppTheme.danger : AppTheme.muted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _departmentTile(Map<String, dynamic> item) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Icon(Icons.apartment_outlined, color: AppTheme.primary, size: 20),
      ),
      title: Text(item['name'] as String? ?? '-',
          style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        'Dibuat ${formatDateTime(item['createdAt'])}',
        style: TextStyle(color: AppTheme.mutedFor(context)),
      ),
    );
  }

  Widget _holidayTile(Map<String, dynamic> item) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.warningSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.event_outlined, color: AppTheme.warning, size: 20),
      ),
      title: Text(item['name'] as String? ?? '-',
          style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        formatDateTime(item['date']),
        style: TextStyle(color: AppTheme.mutedFor(context)),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: item['isCustom'] == true
              ? AppTheme.primarySurface
              : AppTheme.successSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          item['isCustom'] == true ? 'Custom' : 'Nasional',
          style: TextStyle(
            color:
                item['isCustom'] == true ? AppTheme.primary : AppTheme.success,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _auditTile(Map<String, dynamic> item) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.canvasFor(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.fact_check_outlined,
            color: AppTheme.mutedFor(context), size: 20),
      ),
      title: Text(item['action'] as String? ?? '-',
          style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${item['targetTable'] ?? '-'} - ${formatDateTime(item['createdAt'])}',
        style: TextStyle(color: AppTheme.mutedFor(context)),
      ),
      trailing:
          Icon(Icons.chevron_right_rounded, color: AppTheme.mutedFor(context)),
      onTap: () => _showJson(context, 'Audit Detail', item),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.data});

  final _AdminData data;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final totalUsers = summary['totalUsers'] ?? data.users.length;
    final activeUsers = summary['activeUsers'] ?? data.users.length;
    final todayCheckIns = summary['todayCheckIns'] ?? 0;
    final reviewAttendances =
        summary['reviewAttendances'] ?? data.anomalies.length;
    final pendingApproval =
        summary['pendingApproval'] ?? data.unapprovedUsers.length;
    final pendingLeaves = summary['pendingLeaves'] ?? data.pendingLeaves.length;
    final items = [
      (
        'Karyawan',
        '$activeUsers/$totalUsers',
        AppTheme.primary,
        Icons.people_rounded,
        'Aktif / total'
      ),
      (
        'Masuk Hari Ini',
        '$todayCheckIns',
        AppTheme.info,
        Icons.login_rounded,
        'Check-in server'
      ),
      (
        'Lokasi',
        '${summary['activeOffices'] ?? data.offices.length}',
        AppTheme.success,
        Icons.location_on_rounded,
        'Lokasi aktif'
      ),
      (
        'Review',
        '$reviewAttendances',
        AppTheme.warning,
        Icons.fact_check_rounded,
        'Absensi perlu dicek'
      ),
      (
        'Belum Approve',
        '$pendingApproval',
        AppTheme.danger,
        Icons.person_add_rounded,
        'Akun baru'
      ),
      (
        'Izin Pending',
        '$pendingLeaves',
        AppTheme.info,
        Icons.pending_actions_rounded,
        'Menunggu approval'
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 42) / 2,
            child: PremiumStatTile(
              icon: item.$4,
              label: item.$1,
              value: item.$2,
              color: item.$3,
              caption: item.$5,
            ),
          ),
      ],
    );
  }
}

class _OperationalAlerts extends StatelessWidget {
  const _OperationalAlerts({required this.data});

  final _AdminData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.notification_important_rounded,
                    color: AppTheme.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Aksi Operasional',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.warning,
                      ),
                ),
              ],
            ),
            if (data.unapprovedUsers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      size: 18, color: AppTheme.mutedFor(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${data.unapprovedUsers.length} akun belum approve',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            if (data.pendingLeaves.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.pending_actions_rounded,
                      size: 18, color: AppTheme.mutedFor(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${data.pendingLeaves.length} pengajuan izin pending',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LivelyEmptyCard extends StatelessWidget {
  const _LivelyEmptyCard({
    required this.icon,
    required this.title,
    required this.description,
    this.highlights = const [],
    this.accentColor = AppTheme.primary,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> highlights;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppTheme.mutedFor(context),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final item in highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: accentColor,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: AppTheme.mutedFor(context),
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminMenu extends StatelessWidget {
  const _AdminMenu({
    required this.busy,
    required this.onUsers,
    required this.onShifts,
    required this.onOffices,
    required this.onDepartments,
    required this.onHolidays,
    required this.onLeaveBalances,
    required this.onAudit,
    required this.onExport,
    required this.onPayroll,
  });

  final bool busy;
  final VoidCallback onUsers;
  final VoidCallback onShifts;
  final VoidCallback onOffices;
  final VoidCallback onDepartments;
  final VoidCallback onHolidays;
  final VoidCallback onLeaveBalances;
  final VoidCallback onAudit;
  final VoidCallback onExport;
  final VoidCallback onPayroll;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.people_rounded, 'Manajemen Karyawan', AppTheme.primary, onUsers),
      (Icons.schedule_rounded, 'Shift dan Rotasi', AppTheme.info, onShifts),
      (Icons.location_on_rounded, 'Lokasi Kantor', AppTheme.success, onOffices),
      (Icons.apartment_rounded, 'Department', AppTheme.primary, onDepartments),
      (Icons.event_rounded, 'Hari Libur', AppTheme.warning, onHolidays),
      (
        Icons.account_balance_wallet_rounded,
        'Saldo Cuti',
        AppTheme.success,
        onLeaveBalances
      ),
      (Icons.fact_check_rounded, 'Audit Log', AppTheme.muted, onAudit),
      (Icons.table_chart_rounded, 'Export Laporan', AppTheme.info, onExport),
      (
        Icons.payments_rounded,
        'Integrasi Payroll',
        AppTheme.success,
        onPayroll
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.lineFor(context).withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: items[i].$3.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(items[i].$1, color: items[i].$3, size: 20),
              ),
              title: Text(
                items[i].$2,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.mutedFor(context),
                size: 20,
              ),
              onTap: busy ? null : items[i].$4,
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: AppTheme.lineFor(context).withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}

class _UsersPage extends StatefulWidget {
  const _UsersPage({required this.apiClient});

  final ApiClient apiClient;

  @override
  State<_UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<_UsersPage> {
  List<dynamic> _users = [];
  bool _loading = true;
  bool _busy = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.apiClient.adminUsers();
      if (!mounted) return;
      setState(() {
        _users = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _approve(Map<String, dynamic> user, bool approved) async {
    if (_busy || _navigating || !mounted) return;
    final reason = await showTextPromptSheet(
      context,
      title: approved ? 'Catatan approval' : 'Alasan nonaktif approval',
      initialValue: approved ? 'Disetujui dari aplikasi mobile' : '',
      isRequired: !approved,
    );
    if (reason == null || _busy || _navigating || !mounted) return;

    setState(() => _busy = true);
    try {
      await _executeApprove(user, approved, reason);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(error,
                fallback: 'Update approval user gagal.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _executeApprove(
      Map<String, dynamic> user, bool approved, String reason) async {
    await widget.apiClient.approveUser(
      id: user['id'] as String,
      approved: approved,
      reason: reason.isEmpty ? 'Disetujui dari aplikasi mobile' : reason,
    );
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved ? 'User berhasil di-approve.' : 'Approval user dicabut.',
        ),
      ),
    );
  }

  Future<void> _openUserForm([Map<String, dynamic>? user]) async {
    if (_busy || _navigating || !mounted) return;
    setState(() => _navigating = true);
    try {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _UserFormPage(
            apiClient: widget.apiClient,
            user: user,
          ),
        ),
      );
      if (changed == true && mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Karyawan')),
      floatingActionButton: FloatingActionButton(
        onPressed: (_busy || _navigating) ? null : () => _openUserForm(),
        child: Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _users.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 48),
                      _LivelyEmptyCard(
                        icon: Icons.people_outline_rounded,
                        title: 'Belum ada karyawan',
                        description:
                            'Tambahkan karyawan pertama agar absensi, approval, shift, dan laporan punya sumber data.',
                        accentColor: AppTheme.primary,
                        actionLabel: 'Tambah Karyawan',
                        onAction: (_busy || _navigating)
                            ? null
                            : () => _openUserForm(),
                        highlights: const [
                          'NIP dan email harus unik untuk setiap akun.',
                          'Role menentukan akses footer, approval, dan laporan.',
                          'Shift, department, dan lokasi bisa dipasang setelah master data dibuat.',
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index] as Map<String, dynamic>;
                      final approved = user['isApproved'] == true;
                      final active = user['isActive'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceFor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.lineFor(context)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: approved
                                  ? AppTheme.successSurface
                                  : AppTheme.warningSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              approved
                                  ? Icons.verified_user_rounded
                                  : Icons.pending_outlined,
                              color: approved
                                  ? AppTheme.success
                                  : AppTheme.warning,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            user['name'] as String? ?? '-',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${user['role'] ?? '-'} - ${user['email'] ?? '-'}\n'
                            'NIP ${user['nip'] ?? '-'} - ${active ? 'Aktif' : 'Nonaktif'}',
                            style: TextStyle(
                                color: AppTheme.mutedFor(context), height: 1.4),
                          ),
                          trailing: TextButton(
                            onPressed: (_busy || _navigating)
                                ? null
                                : () => _approve(user, !approved),
                            child: Text(
                              approved ? 'Cabut' : 'Approve',
                              style: TextStyle(
                                color: approved
                                    ? AppTheme.danger
                                    : AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          onTap: (_busy || _navigating)
                              ? null
                              : () => _openUserForm(user),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _SimpleDataPage extends StatefulWidget {
  const _SimpleDataPage({
    required this.title,
    required this.loader,
    required this.emptyText,
    required this.itemBuilder,
    this.onAdd,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final Future<List<dynamic>> Function() loader;
  final String emptyText;
  final Widget Function(Map<String, dynamic> item) itemBuilder;
  final Future<bool?> Function(BuildContext context)? onAdd;
  final Future<bool?> Function(BuildContext context, Map<String, dynamic> item)?
      onEdit;
  final Future<void> Function(Map<String, dynamic> item)? onDelete;

  @override
  State<_SimpleDataPage> createState() => _SimpleDataPageState();
}

class _SimpleDataPageState extends State<_SimpleDataPage> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _opening = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.loader();
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

  Future<void> _delete(Map<String, dynamic> item) async {
    if (_deleting || _opening || widget.onDelete == null || !mounted) return;
    final confirmed = await _confirmDanger(
      context,
      title: 'Hapus ${item['name'] ?? widget.title}?',
      body:
          'Data akan dihapus dari database jika belum dipakai data lain. Ketik HAPUS untuk lanjut.',
      confirmationText: 'HAPUS',
      actionLabel: 'Hapus',
    );
    if (!confirmed || _deleting || _opening || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.onDelete!(item);
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showError(context, error, 'Hapus data gagal.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton(
              onPressed: (_loading || _opening || _deleting)
                  ? null
                  : () async {
                      setState(() => _opening = true);
                      try {
                        final changed = await widget.onAdd!(context);
                        if (changed == true && mounted) await _refresh();
                      } finally {
                        if (mounted) setState(() => _opening = false);
                      }
                    },
              child: Icon(Icons.add_rounded),
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 48),
                      _LivelyEmptyCard(
                        icon: _emptyIconFor(widget.title),
                        title: widget.emptyText.replaceAll('.', ''),
                        description: _emptyDescriptionFor(widget.title),
                        accentColor: _emptyColorFor(widget.title),
                        actionLabel:
                            widget.onAdd == null ? null : 'Tambah Data',
                        onAction: widget.onAdd == null ||
                                _loading ||
                                _opening ||
                                _deleting
                            ? null
                            : () async {
                                setState(() => _opening = true);
                                try {
                                  final changed = await widget.onAdd!(context);
                                  if (changed == true && mounted) {
                                    await _refresh();
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _opening = false);
                                  }
                                }
                              },
                        highlights: _emptyHighlightsFor(widget.title),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceFor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              AppTheme.lineFor(context).withValues(alpha: 0.6),
                        ),
                      ),
                      child: _DataActions(
                        item: _items[index] as Map<String, dynamic>,
                        itemBuilder: widget.itemBuilder,
                        busy: _opening || _deleting,
                        onEdit: widget.onEdit == null
                            ? null
                            : (item) async {
                                setState(() => _opening = true);
                                try {
                                  final changed =
                                      await widget.onEdit!(context, item);
                                  if (changed == true && mounted) {
                                    await _refresh();
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _opening = false);
                                  }
                                }
                              },
                        onDelete: widget.onDelete == null
                            ? null
                            : (item) => _delete(item),
                      ),
                    ),
                  ),
      ),
    );
  }

  IconData _emptyIconFor(String title) {
    if (title.contains('Shift')) return Icons.schedule_rounded;
    if (title.contains('Lokasi')) return Icons.location_on_outlined;
    if (title.contains('Department')) return Icons.apartment_rounded;
    if (title.contains('Libur')) return Icons.event_available_rounded;
    if (title.contains('Audit')) return Icons.fact_check_outlined;
    return Icons.inbox_rounded;
  }

  Color _emptyColorFor(String title) {
    if (title.contains('Shift')) return AppTheme.info;
    if (title.contains('Lokasi')) return AppTheme.success;
    if (title.contains('Libur')) return AppTheme.warning;
    if (title.contains('Audit')) return AppTheme.muted;
    return AppTheme.primary;
  }

  String _emptyDescriptionFor(String title) {
    if (title.contains('Shift')) {
      return 'Buat pola jam kerja agar validasi terlambat dan pulang mengikuti aturan server.';
    }
    if (title.contains('Lokasi')) {
      return 'Tambahkan titik kantor dan radius agar absensi lapangan bisa divalidasi dengan jelas.';
    }
    if (title.contains('Department')) {
      return 'Department membantu struktur karyawan, manajer, dan laporan tetap mudah dibaca.';
    }
    if (title.contains('Libur')) {
      return 'Hari libur membuat kalender kerja dan rekap absensi tidak menghitung hari nonaktif.';
    }
    if (title.contains('Audit')) {
      return 'Perubahan penting akan muncul di sini setelah aktivitas admin tercatat oleh server.';
    }
    return 'Data akan muncul setelah dibuat atau setelah server mengirim hasil terbaru.';
  }

  List<String> _emptyHighlightsFor(String title) {
    if (title.contains('Audit')) {
      return const [
        'Audit log membantu melacak perubahan yang berisiko.',
        'Tarik layar ke bawah setelah melakukan perubahan admin.',
      ];
    }
    return const [
      'Gunakan tombol tambah untuk membuat data pertama.',
      'Data yang sudah dipakai absensi tidak seharusnya dihapus sembarangan.',
      'Refresh setelah menyimpan untuk memastikan state lokal sinkron.',
    ];
  }
}

class _DataActions extends StatelessWidget {
  const _DataActions({
    required this.item,
    required this.itemBuilder,
    required this.busy,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic> item;
  final Widget Function(Map<String, dynamic> item) itemBuilder;
  final bool busy;
  final Future<void> Function(Map<String, dynamic> item)? onEdit;
  final Future<void> Function(Map<String, dynamic> item)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        itemBuilder(item),
        if (onEdit != null || onDelete != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (onEdit != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onEdit!(item),
                    icon: Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit'),
                  ),
                if (onDelete != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onDelete!(item),
                    icon: Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                        color: AppTheme.danger.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UserFormPage extends StatefulWidget {
  const _UserFormPage({required this.apiClient, this.user});

  final ApiClient apiClient;
  final Map<String, dynamic>? user;

  @override
  State<_UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<_UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _nip;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  String _role = 'KARYAWAN';
  String? _departmentId;
  String? _shiftId;
  String? _directManagerId;
  final Set<String> _officeLocationIds = {};
  List<dynamic> _departments = [];
  List<dynamic> _shifts = [];
  List<dynamic> _offices = [];
  List<dynamic> _managers = [];
  bool _isActive = true;
  bool _loading = false;
  bool _mastersLoading = true;

  bool get _editing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _name = TextEditingController(text: user?['name'] as String? ?? '');
    _email = TextEditingController(text: user?['email'] as String? ?? '');
    _nip = TextEditingController(text: user?['nip'] as String? ?? '');
    _phone = TextEditingController(text: user?['phone'] as String? ?? '');
    _password = TextEditingController();
    _role = user?['role'] as String? ?? _role;
    _departmentId = user?['departmentId'] as String?;
    _shiftId = user?['shiftId'] as String?;
    _directManagerId = user?['directManagerId'] as String?;
    final officeLocations = user?['officeLocations'];
    if (officeLocations is List) {
      _officeLocationIds.addAll(
        officeLocations
            .whereType<Map>()
            .map((office) => office['id']?.toString())
            .whereType<String>(),
      );
    }
    _isActive = user?['isActive'] != false;
    _loadMasters();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _nip.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final values = await Future.wait([
        widget.apiClient.adminDepartments(),
        widget.apiClient.adminShifts(),
        widget.apiClient.adminOffices(),
        widget.apiClient.adminUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = values[0];
        _shifts = values[1];
        _offices = values[2];
        _managers = values[3]
            .where(
              (item) =>
                  item is Map &&
                  ['MANAJER', 'HR', 'SUPER_ADMIN'].contains(item['role']) &&
                  item['id'] != widget.user?['id'],
            )
            .toList();
        _mastersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _mastersLoading = false);
    }
  }

  Future<void> _save() async {
    if (_loading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_editing) {
        final payload = {
          'name': _name.text.trim(),
          'isActive': _isActive,
          'departmentId': _departmentId,
          'shiftId': _shiftId,
          'directManagerId': _directManagerId,
          'officeLocationIds': _officeLocationIds.toList(),
          if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        };
        await widget.apiClient.updateAdminUser(
          widget.user!['id'] as String,
          payload,
        );
      } else {
        final payload = {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'nip': _nip.text.trim(),
          'password': _password.text,
          'role': _role,
          if (_departmentId != null) 'departmentId': _departmentId,
          if (_shiftId != null) 'shiftId': _shiftId,
          if (_directManagerId != null) 'directManagerId': _directManagerId,
          if (_officeLocationIds.isNotEmpty)
            'officeLocationIds': _officeLocationIds.toList(),
          if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        };
        await widget.apiClient.createAdminUser(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(
              error,
              fallback: 'Simpan karyawan gagal.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Karyawan' : 'Tambah Karyawan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nama',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Nama minimal 2 karakter'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              enabled: !_editing,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                if (_editing) return null;
                final text = (value ?? '').trim();
                if (!text.contains('@')) return 'Email belum valid';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nip,
              enabled: !_editing,
              decoration: const InputDecoration(
                labelText: 'NIP',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                if (_editing) return null;
                return (value ?? '').trim().length < 3
                    ? 'NIP minimal 3 karakter'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Nomor HP',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.length < 8) return 'Password minimal 8 karakter';
                  if (!RegExp(r'[A-Z]').hasMatch(text)) {
                    return 'Password wajib punya huruf besar';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(text)) {
                    return 'Password wajib punya angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'KARYAWAN', child: Text('Karyawan')),
                  DropdownMenuItem(value: 'MANAJER', child: Text('Manajer')),
                  DropdownMenuItem(value: 'HR', child: Text('HR')),
                  DropdownMenuItem(
                      value: 'SUPER_ADMIN', child: Text('Super Admin')),
                ],
                onChanged: (value) => setState(() => _role = value ?? _role),
              ),
            ],
            if (_mastersLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ] else ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _departmentId,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-')),
                  for (final item in _departments.whereType<Map>())
                    DropdownMenuItem(
                      value: item['id'] as String,
                      child: Text(item['name']?.toString() ?? '-'),
                    ),
                ],
                onChanged: (value) => setState(() => _departmentId = value),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _shiftId,
                decoration: const InputDecoration(
                  labelText: 'Shift / Rotasi',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-')),
                  for (final item in _shifts.whereType<Map>())
                    DropdownMenuItem(
                      value: item['id'] as String,
                      child: Text(item['name']?.toString() ?? '-'),
                    ),
                ],
                onChanged: (value) => setState(() => _shiftId = value),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _directManagerId,
                decoration: const InputDecoration(
                  labelText: 'Atasan langsung',
                  prefixIcon: Icon(Icons.supervisor_account_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-')),
                  for (final item in _managers.whereType<Map>())
                    DropdownMenuItem(
                      value: item['id'] as String,
                      child: Text(item['name']?.toString() ?? '-'),
                    ),
                ],
                onChanged: (value) => setState(() => _directManagerId = value),
              ),
              if (_offices.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Lokasi kantor',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceFor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.lineFor(context)),
                  ),
                  child: Column(
                    children: [
                      for (final item in _offices.whereType<Map>())
                        CheckboxListTile(
                          dense: true,
                          value:
                              _officeLocationIds.contains(item['id'] as String),
                          title: Text(item['name']?.toString() ?? '-'),
                          onChanged: (value) {
                            final id = item['id'] as String;
                            setState(() {
                              if (value == true) {
                                _officeLocationIds.add(id);
                              } else {
                                _officeLocationIds.remove(id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Akun aktif'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: Icon(Icons.save_rounded),
              label: Text(_loading ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentFormPage extends StatefulWidget {
  const _DepartmentFormPage({required this.apiClient, this.item});

  final ApiClient apiClient;
  final Map<String, dynamic>? item;

  @override
  State<_DepartmentFormPage> createState() => _DepartmentFormPageState();
}

class _DepartmentFormPageState extends State<_DepartmentFormPage> {
  final _name = TextEditingController();
  bool _loading = false;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _name.text = widget.item?['name'] as String? ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading || !mounted) return;
    if (_name.text.trim().length < 2) return;
    setState(() => _loading = true);
    try {
      if (_editing) {
        await widget.apiClient.updateDepartment(
          widget.item!['id'] as String,
          _name.text.trim(),
        );
      } else {
        await widget.apiClient.createDepartment(_name.text.trim());
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(context, error, 'Simpan department gagal.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SingleFieldForm(
        title: _editing ? 'Edit Department' : 'Tambah Department',
        controller: _name,
        label: 'Nama department',
        loading: _loading,
        onSave: _save,
      );
}

class _ShiftFormPage extends StatefulWidget {
  const _ShiftFormPage({required this.apiClient, this.item});

  final ApiClient apiClient;
  final Map<String, dynamic>? item;

  @override
  State<_ShiftFormPage> createState() => _ShiftFormPageState();
}

class _ShiftFormPageState extends State<_ShiftFormPage> {
  final _name = TextEditingController();
  final _start = TextEditingController(text: '08:00');
  final _end = TextEditingController(text: '17:00');
  final _tolerance = TextEditingController(text: '10');
  final _flexibleHours = TextEditingController(text: '8');
  bool _loading = false;
  bool _isFlexible = false;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    _name.text = item['name'] as String? ?? '';
    _start.text = item['startTime'] as String? ?? '08:00';
    _end.text = item['endTime'] as String? ?? '17:00';
    _tolerance.text = '${item['lateToleranceMinutes'] ?? 10}';
    _isFlexible = item['isFlexible'] == true;
    _flexibleHours.text = '${item['flexibleHours'] ?? 8}';
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    _tolerance.dispose();
    _flexibleHours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    try {
      final payload = {
        'name': _name.text.trim(),
        'startTime': _start.text.trim(),
        'endTime': _end.text.trim(),
        'workDays': [1, 2, 3, 4, 5],
        'lateToleranceMinutes': int.tryParse(_tolerance.text) ?? 10,
        'isFlexible': _isFlexible,
        if (_isFlexible)
          'flexibleHours': int.tryParse(_flexibleHours.text) ?? 8,
      };
      if (_editing) {
        await widget.apiClient
            .updateShift(widget.item!['id'] as String, payload);
      } else {
        await widget.apiClient.createShift(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(context, error, 'Simpan shift gagal.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit Shift' : 'Tambah Shift')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nama',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _start,
              decoration: const InputDecoration(
                labelText: 'Jam masuk',
                prefixIcon: Icon(Icons.login_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _end,
              decoration: const InputDecoration(
                labelText: 'Jam pulang',
                prefixIcon: Icon(Icons.logout_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tolerance,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Toleransi terlambat (menit)',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shift fleksibel'),
              value: _isFlexible,
              onChanged: (value) => setState(() => _isFlexible = value),
            ),
            if (_isFlexible) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _flexibleHours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durasi fleksibel (jam)',
                  prefixIcon: Icon(Icons.av_timer_rounded),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: Icon(Icons.save_rounded),
              label: Text(_loading ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      );
}

class _OfficeFormPage extends StatefulWidget {
  const _OfficeFormPage({required this.apiClient, this.item});

  final ApiClient apiClient;
  final Map<String, dynamic>? item;

  @override
  State<_OfficeFormPage> createState() => _OfficeFormPageState();
}

class _OfficeFormPageState extends State<_OfficeFormPage> {
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radius = TextEditingController(text: '100');
  bool _loading = false;
  bool _fetchingLocation = false;
  bool _isActive = true;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _name.text = item['name'] as String? ?? '';
      _lat.text = '${item['latitude'] ?? ''}';
      _lng.text = '${item['longitude'] ?? ''}';
      _radius.text = '${item['radiusMeters'] ?? 100}';
      _isActive = item['isActive'] != false;
    } else {
      _fetchCurrentLocation();
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (_fetchingLocation || !mounted) return;
    setState(() => _fetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lat.text = position.latitude.toStringAsFixed(6);
        _lng.text = position.longitude.toStringAsFixed(6);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading || !mounted) return;
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = int.tryParse(_radius.text.trim()) ?? 100;

    if (_name.text.trim().length < 2) {
      _showError(context, 'Nama lokasi minimal 2 karakter.', 'Validasi gagal.');
      return;
    }
    if (lat == null || lat < -90 || lat > 90) {
      _showError(
          context, 'Latitude harus antara -90 dan 90.', 'Validasi gagal.');
      return;
    }
    if (lng == null || lng < -180 || lng > 180) {
      _showError(
          context, 'Longitude harus antara -180 dan 180.', 'Validasi gagal.');
      return;
    }
    if (radius < 10 || radius > 10000) {
      _showError(context, 'Radius harus antara 10 dan 10000 meter.',
          'Validasi gagal.');
      return;
    }

    setState(() => _loading = true);
    try {
      final payload = {
        'name': _name.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'radiusMeters': radius,
        'isActive': _isActive,
      };
      if (_editing) {
        await widget.apiClient.updateOffice(
          widget.item!['id'] as String,
          payload,
        );
      } else {
        await widget.apiClient.createOffice(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(context, error, 'Simpan lokasi gagal.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit Lokasi' : 'Tambah Lokasi')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nama lokasi',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _fetchingLocation ? null : _fetchCurrentLocation,
              icon: _fetchingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location_rounded, size: 20),
              label: Text(_fetchingLocation
                  ? 'Mengambil lokasi...'
                  : 'Ambil Lokasi Saat Ini'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _lat,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _lng,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius meter',
                prefixIcon: Icon(Icons.radio_button_unchecked),
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lokasi aktif'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: Icon(Icons.save_rounded),
              label: Text(_loading ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      );
}

class _HolidayFormPage extends StatefulWidget {
  const _HolidayFormPage({required this.apiClient, this.item});

  final ApiClient apiClient;
  final Map<String, dynamic>? item;

  @override
  State<_HolidayFormPage> createState() => _HolidayFormPageState();
}

class _HolidayFormPageState extends State<_HolidayFormPage> {
  final _name = TextEditingController();
  DateTime? _date;
  bool _loading = false;
  bool _isCustom = true;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    _name.text = item['name'] as String? ?? '';
    _date = DateTime.tryParse(item['date']?.toString() ?? '')?.toLocal();
    _isCustom = item['isCustom'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading || !mounted) return;
    final date = _date;
    if (date == null || _name.text.trim().length < 2) return;
    setState(() => _loading = true);
    try {
      final payload = {
        'name': _name.text.trim(),
        'date': date.toUtc().toIso8601String(),
        'isCustom': _isCustom,
      };
      if (_editing) {
        await widget.apiClient.updateHoliday(
          widget.item!['id'] as String,
          payload,
        );
      } else {
        await widget.apiClient.createHoliday(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(context, error, 'Simpan hari libur gagal.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_editing ? 'Edit Hari Libur' : 'Tambah Hari Libur')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nama hari libur',
                prefixIcon: Icon(Icons.celebration_outlined),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 2),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: Icon(Icons.date_range_rounded),
              label: Text(
                _date == null ? 'Pilih tanggal' : formatDateTime(_date),
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hari libur custom'),
              value: _isCustom,
              onChanged: (value) => setState(() => _isCustom = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: Icon(Icons.save_rounded),
              label: Text(_loading ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      );
}

class _SingleFieldForm extends StatelessWidget {
  const _SingleFieldForm({
    required this.title,
    required this.controller,
    required this.label,
    required this.loading,
    required this.onSave,
  });

  final String title;
  final TextEditingController controller;
  final String label;
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: label),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: loading ? null : onSave,
              icon: Icon(Icons.save_rounded),
              label: Text(loading ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      );
}

class _LeaveBalancesPage extends StatefulWidget {
  const _LeaveBalancesPage({required this.apiClient});

  final ApiClient apiClient;

  @override
  State<_LeaveBalancesPage> createState() => _LeaveBalancesPageState();
}

class _LeaveBalancesPageState extends State<_LeaveBalancesPage> {
  List<dynamic> _items = [];
  List<dynamic> _users = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final values = await Future.wait([
        widget.apiClient.adminLeaveBalances(year: DateTime.now().year),
        widget.apiClient.adminUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = values[0];
        _users = values[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _LeaveBalanceFormPage(
            apiClient: widget.apiClient,
            users: _users,
            item: item,
          ),
        ),
      );
      if (changed == true && mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (_busy || !mounted) return;
    final user = item['user'] is Map ? item['user'] as Map : const {};
    final confirmed = await _confirmDanger(
      context,
      title: 'Hapus saldo cuti?',
      body:
          'Saldo cuti ${user['name'] ?? '-'} tahun ${item['year'] ?? '-'} akan dihapus dari database.',
      confirmationText: 'HAPUS',
      actionLabel: 'Hapus',
    );
    if (!confirmed || _busy || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.apiClient.deleteLeaveBalance(item['id'] as String);
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showError(context, error, 'Hapus saldo cuti gagal.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saldo Cuti')),
      floatingActionButton: FloatingActionButton(
        onPressed: (_loading || _busy) ? null : () => _openForm(),
        child: Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 48),
                      _LivelyEmptyCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Belum ada saldo cuti',
                        description:
                            'Buat saldo per karyawan dan tahun agar pengajuan cuti punya batas yang jelas.',
                        accentColor: AppTheme.success,
                        actionLabel: 'Tambah Saldo',
                        onAction: _busy ? null : () => _openForm(),
                        highlights: const [
                          'Kuota tahunan dan cuti terpakai harus sesuai data HR.',
                          'Sistem menolak cuti terpakai yang lebih besar dari kuota.',
                          'Hapus saldo hanya jika belum dipakai proses payroll atau approval.',
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index] as Map<String, dynamic>;
                      final user =
                          item['user'] is Map ? item['user'] as Map : const {};
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceFor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.lineFor(context)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.successSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: AppTheme.success,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                user['name']?.toString() ?? '-',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Tahun ${item['year'] ?? '-'} - '
                                'Kuota ${item['annualQuota'] ?? 0}, '
                                'terpakai ${item['used'] ?? 0}, '
                                'sisa ${item['remaining'] ?? 0}',
                                style: TextStyle(
                                    color: AppTheme.mutedFor(context)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: Wrap(
                                spacing: 8,
                                alignment: WrapAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed:
                                        _busy ? null : () => _openForm(item),
                                    icon: Icon(Icons.edit_rounded, size: 16),
                                    label: const Text('Edit'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _busy ? null : () => _delete(item),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Hapus'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.danger,
                                      side: BorderSide(
                                        color: AppTheme.danger
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _LeaveBalanceFormPage extends StatefulWidget {
  const _LeaveBalanceFormPage({
    required this.apiClient,
    required this.users,
    this.item,
  });

  final ApiClient apiClient;
  final List<dynamic> users;
  final Map<String, dynamic>? item;

  @override
  State<_LeaveBalanceFormPage> createState() => _LeaveBalanceFormPageState();
}

class _LeaveBalanceFormPageState extends State<_LeaveBalanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _year;
  late final TextEditingController _quota;
  late final TextEditingController _used;
  String? _userId;
  bool _loading = false;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _userId = item?['userId'] as String?;
    _year = TextEditingController(
      text: '${item?['year'] ?? DateTime.now().year}',
    );
    _quota = TextEditingController(text: '${item?['annualQuota'] ?? 12}');
    _used = TextEditingController(text: '${item?['used'] ?? 0}');
  }

  @override
  void dispose() {
    _year.dispose();
    _quota.dispose();
    _used.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    final userId = _userId;
    if (userId == null) {
      _showError(context, 'Pilih user dulu.', 'Validasi gagal.');
      return;
    }

    final quota = int.tryParse(_quota.text.trim()) ?? 12;
    final used = int.tryParse(_used.text.trim()) ?? 0;
    if (used > quota) {
      _showError(context, 'Cuti terpakai melebihi kuota.', 'Validasi gagal.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_editing) {
        await widget.apiClient.updateLeaveBalance(
          widget.item!['id'] as String,
          {
            'annualQuota': quota,
            'used': used,
          },
        );
      } else {
        await widget.apiClient.createLeaveBalance({
          'userId': userId,
          'year': int.tryParse(_year.text.trim()) ?? DateTime.now().year,
          'annualQuota': quota,
          'used': used,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showError(context, error, 'Simpan saldo cuti gagal.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.users
        .where((item) => item is Map && item['isActive'] != false)
        .cast<Map>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Saldo Cuti' : 'Tambah Saldo Cuti'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _userId,
              decoration: const InputDecoration(
                labelText: 'User',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              items: [
                for (final user in users)
                  DropdownMenuItem(
                    value: user['id'] as String,
                    child: Text(user['name']?.toString() ?? '-'),
                  ),
              ],
              validator: (value) => value == null ? 'User wajib dipilih' : null,
              onChanged:
                  _editing ? null : (value) => setState(() => _userId = value),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _year,
              enabled: !_editing,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tahun',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (value) {
                final year = int.tryParse((value ?? '').trim());
                if (year == null || year < 2000 || year > 2100) {
                  return 'Tahun belum valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _quota,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kuota cuti tahunan',
                prefixIcon: Icon(Icons.event_available_outlined),
              ),
              validator: (value) {
                final quota = int.tryParse((value ?? '').trim());
                if (quota == null || quota < 0 || quota > 365) {
                  return 'Kuota belum valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _used,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cuti terpakai',
                prefixIcon: Icon(Icons.event_busy_outlined),
              ),
              validator: (value) {
                final used = int.tryParse((value ?? '').trim());
                if (used == null || used < 0 || used > 365) {
                  return 'Cuti terpakai belum valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: Icon(Icons.save_rounded),
              label: Text(_loading ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollSummaryPage extends StatefulWidget {
  const _PayrollSummaryPage({required this.apiClient});

  final ApiClient apiClient;

  @override
  State<_PayrollSummaryPage> createState() => _PayrollSummaryPageState();
}

class _PayrollSummaryPageState extends State<_PayrollSummaryPage> {
  late final String _month = DateFormat('yyyy-MM').format(DateTime.now());
  List<dynamic> _items = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.apiClient.payrollSummary(month: _month);
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

  Future<void> _lockMonth() async {
    if (_busy || !mounted) return;
    final confirmed = await _confirmDanger(
      context,
      title: 'Lock payroll $_month?',
      body:
          'Rekap bulan ini akan dikirim ke workflow payroll. Pastikan data absensi, izin, cuti, dan anomali sudah final.',
      confirmationText: 'LOCK $_month',
      actionLabel: 'Lock',
    );
    if (!confirmed || _busy || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await widget.apiClient.lockPayrollMonth(month: _month);
      if (!mounted) return;
      final delivered = result['delivered'] == true;
      final reason = result['reason'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? 'Payroll $_month berhasil dikirim.'
                : reason ??
                    'Payroll $_month dikunci lokal, webhook belum aktif.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(
              error,
              fallback: 'Lock payroll gagal. Cek role dan data.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payroll $_month'),
        actions: [
          IconButton(
            tooltip: 'Lock payroll',
            onPressed: _busy ? null : _lockMonth,
            icon: Icon(Icons.lock_outline_rounded, size: 22),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 48),
                      _LivelyEmptyCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'Belum ada data payroll bulan ini',
                        description:
                            'Rekap payroll akan muncul setelah absensi masuk, izin, cuti, dan lembur bulan $_month tersedia.',
                        accentColor: AppTheme.info,
                        actionLabel: 'Muat Ulang',
                        onAction: _busy ? null : _refresh,
                        highlights: const [
                          'Pastikan anomali sudah selesai direview sebelum lock payroll.',
                          'Lock payroll membutuhkan konfirmasi karena sulit dibatalkan.',
                          'Data yang tampil tetap berasal dari server, bukan angka contoh.',
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final row = _items[index] as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceFor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.lineFor(context)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.successSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.payments_rounded,
                              color: AppTheme.success,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            row['userId'] as String? ?? '-',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Hadir ${row['totalHadir'] ?? 0}, terlambat ${row['totalTerlambat'] ?? 0}, '
                            'izin ${row['totalIzin'] ?? 0}, cuti ${row['totalCuti'] ?? 0}',
                            style: TextStyle(
                                color: AppTheme.mutedFor(context),
                                fontSize: 12),
                          ),
                          trailing: Text(
                            '${row['totalLemburJam'] ?? 0} jam',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  const _AnomalyTile({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onWarn,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onWarn;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final user = item['user'] is Map ? item['user'] as Map : const {};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warning,
                  size: 22,
                ),
              ),
              title: Text(
                user['name'] as String? ?? 'Karyawan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${item['anomalyReason'] ?? 'Butuh review'}\n'
                '${formatDateTime(item['timestamp'])}',
                style:
                    TextStyle(color: AppTheme.mutedFor(context), height: 1.4),
              ),
              trailing: Text(
                item['status'] as String? ?? '-',
                style: TextStyle(
                  color: AppTheme.mutedFor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              onTap: () => _showJson(context, 'Detail Anomali', item),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: Icon(Icons.close_rounded, size: 16),
                  label: const Text('Tolak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: BorderSide(
                      color: AppTheme.danger.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onWarn,
                  icon: Icon(Icons.report_gmailerrorred_rounded, size: 16),
                  label: const Text('Peringatkan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: BorderSide(
                      color: AppTheme.warning.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: Icon(Icons.check_rounded, size: 16),
                  label: const Text('Setujui'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminData {
  const _AdminData({
    required this.users,
    required this.shifts,
    required this.offices,
    required this.anomalies,
    required this.pendingLeaves,
    required this.summary,
  });

  final List<dynamic> users;
  final List<dynamic> shifts;
  final List<dynamic> offices;
  final List<dynamic> anomalies;
  final List<dynamic> pendingLeaves;
  final Map<String, dynamic> summary;

  List<dynamic> get unapprovedUsers =>
      users.where((item) => item is Map && item['isApproved'] != true).toList();
}

Future<bool> _confirmDanger(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmationText,
  String actionLabel = 'Lanjut',
}) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Ketik "$confirmationText"',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.dangerSurface,
            foregroundColor: AppTheme.danger,
            side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.3)),
          ),
          onPressed: () {
            final valid = controller.text.trim() == confirmationText;
            if (!valid) return;
            Navigator.of(context).pop(true);
          },
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return result == true;
}

void _showError(BuildContext context, Object error, String fallback) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ApiClient.errorMessage(error, fallback: fallback)),
    ),
  );
}

void _showJson(BuildContext context, String title, Map<String, dynamic> data) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceFor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: data.entries.length,
                itemBuilder: (context, index) {
                  final entry = data.entries.elementAt(index);
                  if (entry.value == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labelize(entry.key),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppTheme.mutedFor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _readableValue(entry.value),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _labelize(String value) {
  return value
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
      .replaceAll('_', ' ')
      .trim();
}

String _readableValue(Object? value) {
  if (value == null) return '-';
  if (value is Map && value['name'] != null) return value['name'].toString();
  if (value is Iterable) return value.map(_readableValue).join(', ');
  return value.toString();
}
