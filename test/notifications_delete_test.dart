import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/presentation/notifications_page.dart';

import 'v2_screens_test.dart' show FakeRepo, app, phoneSize;

/// Bildirim listesini bellekte tutan depo: silmeler akışa yansır.
class _NotesRepo extends FakeRepo {
  _NotesRepo(this.notes);

  List<AppNotification> notes;
  final _changes = StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> watch() async* {
    yield notes;
    yield* _changes.stream;
  }

  @override
  Future<void> deleteNotification(String uid, String notificationId) async {
    await super.deleteNotification(uid, notificationId);
    notes = [
      for (final n in notes)
        if (n.id != notificationId) n,
    ];
    _changes.add(notes);
  }

  @override
  Future<void> deleteAllNotifications(String uid) async {
    await super.deleteAllNotifications(uid);
    notes = const [];
    _changes.add(notes);
  }
}

AppNotification note(String id, String message, {bool isRead = false}) =>
    AppNotification(
      id: id,
      type: 'entryRecorded',
      title: '',
      message: message,
      ledgerId: 'p_ayse',
      entryId: null,
      isRead: isRead,
      createdAt: DateTime(2026, 9, 24, 10),
    );

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  Future<_NotesRepo> open(
    WidgetTester tester,
    List<AppNotification> notes,
  ) async {
    phoneSize(tester);
    final repo = _NotesRepo(notes);
    await tester.pumpWidget(
      app(const NotificationsPage(), repo, notificationsStream: repo.watch()),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> swipe(WidgetTester tester, String text) async {
    await tester.drag(find.text(text), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  /// Geri alma süresi (4 sn) dolsun, çubuk kapansın.
  Future<void> waitSnack(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('kaydırılan bildirim gizlenir, geri alınırsa silinmez', (
    tester,
  ) async {
    final repo = await open(tester, [
      note('n1', 'Ayşe kaydı onayladı'),
      note('n2', 'Can hatırlattı', isRead: true),
    ]);
    expect(find.text('Tümünü okundu say'), findsOneWidget);

    await swipe(tester, 'Ayşe kaydı onayladı');
    expect(find.text('Ayşe kaydı onayladı'), findsNothing);
    expect(find.text('Bildirim silindi.'), findsOneWidget);
    // Okunmamış tek bildirim gizlendi: okundu sayma düğmesi de kalkar.
    expect(find.text('Tümünü okundu say'), findsNothing);
    expect(repo.calls, isEmpty);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(find.text('Ayşe kaydı onayladı'), findsOneWidget);
    expect(find.text('Tümünü okundu say'), findsOneWidget);
    await waitSnack(tester);
    expect(repo.calls, isEmpty);
    expect(repo.notes.length, 2);
  });

  testWidgets('geri alınmayan silme süre dolunca yapılır; liste boşalır', (
    tester,
  ) async {
    final repo = await open(tester, [note('n1', 'Ayşe kaydı onayladı')]);

    await swipe(tester, 'Ayşe kaydı onayladı');
    // Satır hemen gider; sunucuya silme henüz gitmedi.
    expect(find.text('Bildirim yok'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await waitSnack(tester);
    expect(repo.calls, ['deleteNotification n1']);
    expect(find.text('Bildirim yok'), findsOneWidget);
    expect(find.byTooltip('Tümünü sil'), findsNothing);
  });

  testWidgets('ikinci kaydırma öncekinin silmesini hemen yapar', (
    tester,
  ) async {
    final repo = await open(tester, [
      note('n1', 'Ayşe kaydı onayladı'),
      note('n2', 'Can hatırlattı'),
    ]);
    await swipe(tester, 'Ayşe kaydı onayladı');
    await swipe(tester, 'Can hatırlattı');
    expect(repo.calls, ['deleteNotification n1']);
    await waitSnack(tester);
    expect(repo.calls, ['deleteNotification n1', 'deleteNotification n2']);
    expect(find.text('Bildirim yok'), findsOneWidget);
  });

  testWidgets('tümünü silme onay ister; vazgeçilirse silinmez', (tester) async {
    final repo = await open(tester, [
      note('n1', 'Ayşe kaydı onayladı'),
      note('n2', 'Can hatırlattı', isRead: true),
    ]);

    await tester.tap(find.byTooltip('Tümünü sil'));
    await tester.pumpAndSettle();
    expect(find.text('Tüm bildirimler silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.text('Can hatırlattı'), findsOneWidget);

    await tester.tap(find.byTooltip('Tümünü sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['deleteAllNotifications']);
    expect(find.text('Bildirim yok'), findsOneWidget);
    expect(find.text('Can hatırlattı'), findsNothing);
    expect(find.byTooltip('Tümünü sil'), findsNothing);
    expect(find.text('Tümünü okundu say'), findsNothing);
  });
}
