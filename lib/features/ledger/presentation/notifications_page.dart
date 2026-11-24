import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/report.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'common.dart';

/// Size gelen bildirimlerin geçmişi (onaylar, itirazlar, hatırlatmalar).
/// Satır kaydırılınca silinir (kısa süre geri alınabilir); tümü onayla
/// silinir. Sunucu 90 günden eski bildirimleri kendisi siler.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  /// Kaydırılıp gizlenen, silinmesi geri alma süresi bitince yapılacaklar.
  final _removed = <String>{};

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final uid = ref.watch(currentUidProvider);
    final notes = ref.watch(notificationsProvider);
    final repo = ref.read(ledgerRepositoryProvider);
    final thisYear = DateFormat('d MMM HH:mm', 'tr_TR');
    final otherYear = DateFormat('d MMM y HH:mm', 'tr_TR');
    String time(DateTime at) =>
        (at.year == DateTime.now().year ? thisYear : otherYear).format(at);
    final visible = [
      for (final n in notes.valueOrNull ?? const <AppNotification>[])
        if (!_removed.contains(n.id)) n,
    ];
    final unread = [
      for (final n in visible)
        if (!n.isRead) n,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              // Tek toplu yazım; ekranda görünmeyen eski bildirimler de.
              onPressed: () => repo.markAllNotificationsRead(uid).catchError((
                Object e,
                StackTrace st,
              ) {
                reportError(e, st, reason: 'Bildirimler işaretlenemedi');
                if (context.mounted) {
                  showSnack(
                    context,
                    'İşaretlenemedi. Tekrar deneyin.',
                    error: true,
                  );
                }
              }),
              child: const Text('Tümünü okundu say'),
            ),
          if (visible.isNotEmpty)
            IconButton(
              tooltip: 'Tümünü sil',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _deleteAll(uid),
            ),
        ],
      ),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Bildirimler yüklenemedi.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (_) => visible.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Bildirim yok',
                message:
                    'Kayıtlarınızla ilgili bir gelişme olunca burada görünür.',
              )
            : ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                children: [
                  SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < visible.length; i++)
                          Dismissible(
                            key: ValueKey(visible[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: c.debtSoft,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: c.debt,
                              ),
                            ),
                            onDismissed: (_) => _remove(uid, visible[i]),
                            child: InkWell(
                              onTap: () {
                                final n = visible[i];
                                if (!n.isRead) {
                                  repo.markNotificationRead(uid, n.id);
                                }
                                if (n.ledgerId == null) return;
                                if (n.entryId != null) {
                                  openEntry(context, n.ledgerId!, n.entryId!);
                                } else {
                                  openLedger(context, n.ledgerId!);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: i < visible.length - 1
                                      ? Border(
                                          bottom: BorderSide(color: c.line),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(
                                        top: 7,
                                        right: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: visible[i].isRead
                                            ? Colors.transparent
                                            : c.pendingDot,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (visible[i].title.isNotEmpty)
                                            Text(
                                              visible[i].title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          Text(visible[i].message),
                                          if (visible[i].createdAt != null)
                                            Text(
                                              time(visible[i].createdAt!),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: c.muted,
                                              ),
                                            ),
                                        ],
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
                ],
              ),
      ),
    );
  }

  /// Satır hemen gizlenir; asıl silme "Geri al" süresi bitince yapılır.
  /// Kural sahibine bildirim oluşturma izni vermez; silinen bildirim geri
  /// yazılamayacağı için geri alma silmeden önce olmalıdır. Sayfa bu sırada
  /// kapansa da silme yapılır (çubuk uygulama düzeyinde kalır).
  void _remove(String uid, AppNotification n) {
    final repo = ref.read(ledgerRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    setState(() => _removed.add(n.id));
    // Önceki çubuk kapanır; onun silmesi o an yapılır.
    messenger.hideCurrentSnackBar();
    final bar = messenger.showSnackBar(
      SnackBar(
        content: const Text('Bildirim silindi.'),
        duration: const Duration(seconds: 4),
        // Eylemli çubuk varsayılan olarak kendiliğinden kapanmaz.
        persist: false,
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () {
            if (mounted) setState(() => _removed.remove(n.id));
          },
        ),
      ),
    );
    bar.closed.then((reason) {
      if (reason == SnackBarClosedReason.action) return;
      repo.deleteNotification(uid, n.id).catchError((Object e, StackTrace st) {
        reportError(e, st, reason: 'Bildirim silinemedi');
        if (mounted) setState(() => _removed.remove(n.id));
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Bildirim silinemedi. Tekrar deneyin.'),
            backgroundColor: errorColor,
          ),
        );
      });
    });
  }

  Future<void> _deleteAll(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Tüm bildirimler silinsin mi?'),
        content: const Text(
          'Bildirimleriniz kalıcı olarak silinir. Kayıtlarınız ve '
          'defterleriniz etkilenmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            // Tema düğmeleri tam genişlik; diyalog eylemlerinde sınırlanır.
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 44),
              backgroundColor: dialog.pacta.debt,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(ledgerRepositoryProvider);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Beklenmez: silme yerel önbelleğe hemen düşer, sunucu onayı internetsiz
    // hiç gelmeyebilir. Hata olursa ayrıca söylenir.
    repo.deleteAllNotifications(uid).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'Bildirimler silinemedi');
      if (mounted) {
        showSnack(
          context,
          'Bildirimler silinemedi. Tekrar deneyin.',
          error: true,
        );
      }
    });
  }
}
