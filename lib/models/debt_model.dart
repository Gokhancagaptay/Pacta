// lib/models/debt_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DebtModel {
  final String? debtId;
  final String borcluId;
  final String alacakliId;
  final double miktar;
  final String? aciklama;
  final DateTime islemTarihi;
  final String
  status; // 'note', 'pending', 'approved', 'rejected', 'pending_deletion'
  final bool isShared;
  final bool requiresApproval;
  final List<String> visibleto;
  final String? createdBy;
  final String? deletionRequesterId;

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
    required this.visibleto,
    this.createdBy,
    this.deletionRequesterId,
  });

  Map<String, dynamic> toMap() {
    return {
      'borcluId': borcluId,
      'alacakliId': alacakliId,
      'miktar': miktar,
      'aciklama': aciklama,
      'islemTarihi': Timestamp.fromDate(islemTarihi),
      'status': status,
      'isShared': isShared,
      'requiresApproval': requiresApproval,
      'visibleto': visibleto,
      'createdBy': createdBy,
      'deletion_requester_id': deletionRequesterId,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return DebtModel(
      debtId: map['debtId'] ?? docId,
      borcluId: map['borcluId'] ?? '',
      alacakliId: map['alacakliId'] ?? '',
      miktar: (map['miktar'] ?? 0).toDouble(),
      aciklama: map['aciklama'],
      islemTarihi: (map['islemTarihi'] as Timestamp).toDate(),
      status: map['status'] ?? 'note',
      isShared: map['isShared'] ?? false,
      requiresApproval: map['requiresApproval'] ?? false,
      visibleto: List<String>.from(map['visibleto'] ?? []),
      createdBy: map['createdBy'],
      deletionRequesterId: map['deletion_requester_id'],
    );
  }
}
