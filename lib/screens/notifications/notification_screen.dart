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
import 'package:pacta/utils/dialog_utils.dart';

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
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
          // Sıralamayı sunucu yerine istemci tarafında yapıyoruz.
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
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
    if (_isProcessing || widget.notification.relatedDebtId == null) return;
    setState(() => _isProcessing = true);

    try {
      final newStatus = isApproved ? 'approved' : 'rejected';
      await _firestoreService.updateDebtStatus(
        widget.notification.relatedDebtId!,
        newStatus,
      );

      if (mounted) {
        DialogUtils.showSuccess(
          context,
          isApproved ? 'İşlem onaylandı.' : 'İşlem reddedildi.',
        );
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showError(context, 'Bir hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDeleteRequestResponse(bool approved) async {
    if (_isProcessing || widget.notification.relatedDebtId == null) return;
    setState(() => _isProcessing = true);

    try {
      await _firestoreService.respondToDeleteRequest(
        widget.notification.relatedDebtId!,
        approved,
        _auth.currentUser!.uid,
      );

      if (mounted) {
        DialogUtils.showSuccess(
          context,
          approved ? 'Silme talebi onaylandı.' : 'Silme talebi reddedildi.',
        );
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showError(context, 'Hata: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildLeadingIcon() {
    final notification = widget.notification;
    Color bgColor;
    IconData iconData;

    final String type = notification.type;

    if (type == 'deletion_request') {
      bgColor = Colors.orange;
      iconData = Icons.delete_sweep_outlined;
    } else if (type == 'approval_request') {
      bgColor = Colors.blueGrey.shade400;
      iconData = Icons.add_circle_outline;
    } else if (type == 'request_approved' || type == 'deletion_approved') {
      bgColor = Colors.green;
      iconData = Icons.check_circle_outline;
    } else if (type == 'request_rejected' || type == 'deletion_rejected') {
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

  Widget _buildContent(DebtModel? currentDebt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_buildTitle(currentDebt), _buildSubtitle()],
    );
  }

  RichText _buildTitle(DebtModel? currentDebt) {
    final theme = Theme.of(context);
    final notification = widget.notification;
    final isUnread =
        !notification.isRead &&
        (notification.type == 'approval_request' ||
            notification.type == 'deletion_request');

    final defaultStyle = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
    );
    final boldStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);

    bool isCurrentUserCreditor =
        _auth.currentUser?.uid == notification.creditorId;
    Color amountColor = isCurrentUserCreditor ? Colors.green : Colors.red;

    String message = notification.message;
    // Eğer işlem sonuçlandıysa, mesajı güncelle
    if (currentDebt != null) {
      if (notification.type == 'approval_request' &&
          currentDebt.status != 'pending') {
        message =
            '${currentDebt.miktar.toStringAsFixed(2)}₺ tutarındaki işlemi ${currentDebt.status == 'approved' ? 'onayladınız' : 'reddettiniz'}.';
      }
    } else if (notification.type == 'deletion_request' && currentDebt == null) {
      // Borç silindiğinde currentDebt null gelir
      message =
          '${notification.amount.toStringAsFixed(2)}₺ tutarındaki işlemin silinmesini onayladınız.';
    }

    final amountRegex = RegExp(r'(\d[\d,.]*₺)');
    final amountMatch = amountRegex.firstMatch(message);

    List<TextSpan> spans = [];
    if (amountMatch != null) {
      spans.add(TextSpan(text: message.substring(0, amountMatch.start)));
      spans.add(
        TextSpan(
          text: amountMatch.group(0)!,
          style: boldStyle.copyWith(color: amountColor),
        ),
      );
      spans.add(TextSpan(text: message.substring(amountMatch.end)));
    } else {
      spans.add(TextSpan(text: message, style: defaultStyle));
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

  Widget _buildTrailing(DebtModel? currentDebt) {
    final notification = widget.notification;
    final currentUserId = _auth.currentUser!.uid;

    final bool isActionable =
        (notification.type == 'approval_request' &&
            (currentDebt?.status == 'pending')) ||
        (notification.type == 'deletion_request' &&
            (currentDebt?.status == 'pending_deletion'));

    if (isActionable && notification.createdById != currentUserId) {
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
                  onPressed: () => notification.type == 'approval_request'
                      ? _handleApproval(false)
                      : _handleDeleteRequestResponse(false),
                  tooltip: 'Reddet',
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => notification.type == 'approval_request'
                      ? _handleApproval(true)
                      : _handleDeleteRequestResponse(true),
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

  void _onTap() async {
    final debtId = widget.notification.relatedDebtId;
    if (debtId == null) return;

    final debtDoc = await _firestoreService.debtsRef.doc(debtId).get();
    if (!debtDoc.exists) {
      DialogUtils.showWarning(context, 'İlgili işlem artık mevcut değil.');
      return;
    }

    final debt = debtDoc.data();
    if (debt == null) return;

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

    final bool isActionableRequest =
        notification.type == 'approval_request' ||
        notification.type == 'deletion_request';

    if (notification.relatedDebtId != null && isActionableRequest) {
      return StreamBuilder<DebtModel?>(
        stream: _firestoreService.getDebtByIdStream(
          notification.relatedDebtId!,
        ),
        builder: (context, debtSnapshot) {
          final currentDebt = debtSnapshot.data;
          return _buildNotificationCard(theme, notification, currentDebt);
        },
      );
    }

    return _buildNotificationCard(theme, notification, null);
  }

  Widget _buildNotificationCard(
    ThemeData theme,
    NotificationModel notification,
    DebtModel? currentDebt,
  ) {
    final isUnread =
        !notification.isRead &&
        (notification.type == 'approval_request' ||
            notification.type == 'deletion_request');

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
                      Expanded(child: _buildContent(currentDebt)),
                      _buildTrailing(currentDebt),
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
