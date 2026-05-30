import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

Future<String?> showTextPromptSheet(
  BuildContext context, {
  required String title,
  bool isRequired = false,
  String initialValue = '',
  String submitLabel = 'Simpan',
}) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: AppTheme.surfaceFor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TextPromptSheet(
      title: title,
      isRequired: isRequired,
      initialValue: initialValue,
      submitLabel: submitLabel,
    ),
  );

  await Future<void>.delayed(const Duration(milliseconds: 220));
  return result;
}

class _TextPromptSheet extends StatefulWidget {
  const _TextPromptSheet({
    required this.title,
    required this.isRequired,
    required this.initialValue,
    required this.submitLabel,
  });

  final String title;
  final bool isRequired;
  final String initialValue;
  final String submitLabel;

  @override
  State<_TextPromptSheet> createState() => _TextPromptSheetState();
}

class _TextPromptSheetState extends State<_TextPromptSheet> {
  late final TextEditingController _controller;
  bool _closing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    if (_closing) return;
    setState(() => _closing = true);
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) Navigator.of(context).pop(value);
    });
  }

  void _submit() {
    final value = _controller.text.trim();
    if (widget.isRequired && value.length < 3) {
      setState(() => _error = 'Minimal 3 karakter.');
      return;
    }
    _close(value);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            const SizedBox(height: 28),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              enabled: !_closing,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: widget.isRequired ? 'Wajib diisi' : 'Opsional',
                errorText: _error,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _closing ? null : () => _close(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _closing ? null : _submit,
                    child: Text(widget.submitLabel),
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
