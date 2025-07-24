import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pacta/services/firestore_service.dart'; // Doğru import yolu
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:pacta/models/debt_model.dart'; // DebtModel'i ekledim

class NotificationItem {
  final String id; // Firestore doküman id'si
  final String title;
  final String description;
  final DateTime date;
  final bool isRead;
  final String? imageUrl;
  final bool isActionable;
  final String relatedDebtId;
  final String toUserId;
  final String? massage; // Yeni eklenen alan
  final String type; // Yeni eklenen alan
  final String status; // Yeni eklenen alan

  NotificationItem(
    this.id,
    this.title,
    this.description,
    this.date,
    this.isRead,
    this.imageUrl,
    this.isActionable,
    this.relatedDebtId,
    this.toUserId,
    this.massage,
    this.type,
    this.status,
  );

  // Firestore'dan veri çekerken kullanmak için factory constructor
  factory NotificationItem.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationItem(
      docId,
      map['title'] ?? '',
      map['description'] ?? '',
      (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      map['isRead'] ?? false,
      map['imageUrl'],
      map['isActionable'] ?? false,
      map['relatedDebtId'] ?? '',
      map['toUserId'] ?? '',
      map['massage'],
      map['type'] ?? '',
      map['status'] ?? 'pending', // status'i varsayılan olarak 'pending' yap
    );
  }
}

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    // Giriş yapan kullanıcının id'si
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    print('currentUserId: $currentUserId'); // Kullanıcı id'sini konsola yazdır
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bildirimler',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      // Firestore'dan sadece bu kullanıcıya ait bildirimleri dinleyen StreamBuilder
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Firestore sorgusunda hata varsa ekranda göster
            return Center(child: Text('Hata: \\${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Hiç bildirim yoksa
            return const Center(
              child: Text(
                'Bildirim bulunamadı.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          // Bildirimler varsa, NotificationItem listesine çevir
          final notifications = snapshot.data!.docs
              .map(
                (doc) => NotificationItem.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return NotificationTitle(
                item: notif,
                currentUserId: currentUserId,
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationTitle extends StatelessWidget {
  final NotificationItem item;
  final String? currentUserId;
  const NotificationTitle({
    required this.item,
    required this.currentUserId,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _firestoreService = FirestoreService();
    final bool isActionable =
        item.isActionable &&
        item.toUserId == currentUserId &&
        item.title == 'Yeni Borç Talebi' &&
        item.relatedDebtId.isNotEmpty &&
        item.type == 'approval_request';
    final Color cardBg = isActionable ? const Color(0xFFEFFCF6) : Colors.white;
    final Color textMain = isActionable
        ? const Color(0xFF111827)
        : Colors.black87;
    final Color textSec = Colors.grey[600]!;

    // Tarih ve saat formatı (örn. 24 Temmuz 2025, 16:03)
    final formattedDate =
        "${item.date.day} ${_monthName(item.date.month)} ${item.date.year}, "
        "${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}";

    // Profil fotoğrafı yoksa baş harfli avatar
    Widget buildAvatar() {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        return CircleAvatar(
          backgroundImage: NetworkImage(item.imageUrl!),
          radius: 24,
        );
      } else {
        // Baş harf (isim başlığı veya title'dan)
        String displayLetter = item.title.isNotEmpty
            ? item.title[0].toUpperCase()
            : '?';
        return CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.13),
          radius: 24,
          child: Text(
            displayLetter,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.green,
            ),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: buildAvatar(),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textMain,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  item.description,
                  style: TextStyle(fontSize: 14, color: textSec),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (item.massage != null && item.massage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  item.massage!,
                  style: TextStyle(fontSize: 14, color: textSec),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                formattedDate,
                style: TextStyle(fontSize: 12, color: textSec),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Onay/ret butonları sadece approval_request tipinde, ilgili kullanıcıya ve status 'pending' ise gösterilir
            if (item.type == 'approval_request' &&
                item.toUserId == currentUserId &&
                item.status == 'pending') ...[
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Reddet',
                onPressed: () async {
                  await _firestoreService.updateDebtStatus(
                    item.relatedDebtId,
                    'rejected',
                  );
                  final notifyUserId = item.toUserId == currentUserId
                      ? null
                      : item.toUserId;
                  if (notifyUserId != null) {
                    await _firestoreService.sendNotification(
                      toUserId: notifyUserId,
                      type: 'approval_result',
                      relatedDebtId: item.relatedDebtId,
                      title: 'Borç Reddedildi',
                      massage: '${item.title} borç talebiniz reddedildi.',
                    );
                  }
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(item.id)
                      .update({'isRead': true});
                },
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: 'Onayla',
                onPressed: () async {
                  await _firestoreService.updateDebtStatus(
                    item.relatedDebtId,
                    'approved',
                  );
                  final notifyUserId = item.toUserId == currentUserId
                      ? null
                      : item.toUserId;
                  if (notifyUserId != null) {
                    await _firestoreService.sendNotification(
                      toUserId: notifyUserId,
                      type: 'approval_result',
                      relatedDebtId: item.relatedDebtId,
                      title: 'Borç Onaylandı',
                      massage: '${item.title} borç talebiniz onaylandı.',
                    );
                  }
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(item.id)
                      .update({'isRead': true});
                },
              ),
            ],
            // Detay (ok) butonu her zaman göster
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey,
                size: 20,
              ),
              tooltip: 'Detay',
              onPressed: () async {
                // Borç detayını Firestore'dan çekip detay ekranına yönlendir
                final doc = await FirebaseFirestore.instance
                    .collection('debts')
                    .doc(item.relatedDebtId)
                    .get();
                if (doc.exists) {
                  final debt = DebtModel.fromMap(doc.data()!, doc.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(
                        debt: debt,
                        userId: currentUserId ?? '',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Borç detayı bulunamadı!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Türkçe ay isimleri için yardımcı fonksiyon
String _monthName(int month) {
  const months = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return months[month];
}
