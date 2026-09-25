import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'common.dart';

/// Size gelen bildirimlerin geçmişi (onaylar, itirazlar, hatırlatmalar).
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final uid = ref.watch(currentUidProvider);
    final notes = ref.watch(notificationsProvider);
    final repo = ref.read(ledgerRepositoryProvider);
    final time = DateFormat('d MMM HH:mm', 'tr_TR');
    final unread = [
      for (final n in notes.valueOrNull ?? const <AppNotification>[])
        if (!n.isRead) n,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: () {
                for (final n in unread) {
                  repo.markNotificationRead(uid, n.id);
                }
              },
              child: const Text('Tümünü okundu say'),
            ),
        ],
      ),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Bildirimler yüklenemedi.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Bildirim yok',
                message: 'Kayıtlarınızla ilgili bir gelişme olunca burada görünür.',
              )
            : ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                children: [
                  SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          InkWell(
                            onTap: () {
                              final n = list[i];
                              if (!n.isRead) repo.markNotificationRead(uid, n.id);
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
                                border: i < list.length - 1
                                    ? Border(bottom: BorderSide(color: c.line))
                                    : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 7, right: 10),
                                    decoration: BoxDecoration(
                                      color: list[i].isRead
                                          ? Colors.transparent
                                          : c.pendingDot,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (list[i].title.isNotEmpty)
                                          Text(
                                            list[i].title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        Text(list[i].message),
                                        if (list[i].createdAt != null)
                                          Text(
                                            time.format(list[i].createdAt!),
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
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
