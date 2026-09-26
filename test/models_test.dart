import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('bildirim ayarları yoksa varsayılanlar kullanılır', () {
      final user = UserModel.fromMap({
        'uid': 'ali',
        'email': 'ali@example.com',
      });

      expect(user.notificationSettings.newDebtRequests, isTrue);
      expect(user.notificationSettings.reminders, isTrue);
      expect(user.favoriteContacts, isEmpty);
      expect(user.favoriteLedgers, isEmpty);
      expect(user.pactaCode, isNull);
    });

    test('favoriler, kaldırılanlar ve sessize alınanlar okunur', () {
      final hiddenAt = DateTime(2026, 9, 20, 10);
      final user = UserModel.fromMap({
        'uid': 'ali',
        'email': 'ali@example.com',
        'pactaCode': 'K7Q3XM',
        'favoriteLedgers': {'p_a': true, 'p_b': false},
        'hiddenLedgers': {'p_c': Timestamp.fromDate(hiddenAt)},
        'reminderMutes': {'p_d': true},
      });

      expect(user.favoriteLedgers, {'p_a'});
      expect(user.hiddenLedgers, {'p_c': hiddenAt});
      expect(user.reminderMutes, {'p_d'});
      expect(user.pactaCode, 'K7Q3XM');
    });
  });
}
