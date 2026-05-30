import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/storage/token_store.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/widgets/rekapin_logo.dart';
import '../dashboard/dashboard_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.apiClient,
    required this.tokenStore,
    required this.offlineQueue,
    super.key,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;
  final OfflineQueue offlineQueue;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  final _steps = const [
    _OnboardingStep(
      icon: Icons.fact_check_rounded,
      title: 'Selamat Datang',
      body:
          'Rekap In membantu absensi masuk, pulang, izin, dan cuti dari satu aplikasi.',
      color: AppTheme.primary,
    ),
    _OnboardingStep(
      icon: Icons.photo_camera_rounded,
      title: 'Selfie Bukti',
      body:
          'Kamera dipakai untuk foto kehadiran dengan watermark waktu dan lokasi.',
      color: AppTheme.info,
    ),
    _OnboardingStep(
      icon: Icons.my_location_rounded,
      title: 'Lokasi Presisi',
      body:
          'GPS membantu sistem memastikan absensi dilakukan dari radius yang benar.',
      color: AppTheme.success,
    ),
    _OnboardingStep(
      icon: Icons.verified_user_rounded,
      title: 'Validasi Aman',
      body:
          'Sistem mengecek izin, lokasi, wajah, dan antrean offline sebelum menyimpan data.',
      color: AppTheme.warning,
    ),
    _OnboardingStep(
      icon: Icons.dashboard_rounded,
      title: 'Dashboard Rapi',
      body: 'Pantau status hari ini, rekap minggu ini, dan sinkronisasi data.',
      color: AppTheme.primary,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_finishing || !mounted) return;
    if (_index < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _finishing = true);
    try {
      await widget.tokenStore.markOnboardingSeen();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => DashboardPage(
            apiClient: widget.apiClient,
            tokenStore: widget.tokenStore,
            offlineQueue: widget.offlineQueue,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_index];
    return Scaffold(
      body: AmbientScaffoldBackground(
        primaryGlow: currentStep.color,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const RekapInLogo(size: 42, showText: false),
                    const SizedBox(width: 12),
                    Text(
                      AppTheme.brandName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                if (_index < _steps.length - 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _finishing ? null : _next,
                      child: const Text('Lewati'),
                    ),
                  ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _steps.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  step.color.withValues(alpha: 0.25),
                                  step.color.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: step.color.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: step.color.withValues(alpha: 0.2),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              step.icon,
                              size: 50,
                              color: step.color,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            step.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              step.body,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: AppTheme.mutedFor(context),
                                    height: 1.6,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: i == _index ? 32 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient:
                              i == _index ? AppTheme.primaryGradient : null,
                          color: i == _index ? null : AppTheme.glassBorder,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    onPressed: _finishing ? null : _next,
                    icon: _finishing
                        ? Icons.hourglass_top_rounded
                        : (_index == _steps.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded),
                    label: _finishing
                        ? 'Menyiapkan...'
                        : (_index == _steps.length - 1 ? 'Mulai' : 'Lanjut'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
}
