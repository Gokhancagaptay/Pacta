// lib/screens/notifications/notification_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/models/notification_model.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _firestoreService = FirestoreService();
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
            onPressed: () {},
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

  Future<void> _handleApproval(bool isApproved) {
    // ... (Mevcut _handleApproval mantığı burada kalacak)
    return Future.value();
  }

  Widget _buildLeadingIcon() {
    final notification = widget.notification;
    Color bgColor;
    IconData iconData;

    final String type = notification.type;
    final String title = notification.title.toLowerCase();

    if (type == 'approval_request') {
      bgColor = Colors.blueGrey.shade400;
      iconData = Icons.add_circle_outline;
    } else if (title.contains('onayladı') || title.contains('onaylandı')) {
      bgColor = Colors.green;
      iconData = Icons.check_circle_outline;
    } else if (title.contains('reddetti') || title.contains('reddedildi')) {
      bgColor = Colors.red;
      iconData = Icons.highlight_off;
    } else {
      bgColor = Colors.blue;
      iconData = Icons.notifications;
    }

    return CircleAvatar(
      backgroundColor: bgColor,
      child: Icon(iconData, color: Colors.white, size: 24),
    );
  }

  RichText _buildTitle() {
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

    bool isCreditor = currentUserId == notification.creditorId;
    String sign = isCreditor ? '+' : '-';
    Color amountColor = isCreditor ? Colors.green : Colors.red;

    final amountText = '$sign${notification.amount.toStringAsFixed(2)}₺';
    final message = notification.message;
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

  Widget _buildTrailing() {
    if (widget.notification.type == 'approval_request') {
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
    return Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  void _onTap() {
    // ... (Mevcut _onTap mantığı burada kalacak)
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notification = widget.notification;
    final isUnread =
        !notification.isRead && notification.type == 'approval_request';

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
                      _buildLeadingIcon(),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [_buildTitle(), _buildSubtitle()],
                        ),
                      ),
                      _buildTrailing(),
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
