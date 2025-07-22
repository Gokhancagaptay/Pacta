// lib/models/debt_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DebtModel {
  final String? debtId;
  final String borcluId;
  final String alacakliId;
  final double miktar;
  final String? aciklama;
  final DateTime islemTarihi;
  final String status; // 'note', 'pending', 'approved', 'rejected'
  final bool isShared;
  final bool requiresApproval;
  final List<String> visibleTo;

  DebtModel({
    this.debtId,
    required this.borcluId,
    required this.alacakliId,
    required this.miktar,
    this.aciklama,
    required this.islemTarihi,
    required this.status,
    required this.isShared,
    required this.requiresApproval,
    required this.visibleTo,
  });

  Map<String, dynamic> toMap() {
    return {
      'debtId': debtId,
      'borcluId': borcluId,
      'alacakliId': alacakliId,
      'miktar': miktar,
      'aciklama': aciklama,
      'islemTarihi': islemTarihi.toIso8601String(),
      'status': status,
      'isShared': isShared,
      'requiresApproval': requiresApproval,
      'visibleTo': visibleTo,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return DebtModel(
      debtId: map['debtId'] ?? docId,
      borcluId: map['borcluId'] ?? '',
      alacakliId: map['alacakliId'] ?? '',
      miktar: (map['miktar'] ?? 0).toDouble(),
      aciklama: map['aciklama'],
      islemTarihi: DateTime.parse(map['islemTarihi']),
      status: map['status'] ?? 'note',
      isShared: map['isShared'] ?? false,
      requiresApproval: map['requiresApproval'] ?? false,
      visibleTo: List<String>.from(map['visibleTo'] ?? []),
    );
  }
}
