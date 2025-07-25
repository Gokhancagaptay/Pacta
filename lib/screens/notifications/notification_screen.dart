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
  final String? createdById; // Yeni eklenen alan

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
    this.createdById,
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
      map['createdById'],
    );
  }
}

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1A202C),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bildirimler',
          style: TextStyle(
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF1A202C),
              size: 26,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: \\${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Bildirim bulunamadı.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          final notifications = snapshot.data!.docs
              .map(
                (doc) => NotificationItem.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
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

class NotificationTitle extends StatefulWidget {
  final NotificationItem item;
  final String? currentUserId;
  const NotificationTitle({
    required this.item,
    required this.currentUserId,
    Key? key,
  }) : super(key: key);

  @override
  State<NotificationTitle> createState() => _NotificationTitleState();
}

class _NotificationTitleState extends State<NotificationTitle> {
  late String? alacakliName;

  @override
  void initState() {
    super.initState();
    alacakliName = null;
    if (widget.item.type == 'approval_request' &&
        widget.item.toUserId == widget.currentUserId) {
      FirestoreService()
          .getUserNameById(widget.item.massage?.split(' ')[0] ?? '')
          .then((name) {
            setState(() {
              alacakliName = name;
            });
          });
    }
  }

  Future<String> fetchDebtStatus(String debtId) async {
    final doc = await FirebaseFirestore.instance
        .collection('debts')
        .doc(debtId)
        .get();
    if (doc.exists && doc.data() != null && doc.data()!['status'] != null) {
      return doc.data()!['status'] as String;
    }
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final _firestoreService = FirestoreService();
    final formattedDate =
        "${widget.item.date.day} ${_monthName(widget.item.date.month)} ${widget.item.date.year}, "
        "${widget.item.date.hour.toString().padLeft(2, '0')}:${widget.item.date.minute.toString().padLeft(2, '0')}";

    Widget buildLeading(String status, String type) {
      // Bildirim türüne göre ikon ve renk seçimi
      Color bgColor = Colors.grey[400]!;
      IconData icon = Icons.notifications;
      if (type == 'approval_request' && status == 'pending') {
        bgColor = const Color(0xFFCBD5E1);
        icon = Icons.add_circle_outline;
      } else if (type == 'approval_result' && status == 'approved') {
        bgColor = Colors.green;
        icon = Icons.check_circle_outline;
      } else if (type == 'approval_result' && status == 'rejected') {
        bgColor = Colors.red;
        icon = Icons.highlight_off;
      } else if (status == 'approved') {
        bgColor = Colors.green;
        icon = Icons.check_circle_outline;
      } else if (status == 'rejected') {
        bgColor = Colors.red;
        icon = Icons.highlight_off;
      }
      return CircleAvatar(
        backgroundColor: bgColor,
        child: Icon(icon, color: Colors.white, size: 24),
      );
    }

    String getBaslik(String status, String type) {
      if (type == 'approval_result' && status == 'approved')
        return 'Pacta Kabul Edildi';
      if (type == 'approval_result' && status == 'rejected')
        return 'Pacta Reddedildi';
      if (status == 'approved') return 'Onaylanan Pacta';
      if (status == 'rejected') return 'Reddedilen Pacta';
      if (type == 'approval_request' && status == 'pending')
        return 'Yeni Pacta Talebi';
      return widget.item.title;
    }

    Widget buildRichTitle(String status, String type) {
      final miktar =
          widget.item.massage?.replaceAll(RegExp(r'[^0-9,.]'), '') ?? '';
      final isim = alacakliName ?? 'Kullanıcı';
      if (type == 'approval_request' && status == 'pending') {
        final parts = widget.item.massage?.split(' ') ?? [];
        final user = parts.isNotEmpty ? parts[0] : '';
        final amount = parts.length > 2 ? parts[2] : '';
        return RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A202C)),
            children: [
              TextSpan(
                text: user,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' senden '),
              TextSpan(
                text: '$amount₺',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' borç istedi.'),
            ],
          ),
        );
      } else if (type == 'approval_result' && status == 'approved') {
        final user = isim;
        return RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A202C)),
            children: [
              TextSpan(
                text: user,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' kullanıcısına gönderdiğin '),
              TextSpan(
                text: '$miktar₺',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' tutarındaki pacta isteği onaylandı.'),
            ],
          ),
        );
      } else if (type == 'approval_result' && status == 'rejected') {
        final user = isim;
        return RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A202C)),
            children: [
              TextSpan(
                text: user,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' kullanıcısına gönderdiğin '),
              TextSpan(
                text: '$miktar₺',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' tutarındaki pacta isteği reddedildi.'),
            ],
          ),
        );
      } else if (status == 'approved') {
        return Text(
          'Sizin tarafınızdan $isim kullanıcısının $miktar₺ miktarındaki pactası onaylandı.',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.green,
            fontSize: 15,
          ),
        );
      } else if (status == 'rejected') {
        return Text(
          'Sizin tarafınızdan $isim kullanıcısının $miktar₺ miktarındaki pactası reddedildi.',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.red,
            fontSize: 15,
          ),
        );
      }
      return Text(
        widget.item.massage ?? '',
        style: const TextStyle(fontSize: 15),
      );
    }

    Color getCardColor(bool isRead, String status) {
      if (!isRead && status == 'pending') {
        return Colors.white;
      }
      return Colors.white;
    }

    Widget buildUnreadBar(bool isRead, String status) {
      return (!isRead && status == 'pending')
          ? Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          : const SizedBox(width: 4);
    }

    return FutureBuilder<String>(
      future: fetchDebtStatus(widget.item.relatedDebtId),
      builder: (context, snapshot) {
        final status = snapshot.data ?? 'pending';
        final bool isActionable =
            widget.item.type == 'approval_request' &&
            widget.item.toUserId == widget.currentUserId &&
            status == 'pending';
        final bool isRead = widget.item.isRead;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildUnreadBar(isRead, status),
            Expanded(
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12.0, left: 0, right: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: getCardColor(isRead, status),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: buildLeading(status, widget.item.type),
                  title: DefaultTextStyle(
                    style: TextStyle(
                      fontWeight: (!isRead && status == 'pending')
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                      color: const Color(0xFF1A202C),
                    ),
                    child: buildRichTitle(status, widget.item.type),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  trailing: isActionable
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                tooltip: 'Reddet',
                                onPressed: () async {
                                  await _firestoreService.updateDebtStatus(
                                    widget.item.relatedDebtId,
                                    'rejected',
                                  );
                                  final notifyUserId =
                                      widget.item.toUserId ==
                                          widget.currentUserId
                                      ? null
                                      : widget.item.toUserId;
                                  if (notifyUserId != null) {
                                    await _firestoreService.sendNotification(
                                      toUserId: notifyUserId,
                                      type: 'approval_result',
                                      relatedDebtId: widget.item.relatedDebtId,
                                      title: 'Borç Reddedildi',
                                      massage:
                                          '${widget.item.title} borç talebiniz reddedildi.',
                                    );
                                  }
                                  await FirebaseFirestore.instance
                                      .collection('notifications')
                                      .doc(widget.item.id)
                                      .update({
                                        'isRead': true,
                                        'status': 'rejected',
                                      });
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.currentUserId)
                                      .collection('recentDebts')
                                      .doc(widget.item.relatedDebtId)
                                      .update({'status': 'rejected'});
                                  if (widget.item.createdById != null &&
                                      widget.item.createdById!.isNotEmpty) {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.item.createdById)
                                        .collection('recentDebts')
                                        .doc(widget.item.relatedDebtId)
                                        .update({'status': 'rejected'});
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                tooltip: 'Onayla',
                                onPressed: () async {
                                  await _firestoreService.updateDebtStatus(
                                    widget.item.relatedDebtId,
                                    'approved',
                                  );
                                  final notifyUserId =
                                      widget.item.toUserId ==
                                          widget.currentUserId
                                      ? null
                                      : widget.item.toUserId;
                                  if (notifyUserId != null) {
                                    await _firestoreService.sendNotification(
                                      toUserId: notifyUserId,
                                      type: 'approval_result',
                                      relatedDebtId: widget.item.relatedDebtId,
                                      title: 'Borç Onaylandı',
                                      massage:
                                          '${widget.item.title} borç talebiniz onaylandı.',
                                    );
                                  }
                                  await FirebaseFirestore.instance
                                      .collection('notifications')
                                      .doc(widget.item.id)
                                      .update({
                                        'isRead': true,
                                        'status': 'approved',
                                      });
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.currentUserId)
                                      .collection('recentDebts')
                                      .doc(widget.item.relatedDebtId)
                                      .update({'status': 'approved'});
                                  if (widget.item.createdById != null &&
                                      widget.item.createdById!.isNotEmpty) {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.item.createdById)
                                        .collection('recentDebts')
                                        .doc(widget.item.relatedDebtId)
                                        .update({'status': 'approved'});
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 22,
                        ),
                  onTap: () async {
                    final doc = await FirebaseFirestore.instance
                        .collection('debts')
                        .doc(widget.item.relatedDebtId)
                        .get();
                    if (doc.exists) {
                      final debt = DebtModel.fromMap(doc.data()!, doc.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(
                            debt: debt,
                            userId: widget.currentUserId ?? '',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Borç detayı bulunamadı!'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
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
