import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;
  String type; // 'approval_request', 'status_change'
  final String? relatedDebtId;
  final String? createdById; // Bildirimi gönderen
  final String toUserId; // Bildirimi alan

  // Yeni eklenen alanlar
  final String debtorId; // Borçlu olan kullanıcının ID'si
  final String creditorId; // Alacaklı olan kullanıcının ID'si
  final double amount; // İşlem tutarı

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.type,
    this.relatedDebtId,
    this.createdById,
    required this.toUserId,
    // Yeni alanların constructor'a eklenmesi
    required this.debtorId,
    required this.creditorId,
    required this.amount,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? '',
      relatedDebtId: data['relatedDebtId'],
      createdById: data['createdById'],
      toUserId: data['toUserId'] ?? '',
      // Yeni alanların Firestore'dan okunması
      debtorId: data['debtorId'] ?? '',
      creditorId: data['creditorId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
    );
  }

  // Firestore'a yazmak için toMap metodu (opsiyonel ama iyi bir pratik)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'createdAt': createdAt,
      'isRead': isRead,
      'type': type,
      'relatedDebtId': relatedDebtId,
      'createdById': createdById,
      'toUserId': toUserId,
      'debtorId': debtorId,
      'creditorId': creditorId,
      'amount': amount,
    };
  }
}
