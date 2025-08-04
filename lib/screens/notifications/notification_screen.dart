// lib/screens/notifications/notification_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:pacta/models/notification_model.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/screens/settings/notification_settings_screen.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;

  Stream<List<NotificationModel>> _getNotificationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: uid)
        .where('isRead', whereIn: [true, false])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Bildirimler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: theme.colorScheme.onBackground,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Yeni bildirim yok.'));
          }
          final notifications = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                key: ValueKey(notification.id),
                notification: notification,
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  const _NotificationCard({Key? key, required this.notification})
    : super(key: key);

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  bool _isProcessing = false;

  Future<void> _handleApproval(bool isApproved) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final newStatus = isApproved ? 'approved' : 'rejected';
      await _firestoreService.updateDebtStatus(
        widget.notification.relatedDebtId!,
        newStatus,
      );

      final senderName = await _firestoreService.getUserNameById(
        widget.notification.createdById ?? '',
      );

      final newTitle = isApproved ? 'Talep Onaylandı' : 'Talep Reddedildi';
      final newMessage = isApproved
          ? '$senderName kullanıcısından gelen ${widget.notification.amount.toStringAsFixed(2)}₺ tutarındaki talebi onayladınız.'
          : '$senderName kullanıcısından gelen ${widget.notification.amount.toStringAsFixed(2)}₺ tutarındaki talebi reddettiniz.';

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.notification.id)
          .update({
            'type': isApproved
                ? 'request_approved_local'
                : 'request_rejected_local', // Türü güncelleyerek işlem butonlarını kaldırıyoruz
            'message': newMessage,
            'title': newTitle,
            'isRead': true, // Okunmuş olarak işaretle
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApproved ? 'Talep onaylandı.' : 'Talep reddedildi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildLeadingIcon(DebtModel? currentDebt) {
    final notification = widget.notification;
    Color bgColor;
    IconData iconData;

    final String type = notification.type;
    final String title = notification.title.toLowerCase();

    // Eğer gerçek zamanlı borç durumu varsa, ona göre icon belirle
    if (currentDebt != null) {
      if (currentDebt.status == 'approved') {
        bgColor = Colors.green;
        iconData = Icons.check_circle_outline;
      } else if (currentDebt.status == 'rejected') {
        bgColor = Colors.red;
        iconData = Icons.highlight_off;
      } else if (currentDebt.status == 'pending' &&
          type == 'approval_request') {
        bgColor = Colors.blueGrey.shade400;
        iconData = Icons.add_circle_outline;
      } else {
        bgColor = Colors.blue;
        iconData = Icons.notifications;
      }
    } else {
      // Mevcut mantık (gerçek zamanlı borç durumu yok)
      if (type == 'approval_request') {
        bgColor = Colors.blueGrey.shade400;
        iconData = Icons.add_circle_outline;
      } else if (title.contains('onayladı') || title.contains('onaylandı')) {
        bgColor = Colors.green;
        iconData = Icons.check_circle_outline;
      } else if (title.contains('reddetti') ||
          title.contains('reddedildi') ||
          type == 'request_rejected' ||
          type == 'request_rejected_local') {
        bgColor = Colors.red;
        iconData = Icons.highlight_off;
      } else {
        bgColor = Colors.blue;
        iconData = Icons.notifications;
      }
    }

    return CircleAvatar(
      backgroundColor: bgColor,
      child: Icon(iconData, color: Colors.white, size: 24),
    );
  }

  Widget _buildContent(DebtModel? currentDebt) {
    return FutureBuilder<String>(
      future: _firestoreService.getUserNameById(
        widget.notification.createdById ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Yükleniyor...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
            ],
          );
        }

        final senderName = snapshot.data ?? 'Bilinmeyen Kullanıcı';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildTitle(senderName, currentDebt), _buildSubtitle()],
        );
      },
    );
  }

  RichText _buildTitle(String senderName, DebtModel? currentDebt) {
    final theme = Theme.of(context);
    final notification = widget.notification;
    final currentUserId = _auth.currentUser?.uid;
    final isUnread =
        !notification.isRead && notification.type == 'approval_request';

    final defaultStyle = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
    );
    final boldStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);

    // Doğru mantık: Bildirim alan kişi (currentUser) alacaklı mı borçlu mu?
    bool isCurrentUserCreditor = currentUserId == notification.creditorId;
    String sign = isCurrentUserCreditor ? '+' : '-';
    Color amountColor = isCurrentUserCreditor ? Colors.green : Colors.red;

    final amountText = '$sign${notification.amount.toStringAsFixed(2)}₺';

    // Eğer gerçek zamanlı borç durumu varsa ve durum değişmişse mesajı güncelle
    String message = notification.message;
    if (currentDebt != null &&
        currentDebt.status != 'pending' &&
        notification.type == 'approval_request') {
      if (currentDebt.status == 'approved') {
        message =
            '$senderName kullanıcısından gelen ${notification.amount.toStringAsFixed(2)}₺ tutarındaki talebi onayladınız.';
      } else if (currentDebt.status == 'rejected') {
        message =
            '$senderName kullanıcısından gelen ${notification.amount.toStringAsFixed(2)}₺ tutarındaki talebi reddettiniz.';
      }
    }

    final amountRegex = RegExp(r'(\d[\d,.]*₺)');
    final amountMatch = amountRegex.firstMatch(message);

    List<TextSpan> spans = [];
    if (amountMatch != null) {
      spans.add(TextSpan(text: message.substring(0, amountMatch.start)));
      spans.add(
        TextSpan(
          text: amountText,
          style: boldStyle.copyWith(color: amountColor),
        ),
      );
      spans.add(TextSpan(text: message.substring(amountMatch.end)));
    } else {
      spans.add(TextSpan(text: message));
    }

    return RichText(
      text: TextSpan(style: defaultStyle, children: spans),
    );
  }

  Widget _buildSubtitle() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        DateFormat(
          'd MMMM y, HH:mm',
          'tr_TR',
        ).format(widget.notification.createdAt),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildTrailing(bool showActionButtons, DebtModel? currentDebt) {
    // Eğer gerçek zamanlı borç durumu varsa ve işlem tamamlanmışsa durum göster
    if (currentDebt != null && currentDebt.status != 'pending') {
      String statusText;
      Color statusColor;

      if (currentDebt.status == 'approved') {
        statusText = 'Onaylandı';
        statusColor = Colors.green;
      } else if (currentDebt.status == 'rejected') {
        statusText = 'Reddedildi';
        statusColor = Colors.red;
      } else {
        statusText = currentDebt.status;
        statusColor = Colors.grey;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Eğer onay bekleyen bir işlemse ve butonlar gösterilecekse
    if (showActionButtons) {
      return _isProcessing
          ? const SizedBox(
              width: 50,
              height: 50,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _handleApproval(false),
                  tooltip: 'Reddet',
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _handleApproval(true),
                  tooltip: 'Onayla',
                ),
              ],
            );
    }

    // Normal durum - sadece ok işareti
    return Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  void _onTap() async {
    final debtId = widget.notification.relatedDebtId;
    if (debtId == null) return;

    // Önce borç verisini Firestore'dan çek
    final debtDoc = await _firestoreService.debtsRef.doc(debtId).get();
    if (!debtDoc.exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İlgili işlem bulunamadı.')));
      return;
    }

    final debt = debtDoc.data();
    if (debt == null) return;

    // Sonra TransactionDetailScreen'e yönlendir
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TransactionDetailScreen(debt: debt, userId: _auth.currentUser!.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notification = widget.notification;

    // Eğer notification'ın ilgili borcu varsa, gerçek zamanlı durumunu takip et
    if (notification.relatedDebtId != null &&
        notification.type == 'approval_request') {
      return StreamBuilder<DebtModel?>(
        stream: _firestoreService.getDebtByIdStream(
          notification.relatedDebtId!,
        ),
        builder: (context, debtSnapshot) {
          if (!debtSnapshot.hasData) {
            return _buildNotificationCard(theme, notification, null);
          }

          final currentDebt = debtSnapshot.data!;
          return _buildNotificationCard(theme, notification, currentDebt);
        },
      );
    }

    // Normal notification (ilgili borç yok)
    return _buildNotificationCard(theme, notification, null);
  }

  Widget _buildNotificationCard(
    ThemeData theme,
    NotificationModel notification,
    DebtModel? currentDebt,
  ) {
    // Eğer ilgili borç varsa ve durumu değişmişse, notification tipini güncelle
    bool isApprovalRequest = notification.type == 'approval_request';
    bool showActionButtons = isApprovalRequest;

    if (currentDebt != null) {
      // Borç durumu 'pending' değilse, artık onay beklemez
      if (currentDebt.status != 'pending') {
        showActionButtons = false;
        isApprovalRequest = false;
      }
    }

    final isUnread = !notification.isRead && isApprovalRequest;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      color: theme.cardColor,
      child: InkWell(
        onTap: _onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isUnread) Container(width: 4, color: theme.primaryColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      _buildLeadingIcon(currentDebt),
                      const SizedBox(width: 12.0),
                      Expanded(child: _buildContent(currentDebt)),
                      _buildTrailing(showActionButtons, currentDebt),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
