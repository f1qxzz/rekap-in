import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/storage/token_store.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/widgets/private_photo_avatar.dart';
import '../auth/login_page.dart';
import '../settings/api_settings_page.dart';
import '../settings/offline_sync_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.apiClient,
    required this.tokenStore,
    required this.offlineQueue,
    required this.user,
    super.key,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;
  final OfflineQueue offlineQueue;
  final Map<String, dynamic> user;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Map<String, dynamic> _user;
  final String _appVersion =
      const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  
  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
  }


  Future<void> _logout(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surfaceFor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.dangerSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: AppTheme.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Keluar Akun?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sesi login di perangkat ini akan dihapus.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedFor(context),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
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
    if (confirmed != true || !context.mounted) return;

    await widget.apiClient.logout();
    if (!context.mounted) return;
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

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          apiClient: widget.apiClient,
          user: _user,
          onSaved: (data) {},
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final oldPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    String? validateNewPassword(String? value) {
      final text = value ?? '';
      if (text.length < 8) return 'Minimal 8 karakter';
      if (!RegExp(r'[A-Z]').hasMatch(text)) {
        return 'Password wajib punya huruf besar';
      }
      if (!RegExp(r'[0-9]').hasMatch(text)) {
        return 'Password wajib punya angka';
      }
      return null;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceFor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 32,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),
                Text(
                  'Ganti Password',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: oldPw,
                  obscureText: true,
                  autofocus: true,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: 'Password Lama',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) => (v ?? '').isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: newPw,
                  obscureText: true,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: 'Password Baru',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                  validator: validateNewPassword,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmPw,
                  obscureText: true,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                  validator: (v) =>
                      v != newPw.text ? 'Password tidak cocok' : null,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() => loading = true);
                          try {
                            await widget.apiClient.changePassword(
                              oldPassword: oldPw.text,
                              newPassword: newPw.text,
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          } catch (e) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ApiClient.errorMessage(e,
                                        fallback: 'Gagal mengganti password.'),
                                  ),
                                ),
                              );
                            }
                            setSheetState(() => loading = false);
                          }
                        },
                  child: Text(loading ? 'Menyimpan...' : 'Simpan Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    oldPw.dispose();
    newPw.dispose();
    confirmPw.dispose();
    if (saved == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diganti.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user['name'] as String? ?? 'Karyawan';
    final role = _user['role'] as String? ?? 'Karyawan';
    final email = _user['email'] as String? ?? '-';
    final nip = _user['nip'] as String? ?? '-';
    final phone = (_user['phone'] as String?)?.trim().isNotEmpty == true
        ? _user['phone'] as String
        : 'Belum diisi';
    final photoUrl = _user['photoUrl'] as String?;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'K';
    final isActive = _user['isActive'] != false;
    final department = _nameOf(_user['department']);
    final shift = _nameOf(_user['shift']);

    return Scaffold(
      backgroundColor: AppTheme.canvasFor(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _ProfileHeader(
            apiClient: widget.apiClient,
            name: name,
            role: role,
            initials: initials,
            isActive: isActive,
            photoUrl: photoUrl,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuickStatsRow(
                    isActive: isActive,
                    nip: nip,
                    email: email,
                  ),
                  const SizedBox(height: 14),
                  _ProfileCompletionCard(
                    user: _user,
                    onEdit: _openEditProfile,
                  ),
                  const SizedBox(height: 14),
                  _RoleAccessCard(role: role),
                  const SizedBox(height: 24),
                  const _SectionLabel(label: 'Informasi Pribadi'),
                  const SizedBox(height: 12),
                  _InfoCard(
                    items: [
                      _InfoItem(
                        icon: Icons.mail_rounded,
                        label: 'Email',
                        value: email,
                        color: AppTheme.info,
                      ),
                      _InfoItem(
                        icon: Icons.badge_rounded,
                        label: 'NIP',
                        value: nip,
                        color: AppTheme.primary,
                      ),
                      _InfoItem(
                        icon: Icons.phone_rounded,
                        label: 'No. HP',
                        value: phone,
                        color: AppTheme.success,
                      ),
                      _InfoItem(
                        icon: Icons.apartment_rounded,
                        label: 'Department',
                        value: department,
                        color: AppTheme.warning,
                      ),
                      _InfoItem(
                        icon: Icons.schedule_rounded,
                        label: 'Shift Kerja',
                        value: shift,
                        color: AppTheme.mutedFor(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _SectionLabel(label: 'Pengaturan'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    apiClient: widget.apiClient,
                    tokenStore: widget.tokenStore,
                    offlineQueue: widget.offlineQueue,
                    onLogout: () => _logout(context),
                    onEditProfile: _openEditProfile,
                    onChangePassword: () => _showChangePassword(context),
                    appVersion: _appVersion,
                    
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Profile Header ───────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.apiClient,
    required this.name,
    required this.role,
    required this.initials,
    required this.isActive,
    this.photoUrl,
  });

  final ApiClient apiClient;
  final String name;
  final String role;
  final String initials;
  final bool isActive;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppTheme.surfaceFor(context),
      foregroundColor: AppTheme.inkFor(context),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration:
                  BoxDecoration(gradient: AppTheme.heroGradientFor(context)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.12),
                      Colors.transparent,
                      AppTheme.info.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.5),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.inkLight,
                              ),
                              child: ClipOval(
                                child: PrivatePhotoAvatar(
                                  apiClient: apiClient,
                                  initials: initials,
                                  photoUrl: photoUrl,
                                  size: 102,
                                  textStyle: TextStyle(
                                    color: AppTheme.inkLight,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 42,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? AppTheme.success
                                    : AppTheme.danger,
                                border: Border.all(
                                  color: AppTheme.inkFor(context),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isActive
                                            ? AppTheme.success
                                            : AppTheme.danger)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isActive ? Icons.check : Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        style: TextStyle(
                          color: AppTheme.inkFor(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.buttonSurfaceFor(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppTheme.buttonBorderFor(context)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          role.replaceAll('_', ' '),
                          style: TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Quick Stats Row ───────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.isActive,
    required this.nip,
    required this.email,
  });

  final bool isActive;
  final String nip;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: isActive ? Icons.verified_user_rounded : Icons.block_rounded,
            label: 'Status',
            value: isActive ? 'Aktif' : 'Nonaktif',
            color: isActive ? AppTheme.success : AppTheme.danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.badge_rounded,
            label: 'NIP',
            value: nip,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.alternate_email_rounded,
            label: 'Username',
            value: email.contains('@') ? email.split('@').first : email,
            color: AppTheme.info,
          ),
        ),
      ],
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.user, required this.onEdit});

  final Map<String, dynamic> user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final checks = [
      _hasText(user['name']),
      _hasText(user['email']),
      _hasText(user['nip']),
      _hasText(user['phone']),
      user['department'] is Map,
      user['shift'] is Map,
      _hasText(user['photoUrl']),
    ];
    final complete = checks.where((ok) => ok).length;
    final percent = (complete / checks.length).clamp(0.0, 1.0);
    final color = percent >= 0.85
        ? AppTheme.success
        : percent >= 0.55
            ? AppTheme.warning
            : AppTheme.info;

    return PremiumInsightCard(
      icon: Icons.person_pin_rounded,
      title: 'Kelengkapan profil ${(percent * 100).round()}%',
      description:
          'Lengkapi nomor HP, foto, department, dan shift agar approval dan absensi lebih mudah dicek.',
      accentColor: color,
      trailing: TextButton(
        onPressed: onEdit,
        child: const Text('Edit'),
      ),
    );
  }

  bool _hasText(Object? value) => (value?.toString().trim() ?? '').isNotEmpty;
}

class _RoleAccessCard extends StatelessWidget {
  const _RoleAccessCard({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final normalized = role.toUpperCase();
    final title = normalized.replaceAll('_', ' ');
    final access = switch (normalized) {
      'SUPER_ADMIN' => [
          'Kelola user dan approval akun',
          'Pantau audit log, shift, lokasi, dan report',
          'Akses menu HR dan operasional penuh',
        ],
      'HR' => [
          'Approval akun dan cuti level HR',
          'Kelola shift, lokasi, department, dan hari libur',
          'Pantau anomali, audit log, payroll, dan export report',
        ],
      'MANAJER' => [
          'Approval cuti tim',
          'Pantau laporan dan absensi anggota tim',
          'Review data operasional sesuai area kerja',
        ],
      _ => [
          'Absensi masuk dan pulang',
          'Ajukan izin atau cuti',
          'Lihat riwayat, notifikasi, dan profil sendiri',
        ],
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
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
                      'Akses $title',
                      style: TextStyle(
                        color: AppTheme.inkFor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Menu aktif mengikuti role server.',
                      style: TextStyle(
                        color: AppTheme.mutedFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in access) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppTheme.primaryDark,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: AppTheme.inkFor(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (item != access.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.mutedFor(context),
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Section Label ───────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
    );
  }
}

// ─────────────────── Info Card ───────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.items});

  final List<_InfoItem> items;

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
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _InfoTile(item: items[i]),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: AppTheme.lineFor(context).withValues(alpha: 0.3),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0,
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

// ─────────────────── Settings Card ───────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.apiClient,
    required this.tokenStore,
    required this.offlineQueue,
    required this.onLogout,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.appVersion,
      });

  final ApiClient apiClient;
  final TokenStore tokenStore;
  final OfflineQueue offlineQueue;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final String appVersion;
  
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
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.edit_rounded,
            iconColor: AppTheme.primary,
            iconBg: AppTheme.primarySurface,
            title: 'Edit Profil',
            subtitle: 'Ubah nama, nomor HP, dan foto profil',
            onTap: onEditProfile,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: AppTheme.lineFor(context).withValues(alpha: 0.3),
            ),
          ),
          _SettingsTile(
            icon: Icons.lock_rounded,
            iconColor: AppTheme.warning,
            iconBg: AppTheme.warningSurface,
            title: 'Ganti Password',
            subtitle: 'Ubah password akun kamu',
            onTap: onChangePassword,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: AppTheme.lineFor(context).withValues(alpha: 0.3),
            ),
          ),
          _SettingsTile(
            icon: Icons.dns_rounded,
            iconColor: AppTheme.info,
            iconBg: AppTheme.infoSurface,
            title: 'Pengaturan API Server',
            subtitle: apiClient.dio.options.baseUrl,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ApiSettingsPage(
                  apiClient: apiClient,
                  tokenStore: tokenStore,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: AppTheme.lineFor(context).withValues(alpha: 0.3),
            ),
          ),
          _SettingsTile(
            icon: Icons.cloud_sync_rounded,
            iconColor: AppTheme.primary,
            iconBg: AppTheme.primarySurface,
            title: 'Log Sinkronisasi Offline',
            subtitle: 'Pantau antrean absensi yang belum terkirim',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OfflineSyncPage(
                  apiClient: apiClient,
                  offlineQueue: offlineQueue,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: AppTheme.lineFor(context).withValues(alpha: 0.3),
            ),
          ),

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.mutedFor(context),
            iconBg: AppTheme.lineLight,
            title: 'Tentang Aplikasi',
            subtitle: '${AppTheme.brandName} v$appVersion',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppTheme.brandName,
                applicationVersion: appVersion,
                applicationIcon: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.fact_check_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                children: const [
                  Text(
                    'Aplikasi presensi karyawan dengan GPS, selfie, dan offline queue.',
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: AppTheme.lineFor(context).withValues(alpha: 0.3),
            ),
          ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconColor: AppTheme.danger,
            iconBg: AppTheme.dangerSurface,
            title: 'Keluar Akun',
            subtitle: 'Sesi login akan dihapus',
            titleColor: AppTheme.danger,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }

}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 22),
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
                      color: titleColor ?? AppTheme.inkFor(context),
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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

String _nameOf(Object? value) {
  if (value is Map && value['name'] != null) return value['name'].toString();
  return 'Belum diatur';
}
