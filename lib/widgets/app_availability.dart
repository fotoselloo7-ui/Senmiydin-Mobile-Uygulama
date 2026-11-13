import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import 'common.dart';

class AppAvailability extends StatefulWidget {
  const AppAvailability({super.key, required this.store, required this.child});
  final AppStore store;
  final Widget child;
  @override
  State<AppAvailability> createState() => _AppAvailabilityState();
}

class _AppAvailabilityState extends State<AppAvailability> {
  String? dismissed;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final update = store.versionPolicy;
      final maintenance = store.authenticated ? store.maintenanceNotice : null;
      final suggest =
          update != null && (update.required || dismissed != update.latest);
      final blocked = maintenance != null || suggest;
      return Stack(
        fit: StackFit.expand,
        children: [
          FocusScope(
            canRequestFocus: !blocked,
            child: Offstage(offstage: blocked, child: widget.child),
          ),
          if (blocked)
            Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Brand(),
                    const SizedBox(height: 48),
                    EmptyState(
                      maintenance != null
                          ? 'Kısa bir ara'
                          : update!.required
                          ? 'Güncelleme gerekli'
                          : 'Yeni sürüm hazır',
                      maintenance ?? 'SenMiydin? uygulamasını mağazadan güncelleyebilirsin.',
                      icon: maintenance != null
                          ? Icons.build_outlined
                          : Icons.system_update,
                    ),
                    if (maintenance == null) ...[
                      PrimaryButton(
                        'Mağazada Aç',
                        onPressed: () async {
                          if (!await launchUrl(
                                update!.url,
                                mode: LaunchMode.externalApplication,
                              ) &&
                              context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Mağaza açılamadı. Daha sonra tekrar dene.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      if (!update!.required)
                        SecondaryButton(
                          'Daha Sonra',
                          onPressed: () =>
                              setState(() => dismissed = update.latest),
                        ),
                    ],
                    if (maintenance != null)
                      PrimaryButton(
                        'Tekrar Dene',
                        onPressed: store.refreshHomeConfig,
                      ),
                    if (store.authenticated)
                      SecondaryButton(
                        'Çıkış Yap',
                        onPressed: () async {
                          try {
                            await store.signOut();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Çıkış yapılamadı. Tekrar dene.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
