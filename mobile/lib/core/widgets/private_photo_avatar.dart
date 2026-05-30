import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../api/api_client.dart';

class PrivatePhotoAvatar extends StatefulWidget {
  const PrivatePhotoAvatar({
    required this.apiClient,
    required this.initials,
    required this.size,
    this.photoUrl,
    this.memoryBytes,
    this.borderRadius,
    this.shape = BoxShape.circle,
    this.textStyle,
    super.key,
  });

  final ApiClient apiClient;
  final String initials;
  final double size;
  final String? photoUrl;
  final Uint8List? memoryBytes;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final TextStyle? textStyle;

  @override
  State<PrivatePhotoAvatar> createState() => _PrivatePhotoAvatarState();
}

class _PrivatePhotoAvatarState extends State<PrivatePhotoAvatar> {
  Future<Uint8List?>? _photoFuture;
  String? _lastPhotoUrl;

  @override
  void initState() {
    super.initState();
    _syncFuture();
  }

  @override
  void didUpdateWidget(covariant PrivatePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.memoryBytes != widget.memoryBytes) {
      _syncFuture();
    }
  }

  void _syncFuture() {
    final url = widget.photoUrl;
    if (url == null || url.isEmpty) {
      _photoFuture = null;
      _lastPhotoUrl = null;
      return;
    }
    if (url == _lastPhotoUrl && _photoFuture != null) return;
    _lastPhotoUrl = url;
    _photoFuture = widget.apiClient.attendancePhotoBytes(url);
  }

  @override
  Widget build(BuildContext context) {
    final memoryBytes = widget.memoryBytes;
    if (memoryBytes != null) {
      return _clip(Image.memory(memoryBytes, fit: BoxFit.cover));
    }

    final future = _photoFuture;
    if (future == null) return _fallback();

    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return _fallback();
        return _clip(Image.memory(bytes, fit: BoxFit.cover));
      },
    );
  }

  Widget _clip(Widget child) {
    final sized = SizedBox(
      width: widget.size,
      height: widget.size,
      child: child,
    );

    if (widget.shape == BoxShape.circle) {
      return ClipOval(child: sized);
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
      child: sized,
    );
  }

  Widget _fallback() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.rectangle
            ? widget.borderRadius ?? BorderRadius.circular(16)
            : null,
        gradient: AppTheme.primaryGradient,
      ),
      child: Center(
        child: Text(
          widget.initials,
          style: widget.textStyle ??
              TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: widget.size * 0.36,
              ),
        ),
      ),
    );
  }
}
