// lib/models/debt_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DebtModel {
  final String? debtId;
  final String borcluId;
  final String alacakliId;
  final double miktar;
  final String? aciklama;
  final DateTime islemTarihi;
  final DateTime? tahminiOdemeTarihi; // yeni: tahmini ödeme tarihi (nullable)
  final DateTime?
  createdAt; // yeni: server tarafında set edilecek oluşturulma tarihi
  final bool dueReminderSent; // yeni: ödeme hatırlatması gönderildi mi
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
    this.tahminiOdemeTarihi,
    this.createdAt,
    this.dueReminderSent = false,
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
      'tahminiOdemeTarihi': tahminiOdemeTarihi != null
          ? Timestamp.fromDate(tahminiOdemeTarihi!)
          : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'dueReminderSent': dueReminderSent,
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
      tahminiOdemeTarihi: map['tahminiOdemeTarihi'] != null
          ? (map['tahminiOdemeTarihi'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      dueReminderSent: map['dueReminderSent'] ?? false,
      status: map['status'] ?? 'note',
      isShared: map['isShared'] ?? false,
      requiresApproval: map['requiresApproval'] ?? false,
      visibleto: List<String>.from(map['visibleto'] ?? []),
      createdBy: map['createdBy'],
      deletionRequesterId: map['deletion_requester_id'],
    );
  }
}
