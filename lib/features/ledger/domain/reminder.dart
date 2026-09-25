import '../../../core/dates/local_date.dart';
import 'models.dart';

/// Hatırlatmanın konusu; sunucu aynı sırayla seçer (reminders.ts).
enum ReminderKind { overdue, pending, balance }

/// Bir defterde şu an hatırlatma gönderilebilir mi, gönderilirse ne yazar.
///
/// Son söz sunucunundur; bu hesap düğmeyi ve önizlemeyi göstermek içindir.
class ReminderPlan {
  const ReminderPlan({required this.kind, required this.waiting, this.nextOn});

  /// Hatırlatılacak bir şey yoksa null.
  final ReminderKind? kind;

  /// Karşı tarafın yanıtını bekleyen kayıt sayısı.
  final int waiting;

  /// Yakın zamanda gönderildiyse tekrar gönderilebileceği gün.
  final LocalDate? nextOn;

  bool get isRelevant => kind != null;
  bool get canSend => kind != null && nextOn == null;

  /// Aynı kişiye iki hatırlatma arası gün; vadesi geçmişse daha kısa.
  static int intervalDays(ReminderKind kind) =>
      kind == ReminderKind.overdue ? 3 : 7;

  factory ReminderPlan.of(
    Ledger ledger,
    List<LedgerEntry> entries,
    String uid,
    LocalDate today,
  ) {
    if (ledger.isPrivate) return const ReminderPlan(kind: null, waiting: 0);
    final me = ledger.sideOf(uid) ?? Side.a;
    final other = me == Side.a ? Side.b : Side.a;
    final waiting = entries.where((e) => e.awaits(other)).length;
    final owesMe = ledger.balancesFor(uid).any((m) => m.minor > 0);
    final overdue = ledger.dueItems.any(
      (i) => i.debtorSide == other && i.dueOn < today,
    );
    final kind = overdue
        ? ReminderKind.overdue
        : waiting > 0
        ? ReminderKind.pending
        : owesMe
        ? ReminderKind.balance
        : null;

    LocalDate? nextOn;
    final last = ledger.lastReminderOn[me];
    if (kind != null && last != null) {
      final allowed = last.addDays(intervalDays(kind));
      if (today < allowed) nextOn = allowed;
    }
    return ReminderPlan(kind: kind, waiting: waiting, nextOn: nextOn);
  }

  /// Karşı tarafa gidecek metin. Tutar yazılmaz; sunucudaki metinle aynıdır.
  static ({String title, String message}) text(
    ReminderKind kind,
    String fromName,
    int waiting,
  ) => switch (kind) {
    ReminderKind.overdue => (
      title: 'Vadesi geçmiş kayıt',
      message:
          '$fromName ile hesabınızda vadesi geçmiş bir kayıt görünüyor. '
          'Uygun olduğunuzda göz atabilirsiniz.',
    ),
    ReminderKind.pending => (
      title: 'Yanıtınızı bekleyen kayıt',
      message:
          '$fromName ile hesabınızda yanıtınızı bekleyen $waiting kayıt var. '
          'Uygun olduğunuzda göz atabilirsiniz.',
    ),
    ReminderKind.balance => (
      title: 'Hesap hatırlatması',
      message:
          '$fromName ile ortak hesabınızda açık bir bakiye görünüyor. '
          'Uygun olduğunuzda kontrol edebilirsiniz.',
    ),
  };
}

/// sendReminder yanıtı.
class ReminderResult {
  const ReminderResult({
    required this.kind,
    required this.queued,
    required this.nextOn,
  });

  final ReminderKind kind;

  /// Gece gönderildi; bildirim sabah 09:00'da düşecek.
  final bool queued;
  final LocalDate nextOn;
}
