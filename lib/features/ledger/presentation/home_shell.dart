import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../profile/profile_page.dart';
import '../application/providers.dart';
import 'entry_composer_page.dart';
import 'home_page.dart';
import 'inbox_page.dart';
import 'people_page.dart';

/// Giriş sonrası ana kabuk: dört sekme ve ortada "Kayıt ekle".
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  void _addEntry() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const EntryComposerPage()),
  );

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(inboxProvider).valueOrNull?.length ?? 0;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            onSeeAllPeople: () => _go(1),
            onOpenInbox: () => _go(2),
            onAddEntry: _addEntry,
          ),
          const PeoplePage(),
          const InboxPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _NavBar(
        index: _index,
        pending: pending,
        onTap: _go,
        onAdd: _addEntry,
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.pending,
    required this.onTap,
    required this.onAdd,
  });

  final int index;
  final int pending;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final scheme = Theme.of(context).colorScheme;

    Widget item(int i, IconData icon, String label, {int badge = 0}) {
      final active = index == i;
      final color = active ? c.credit : c.muted;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(i),
          child: Semantics(
            selected: active,
            button: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  backgroundColor: c.pendingDot,
                  label: Text('$badge'),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              item(0, Icons.home_rounded, 'Ana sayfa'),
              item(1, Icons.people_alt_rounded, 'Kişiler'),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Semantics(
                      label: 'Kayıt ekle',
                      button: true,
                      child: Material(
                        color: PactaTheme.brandFill,
                        shape: CircleBorder(
                          side: BorderSide(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 4,
                          ),
                        ),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAdd,
                          child: const SizedBox(
                            width: 58,
                            height: 58,
                            child: Icon(Icons.add_rounded, color: PactaTheme.onBrandFill, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(2, Icons.inbox_rounded, 'Gelen kutusu', badge: pending),
              item(3, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}
