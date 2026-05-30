import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/token_store.dart';

class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({
    required this.apiClient,
    required this.tokenStore,
    super.key,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool? _serverOnline;
  String? _serverMessage;
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await widget.tokenStore.apiBaseUrl();
    _controller.text = stored ?? widget.apiClient.dio.options.baseUrl;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !mounted) return;
    final value = _controller.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (!_isValidEndpoint(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL API belum valid.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.tokenStore.saveApiBaseUrl(value);
      widget.apiClient.setBaseUrl(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API server disimpan.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_testing || !mounted) return;
    final value = _controller.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (!_isValidEndpoint(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL API belum valid.')),
      );
      return;
    }

    final previous = widget.apiClient.dio.options.baseUrl;
    setState(() {
      _testing = true;
      _serverMessage = null;
    });

    try {
      widget.apiClient.setBaseUrl(value);
      final response = await widget.apiClient.health();
      if (!mounted) return;
      setState(() {
        _serverOnline = response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300;
        _serverMessage = _serverOnline == true
            ? 'Server merespons normal.'
            : 'Server merespons dengan status ${response.statusCode}.';
        _checkedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverOnline = false;
        _serverMessage = ApiClient.errorMessage(
          error,
          fallback: 'Tidak bisa tersambung ke server.',
        );
        _checkedAt = DateTime.now();
      });
    } finally {
      widget.apiClient.setBaseUrl(previous);
      if (mounted) setState(() => _testing = false);
    }
  }

  void _reset() {
    _controller.text = ApiClient.defaultBaseUrl;
  }

  bool _isValidEndpoint(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Server')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceFor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.lineFor(context).withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.dns_outlined,
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
                                'API Server',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Konfigurasi endpoint backend',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppTheme.mutedFor(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _reset,
                            icon: Icon(Icons.restore_rounded, size: 18),
                            label: const Text('Default'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryDark,
                                    ),
                                  )
                                : Icon(Icons.save_rounded, size: 18),
                            label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ServerStatusCard(
                online: _serverOnline,
                message: _serverMessage,
                checkedAt: _checkedAt,
                testing: _testing,
                endpoint: _controller.text,
                onTest: _testConnection,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServerStatusCard extends StatelessWidget {
  const _ServerStatusCard({
    required this.online,
    required this.message,
    required this.checkedAt,
    required this.testing,
    required this.endpoint,
    required this.onTest,
  });

  final bool? online;
  final String? message;
  final DateTime? checkedAt;
  final bool testing;
  final String endpoint;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final statusColor = online == null
        ? AppTheme.muted
        : online == true
            ? AppTheme.success
            : AppTheme.danger;
    final statusText = online == null
        ? 'Belum dicek'
        : online == true
            ? 'Online'
            : 'Offline';
    final mode =
        const bool.fromEnvironment('dart.vm.product') ? 'Release' : 'Debug';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.lineFor(context).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  online == true
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Server',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$statusText - Mode $mode',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            endpoint.trim().isEmpty ? '-' : endpoint.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.mutedFor(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: TextStyle(
                color: AppTheme.inkFor(context),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          if (checkedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Dicek ${checkedAt!.hour.toString().padLeft(2, '0')}:${checkedAt!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: AppTheme.mutedFor(context), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: testing ? null : onTest,
            icon: testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.wifi_tethering_rounded, size: 18),
            label: Text(testing ? 'Mengecek...' : 'Tes Koneksi'),
          ),
        ],
      ),
    );
  }
}
