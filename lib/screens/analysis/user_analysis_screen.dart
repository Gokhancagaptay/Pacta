import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';

class UserAnalysisScreen extends StatefulWidget {
  const UserAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<UserAnalysisScreen> createState() => _UserAnalysisScreenState();
}

class _UserAnalysisScreenState extends State<UserAnalysisScreen> {
  bool isLoading = true;
  double toplamBorclarim = 0;
  double toplamAlacaklarim = 0;
  double toplamNotAlacaklarim = 0;
  double toplamNotBorclarim = 0;
  List<Map<String, dynamic>> tumIslemler = [];

  // Filtreleme değişkenleri
  String selectedTransactionType = 'Tümü';
  String selectedStatus = 'Tümü';
  String selectedDateRange = 'Tüm Zamanlar';
  List<Map<String, dynamic>> filteredIslemler = [];

  @override
  void initState() {
    super.initState();
    print('UserAnalysisScreen: initState başladı');
    fetchUserAnalysis();
  }

  Future<void> fetchUserAnalysis() async {
    print('UserAnalysisScreen: fetchUserAnalysis() başladı');

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      print('UserAnalysisScreen: currentUserId: $currentUserId');

      if (currentUserId == null) {
        print('UserAnalysisScreen: currentUserId null!');
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Tüm borçları çek
      final firestore = FirebaseFirestore.instance;
      final debtsCollection = firestore.collection('debts');
      final allDebtsSnap = await debtsCollection.get();

      print('UserAnalysisScreen: Tüm borçlar: ${allDebtsSnap.docs.length}');

      // Değişkenleri tanımla
      double borc = 0;
      double alacak = 0;
      double notAlacak = 0;
      double notBorc = 0;
      List<Map<String, dynamic>> tempIslemler = [];

      // Tüm işlemleri işle
      for (final doc in allDebtsSnap.docs) {
        final data = doc.data();
        final borcluId = data['borcluId'];
        final alacakliId = data['alacakliId'];
        final status = data['status']?.toString().toLowerCase() ?? '';

        // Sadece mevcut kullanıcının işlemleri
        if (borcluId == currentUserId || alacakliId == currentUserId) {
          print(
            'UserAnalysisScreen: İşlem bulundu - miktar: ${data['miktar']}, status: ${data['status']}, borcluId: $borcluId, alacakliId: $alacakliId',
          );

          tempIslemler.add({
            'debtId': doc.id,
            'miktar': data['miktar'],
            'tarih': data['islemTarihi'],
            'status': data['status'] ?? 'pending',
            'aciklama': data['aciklama'] ?? '',
            'borcluId': borcluId,
            'alacakliId': alacakliId,
          });

          // Not işlemleri
          if (status == 'note' || status == 'not' || status == 'notes') {
            if (borcluId == currentUserId) {
              // Ben borçluyum
              notBorc += (data['miktar'] as num).toDouble();
              print(
                'UserAnalysisScreen: Not borç eklendi - miktar: ${data['miktar']}, toplam not borç: $notBorc',
              );
            } else if (alacakliId == currentUserId) {
              // Ben alacaklıyım
              notAlacak += (data['miktar'] as num).toDouble();
              print(
                'UserAnalysisScreen: Not alacak eklendi - miktar: ${data['miktar']}, toplam not alacak: $notAlacak',
              );
            }
          } else {
            // Normal işlemler
            if (borcluId == currentUserId) {
              borc += (data['miktar'] as num).toDouble();
              print(
                'UserAnalysisScreen: Borç eklendi - miktar: ${data['miktar']}, toplam borç: $borc',
              );
            } else if (alacakliId == currentUserId) {
              alacak += (data['miktar'] as num).toDouble();
              print(
                'UserAnalysisScreen: Alacak eklendi - miktar: ${data['miktar']}, toplam alacak: $alacak',
              );
            }
          }
        }
      }

      print(
        'UserAnalysisScreen: Final hesaplama - borç: $borc, alacak: $alacak, not alacak: $notAlacak, not borç: $notBorc',
      );

      setState(() {
        toplamBorclarim = borc;
        toplamAlacaklarim = alacak;
        toplamNotAlacaklarim = notAlacak;
        toplamNotBorclarim = notBorc;
        tumIslemler = tempIslemler;
        filteredIslemler = tempIslemler;
        isLoading = false;
      });

      print('UserAnalysisScreen: setState tamamlandı');
    } catch (e) {
      print('UserAnalysisScreen: HATA! $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      filteredIslemler = tumIslemler.where((islem) {
        final status = islem['status']?.toString().toLowerCase() ?? '';
        final isBorc =
            islem['borcluId'] == FirebaseAuth.instance.currentUser?.uid;

        // Transaction Type filtresi
        if (selectedTransactionType != 'Tümü') {
          if (selectedTransactionType == 'Sadece Borçlar' && !isBorc) {
            return false;
          }
          if (selectedTransactionType == 'Sadece Alacaklar' && isBorc) {
            return false;
          }
        }

        // Status filtresi
        if (selectedStatus != 'Tümü') {
          if (selectedStatus == 'Onaylananlar' && status != 'approved') {
            return false;
          }
          if (selectedStatus == 'Notlar' &&
              (status != 'note' && status != 'not' && status != 'notes')) {
            return false;
          }
        }

        // Date Range filtresi
        if (selectedDateRange != 'Tüm Zamanlar') {
          final islemTarihi = islem['tarih'];
          if (islemTarihi != null) {
            DateTime? tarih;
            try {
              if (islemTarihi is String) {
                tarih = DateTime.parse(islemTarihi);
              } else if (islemTarihi is Timestamp) {
                tarih = (islemTarihi as Timestamp).toDate();
              }
            } catch (e) {
              print('UserAnalysisScreen: Tarih parse hatası: $e');
              tarih = DateTime.now();
            }

            if (tarih != null) {
              final now = DateTime.now();
              if (selectedDateRange == 'Son 1 Hafta') {
                final birHaftaOnce = now.subtract(const Duration(days: 7));
                if (tarih.isBefore(birHaftaOnce)) return false;
              } else if (selectedDateRange == 'Son 1 Ay') {
                final birAyOnce = now.subtract(const Duration(days: 30));
                if (tarih.isBefore(birAyOnce)) return false;
              }
            }
          }
        }

        return true;
      }).toList();
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  const Icon(Icons.filter_list, color: Color(0xFF667eea)),
                  const SizedBox(width: 8),
                  const Text(
                    'Filtrele',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedTransactionType = 'Tümü';
                        selectedStatus = 'Tümü';
                        selectedDateRange = 'Tüm Zamanlar';
                        filteredIslemler = tumIslemler;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Sıfırla'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // İşlem Türü
              const Text(
                'İşlem Türü',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Tümü', 'Sadece Borçlar', 'Sadece Alacaklar'].map((
                  type,
                ) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: selectedTransactionType == type,
                    onSelected: (selected) {
                      setState(() {
                        selectedTransactionType = type;
                        _applyFilters();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Durum
              const Text(
                'Durum',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Tümü', 'Onaylananlar', 'Notlar'].map((status) {
                  return ChoiceChip(
                    label: Text(status),
                    selected: selectedStatus == status,
                    onSelected: (selected) {
                      setState(() {
                        selectedStatus = status;
                        _applyFilters();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Tarih Aralığı
              const Text(
                'Tarih Aralığı',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Tüm Zamanlar', 'Son 1 Hafta', 'Son 1 Ay'].map((
                  range,
                ) {
                  return ChoiceChip(
                    label: Text(range),
                    selected: selectedDateRange == range,
                    onSelected: (selected) {
                      setState(() {
                        selectedDateRange = range;
                        _applyFilters();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionDetail(Map<String, dynamic> islem) {
    print('UserAnalysisScreen: İşlem detayına tıklandı: $islem');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      // İşlem verilerini DebtModel formatına uygun hale getiriyorum
      final debtData = Map<String, dynamic>.from(islem);

      // debtId'yi doğru şekilde set ediyorum
      debtData['debtId'] = debtData['debtId'] ?? debtData['id'] ?? '';

      // Eksik alanları varsayılan değerlerle dolduruyorum
      debtData['isShared'] = debtData['isShared'] ?? false;
      debtData['requiresApproval'] = debtData['requiresApproval'] ?? false;
      debtData['visibleTo'] = debtData['visibleTo'] ?? [];
      debtData['createdBy'] = debtData['createdBy'] ?? '';

      // Tarih alanını kontrol ediyorum
      if (debtData['islemTarihi'] == null && debtData['tarih'] != null) {
        debtData['islemTarihi'] = debtData['tarih'];
      }

      print('UserAnalysisScreen: DebtModel için hazırlanan veri: $debtData');

      final debt = DebtModel.fromMap(debtData);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransactionDetailScreen(debt: debt, userId: currentUserId),
        ),
      );
    } catch (e) {
      print('UserAnalysisScreen: İşlem detayı hatası: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem detayı açılamadı: $e')));
    }
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
            icon: Icon(Icons.share, color: iconShare, size: 20),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paylaşım özelliği yakında')),
              );
            },
          ),
        ],
      ),
      body: isLoading
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
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 100,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pasta Grafik
                  Container(
                    height: 380,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(20),
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
                        const SizedBox(height: 20),
                        // Grafik
                        SizedBox(
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 45,
                                  sections: [
                                    if (toplamBorclarim > 0)
                                      PieChartSectionData(
                                        color: red,
                                        value: toplamBorclarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (toplamAlacaklarim > 0)
                                      PieChartSectionData(
                                        color: green,
                                        value: toplamAlacaklarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (toplamNotAlacaklarim > 0)
                                      PieChartSectionData(
                                        color: blue,
                                        value: toplamNotAlacaklarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (toplamNotBorclarim > 0)
                                      PieChartSectionData(
                                        color: orange,
                                        value: toplamNotBorclarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (toplamBorclarim == 0 &&
                                        toplamAlacaklarim == 0 &&
                                        toplamNotAlacaklarim == 0 &&
                                        toplamNotBorclarim == 0)
                                      PieChartSectionData(
                                        color: isDark
                                            ? Colors.grey[800]!
                                            : Colors.grey,
                                        value: 1,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                  ],
                                ),
                              ),
                              // Ortadaki toplam bakiye
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF23262F)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${(toplamAlacaklarim - toplamBorclarim).toStringAsFixed(2)}₺',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A202C),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      toplamAlacaklarim - toplamBorclarim >= 0
                                          ? 'Alacaklısın'
                                          : 'Borçlusun',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey[500],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Bar Graph
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor:
                                          toplamBorclarim > 0 ||
                                              toplamAlacaklarim > 0 ||
                                              toplamNotAlacaklarim > 0 ||
                                              toplamNotBorclarim > 0
                                          ? toplamBorclarim /
                                                (toplamBorclarim +
                                                    toplamAlacaklarim +
                                                    toplamNotAlacaklarim +
                                                    toplamNotBorclarim)
                                          : 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: red,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Borçlarım',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                      color: textSec,
                                    ),
                                  ),
                                  Text(
                                    '${toplamBorclarim.toStringAsFixed(2)}₺',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textMain,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor:
                                          toplamBorclarim > 0 ||
                                              toplamAlacaklarim > 0 ||
                                              toplamNotAlacaklarim > 0 ||
                                              toplamNotBorclarim > 0
                                          ? toplamAlacaklarim /
                                                (toplamBorclarim +
                                                    toplamAlacaklarim +
                                                    toplamNotAlacaklarim +
                                                    toplamNotBorclarim)
                                          : 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: green,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Alacaklarım',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                      color: textSec,
                                    ),
                                  ),
                                  Text(
                                    '${toplamAlacaklarim.toStringAsFixed(2)}₺',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textMain,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (toplamNotAlacaklarim > 0 ||
                            toplamNotBorclarim > 0) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: toplamNotAlacaklarim > 0
                                            ? toplamNotAlacaklarim /
                                                  (toplamNotAlacaklarim +
                                                      toplamNotBorclarim)
                                            : 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: blue,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Not Alacaklarım',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                        color: textSec,
                                      ),
                                    ),
                                    Text(
                                      '${toplamNotAlacaklarim.toStringAsFixed(2)}₺',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textMain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: toplamNotBorclarim > 0
                                            ? toplamNotBorclarim /
                                                  (toplamNotAlacaklarim +
                                                      toplamNotBorclarim)
                                            : 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: orange,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Not Borçlarım',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                        color: textSec,
                                      ),
                                    ),
                                    Text(
                                      '${toplamNotBorclarim.toStringAsFixed(2)}₺',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textMain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // İşlemler Listesi
                  Container(
                    height: 400,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(24),
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
                        // Başlık
                        Row(
                          children: [
                            Text(
                              'Tüm İşlemler',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filteredIslemler.length} işlem',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showFilterBottomSheet(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.filter_list,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // İşlemler Listesi - Scrollable
                        Expanded(
                          child: filteredIslemler.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inbox_outlined,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Henüz işlem yok',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Henüz borç/alacak işlemi yapılmamış',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: filteredIslemler.length,
                                  itemBuilder: (context, index) {
                                    final islem = filteredIslemler[index];
                                    final isBorc =
                                        islem['borcluId'] ==
                                        FirebaseAuth.instance.currentUser?.uid;
                                    final miktar = islem['miktar'] ?? 0;
                                    final status = islem['status'] ?? '';
                                    final aciklama = islem['aciklama'] ?? '';

                                    // Tarih formatını düzelt
                                    DateTime? tarih;
                                    try {
                                      if (islem['tarih'] is String) {
                                        tarih = DateTime.parse(islem['tarih']);
                                      } else if (islem['tarih'] is Timestamp) {
                                        tarih = (islem['tarih'] as Timestamp)
                                            .toDate();
                                      }
                                    } catch (e) {
                                      print(
                                        'UserAnalysisScreen: Tarih parse hatası: $e',
                                      );
                                      tarih = DateTime.now();
                                    }

                                    return InkWell(
                                      onTap: () =>
                                          _showTransactionDetail(islem),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          bottom:
                                              index ==
                                                  filteredIslemler.length - 1
                                              ? 0
                                              : 12,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: cardInnerColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.grey[800]!
                                                : Colors.grey[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // İkon
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: isBorc
                                                  ? (islem['status'] == 'note'
                                                        ? orange.withOpacity(
                                                            0.18,
                                                          )
                                                        : red.withOpacity(0.18))
                                                  : (islem['status'] == 'note'
                                                        ? blue.withOpacity(0.18)
                                                        : green.withOpacity(
                                                            0.18,
                                                          )),
                                              child: Icon(
                                                isBorc
                                                    ? (islem['status'] == 'note'
                                                          ? Icons.note_rounded
                                                          : Icons
                                                                .arrow_upward_rounded)
                                                    : (islem['status'] == 'note'
                                                          ? Icons.note_rounded
                                                          : Icons
                                                                .arrow_downward_rounded),
                                                color: isBorc
                                                    ? (islem['status'] == 'note'
                                                          ? orange
                                                          : red)
                                                    : (islem['status'] == 'note'
                                                          ? blue
                                                          : green),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // İçerik
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    isBorc
                                                        ? (islem['status'] ==
                                                                  'note'
                                                              ? 'Not Borcun: ${miktar.toStringAsFixed(2)}₺'
                                                              : 'Senin Borcun: ${miktar.toStringAsFixed(2)}₺')
                                                        : (islem['status'] ==
                                                                  'note'
                                                              ? 'Not Alacağın: ${miktar.toStringAsFixed(2)}₺'
                                                              : 'Senin Alacağın: ${miktar.toStringAsFixed(2)}₺'),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: textMain,
                                                    ),
                                                  ),
                                                  if (aciklama.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      aciklama,
                                                      style: TextStyle(
                                                        color: textSec,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .access_time_rounded,
                                                        size: 14,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        tarih != null
                                                            ? '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year} ${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}'
                                                            : '',
                                                        style: TextStyle(
                                                          color: textSec,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Durum etiketi
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: status == 'approved'
                                                    ? green
                                                    : status == 'pending'
                                                    ? orange
                                                    : status == 'note'
                                                    ? (isBorc ? orange : blue)
                                                    : red,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status == 'approved'
                                                    ? 'Onaylandı'
                                                    : status == 'pending'
                                                    ? 'Beklemede'
                                                    : status == 'note'
                                                    ? (isBorc
                                                          ? 'Not Borç'
                                                          : 'Not Alacak')
                                                    : 'Reddedildi',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
