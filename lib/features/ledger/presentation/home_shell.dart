import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/dates/local_date.dart';
import '../../../services/notification_routes.dart';
import '../../profile/profile_page.dart';
import '../application/providers.dart';
import 'activity_page.dart';
import 'common.dart';
import 'contacts_ui.dart';
import 'entry_composer_page.dart';
import 'home_page.dart';
import 'people_page.dart';

/// Giriş sonrası ana kabuk: dört sekme ve ortada "Kayıt ekle".
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;
  StreamSubscription<String>? _routes;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    // Bildirime dokunulunca ilgili kayıt ya da defter açılır.
    _routes = NotificationRoutes.stream.listen(_openRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationRoutes.takePending();
      if (pending != null) _openRoute(pending);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _routes?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  void _refreshToday() {
    final today = LocalDate.today();
    final current = ref.read(todayProvider.notifier);
    if (current.state != today) current.state = today;
  }

  /// Uygulama gece yarısını açık geçirirse gün değişir.
  void _scheduleMidnight() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      if (!mounted) return;
      _refreshToday();
      _scheduleMidnight();
    });
  }

  void _openRoute(String route) {
    if (!mounted) return;
    if (route.startsWith('/u/')) {
      // Davet linki: kişiyi göster, onaylanırsa ortak defter aç.
      confirmAddByCode(context, ref, route);
    } else {
      openRoute(context, route);
    }
  }

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
            onOpenActivity: () => _go(2),
            onAddEntry: _addEntry,
          ),
          const PeoplePage(),
          const ActivityPage(),
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
              item(2, Icons.event_note_rounded, 'Hareketler', badge: pending),
              item(3, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}
