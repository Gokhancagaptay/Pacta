import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:pacta/screens/analysis/generate_document_screen.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:auto_size_text/auto_size_text.dart';

class UserAnalysisScreen extends StatefulWidget {
  const UserAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<UserAnalysisScreen> createState() => _UserAnalysisScreenState();
}

class _UserAnalysisScreenState extends State<UserAnalysisScreen> {
  bool isLoading = true;
  double toplamBorclarim = 0;
  double toplamAlacaklarim = 0;
  double toplamNotBorclarim = 0;
  double toplamNotAlacaklarim = 0;

  double onayliToplamBorclarim = 0;
  double onayliToplamAlacaklarim = 0;

  List<Map<String, dynamic>> tumIslemler = [];
  List<Map<String, dynamic>> filteredIslemler = [];

  late PageController _pageController;
  int _currentPage = 0;

  final FirestoreService _firestoreService = FirestoreService();

  // Sayı formatı yardımcı fonksiyonu
  String formatNumber(double number) {
    if (number.abs() >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M₺';
    }
    if (number.abs() >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K₺';
    }
    return '${number.toStringAsFixed(2)}₺';
  }

  // Basit ve çalışır tooltip - SnackBar yaklaşımı
  void _showCustomTooltip(
    BuildContext context,
    String fullAmount, {
    String? title,
  }) {
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      print('Tooltip tetiklendi: $fullAmount');

      // SnackBar ile güvenilir gösterim
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFFCCCCCC),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  fullAmount,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF2D3748) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          backgroundColor: isDark ? Colors.white : const Color(0xFF2D3748),
          duration: const Duration(milliseconds: 2500),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      );

      print('Tooltip gösterildi: $fullAmount');
    } catch (e) {
      print('Tooltip gösterme hatası: $e');

      // En basit fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${title ?? "Tam Tutar"}: $fullAmount'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Modern Pie Chart Tooltip
  void _showPieTooltip(
    BuildContext context,
    PieTouchResponse? pieTouchResponse,
    List<Map<String, dynamic>> sections,
  ) {
    if (pieTouchResponse?.touchedSection?.touchedSectionIndex == null) return;

    final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;

    // Sadece değeri 0'dan büyük olan bölümleri filtrele
    final validSections = sections
        .where((section) => section['value'] > 0)
        .toList();

    if (touchedIndex >= validSections.length) return;

    final touchedSection = validSections[touchedIndex];
    final name = touchedSection['name'] as String;
    final value = touchedSection['value'] as double;
    final color = touchedSection['color'] as Color;

    // Toplam değeri hesapla
    final total = sections.fold<double>(
      0,
      (sum, section) => sum + (section['value'] as double),
    );
    final percentage = total > 0 ? (value / total * 100) : 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      print(
        'Pie Chart tooltip tetiklendi: $name - ${value.toStringAsFixed(2)}₺',
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Renk göstergesi
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Metin bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Başlık
                      Text(
                        name,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF999999)
                              : const Color(0xFFCCCCCC),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Ana tutar
                      Row(
                        children: [
                          Text(
                            '${value.toStringAsFixed(2)}₺',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF2D3748)
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Yüzde bilgisi
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: color.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: isDark
                                    ? color.withOpacity(0.8)
                                    : Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: isDark ? Colors.white : const Color(0xFF2D3748),
          duration: const Duration(milliseconds: 3000),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 12,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );

      print('Modern pie tooltip gösterildi: $name');
    } catch (e) {
      print('Pie tooltip hatası: $e');

      // Fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name: ${value.toStringAsFixed(2)}₺ (${percentage.toStringAsFixed(1)}%)',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    fetchUserAnalysis();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchUserAnalysis() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    double tempBorclarim = 0;
    double tempAlacaklarim = 0;
    double tempNotBorclarim = 0;
    double tempNotAlacaklarim = 0;
    double tempOnayliBorclarim = 0;
    double tempOnayliAlacaklarim = 0;
    List<Map<String, dynamic>> tempIslemler = [];
    final Map<String, String> _nameCache = {};

    try {
      final allDebtsSnap = await FirebaseFirestore.instance
          .collection('debts')
          .get();
      for (var doc in allDebtsSnap.docs) {
        final data = doc.data();
        final borcluId = data['borcluId'] as String?;
        final alacakliId = data['alacakliId'] as String?;

        if (borcluId != currentUserId && alacakliId != currentUserId) {
          continue;
        }

        final status = data['status']?.toString().toLowerCase() ?? '';
        final miktar = (data['miktar'] as num?)?.toDouble() ?? 0;

        DateTime? islemTarihi;
        final dynamic islemTarihiData = data['islemTarihi'];
        if (islemTarihiData is Timestamp) {
          islemTarihi = islemTarihiData.toDate();
        } else if (islemTarihiData is String) {
          islemTarihi = DateTime.tryParse(islemTarihiData);
        }

        // Karşı tarafın adını çek ve cache'le
        final String otherPartyId = borcluId == currentUserId
            ? (alacakliId ?? '')
            : (borcluId ?? '');
        String otherPartyName = 'Bilinmeyen Kullanıcı';
        if (otherPartyId.isNotEmpty) {
          if (_nameCache.containsKey(otherPartyId)) {
            otherPartyName = _nameCache[otherPartyId]!;
          } else {
            otherPartyName = await _firestoreService.getUserNameById(
              otherPartyId,
            );
            _nameCache[otherPartyId] = otherPartyName;
          }
        }

        final islemDetayi = {
          'debtId': doc.id,
          'miktar': miktar,
          'tarih': islemTarihi,
          'status': status,
          'aciklama': data['aciklama'] ?? '',
          'borcluId': borcluId,
          'alacakliId': alacakliId,
          'otherPartyName': otherPartyName, // Zenginleştirilmiş veri
        };

        if (status == 'approved' || status == 'note') {
          tempIslemler.add(islemDetayi);
        }

        if (status == 'note') {
          if (borcluId == currentUserId)
            tempNotBorclarim += miktar;
          else if (alacakliId == currentUserId)
            tempNotAlacaklarim += miktar;
        } else if (status == 'approved') {
          if (borcluId == currentUserId)
            tempBorclarim += miktar;
          else if (alacakliId == currentUserId)
            tempAlacaklarim += miktar;
        }

        if (status == 'approved') {
          if (borcluId == currentUserId)
            tempOnayliBorclarim += miktar;
          else if (alacakliId == currentUserId)
            tempOnayliAlacaklarim += miktar;
        }
      }
    } catch (e) {
      // Hata yönetimi (örn. bir snackbar gösterme)
    }

    if (mounted) {
      setState(() {
        toplamBorclarim = tempBorclarim;
        toplamAlacaklarim = tempAlacaklarim;
        toplamNotBorclarim = tempNotBorclarim;
        toplamNotAlacaklarim = tempNotAlacaklarim;
        onayliToplamBorclarim = tempOnayliBorclarim;
        onayliToplamAlacaklarim = tempOnayliAlacaklarim;
        tumIslemler = tempIslemler;
        filteredIslemler = List.from(tumIslemler);
        isLoading = false;
      });
    }
  }

  void _showTransactionDetail(Map<String, dynamic> islem) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(
          debt: DebtModel.fromMap(
            islem
              ..['islemTarihi'] = Timestamp.fromDate(
                islem['tarih'] ?? DateTime.now(),
              ),
            islem['debtId'],
          ),
          userId: currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF181A20) : const Color(0xFFF7F8FC);
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
    final cardInnerColor = isDark
        ? const Color(0xFF2A2D3A)
        : const Color(0xFFF8F9FA);
    final textMain = isDark ? Colors.white : const Color(0xFF1A202C);
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final iconMain = isDark ? Colors.white : const Color(0xFF1A202C);
    final iconShare = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final red = const Color(0xFFF87171);
    final green = const Color(0xFF4ADE80);
    final blue = const Color(0xFF3B82F6);
    final orange = const Color(0xFFFFA726);

    String listTitle;
    switch (_currentPage) {
      case 1:
        listTitle = 'Onaylı İşlemler';
        break;
      case 2:
        listTitle = 'Not İşlemleri';
        break;
      default:
        listTitle = 'Tüm İşlemler';
        break;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: iconMain),
        title: Text(
          'Genel Analiz',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textMain,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: iconMain,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.description_outlined, color: iconShare, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GenerateDocumentScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Analiz yükleniyor...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 100),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 350,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // PageView
                                  PageView(
                                    controller: _pageController,
                                    onPageChanged: (page) {
                                      setState(() {
                                        _currentPage = page;
                                        // Sayfa değiştikçe listeyi filtrele
                                        switch (page) {
                                          case 1: // Onaylı İşlemler
                                            filteredIslemler = tumIslemler
                                                .where(
                                                  (islem) =>
                                                      islem['status'] ==
                                                      'approved',
                                                )
                                                .toList();
                                            break;
                                          case 2: // Not İşlemleri
                                            filteredIslemler = tumIslemler
                                                .where((islem) {
                                                  final status =
                                                      islem['status']
                                                          ?.toString()
                                                          .toLowerCase() ??
                                                      '';
                                                  return status == 'note' ||
                                                      status == 'not' ||
                                                      status == 'notes';
                                                })
                                                .toList();
                                            break;
                                          default: // Genel Durum
                                            filteredIslemler = List.from(
                                              tumIslemler,
                                            );
                                            break;
                                        }
                                      });
                                    },
                                    children: [
                                      _buildGenelDurumKarti(
                                        cardColor,
                                        textMain,
                                        textSec,
                                        red,
                                        green,
                                        blue,
                                        orange,
                                        isDark,
                                      ),
                                      _buildOnayliAnalizKarti(
                                        cardColor,
                                        textMain,
                                        textSec,
                                        red,
                                        green,
                                        isDark,
                                      ),
                                      _buildNotAnalizKarti(
                                        cardColor,
                                        textMain,
                                        textSec,
                                        blue,
                                        orange,
                                        isDark,
                                      ),
                                    ],
                                  ),

                                  // Sol Ok
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Visibility(
                                      visible: _currentPage > 0,
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.arrow_back_ios_new_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _pageController.previousPage(
                                              duration: const Duration(
                                                milliseconds: 400,
                                              ),
                                              curve: Curves.easeInOut,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Sağ Ok
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Visibility(
                                      visible: _currentPage < 2,
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _pageController.nextPage(
                                              duration: const Duration(
                                                milliseconds: 400,
                                              ),
                                              curve: Curves.easeInOut,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // İşlemler Listesi
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.of(context).size.width * 0.01,
                                ),
                                padding: EdgeInsets.all(
                                  MediaQuery.of(context).size.width * 0.05,
                                ),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        isDark ? 0.18 : 0.08,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Başlık
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          listTitle, // Dinamik başlık
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: textMain,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${filteredIslemler.length} işlem',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: textSec,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.filter_list,
                                              color: textSec,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // İşlemler Listesi
                                    Expanded(
                                      child: filteredIslemler.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.search_off_rounded,
                                                    size: 60,
                                                    color: textSec.withOpacity(
                                                      0.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'İşlem Bulunamadı',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: textMain
                                                          .withOpacity(0.8),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Bu kritere uygun işlem kaydı yok.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: textSec,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount:
                                                  filteredIslemler.length,
                                              itemBuilder: (context, index) {
                                                final islem =
                                                    filteredIslemler[index];
                                                final bool isAlacak =
                                                    islem['alacakliId'] ==
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid;

                                                return _buildTransactionListItem(
                                                  islem,
                                                  isAlacak,
                                                  context,
                                                  index,
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // YENİ WIDGET: Modern işlem listesi öğesi
  Widget _buildTransactionListItem(
    Map<String, dynamic> islem,
    bool isAlacak,
    BuildContext context,
    int index,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF1A202C);
    final textSec = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardInnerColor = isDark ? const Color(0xFF2D3748) : Colors.white;
    final green = const Color(0xFF48BB78);
    final red = const Color(0xFFF56565);

    final String otherPartyName = islem['otherPartyName'] ?? 'Bilinmeyen';
    final String aciklama = islem['aciklama']?.toString() ?? '';
    final double miktar = islem['miktar'] ?? 0.0;
    final DateTime? tarih = islem['tarih'];
    final String status = islem['status'] ?? '';

    String statusText;
    Color statusColor;

    switch (status) {
      case 'approved':
        statusText = 'Onaylandı';
        statusColor = green;
        break;
      case 'pending':
        statusText = 'Bekleniyor';
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusText = 'Reddedildi';
        statusColor = red;
        break;
      case 'note':
        statusText = isAlacak ? 'Not Alacak' : 'Not Borç';
        statusColor = isAlacak ? const Color(0xFF3B82F6) : Colors.orange;
        break;
      default:
        statusText = status.toUpperCase();
        statusColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: index == filteredIslemler.length - 1 ? 0 : 12,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardInnerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: (isAlacak ? green : red).withOpacity(0.1),
            child: Text(
              otherPartyName.isNotEmpty ? otherPartyName[0].toUpperCase() : '?',
              style: TextStyle(
                color: isAlacak ? green : red,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        otherPartyName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _showCustomTooltip(
                          context,
                          '${isAlacak ? '+' : '-'}${miktar.toStringAsFixed(2)}₺',
                          title: isAlacak ? 'Alacağınız' : 'Borcunuz',
                        );
                      },
                      onLongPress: () {
                        _showCustomTooltip(
                          context,
                          '${isAlacak ? '+' : '-'}${miktar.toStringAsFixed(2)}₺',
                          title: isAlacak ? 'Alacağınız' : 'Borcunuz',
                        );
                      },
                      child: MouseRegion(
                        onEnter: (_) {
                          if (Theme.of(context).platform ==
                                  TargetPlatform.windows ||
                              Theme.of(context).platform ==
                                  TargetPlatform.macOS ||
                              Theme.of(context).platform ==
                                  TargetPlatform.linux) {
                            _showCustomTooltip(
                              context,
                              '${isAlacak ? '+' : '-'}${miktar.toStringAsFixed(2)}₺',
                              title: isAlacak ? 'Alacağınız' : 'Borcunuz',
                            );
                          }
                        },
                        child: AutoSizeText(
                          '${isAlacak ? '+' : '-'}${formatNumber(miktar).replaceAll('₺', '')}₺',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isAlacak ? green : red,
                          ),
                          maxLines: 1,
                          minFontSize: 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  aciklama.isNotEmpty ? aciklama : 'Açıklama bulunamadı 🤔',
                  style: TextStyle(fontSize: 14, color: textSec),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      tarih != null
                          ? DateFormat('d MMMM yyyy', 'tr_TR').format(tarih)
                          : 'Tarih yok',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSec.withOpacity(0.8),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenelDurumKarti(
    Color cardColor,
    Color textMain,
    Color textSec,
    Color red,
    Color green,
    Color blue,
    Color orange,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Genel Durum',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: textMain,
            ),
          ),
          const SizedBox(height: 16),
          // Grafik
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent || event is FlLongPressEnd) {
                          _showPieTooltip(context, pieTouchResponse, [
                            {
                              'name': 'Alacaklarım',
                              'value': toplamAlacaklarim,
                              'color': green,
                            },
                            {
                              'name': 'Not Alacaklarım',
                              'value': toplamNotAlacaklarim,
                              'color': blue,
                            },
                            {
                              'name': 'Borçlarım',
                              'value': toplamBorclarim,
                              'color': red,
                            },
                            {
                              'name': 'Not Borçlarım',
                              'value': toplamNotBorclarim,
                              'color': orange,
                            },
                          ]);
                        }
                      },
                    ),
                    sections: [
                      if (toplamAlacaklarim > 0)
                        PieChartSectionData(
                          color: green,
                          value: toplamAlacaklarim,
                          showTitle: false,
                          radius: 55,
                        ),
                      if (toplamNotAlacaklarim > 0)
                        PieChartSectionData(
                          color: blue,
                          value: toplamNotAlacaklarim,
                          showTitle: false,
                          radius: 55,
                        ),
                      if (toplamBorclarim > 0)
                        PieChartSectionData(
                          color: red,
                          value: toplamBorclarim,
                          showTitle: false,
                          radius: 55,
                        ),
                      if (toplamNotBorclarim > 0)
                        PieChartSectionData(
                          color: orange,
                          value: toplamNotBorclarim,
                          showTitle: false,
                          radius: 55,
                        ),
                      if (toplamBorclarim == 0 &&
                          toplamAlacaklarim == 0 &&
                          toplamNotAlacaklarim == 0 &&
                          toplamNotBorclarim == 0)
                        PieChartSectionData(
                          color: isDark ? Colors.grey[800]! : Colors.grey,
                          value: 1,
                          showTitle: false,
                          radius: 55,
                        ),
                    ],
                  ),
                ),
                // Ortadaki toplam bakiye
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final fullAmount =
                              (toplamAlacaklarim + toplamNotAlacaklarim) -
                              (toplamBorclarim + toplamNotBorclarim);
                          _showCustomTooltip(
                            context,
                            '${fullAmount.toStringAsFixed(2)}₺',
                            title: 'Net Bakiye',
                          );
                        },
                        onLongPress: () {
                          final fullAmount =
                              (toplamAlacaklarim + toplamNotAlacaklarim) -
                              (toplamBorclarim + toplamNotBorclarim);
                          _showCustomTooltip(
                            context,
                            '${fullAmount.toStringAsFixed(2)}₺',
                            title: 'Net Bakiye',
                          );
                        },
                        child: MouseRegion(
                          onEnter: (_) {
                            if (Theme.of(context).platform ==
                                    TargetPlatform.windows ||
                                Theme.of(context).platform ==
                                    TargetPlatform.macOS ||
                                Theme.of(context).platform ==
                                    TargetPlatform.linux) {
                              final fullAmount =
                                  (toplamAlacaklarim + toplamNotAlacaklarim) -
                                  (toplamBorclarim + toplamNotBorclarim);
                              _showCustomTooltip(
                                context,
                                '${fullAmount.toStringAsFixed(2)}₺',
                                title: 'Net Bakiye',
                              );
                            }
                          },
                          child: AutoSizeText(
                            formatNumber(
                              (toplamAlacaklarim + toplamNotAlacaklarim) -
                                  (toplamBorclarim + toplamNotBorclarim),
                            ),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            minFontSize: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AutoSizeText(
                        (toplamAlacaklarim + toplamNotAlacaklarim) -
                                    (toplamBorclarim + toplamNotBorclarim) >=
                                0
                            ? 'Alacaklısın'
                            : 'Borçlusun',
                        style: TextStyle(fontSize: 9, color: textSec),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        minFontSize: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(), // DİNAMİK BOŞLUK
          // Bar Graph
          if (toplamAlacaklarim > 0 || toplamBorclarim > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SOL TARAF (ALACAKLAR)
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Alacaklarım',
                    amount: toplamAlacaklarim,
                    total: toplamAlacaklarim + toplamBorclarim,
                    color: green,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
                const SizedBox(width: 20),
                // SAĞ TARAF (BORÇLAR)
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Borçlarım',
                    amount: toplamBorclarim,
                    total: toplamAlacaklarim + toplamBorclarim,
                    color: red,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
              ],
            ),
          if ((toplamAlacaklarim > 0 || toplamBorclarim > 0) &&
              (toplamNotAlacaklarim > 0 || toplamNotBorclarim > 0))
            const SizedBox(height: 12),
          if (toplamNotAlacaklarim > 0 || toplamNotBorclarim > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SOL TARAF (NOT ALACAKLAR)
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Not Alacaklarım',
                    amount: toplamNotAlacaklarim,
                    total: toplamNotAlacaklarim + toplamNotBorclarim,
                    color: blue,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
                const SizedBox(width: 20),
                // SAĞ TARAF (NOT BORÇLAR)
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Not Borçlarım',
                    amount: toplamNotBorclarim,
                    total: toplamNotAlacaklarim + toplamNotBorclarim,
                    color: orange,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBarGraphItem({
    required String title,
    required double amount,
    required double total,
    required Color color,
    required bool isDark,
    required Color textMain,
    required Color textSec,
  }) {
    final factor = total > 0 ? amount / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.transparent, // Arka planı şeffaf yap
            border: Border.all(
              color: isDark
                  ? Colors.grey[700]!
                  : Colors.grey[300]!, // Çerçeve rengi
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: factor,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AutoSizeText(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: textSec,
          ),
          maxLines: 1,
          minFontSize: 8,
          overflow: TextOverflow.ellipsis,
        ),
        GestureDetector(
          onTap: () {
            _showCustomTooltip(
              context,
              '${amount.toStringAsFixed(2)}₺',
              title: title,
            );
          },
          onLongPress: () {
            _showCustomTooltip(
              context,
              '${amount.toStringAsFixed(2)}₺',
              title: title,
            );
          },
          child: MouseRegion(
            onEnter: (_) {
              if (Theme.of(context).platform == TargetPlatform.windows ||
                  Theme.of(context).platform == TargetPlatform.macOS ||
                  Theme.of(context).platform == TargetPlatform.linux) {
                _showCustomTooltip(
                  context,
                  '${amount.toStringAsFixed(2)}₺',
                  title: title,
                );
              }
            },
            child: AutoSizeText(
              formatNumber(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textMain,
              ),
              maxLines: 1,
              minFontSize: 9,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnayliAnalizKarti(
    Color cardColor,
    Color textMain,
    Color textSec,
    Color red,
    Color green,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onaylı İşlemler',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: textMain,
            ),
          ),
          const SizedBox(height: 16),
          // Grafik
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent || event is FlLongPressEnd) {
                          _showPieTooltip(context, pieTouchResponse, [
                            {
                              'name': 'Onaylı Borçlarım',
                              'value': onayliToplamBorclarim,
                              'color': red,
                            },
                            {
                              'name': 'Onaylı Alacaklarım',
                              'value': onayliToplamAlacaklarim,
                              'color': green,
                            },
                          ]);
                        }
                      },
                    ),
                    sections: [
                      if (onayliToplamBorclarim > 0)
                        PieChartSectionData(
                          color: red,
                          value: onayliToplamBorclarim,
                          title: '',
                          radius: 55,
                          showTitle: false,
                        ),
                      if (onayliToplamAlacaklarim > 0)
                        PieChartSectionData(
                          color: green,
                          value: onayliToplamAlacaklarim,
                          title: '',
                          radius: 55,
                          showTitle: false,
                        ),
                      if (onayliToplamBorclarim == 0 &&
                          onayliToplamAlacaklarim == 0)
                        PieChartSectionData(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          value: 1,
                          title: '',
                          radius: 55,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                // Ortadaki toplam bakiye
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final fullAmount =
                              onayliToplamAlacaklarim - onayliToplamBorclarim;
                          _showCustomTooltip(
                            context,
                            '${fullAmount.toStringAsFixed(2)}₺',
                            title: 'Onaylı Net Durum',
                          );
                        },
                        onLongPress: () {
                          final fullAmount =
                              onayliToplamAlacaklarim - onayliToplamBorclarim;
                          _showCustomTooltip(
                            context,
                            '${fullAmount.toStringAsFixed(2)}₺',
                            title: 'Onaylı Net Durum',
                          );
                        },
                        child: MouseRegion(
                          onEnter: (_) {
                            if (Theme.of(context).platform ==
                                    TargetPlatform.windows ||
                                Theme.of(context).platform ==
                                    TargetPlatform.macOS ||
                                Theme.of(context).platform ==
                                    TargetPlatform.linux) {
                              final fullAmount =
                                  onayliToplamAlacaklarim -
                                  onayliToplamBorclarim;
                              _showCustomTooltip(
                                context,
                                '${fullAmount.toStringAsFixed(2)}₺',
                                title: 'Onaylı Net Durum',
                              );
                            }
                          },
                          child: AutoSizeText(
                            formatNumber(
                              onayliToplamAlacaklarim - onayliToplamBorclarim,
                            ),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            minFontSize: 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AutoSizeText(
                        'Net Durum',
                        style: TextStyle(fontSize: 9, color: textSec),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        minFontSize: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(), // DİNAMİK BOŞLUK
          // Bar Graph
          if (onayliToplamAlacaklarim > 0 || onayliToplamBorclarim > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Alacaklar',
                    amount: onayliToplamAlacaklarim,
                    total: onayliToplamAlacaklarim + onayliToplamBorclarim,
                    color: green,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Borçlarım',
                    amount: onayliToplamBorclarim,
                    total: onayliToplamAlacaklarim + onayliToplamBorclarim,
                    color: red,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNotAnalizKarti(
    Color cardColor,
    Color textMain,
    Color textSec,
    Color blue,
    Color orange,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not İşlemleri',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: textMain,
            ),
          ),
          const SizedBox(height: 16),
          // Grafik
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent || event is FlLongPressEnd) {
                          _showPieTooltip(context, pieTouchResponse, [
                            {
                              'name': 'Not Alacaklarım',
                              'value': toplamNotAlacaklarim,
                              'color': blue,
                            },
                            {
                              'name': 'Not Borçlarım',
                              'value': toplamNotBorclarim,
                              'color': orange,
                            },
                          ]);
                        }
                      },
                    ),
                    sections: [
                      if (toplamNotAlacaklarim > 0)
                        PieChartSectionData(
                          color: blue,
                          value: toplamNotAlacaklarim,
                          title: '',
                          radius: 55,
                          showTitle: false,
                        ),
                      if (toplamNotBorclarim > 0)
                        PieChartSectionData(
                          color: orange,
                          value: toplamNotBorclarim,
                          title: '',
                          radius: 55,
                          showTitle: false,
                        ),
                      if (toplamNotAlacaklarim == 0 && toplamNotBorclarim == 0)
                        PieChartSectionData(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          value: 1,
                          title: '',
                          radius: 55,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                // Ortadaki toplam bakiye
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final fullAmount =
                              toplamNotAlacaklarim - toplamNotBorclarim;
                          _showCustomTooltip(
                            context,
                            '${fullAmount.toStringAsFixed(2)}₺',
                            title: 'Not Net Durum',
                          );
                        },
                        onLongPress: () {
                          final fullAmount =
                              toplamNotAlacaklarim - toplamNotBorclarim;
                          _showCustomTooltip(
                            context,
                            '${fullAmount.toStringAsFixed(2)}₺',
                            title: 'Not Net Durum',
                          );
                        },
                        child: MouseRegion(
                          onEnter: (_) {
                            if (Theme.of(context).platform ==
                                    TargetPlatform.windows ||
                                Theme.of(context).platform ==
                                    TargetPlatform.macOS ||
                                Theme.of(context).platform ==
                                    TargetPlatform.linux) {
                              final fullAmount =
                                  toplamNotAlacaklarim - toplamNotBorclarim;
                              _showCustomTooltip(
                                context,
                                '${fullAmount.toStringAsFixed(2)}₺',
                                title: 'Not Net Durum',
                              );
                            }
                          },
                          child: AutoSizeText(
                            formatNumber(
                              toplamNotAlacaklarim - toplamNotBorclarim,
                            ),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            minFontSize: 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AutoSizeText(
                        'Not Net Durum',
                        style: TextStyle(fontSize: 9, color: textSec),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        minFontSize: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(), // DİNAMİK BOŞLUK
          // Bar Graph
          if (toplamNotAlacaklarim > 0 || toplamNotBorclarim > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Not Alacaklarım',
                    amount: toplamNotAlacaklarim,
                    total: toplamNotAlacaklarim + toplamNotBorclarim,
                    color: blue,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildBarGraphItem(
                    title: 'Not Borçlarım',
                    amount: toplamNotBorclarim,
                    total: toplamNotAlacaklarim + toplamNotBorclarim,
                    color: orange,
                    isDark: isDark,
                    textMain: textMain,
                    textSec: textSec,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
