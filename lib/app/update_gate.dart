import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

// Zorunlu güncelleme: sunucu eski uygulamanın çalışamayacağı biçimde
// değiştiğinde config/app.minBuild yükseltilir; daha eski derlemeler
// güncelleme ekranında kalır. Belge yoksa, okunamazsa ya da değer sayı
// değilse uygulama engellenmez.

/// Desteklenen en düşük derleme numarası; bilinmiyorsa null.
final minBuildProvider = StreamProvider<int?>(
  (ref) => FirebaseFirestore.instance
      .collection('config')
      .doc('app')
      .snapshots()
      .map((s) {
        final value = s.data()?['minBuild'];
        return value is num ? value.toInt() : null;
      }),
);

/// Mağaza sayfası (Android). Uygulama yayınlanınca çalışır.
final Uri storeUri = Uri.parse(
  'https://play.google.com/store/apps/details'
  '?id=${AppConstants.androidPackageName}',
);

class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minBuild = ref.watch(minBuildProvider).valueOrNull;
    if (minBuild != null && minBuild > AppConstants.buildNumber) {
      return const UpdateRequiredScreen();
    }
    return child;
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openStore(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Mağaza açılamadı. Pacta'yı mağazadan güncelleyin."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Güncelleme gerekli',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Pacta'nın bu sürümü artık desteklenmiyor. Kayıtlarınız "
                  'güvende; devam etmek için uygulamayı güncelleyin.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 48),
                  ),
                  onPressed: () => _openStore(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Güncelle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
