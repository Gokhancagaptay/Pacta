import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/models/user_model.dart';

void main() {
  group('DebtModel', () {
    final islemTarihi = DateTime(2026, 9, 24, 10, 30);

    DebtModel pendingDebt() => DebtModel(
      borcluId: 'ayse',
      alacakliId: 'ali',
      miktar: 150.5,
      aciklama: 'Yemek',
      islemTarihi: islemTarihi,
      status: 'pending',
      isShared: true,
      requiresApproval: true,
      visibleto: const ['ali', 'ayse'],
      createdBy: 'ali',
    );

    test('toMap/fromMap veriyi korur', () {
      final restored = DebtModel.fromMap(pendingDebt().toMap(), 'debt-1');

      expect(restored.debtId, 'debt-1');
      expect(restored.borcluId, 'ayse');
      expect(restored.alacakliId, 'ali');
      expect(restored.miktar, 150.5);
      expect(restored.islemTarihi, islemTarihi);
      expect(restored.tahminiOdemeTarihi, isNull);
      expect(restored.status, 'pending');
      expect(restored.visibleto, ['ali', 'ayse']);
      expect(restored.createdBy, 'ali');
    });

    // firestore.rules > validNewDebt yalnızca bu alanlara izin verir. Model
    // yeni bir alan yazarsa kurallar kaydı reddeder; ikisi birlikte değişmeli.
    test('toMap yalnızca kuralların izin verdiği alanları yazar', () {
      const allowed = {
        'borcluId',
        'alacakliId',
        'miktar',
        'aciklama',
        'islemTarihi',
        'tahminiOdemeTarihi',
        'createdAt',
        'dueReminderSent',
        'status',
        'isShared',
        'requiresApproval',
        'visibleto',
        'createdBy',
        'deletion_requester_id',
      };

      expect(allowed.containsAll(pendingDebt().toMap().keys), isTrue);
    });

    test('eksik alanlar güvenli varsayılanlara düşer', () {
      final debt = DebtModel.fromMap({
        'islemTarihi': Timestamp.fromDate(islemTarihi),
      });

      expect(debt.status, 'note');
      expect(debt.miktar, 0);
      expect(debt.visibleto, isEmpty);
      expect(debt.dueReminderSent, isFalse);
    });
  });

  group('UserModel', () {
    test('bildirim ayarları yoksa varsayılanlar kullanılır', () {
      final user = UserModel.fromMap({
        'uid': 'ali',
        'email': 'ali@example.com',
      });

      expect(user.notificationSettings.newDebtRequests, isTrue);
      expect(user.notificationSettings.paymentReminders, isFalse);
      expect(user.favoriteContacts, isEmpty);
    });
  });
}
