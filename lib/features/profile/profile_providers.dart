import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../ledger/application/providers.dart';

final userProfileProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid.isEmpty) return Stream.value(null);
  return FirestoreService().getUserStream(uid);
});
