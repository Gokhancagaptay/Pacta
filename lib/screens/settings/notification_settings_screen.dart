import 'package:flutter/material.dart';
import 'package:pacta/core/report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/ui/widgets.dart';
import 'package:pacta/features/ledger/application/providers.dart';
import 'package:pacta/features/profile/profile_providers.dart';
import 'package:pacta/services/firestore_service.dart';

/// Push bildirimi tercihleri. Uygulama içi bildirim listesi her zaman
/// tutulur; bu anahtarlar yalnızca telefona gelen bildirimi kapatır.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _set(
    BuildContext context,
    String uid,
    String key,
    bool value,
  ) async {
    try {
      await FirestoreService().updateUser(uid, {
        'notificationSettings.$key': value,
      });
    } catch (e, st) {
      reportError(e, st, reason: 'Bildirim ayarı kaydedilemedi');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayar kaydedilemedi. Tekrar deneyin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Ayarlar yüklenemedi.',
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = user.notificationSettings;
          Widget toggle(String key, String title, String subtitle, bool on) =>
              SwitchListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                value: on,
                onChanged: (v) => _set(context, uid, key, v),
              );
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Kapattıklarınız telefonunuza bildirim olarak gelmez; '
                  'uygulamadaki bildirim listesinde yine görünür.',
                  style: TextStyle(color: context.pacta.muted),
                ),
              ),
              SurfaceCard(
                child: Column(
                  children: [
                    toggle(
                      'newDebtRequests',
                      'Onay istekleri',
                      'Biri sizin onayınızı bekleyen bir kayıt girdiğinde.',
                      s.newDebtRequests,
                    ),
                    const Divider(indent: 16),
                    toggle(
                      'statusChanges',
                      'Kayıt güncellemeleri',
                      'Kaydınız onaylandığında, itiraz edildiğinde ya da '
                          'reddedildiğinde.',
                      s.statusChanges,
                    ),
                    const Divider(indent: 16),
                    toggle(
                      'reminders',
                      'Hatırlatmalar',
                      'Vade günleri ve kişilerin gönderdiği hatırlatmalar. '
                          'Tek bir kişiyi defter sayfasından sessize '
                          'alabilirsiniz.',
                      s.reminders,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
