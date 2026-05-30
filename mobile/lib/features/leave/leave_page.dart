import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/text_prompt_sheet.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({
    required this.apiClient,
    this.user,
    super.key,
  });

  final ApiClient apiClient;
  final Map<String, dynamic>? user;

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  _LeaveData? _data;
  Map<String, dynamic>? _balance;
  bool _initialLoading = true;
  String? _loadError;
  final _reason = TextEditingController();
  String _type = 'CUTI_TAHUNAN';
  DateTimeRange? _range;
  String? _documentUrl;
  String? _documentName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final userRole = widget.user?['role']?.toString() ?? 'KARYAWAN';
      final canApprove = ['MANAJER', 'HR', 'SUPER_ADMIN'].contains(userRole);

      final mineFuture = widget.apiClient.leaveMine();
      final balanceFuture = widget.apiClient.leaveBalance();
      final pendingFuture = canApprove
          ? widget.apiClient.leavePending()
          : Future.value(<dynamic>[]);

      final mine = await mineFuture;
      final pending = await pendingFuture;
      final balance = await balanceFuture;
      if (!mounted) return;
      setState(() {
        _data = _LeaveData(mine: mine, pending: pending);
        _balance = balance;
        _initialLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !mounted) return;
    final range = _range;
    if (range == null || _reason.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih tanggal dan isi keterangan minimal 5 karakter.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.apiClient.createLeave({
        'type': _type,
        'dateFrom': range.start.toUtc().toIso8601String(),
        'dateTo': range.end.toUtc().toIso8601String(),
        'reason': _reason.text.trim(),
        if (_documentUrl != null) 'documentUrl': _documentUrl,
      });
      _reason.clear();
      _range = null;
      _documentUrl = null;
      _documentName = null;
      setState(() => _loading = false);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan berhasil dikirim.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(
              error,
              fallback: 'Pengajuan gagal. Cek saldo cuti atau koneksi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument() async {
    if (_loading || !mounted) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Dokumen',
          extensions: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();

    setState(() => _loading = true);
    try {
      final url = await widget.apiClient.uploadDocument(
        fileName: file.name,
        mimeType: mimeTypeFromExtension(file.name.split('.').last),
        bytes: bytes,
      );
      setState(() {
        _documentUrl = url;
        _documentName = file.name;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumen berhasil dilampirkan.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(
              error,
              fallback: 'Upload dokumen gagal.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> item, bool approved) async {
    if (_loading || !mounted) return;
    final comment = await showTextPromptSheet(
      context,
      title: approved ? 'Catatan approval' : 'Alasan penolakan',
      isRequired: !approved,
      submitLabel: 'Kirim',
    );
    if (comment == null || _loading || !mounted) return;

    setState(() => _loading = true);
    try {
      await _executeApprove(item, approved, comment);
      if (mounted) _applyApprovalLocally(item, approved);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(
              error,
              fallback: 'Approval gagal. Cek role dan status.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyApprovalLocally(Map<String, dynamic> item, bool approved) {
    final data = _data;
    if (data == null) return;

    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;

    final nextStatus = _nextLeaveStatus(item, approved);
    setState(() {
      _data = _LeaveData(
        pending: data.pending
            .where((entry) => entry is! Map || entry['id']?.toString() != id)
            .toList(),
        mine: data.mine.map((entry) {
          if (entry is! Map || entry['id']?.toString() != id) return entry;
          return {
            ...Map<String, dynamic>.from(entry),
            'status': nextStatus,
          };
        }).toList(),
      );
    });
  }

  String _nextLeaveStatus(Map<String, dynamic> item, bool approved) {
    if (!approved) return 'DITOLAK';
    final status = item['status']?.toString();
    if (status == 'MENUNGGU_HR') return 'DISETUJUI';

    final role = widget.user?['role']?.toString() ?? 'KARYAWAN';
    final days = _businessDays(item['dateFrom'], item['dateTo']);
    if (days > 3 && !['HR', 'SUPER_ADMIN'].contains(role)) {
      return 'MENUNGGU_HR';
    }
    return 'DISETUJUI';
  }

  int _businessDays(Object? fromValue, Object? toValue) {
    final from = DateTime.tryParse(fromValue?.toString() ?? '');
    final to = DateTime.tryParse(toValue?.toString() ?? '');
    if (from == null || to == null || to.isBefore(from)) return 1;

    var cursor = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    var days = 0;
    while (!cursor.isAfter(end)) {
      if (cursor.weekday <= DateTime.friday) days++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return days == 0 ? 1 : days;
  }

  Future<void> _executeApprove(
      Map<String, dynamic> item, bool approved, String comment) async {
    final id = item['id']?.toString();
    final status = item['status']?.toString() ?? 'MENUNGGU_MANAJER';
    if (id == null || id.isEmpty) {
      throw StateError('ID pengajuan tidak ditemukan.');
    }

    await widget.apiClient.approveLeave(
      id: id,
      status: status,
      approved: approved,
      comment: comment,
    );

    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approved
            ? 'Pengajuan berhasil disetujui.'
            : 'Pengajuan berhasil ditolak.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = widget.user?['role']?.toString() ?? 'KARYAWAN';
    final canApprove = ['MANAJER', 'HR', 'SUPER_ADMIN'].contains(userRole);

    return Scaffold(
      backgroundColor: AppTheme.canvasFor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceFor(context),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Izin & Cuti',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_balance != null) _LeaveBalanceCard(data: _balance!),
            const SizedBox(height: 20),
            _LeaveFormCard(
              loading: _loading,
              type: _type,
              range: _range,
              documentName: _documentName,
              reason: _reason,
              onTypeChanged: (value) => setState(() => _type = value ?? _type),
              onRangePicked: (value) => setState(() => _range = value),
              onPickDocument: _pickDocument,
              onSubmit: _submit,
            ),
            const SizedBox(height: 20),
            if (_initialLoading)
              const Center(child: CircularProgressIndicator())
            else if (_loadError != null)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.dangerSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.12),
                  ),
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
                      'Gagal memuat data izin',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tarik ke bawah untuk mencoba lagi.',
                      style: TextStyle(
                          color: AppTheme.mutedFor(context), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (_data != null) ...[
              _LeaveInsightCard(
                mine: _data!.mine,
                pending: _data!.pending,
                canApprove: canApprove,
              ),
              const SizedBox(height: 20),
              if (canApprove && _data!.pending.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Menunggu Approval',
                  count: _data!.pending.length,
                ),
                const SizedBox(height: 12),
                for (final item in _data!.pending)
                  _PendingLeaveCard(
                    item: item as Map<String, dynamic>,
                    loading: _loading,
                    onApprove: () => _approve(item, true),
                    onReject: () => _approve(item, false),
                  ),
                const SizedBox(height: 24),
              ],
              _SectionHeader(
                title: 'Pengajuan Saya',
                count: _data!.mine.length,
              ),
              const SizedBox(height: 12),
              if (_data!.mine.isEmpty)
                const _EmptyState(
                  icon: Icons.event_available_rounded,
                  message: 'Belum ada pengajuan',
                  description:
                      'Form di atas siap dipakai untuk cuti, sakit, dinas luar, atau izin mendesak.',
                  highlights: [
                    'Pilih rentang tanggal agar sistem bisa menghitung hari kerja.',
                    'Lampirkan dokumen jika diperlukan oleh HR atau manajer.',
                    'Status approval akan diperbarui dari server setelah pengajuan dikirim.',
                  ],
                )
              else
                for (final item in _data!.mine)
                  _LeaveCard(item: item as Map<String, dynamic>),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Balance Card ───────────────────

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cuti = data['cuti'] as Map? ?? {};
    final sakit = data['sakit'] as Map? ?? {};
    final izin = data['izin'] as Map? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Saldo Cuti ${data['year']}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BalanceItem(
                  label: 'Cuti',
                  used: cuti['used'] ?? 0,
                  total: cuti['total'] ?? 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceItem(
                  label: 'Sakit',
                  used: sakit['used'] ?? 0,
                  total: sakit['total'] ?? -1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceItem(
                  label: 'Izin',
                  used: izin['used'] ?? 0,
                  total: izin['total'] ?? -1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  const _BalanceItem({
    required this.label,
    required this.used,
    required this.total,
  });

  final String label;
  final int used;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isUnlimited = total < 0;
    final remaining = isUnlimited ? 999 : total - used;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUnlimited ? '$used' : '$remaining',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isUnlimited ? 'dipakai' : 'sisa',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Section Header ───────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count = 0});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────── Empty State ───────────────────

class _LeaveInsightCard extends StatelessWidget {
  const _LeaveInsightCard({
    required this.mine,
    required this.pending,
    required this.canApprove,
  });

  final List<dynamic> mine;
  final List<dynamic> pending;
  final bool canApprove;

  @override
  Widget build(BuildContext context) {
    final approved = mine.where((item) {
      if (item is! Map) return false;
      final status = item['status']?.toString() ?? '';
      return status.contains('DISETUJUI') || status.contains('APPROVE');
    }).length;
    final rejected = mine.where((item) {
      if (item is! Map) return false;
      final status = item['status']?.toString() ?? '';
      return status.contains('DITOLAK') || status.contains('REJECT');
    }).length;
    final waitingMine = mine.length - approved - rejected;
    final actionText = canApprove
        ? '${pending.length} menunggu approval kamu'
        : '$waitingMine pengajuan masih berjalan';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.premiumCardDecorationFor(context,
        accent: canApprove && pending.isNotEmpty
            ? AppTheme.warning
            : AppTheme.primary,
        radius: 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.route_rounded,
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
                      'Status Izin & Cuti',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      actionText,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniLeaveStat(
                  label: 'Disetujui',
                  value: '$approved',
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniLeaveStat(
                  label: 'Proses',
                  value: '$waitingMine',
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniLeaveStat(
                  label: 'Ditolak',
                  value: '$rejected',
                  color: AppTheme.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniLeaveStat extends StatelessWidget {
  const _MiniLeaveStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.mutedFor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.description,
    this.highlights = const [],
  });

  final IconData icon;
  final String message;
  final String description;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.lineFor(context).withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.16),
                    AppTheme.info.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedFor(context),
                height: 1.45,
                fontSize: 13,
              ),
            ),
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final item in highlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.success,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Form Card ───────────────────

class _LeaveFormCard extends StatelessWidget {
  const _LeaveFormCard({
    required this.loading,
    required this.type,
    required this.range,
    required this.documentName,
    required this.reason,
    required this.onTypeChanged,
    required this.onRangePicked,
    required this.onPickDocument,
    required this.onSubmit,
  });

  final bool loading;
  final String type;
  final DateTimeRange? range;
  final String? documentName;
  final TextEditingController reason;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<DateTimeRange?> onRangePicked;
  final VoidCallback onPickDocument;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Buat Pengajuan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(
                labelText: 'Jenis',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'SAKIT', child: Text('Sakit')),
                DropdownMenuItem(
                    value: 'CUTI_TAHUNAN', child: Text('Cuti tahunan')),
                DropdownMenuItem(
                    value: 'DINAS_LUAR', child: Text('Dinas luar')),
                DropdownMenuItem(
                    value: 'IZIN_MENDESAK', child: Text('Izin mendesak')),
                DropdownMenuItem(
                    value: 'CUTI_MELAHIRKAN', child: Text('Cuti melahirkan')),
                DropdownMenuItem(
                    value: 'CUTI_MENIKAH', child: Text('Cuti menikah')),
              ],
              onChanged: onTypeChanged,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: loading
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: now.subtract(const Duration(days: 30)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      onRangePicked(picked);
                    },
              icon: Icon(Icons.date_range_rounded),
              label: Text(
                range == null
                    ? 'Pilih tanggal'
                    : '${range!.start.toLocal().toString().split(' ').first} - ${range!.end.toLocal().toString().split(' ').first}',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: loading ? null : onPickDocument,
              icon: Icon(Icons.attach_file_rounded),
              label: Text(
                documentName ?? 'Lampirkan dokumen opsional',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryDark,
                      ),
                    )
                  : Icon(Icons.send_rounded),
              label: Text(loading ? 'Mengirim...' : 'Ajukan'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Pending Card ───────────────────

class _PendingLeaveCard extends StatelessWidget {
  const _PendingLeaveCard({
    required this.item,
    required this.loading,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final bool loading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final user = item['user'] is Map ? item['user'] as Map : const {};
    final type = item['type']?.toString() ?? '-';
    final dateFrom = formatDate(item['dateFrom']);
    final dateTo = formatDate(item['dateTo']);
    final reason = item['reason']?.toString() ?? '';
    final userName = user['name']?.toString() ?? 'Karyawan';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warning.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.warningSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.pending_actions_rounded,
                    color: AppTheme.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$type · $dateFrom – $dateTo',
                        style: TextStyle(
                          color: AppTheme.mutedFor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.canvasFor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    height: 1.4,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onReject,
                    icon: Icon(Icons.close_rounded, size: 18),
                    label: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: loading ? null : onApprove,
                    icon: Icon(Icons.check_rounded, size: 18),
                    label: const Text('Setujui'),
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

// ─────────────────── Leave Card ───────────────────

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? '-';
    final type = item['type']?.toString() ?? '-';
    final dateFrom = formatDate(item['dateFrom']);
    final dateTo = formatDate(item['dateTo']);
    final reason = item['reason']?.toString() ?? '';
    final isApproved =
        status.contains('DISETUJUI') || status.contains('APPROVE');
    final isRejected = status.contains('DITOLAK') || status.contains('REJECT');
    final statusColor = isApproved
        ? AppTheme.success
        : isRejected
            ? AppTheme.danger
            : AppTheme.warning;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isApproved
                    ? Icons.check_circle_rounded
                    : isRejected
                        ? Icons.cancel_rounded
                        : Icons.schedule_rounded,
                color: statusColor,
                size: 24,
              ),
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
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$dateFrom – $dateTo',
                    style: TextStyle(
                      color: AppTheme.mutedFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: TextStyle(
                        color: AppTheme.mutedLightFor(context),
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveData {
  const _LeaveData({required this.mine, required this.pending});

  final List<dynamic> mine;
  final List<dynamic> pending;
}
