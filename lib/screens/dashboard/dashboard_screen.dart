import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pacta/screens/notifications/notification_screen.dart';
import 'package:pacta/screens/debt/saved_contacts_screen.dart';
import '../debt/amount_input_screen.dart';
import 'package:pacta/screens/settings/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:pacta/screens/contacts/contacts_screen.dart';
import 'package:pacta/screens/analysis/user_analysis_screen.dart';
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/screens/debt/all_transactions_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  double _calculateBakiye(List<DebtModel> debts, String userId) {
    double alacak = 0;
    double verecek = 0;
    for (final d in debts) {
      if (d.alacakliId == userId) {
        alacak += d.miktar;
      } else if (d.borcluId == userId) {
        verecek += d.miktar;
      }
    }
    return alacak - verecek;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;
    final Color bg = isDark ? const Color(0xFF181A20) : const Color(0xFFF9FAFB);
    final Color textMain = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final userId = _auth.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<DocumentSnapshot<UserModel>>(
        stream: _firestoreService.usersRef.doc(userId).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnap.hasData || userSnap.data?.data() == null) {
            return Center(
              child: Text(
                'Kullanıcı verisi bulunamadı.',
                style: TextStyle(color: textSec),
              ),
            );
          }

          final userModel = userSnap.data!.data()!;
          final userName =
              userModel.adSoyad ?? userModel.email.split('@').first;

          return StreamBuilder<List<DebtModel>>(
            stream: _firestoreService.getRecentDebtsStream(userId),
            builder: (context, recentSnapshot) {
              if (recentSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (recentSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Veriler alınırken hata oluştu.',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              final allRecent = recentSnapshot.data ?? [];
              final onayliList = allRecent
                  .where(
                    (d) =>
                        d.status == 'approved' ||
                        d.status == 'pending' ||
                        d.status == 'rejected' ||
                        d.status == 'pending_deletion',
                  )
                  .toList();
              final takipList = allRecent
                  .where((d) => d.status == 'note')
                  .toList();

              return StreamBuilder<List<DebtModel>>(
                stream: _firestoreService.getUserDebtsStream(userId),
                builder: (context, allDebtsSnapshot) {
                  final allDebts = allDebtsSnapshot.data ?? [];
                  final approved = allDebts
                      .where((d) => d.status == 'approved')
                      .toList();
                  final note = allDebts
                      .where((d) => d.status == 'note')
                      .toList();
                  final double approvedBakiye = _calculateBakiye(
                    approved,
                    userId,
                  );
                  final double noteBakiye = _calculateBakiye(note, userId);
                  final double ortakBakiye = approvedBakiye + noteBakiye;

                  return Stack(
                    children: [
                      SafeArea(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: width * 0.04,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: height * 0.025),
                                _buildHeader(context, userName),
                                _BakiyeCardSection(
                                  approvedBakiye: approvedBakiye,
                                  noteBakiye: noteBakiye,
                                  ortakBakiye: ortakBakiye,
                                ),
                                _buildQuickActions(context),
                                _buildTransactionSections(
                                  context,
                                  onayliList,
                                  takipList,
                                ),
                                SizedBox(
                                  height: height * 0.12,
                                ), // Bottom nav bar space
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: _ModernBottomBar(
        selectedTab: _selectedTab,
        onTabChanged: (i) => _onTabChanged(context, i),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final userId = _auth.currentUser?.uid ?? "";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "👋 Merhaba, $userName!",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: size.width * 0.055,
                color: textMain,
              ),
            ),
            SizedBox(height: size.height * 0.005),
            Text(
              DateFormat('d MMMM EEEE', 'tr_TR').format(DateTime.now()),
              style: TextStyle(fontSize: size.width * 0.032, color: textSec),
            ),
          ],
        ),
        StreamBuilder<bool>(
          stream: _firestoreService.getUnreadNotificationsStream(userId),
          builder: (context, snapshot) {
            final hasNotification = snapshot.data ?? false;
            return Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: textMain,
                    size: size.width * 0.07,
                  ),
                  onPressed: () {
                    _firestoreService.markAllNotificationsAsRead(userId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationScreen(),
                      ),
                    );
                  },
                  tooltip: 'Pacta Bildirimleri',
                ),
                if (hasNotification)
                  Positioned(
                    right: size.width * 0.025,
                    top: size.width * 0.025,
                    child: Container(
                      width: size.width * 0.025,
                      height: size.width * 0.025,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF23262F)
                              : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.only(top: size.height * 0.03),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _AnimatedActionButton(
            icon: Icons.send_rounded,
            label: "Pacta Ver",
            color: const Color(0xFFF87171),
            onTap: () => _handlePactaAction(context, isPactaAl: false),
          ),
          _AnimatedActionButton(
            icon: Icons.download_rounded,
            label: "Pacta Al",
            color: const Color(0xFF4ADE80),
            onTap: () => _handlePactaAction(context, isPactaAl: true),
          ),
          _AnimatedActionButton(
            icon: Icons.note_add_rounded,
            label: "Not Ekle",
            color: const Color(0xFFFACC15),
            onTap: () => _showAddNoteDialog(context),
          ),
          _AnimatedActionButton(
            icon: Icons.analytics_rounded,
            label: "Analiz",
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserAnalysisScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSections(
    BuildContext context,
    List<DebtModel> onayliList,
    List<DebtModel> takipList,
  ) {
    final userId = _auth.currentUser?.uid ?? "";
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: size.height * 0.04),
          child: _TransactionListSection(
            title: "Onaylı Hareketler",
            transactionList: onayliList,
            userId: userId,
            emptyIcon: Icons.check_circle_outline_rounded,
            emptyMessage: 'Onaylı hareket bulunamadı.',
            onSeeAll: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllTransactionsScreen(
                  title: 'Onaylı Hareketler',
                  userId: userId,
                  statuses: const [
                    'approved',
                    'pending',
                    'rejected',
                    'pending_deletion',
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: size.height * 0.018),
          child: _TransactionListSection(
            title: "Kendi Takiplerin",
            transactionList: takipList,
            userId: userId,
            emptyIcon: Icons.notes_rounded,
            emptyMessage: 'Son zamanlarda not almadınız.',
            onSeeAll: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllTransactionsScreen(
                  title: 'Kendi Takiplerin',
                  userId: userId,
                  statuses: const ['note'],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onTabChanged(BuildContext context, int i) {
    if (_selectedTab == i && i == 0) return;

    if (i == 0) {
      setState(() => _selectedTab = i);
    } else {
      setState(() => _selectedTab = 0);
      switch (i) {
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
          break;
        case 2:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserAnalysisScreen()),
          );
          break;
        case 3:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
          break;
      }
    }
  }

  Future<void> _handlePactaAction(
    BuildContext context, {
    required bool isPactaAl,
  }) async {
    final selectedContact = await Navigator.push<SavedContactModel>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedContactsScreen(
          title: isPactaAl ? 'Kimden Aldınız?' : 'Kime Verdiniz?',
        ),
      ),
    );
    if (selectedContact != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AmountInputScreen(
            selectedContact: selectedContact,
            isPactaAl: isPactaAl,
          ),
        ),
      );
    }
  }

  void _showAddNoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Not Ekle'),
          content: const Text('Ne tür bir not eklemek istersiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Alacak Notu'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleNoteAction(context, isAlacakNotu: true);
              },
            ),
            TextButton(
              child: const Text('Borç Notu'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleNoteAction(context, isAlacakNotu: false);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleNoteAction(
    BuildContext context, {
    required bool isAlacakNotu,
  }) async {
    final selectedContact = await Navigator.push<SavedContactModel>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedContactsScreen(
          title: isAlacakNotu ? 'Kimden Alacak Notu?' : 'Kime Borç Notu?',
          isNoteModeFlow: true,
        ),
      ),
    );
    if (selectedContact != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AmountInputScreen(
            selectedContact: selectedContact,
            isPactaAl: isAlacakNotu,
            isNote: true,
          ),
        ),
      );
    }
  }
}

class _TransactionListSection extends StatelessWidget {
  final String title;
  final List<DebtModel> transactionList;
  final String userId;
  final IconData emptyIcon;
  final String emptyMessage;
  final VoidCallback onSeeAll;

  const _TransactionListSection({
    required this.title,
    required this.transactionList,
    required this.userId,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: size.width * 0.042,
                color: textMain,
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                "Tümünü Gör",
                style: TextStyle(color: textMain, fontSize: size.width * 0.038),
              ),
            ),
          ],
        ),
        if (transactionList.isNotEmpty)
          ...transactionList.map(
            (d) => _TransactionCard(debt: d, userId: userId),
          )
        else
          _EmptyState(icon: emptyIcon, message: emptyMessage),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final DebtModel debt;
  final String userId;

  const _TransactionCard({required this.debt, required this.userId});

  String getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Onaylandı';
      case 'pending':
        return 'Bekleniyor';
      case 'rejected':
        return 'Reddedildi';
      case 'note':
        return 'Not';
      case 'pending_deletion':
        return 'Siliniyor';
      default:
        return '-';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF4ADE80);
      case 'pending':
        return const Color(0xFFFFA726);
      case 'rejected':
        return const Color(0xFFF87171);
      case 'note':
        return const Color(0xFF6B7280);
      case 'pending_deletion':
        return const Color(0xFFFFA726);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    final bool isAlacak = debt.alacakliId == userId;
    final Color amountColor = isAlacak
        ? const Color(0xFF4ADE80)
        : const Color(0xFFF87171);
    final String amountPrefix = isAlacak ? '+' : '-';
    final String otherPartyId = isAlacak ? debt.borcluId : debt.alacakliId;
    final String statusLabel = getStatusLabel(debt.status);
    final Color statusColor = getStatusColor(debt.status);
    final firestoreService = FirestoreService();

    return FutureBuilder<String>(
      future: firestoreService.getUserNameById(otherPartyId),
      builder: (context, snapshot) {
        final otherPartyName = snapshot.connectionState == ConnectionState.done
            ? (snapshot.data ?? otherPartyId.substring(0, 6))
            : '...';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TransactionDetailScreen(debt: debt, userId: userId),
            ),
          ),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: size.height * 0.008),
            padding: EdgeInsets.symmetric(
              vertical: size.height * 0.015,
              horizontal: size.width * 0.03,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(size.width * 0.045),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: amountColor.withOpacity(isDark ? 0.10 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: size.width * 0.07,
                  backgroundColor: amountColor.withOpacity(0.13),
                  child: Text(
                    (otherPartyName.isNotEmpty
                        ? otherPartyName[0].toUpperCase()
                        : '?'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: size.width * 0.07,
                      color: amountColor,
                    ),
                  ),
                ),
                SizedBox(width: size.width * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherPartyName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: size.width * 0.04,
                          color: textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: size.height * 0.004),
                      Text(
                        (debt.aciklama ?? '').isNotEmpty
                            ? debt.aciklama!
                            : 'Açıklama yok',
                        style: TextStyle(
                          fontSize: size.width * 0.035,
                          color: textSec,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: size.height * 0.005),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: size.width * 0.02,
                        children: [
                          Text(
                            DateFormat(
                              'd MMM y',
                              'tr_TR',
                            ).format(debt.islemTarihi),
                            style: TextStyle(
                              fontSize: size.width * 0.03,
                              color: textSec,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width * 0.02,
                              vertical: size.height * 0.0025,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(
                                size.width * 0.02,
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: size.width * 0.028,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: size.width * 0.02),
                Text(
                  amountPrefix + debt.miktar.toStringAsFixed(2) + '₺',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: size.width * 0.045,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final containerBg = isDark ? const Color(0xFF23262F) : Colors.grey[50]!;
    final borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: size.height * 0.01),
      padding: EdgeInsets.symmetric(
        vertical: size.height * 0.03,
        horizontal: size.width * 0.04,
      ),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(size.width * 0.045),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: size.width * 0.1, color: textSec.withOpacity(0.7)),
          SizedBox(height: size.height * 0.015),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: size.width * 0.04, color: textSec),
          ),
        ],
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AnimatedActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBg = isDark ? const Color(0xFF23262F) : Colors.white;

    return GestureDetector(
      onTap: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Column(
          children: [
            Container(
              width: size.width * 0.15,
              height: size.width * 0.15,
              decoration: BoxDecoration(
                color: buttonBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(isDark ? 0.10 : 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark
                    ? Border.all(
                        color: widget.color.withOpacity(0.18),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: size.width * 0.07,
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: size.width * 0.032,
                fontWeight: FontWeight.w500,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernBottomBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  const _ModernBottomBar({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF181A20) : Colors.white;

    return Container(
      height: size.height * 0.1,
      decoration: BoxDecoration(
        color: barBg,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : const Color(0x11000000),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ModernNavItem(
            icon: Icons.home_rounded,
            label: "Ana Sayfa",
            selected: selectedTab == 0,
            onTap: () => onTabChanged(0),
          ),
          _ModernNavItem(
            icon: Icons.people_alt_rounded,
            label: "Kişiler",
            selected: selectedTab == 1,
            onTap: () => onTabChanged(1),
          ),
          _ModernNavItem(
            icon: Icons.bar_chart_rounded,
            label: "Analiz",
            selected: selectedTab == 2,
            onTap: () => onTabChanged(2),
          ),
          _ModernNavItem(
            icon: Icons.settings_rounded,
            label: "Ayarlar",
            selected: selectedTab == 3,
            onTap: () => onTabChanged(3),
          ),
        ],
      ),
    );
  }
}

class _ModernNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModernNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const navGlow = Color(0xFF86EFAC);
    const textSec = Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: size.height * 0.01,
          horizontal: size.width * 0.03,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Container(
                    width: size.width * 0.1,
                    height: size.width * 0.1,
                    decoration: BoxDecoration(
                      color: navGlow.withOpacity(0.18),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: navGlow.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                Icon(
                  icon,
                  color: selected ? navGlow : textSec,
                  size: size.width * 0.065,
                ),
              ],
            ),
            SizedBox(height: size.height * 0.0025),
            Text(
              label,
              style: TextStyle(
                fontSize: size.width * 0.03,
                color: selected ? navGlow : textSec,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (selected)
              Container(
                margin: EdgeInsets.only(top: size.height * 0.0025),
                width: size.width * 0.045,
                height: size.height * 0.0035,
                decoration: BoxDecoration(
                  color: navGlow,
                  borderRadius: BorderRadius.circular(size.width * 0.01),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BakiyeCardSection extends StatefulWidget {
  final double approvedBakiye;
  final double noteBakiye;
  final double ortakBakiye;

  const _BakiyeCardSection({
    required this.approvedBakiye,
    required this.noteBakiye,
    required this.ortakBakiye,
  });

  @override
  State<_BakiyeCardSection> createState() => _BakiyeCardSectionState();
}

class _BakiyeCardSectionState extends State<_BakiyeCardSection> {
  int _bakiyePage = 0;
  late final PageController _bakiyeController;

  @override
  void initState() {
    super.initState();
    _bakiyeController = PageController();
  }

  @override
  void dispose() {
    _bakiyeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4ADE80);
    const blue = Color(0xFF60A5FA);
    const purple = Color(0xFFC4B5FD);
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arrowColor = isDark ? Colors.white70 : Colors.black54;
    final disabledArrowColor = isDark ? Colors.white24 : Colors.grey[400]!;

    return Padding(
      padding: EdgeInsets.only(top: size.height * 0.022),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: size.height * 0.19,
            child: PageView(
              controller: _bakiyeController,
              onPageChanged: (i) => setState(() => _bakiyePage = i),
              children: [
                _BakiyeCard(
                  title: "Onaylanmış Pacta Bakiyem",
                  amount:
                      (widget.approvedBakiye >= 0 ? "+" : "") +
                      widget.approvedBakiye.toStringAsFixed(2) +
                      "₺",
                  color: green,
                  subtitle: "Çift taraflı onaylanmış işlemler",
                ),
                _BakiyeCard(
                  title: "Pacta Bakiyem",
                  amount:
                      (widget.noteBakiye >= 0 ? "+" : "") +
                      widget.noteBakiye.toStringAsFixed(2) +
                      "₺",
                  color: blue,
                  subtitle: "Kendi notların ve takiplerin",
                ),
                _BakiyeCard(
                  title: "Pacta Ortak",
                  amount:
                      (widget.ortakBakiye >= 0 ? "+" : "") +
                      widget.ortakBakiye.toStringAsFixed(2) +
                      "₺",
                  color: purple,
                  subtitle: "Tüm işlemlerin toplamı",
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _bakiyePage == 0 ? disabledArrowColor : arrowColor,
                size: size.width * 0.055,
              ),
              onPressed: _bakiyePage == 0
                  ? null
                  : () => _bakiyeController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                color: _bakiyePage == 2 ? disabledArrowColor : arrowColor,
                size: size.width * 0.055,
              ),
              onPressed: _bakiyePage == 2
                  ? null
                  : () => _bakiyeController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.01,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _bakiyePage == i
                      ? size.width * 0.045
                      : size.width * 0.018,
                  height: size.width * 0.018,
                  decoration: BoxDecoration(
                    color: _bakiyePage == i
                        ? green
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(size.width * 0.01),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BakiyeCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final String subtitle;
  const _BakiyeCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF23262F) : Colors.white;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: size.width * 0.02),
      padding: EdgeInsets.symmetric(
        vertical: size.height * 0.02,
        horizontal: size.width * 0.05,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.width * 0.06),
        gradient: isDark
            ? null
            : LinearGradient(
                colors: [color.withOpacity(0.13), color.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isDark ? cardBg : null,
        border: isDark
            ? Border.all(color: color.withOpacity(0.2), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.08 : 0.13),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: size.width * 0.04,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: size.height * 0.01),
          Text(
            amount,
            style: TextStyle(
              fontSize: size.width * 0.07,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: size.height * 0.005),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: size.width * 0.035,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
