import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import 'common.dart';

/// Onayınızı bekleyenler üstte, son gelişmeler altta.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final inbox = ref.watch(inboxProvider);
    final notes = ref.watch(notificationsProvider).valueOrNull ?? const [];
    final uid = ref.watch(currentUidProvider);
    final time = DateFormat('d MMM HH:mm', 'tr_TR');

    return Scaffold(
      appBar: AppBar(title: const Text('Gelen kutusu')),
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Gelen kutusu yüklenemedi.',
          onRetry: () => ref.invalidate(inboxProvider),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.task_alt_rounded,
                title: 'Her şey yolunda',
                message:
                    'Onayınızı bekleyen kayıt yok. Yeni bir şey olunca haber '
                    'veririz.',
              )
            else ...[
              const SectionHeader(title: 'Onayınızı bekleyen'),
              for (final item in items) ...[
                InboxCard(item: item, actions: true),
                const SizedBox(height: 10),
              ],
            ],
            if (notes.isNotEmpty) ...[
              const SectionHeader(title: 'Son gelişmeler'),
              SurfaceCard(
                child: Column(
                  children: [
                    for (var i = 0; i < notes.length; i++)
                      InkWell(
                        onTap: () {
                          final n = notes[i];
                          if (!n.isRead) {
                            ref.read(ledgerRepositoryProvider).markNotificationRead(uid, n.id);
                          }
                          if (n.ledgerId != null && n.entryId != null) {
                            openEntry(context, n.ledgerId!, n.entryId!);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: i < notes.length - 1
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
                                  color: notes[i].isRead ? Colors.transparent : c.pendingDot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notes[i].message),
                                    if (notes[i].createdAt != null)
                                      Text(
                                        time.format(notes[i].createdAt!),
                                        style: TextStyle(fontSize: 12, color: c.muted),
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
          ],
        ),
      ),
    );
  }
}
