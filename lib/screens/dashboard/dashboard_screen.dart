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
  // Animasyon için controller
  late AnimationController _controller;

  int _selectedTab = 0;

  final PageController _bakiyeController = PageController();
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  // List<DebtModel> _approvedDebts = [];
  // List<DebtModel> _noteDebts = [];
  // List<DebtModel> _recentDebts = [];
  // bool _loading = true;
  // String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _controller.forward();
    // _fetchData(); // kaldırıldı
  }

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
  void dispose() {
    _controller.dispose();
    _bakiyeController.dispose();
    super.dispose();
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
    const Color green = Color(0xFF4ADE80);
    const Color red = Color(0xFFF87171);
    const Color yellow = Color(0xFFFACC15);
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

          final userModel = userSnap.data?.data();
          if (userModel == null) {
            return Center(
              child: Text(
                'Kullanıcı verisi alınamadı.',
                style: TextStyle(color: textSec),
              ),
            );
          }
          final userName =
              userModel.adSoyad ?? userModel.email.split('@').first;
          return StreamBuilder<List<DebtModel>>(
            stream: _firestoreService.getRecentDebtsStream(userId),
            builder: (context, recentSnapshot) {
              if (recentSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (recentSnapshot.hasError) {
                print('DASHBOARD HATASI: ${recentSnapshot.error}');
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
                        d.status == 'rejected',
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
                                // Üst bilgi
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "👋 Merhaba, $userName!",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: width * 0.055,
                                            color: textMain,
                                          ),
                                        ),
                                        SizedBox(height: height * 0.005),
                                        Text(
                                          DateFormat(
                                            'd MMMM EEEE',
                                            'tr_TR',
                                          ).format(DateTime.now()),
                                          style: TextStyle(
                                            fontSize: width * 0.032,
                                            color: textSec,
                                          ),
                                        ),
                                      ],
                                    ),
                                    StreamBuilder<bool>(
                                      stream: _firestoreService
                                          .getUnreadNotificationsStream(userId),
                                      builder: (context, snapshot) {
                                        final hasNotification =
                                            snapshot.data ?? false;
                                        return Stack(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons
                                                    .notifications_none_rounded,
                                                color: textMain,
                                                size: width * 0.07,
                                              ),
                                              onPressed: () {
                                                // Mark notifications as read when the user navigates to the screen
                                                _firestoreService
                                                    .markAllNotificationsAsRead(
                                                      userId,
                                                    );
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const NotificationScreen(),
                                                  ),
                                                );
                                              },
                                              tooltip: 'Pacta Bildirimleri',
                                            ),
                                            if (hasNotification)
                                              Positioned(
                                                right: width * 0.025,
                                                top: width * 0.025,
                                                child: Container(
                                                  width: width * 0.025,
                                                  height: width * 0.025,
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF23262F,
                                                            )
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
                                ),
                                // Genel borç durumu kartı (Artık swipeable 3 kart)
                                _BakiyeCardSection(
                                  approvedBakiye: approvedBakiye,
                                  noteBakiye: noteBakiye,
                                  ortakBakiye: ortakBakiye,
                                  width: width,
                                  height: height,
                                ),
                                // Hızlı erişim butonları
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    height * 0.03,
                                    0,
                                    0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _AnimatedActionButton(
                                        icon: Icons.send_rounded,
                                        label: "Pacta Ver",
                                        color: red,
                                        onTap: () async {
                                          final selectedContact =
                                              await Navigator.push<
                                                SavedContactModel
                                              >(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SavedContactsScreen(),
                                                ),
                                              );
                                          if (selectedContact != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AmountInputScreen(
                                                      selectedContact:
                                                          selectedContact,
                                                      isPactaAl: false,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      _AnimatedActionButton(
                                        icon: Icons.download_rounded,
                                        label: "Pacta Al",
                                        color: green,
                                        onTap: () async {
                                          final selectedContact =
                                              await Navigator.push<
                                                SavedContactModel
                                              >(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SavedContactsScreen(
                                                        title:
                                                            'Kimden Aldınız?',
                                                      ),
                                                ),
                                              );
                                          if (selectedContact != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AmountInputScreen(
                                                      selectedContact:
                                                          selectedContact,
                                                      isPactaAl: true,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      _AnimatedActionButton(
                                        icon: Icons.note_add_rounded,
                                        label: "Not Ekle",
                                        color: yellow,
                                        onTap: () {
                                          _showAddNoteDialog(context);
                                        },
                                      ),
                                      _AnimatedActionButton(
                                        icon: Icons.analytics_rounded,
                                        label: "Analiz",
                                        color: const Color(0xFF8B5CF6),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const UserAnalysisScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Onaylı Hareketler ve Kendi Takiplerin başlıkları
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    height * 0.04,
                                    0,
                                    0,
                                  ),
                                  child: _TransactionListSection(
                                    title: "Onaylı Hareketler",
                                    transactionList: onayliList,
                                    userId: userId,
                                    width: width,
                                    height: height,
                                    green: green,
                                    red: red,
                                    textMain: textMain,
                                    textSec: textSec,
                                    emptyIcon:
                                        Icons.check_circle_outline_rounded,
                                    emptyMessage: 'Onaylı hareket bulunamadı.',
                                    onSeeAll: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AllTransactionsScreen(
                                            title: 'Onaylı Hareketler',
                                            userId: userId,
                                            statuses: const [
                                              'approved',
                                              'pending',
                                              'rejected',
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Kendi Takiplerim başlığı ve listesi
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    height * 0.018,
                                    0,
                                    0,
                                  ),
                                  child: _TransactionListSection(
                                    title: "Kendi Takiplerin",
                                    transactionList: takipList,
                                    userId: userId,
                                    width: width,
                                    height: height,
                                    green: green,
                                    red: red,
                                    textMain: textMain,
                                    textSec: textSec,
                                    emptyIcon: Icons.notes_rounded,
                                    emptyMessage:
                                        'Son zamanlarda not almadınız.',
                                    onSeeAll: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AllTransactionsScreen(
                                            title: 'Kendi Takiplerin',
                                            userId: userId,
                                            statuses: const ['note'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: height * 0.1), // Alt boşluk
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
        onTabChanged: (i) {
          if (_selectedTab == i && i == 0) return;

          if (i == 0) {
            setState(() => _selectedTab = i);
          } else {
            // Diğer sayfalara gitmeden önce state'i sıfırla ki geri dönüldüğünde Ana Sayfa seçili olsun.
            setState(() => _selectedTab = 0);
            if (i == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              );
            } else if (i == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserAnalysisScreen()),
              );
            } else if (i == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }
          }
        },
      ),
    );
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
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Diyaloğu kapat
                final selectedContact = await Navigator.push<SavedContactModel>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SavedContactsScreen(title: 'Kimden Alacak Notu?'),
                  ),
                );
                if (selectedContact != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AmountInputScreen(
                        selectedContact: selectedContact,
                        isPactaAl: true, // Alacak
                        isNote: true, // Not
                      ),
                    ),
                  );
                }
              },
            ),
            TextButton(
              child: const Text('Borç Notu'),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Diyaloğu kapat
                final selectedContact = await Navigator.push<SavedContactModel>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SavedContactsScreen(title: 'Kime Borç Notu?'),
                  ),
                );
                if (selectedContact != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AmountInputScreen(
                        selectedContact: selectedContact,
                        isPactaAl: false, // Borç
                        isNote: true, // Not
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _TransactionListSection extends StatelessWidget {
  final String title;
  final List<DebtModel> transactionList;
  final String userId;
  final double width;
  final double height;
  final Color green;
  final Color red;
  final Color textMain;
  final Color textSec;
  final IconData emptyIcon;
  final String emptyMessage;
  final VoidCallback onSeeAll;

  const _TransactionListSection({
    required this.title,
    required this.transactionList,
    required this.userId,
    required this.width,
    required this.height,
    required this.green,
    required this.red,
    required this.textMain,
    required this.textSec,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
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
                fontSize: width * 0.042,
                color: textMain,
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                "Tümünü Gör",
                style: TextStyle(color: textMain, fontSize: width * 0.038),
              ),
            ),
          ],
        ),
        if (transactionList.isNotEmpty)
          ...transactionList.map(
            (d) => _transactionCard(
              d,
              userId,
              width,
              green,
              red,
              textMain,
              textSec,
              context,
            ),
          )
        else
          _EmptyState(
            width: width,
            height: height,
            icon: emptyIcon,
            message: emptyMessage,
          ),
      ],
    );
  }

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
      default:
        return '-';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF4ADE80); // yeşil
      case 'pending':
        return const Color(0xFFFFA726); // turuncu
      case 'rejected':
        return const Color(0xFFF87171); // kırmızı
      case 'note':
        return const Color(0xFF6B7280); // gri
      default:
        return Colors.grey;
    }
  }

  Widget _transactionCard(
    DebtModel d,
    String userId,
    double width,
    Color green,
    Color red,
    Color textMain,
    Color textSec,
    BuildContext context,
  ) {
    final bool isAlacak = d.alacakliId == userId;
    final bool isNote = d.status == 'note';
    final Color amountColor = isNote ? green : (isAlacak ? green : red);
    final String amountPrefix = isNote ? '+' : (isAlacak ? '+' : '-');
    final String otherPartyId = isAlacak ? d.borcluId : d.alacakliId;
    final String statusLabel = getStatusLabel(d.status);
    final Color statusColor = getStatusColor(d.status);
    final firestoreService = FirestoreService();
    return FutureBuilder<String>(
      future: firestoreService.getUserNameById(otherPartyId),
      builder: (context, snapshot) {
        final otherPartyName = snapshot.connectionState == ConnectionState.done
            ? (snapshot.data ?? otherPartyId.substring(0, 6))
            : '...';
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
        final Color borderColor = isDark ? Colors.white10 : Colors.grey[200]!;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TransactionDetailScreen(debt: d, userId: userId),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: width * 0.015),
            padding: EdgeInsets.symmetric(
              vertical: width * 0.025,
              horizontal: width * 0.03,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
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
                  radius: width * 0.07,
                  backgroundColor: amountColor.withOpacity(0.13),
                  child: Text(
                    (otherPartyName.isNotEmpty
                        ? otherPartyName[0].toUpperCase()
                        : '?'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: width * 0.07,
                      color: amountColor,
                    ),
                  ),
                ),
                SizedBox(width: width * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherPartyName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: width * 0.045,
                          color: textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: width * 0.01),
                      Text(
                        (d.aciklama ?? '').isNotEmpty
                            ? d.aciklama!
                            : 'Açıklama bulunamadı 🤔',
                        style: TextStyle(
                          fontSize: width * 0.038,
                          color: textSec,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: width * 0.01),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: width * 0.02,
                        children: [
                          Text(
                            DateFormat(
                              'd MMMM y',
                              'tr_TR',
                            ).format(d.islemTarihi),
                            style: TextStyle(
                              fontSize: width * 0.032,
                              color: textSec,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: width * 0.032,
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
                SizedBox(width: width * 0.02),
                Text(
                  amountPrefix + d.miktar.toStringAsFixed(2) + '₺',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.05,
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
  final double width;
  final double height;
  final IconData icon;
  final String message;

  const _EmptyState({
    required this.width,
    required this.height,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final Color containerBg = isDark
        ? const Color(0xFF23262F)
        : Colors.grey[50]!;
    final Color borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: height * 0.01),
      padding: EdgeInsets.symmetric(
        vertical: height * 0.03,
        horizontal: width * 0.04,
      ),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: width * 0.1, color: textSec.withOpacity(0.7)),
          SizedBox(height: height * 0.015),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: width * 0.04, color: textSec),
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

  void _onTapDown(TapDownDetails d) => _controller.forward();
  void _onTapUp(TapUpDetails d) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color buttonBg = isDark ? const Color(0xFF23262F) : Colors.white;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
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
              child: Icon(widget.icon, color: widget.color, size: 28),
            ),
            const SizedBox(height: 7),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBg = isDark ? const Color(0xFF181A20) : Colors.white;
    return Container(
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
          for (int i = 0; i < 4; i++)
            _ModernNavItem(
              icon: [
                Icons.home_rounded,
                Icons.people_alt_rounded,
                Icons.bar_chart_rounded,
                Icons.settings_rounded,
              ][i],
              label: ["Ana Sayfa", "Kişiler", "Analiz", "Ayarlar"][i],
              selected: selectedTab == i,
              onTap: () => onTabChanged(i),
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
    const Color navGlow = Color(0xFF86EFAC);
    const Color textSec = Color(0xFF6B7280);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Container(
                    width: 38,
                    height: 38,
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
                Icon(icon, color: selected ? navGlow : textSec, size: 26),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? navGlow : textSec,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (selected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: navGlow,
                  borderRadius: BorderRadius.circular(2),
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
  final double width;
  final double height;
  const _BakiyeCardSection({
    required this.approvedBakiye,
    required this.noteBakiye,
    required this.ortakBakiye,
    required this.width,
    required this.height,
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
    const Color green = Color(0xFF4ADE80);
    const Color blue = Color(0xFF60A5FA);
    const Color purple = Color(0xFFC4B5FD);
    final double width = widget.width;
    final double height = widget.height;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color arrowColor = isDark ? Colors.white70 : Colors.black54;
    final Color disabledArrowColor = isDark
        ? Colors.white24
        : Colors.grey[400]!;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, height * 0.022, 0, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: height * 0.19,
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
                  width: width,
                ),
                _BakiyeCard(
                  title: "Pacta Bakiyem",
                  amount:
                      (widget.noteBakiye >= 0 ? "+" : "") +
                      widget.noteBakiye.toStringAsFixed(2) +
                      "₺",
                  color: blue,
                  subtitle: "Kendi notların ve takiplerin",
                  width: width,
                ),
                _BakiyeCard(
                  title: "Pacta Ortak",
                  amount:
                      (widget.ortakBakiye >= 0 ? "+" : "") +
                      widget.ortakBakiye.toStringAsFixed(2) +
                      "₺",
                  color: purple,
                  subtitle: "Tüm işlemlerin toplamı",
                  width: width,
                ),
              ],
            ),
          ),
          // Sol ok
          Positioned(
            left: 0,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _bakiyePage == 0 ? disabledArrowColor : arrowColor,
                size: width * 0.055,
              ),
              onPressed: _bakiyePage == 0
                  ? null
                  : () {
                      _bakiyeController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
            ),
          ),
          // Sağ ok
          Positioned(
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                color: _bakiyePage == 2 ? disabledArrowColor : arrowColor,
                size: width * 0.055,
              ),
              onPressed: _bakiyePage == 2
                  ? null
                  : () {
                      _bakiyeController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
            ),
          ),
          // Dot göstergesi
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _bakiyePage == i ? width * 0.045 : width * 0.018,
                  height: width * 0.018,
                  decoration: BoxDecoration(
                    color: _bakiyePage == i
                        ? green
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
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
  final double width;
  const _BakiyeCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.subtitle,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: width * 0.04,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: width * 0.07,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: width * 0.035,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
