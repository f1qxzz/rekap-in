import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/private_photo_avatar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    required this.apiClient,
    required this.user,
    required this.onSaved,
    super.key,
  });

  final ApiClient apiClient;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _photoUrl;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user['name'] as String? ?? '');
    _phone = TextEditingController(text: widget.user['phone'] as String? ?? '');
    _photoUrl = widget.user['photoUrl'] as String?;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_loading || !mounted) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Foto',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukuran foto maksimal 5 MB.')),
      );
      return;
    }
    setState(() {
      _photoBytes = bytes;
      _photoName = file.name;
    });
  }

  Future<void> _save() async {
    if (_loading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      String? uploadedUrl = _photoUrl;

      if (_photoBytes != null) {
        uploadedUrl = await widget.apiClient.uploadDocument(
          fileName: _photoName ?? 'profile.jpg',
          mimeType: mimeTypeFromFileName(_photoName),
          bytes: _photoBytes!,
        );
      }

      final updated = await widget.apiClient.updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        photoUrl: uploadedUrl,
      );

      if (!mounted) return;
      widget.onSaved(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.errorMessage(
              error,
              fallback: 'Gagal menyimpan profil.',
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
    final name = widget.user['name'] as String? ?? 'K';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'K';

    return Scaffold(
      backgroundColor: AppTheme.canvasFor(context),
      appBar: AppBar(
        title: const Text('Edit Profil'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: _PhotoAvatar(
                apiClient: widget.apiClient,
                initials: initials,
                photoBytes: _photoBytes,
                photoUrl: _photoUrl,
                onPick: _pickPhoto,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickPhoto,
                icon: Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Ganti Foto'),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceFor(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.lineFor(context).withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Dasar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) => (value ?? '').trim().length < 2
                          ? 'Nama minimal 2 karakter'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor HP',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: 'Contoh: 081234567890',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.infoSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.info.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.info,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Email dan NIP tidak dapat diubah dari aplikasi. Hubungi HR untuk perubahan.',
                      style: TextStyle(
                        color: AppTheme.info,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryDark,
                      ),
                    )
                  : Icon(Icons.save_rounded),
              label: Text(_loading ? 'Menyimpan...' : 'Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({
    required this.apiClient,
    required this.initials,
    required this.photoBytes,
    required this.photoUrl,
    required this.onPick,
  });

  final ApiClient apiClient;
  final String initials;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: photoBytes == null && photoUrl == null
                  ? AppTheme.primaryGradient
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: PrivatePhotoAvatar(
              apiClient: apiClient,
              initials: initials,
              photoUrl: photoUrl,
              memoryBytes: photoBytes,
              size: 110,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
