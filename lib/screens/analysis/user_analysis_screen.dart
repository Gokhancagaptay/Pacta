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
import 'dart:async';
import 'package:pacta/widgets/custom_date_range_picker.dart';

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

  // Filtreleme değişkenleri
  String selectedTransactionType = 'Tümü';
  String selectedStatus = 'Tümü';
  String selectedDateRange = 'Tüm Zamanlar';
  DateTimeRange? customDateRange;

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

  // Modern Baloncuk Tooltip - Overlay ile pozisyonlu gösterim
  OverlayEntry? _currentTooltip;

  void _showCustomTooltip(
    BuildContext context,
    String fullAmount, {
    String? title,
    GlobalKey? targetKey,
  }) {
    try {
      // Önceki tooltip varsa kapat
      _hideCurrentTooltip();

      final isDark = Theme.of(context).brightness == Brightness.dark;

      print('Baloncuk tooltip tetiklendi: $fullAmount');

      // Target widget'ın pozisyonunu bul
      RenderBox? targetRenderBox;
      Offset targetPosition = Offset.zero;
      Size targetSize = Size.zero;

      if (targetKey?.currentContext != null) {
        targetRenderBox =
            targetKey!.currentContext!.findRenderObject() as RenderBox?;
        if (targetRenderBox != null) {
          targetPosition = targetRenderBox.localToGlobal(Offset.zero);
          targetSize = targetRenderBox.size;
        }
      }

      // Overlay entry oluştur
      _currentTooltip = OverlayEntry(
        builder: (context) => _BubbleTooltip(
          position: targetPosition,
          targetSize: targetSize,
          fullAmount: fullAmount,
          title: title,
          isDark: isDark,
          onDismiss: _hideCurrentTooltip,
        ),
      );

      // Overlay'e ekle
      Overlay.of(context).insert(_currentTooltip!);

      // 3 saniye sonra otomatik kapat
      Timer(const Duration(seconds: 3), () {
        _hideCurrentTooltip();
      });

      print('Baloncuk tooltip gösterildi: $fullAmount');
    } catch (e) {
      print('Tooltip gösterme hatası: $e');

      // Fallback: basit SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${title ?? "Tam Tutar"}: $fullAmount'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _hideCurrentTooltip() {
    _currentTooltip?.remove();
    _currentTooltip = null;
  }

  void _applyFilters() {
    setState(() {
      List<Map<String, dynamic>> baseFilteredIslemler;

      // Adım 1: Mevcut sayfaya göre temel filtreleme
      switch (_currentPage) {
        case 1: // Onaylı İşlemler
          baseFilteredIslemler = tumIslemler
              .where((islem) => islem['status'] == 'approved')
              .toList();
          break;
        case 2: // Not İşlemleri
          baseFilteredIslemler = tumIslemler.where((islem) {
            final status = islem['status']?.toString().toLowerCase() ?? '';
            return status == 'note' || status == 'not' || status == 'notes';
          }).toList();
          break;
        default: // Genel Durum (Tüm İşlemler)
          baseFilteredIslemler = List.from(tumIslemler);
          break;
      }

      // Adım 2: Kullanıcı tarafından seçilen ek filtreleri uygula
      filteredIslemler = baseFilteredIslemler.where((islem) {
        final isBorc =
            islem['borcluId'] == FirebaseAuth.instance.currentUser?.uid;

        // İşlem Türü Filtresi
        if (selectedTransactionType != 'Tümü') {
          if (selectedTransactionType == 'Sadece Borçlar' && !isBorc) {
            return false;
          }
          if (selectedTransactionType == 'Sadece Alacaklar' && isBorc) {
            return false;
          }
        }

        // Durum Filtresi (Sadece Genel Durum sayfasında aktif)
        if (_currentPage == 0 && selectedStatus != 'Tümü') {
          final status = islem['status']?.toString().toLowerCase() ?? '';
          if (selectedStatus == 'Onaylananlar' && status != 'approved') {
            return false;
          }
          if (selectedStatus == 'Notlar' &&
              (status != 'note' && status != 'not' && status != 'notes')) {
            return false;
          }
        }

        // Tarih Aralığı Filtresi
        if (selectedDateRange != 'Tüm Zamanlar') {
          final islemTarihi = islem['tarih'] ?? islem['islemTarihi'];
          if (islemTarihi == null) return false;

          DateTime? tarih;
          try {
            if (islemTarihi is DateTime) {
              tarih = islemTarihi;
            } else if (islemTarihi is String) {
              tarih = DateTime.parse(islemTarihi);
            } else if (islemTarihi is Timestamp) {
              tarih = islemTarihi.toDate();
            }
          } catch (e) {
            print('UserAnalysisScreen: Tarih parse hatası: $e');
          }

          if (tarih == null) return false;

          final now = DateTime.now();
          if (selectedDateRange == 'Son 1 Hafta') {
            if (tarih.isBefore(now.subtract(const Duration(days: 7))) ||
                tarih.isAfter(now.add(const Duration(days: 7)))) {
              return false;
            }
          } else if (selectedDateRange == 'Son 1 Ay') {
            if (tarih.isBefore(now.subtract(const Duration(days: 30))) ||
                tarih.isAfter(now.add(const Duration(days: 30)))) {
              return false;
            }
          } else if (selectedDateRange == 'Tarih Seç' &&
              customDateRange != null) {
            final start = DateTime(
              customDateRange!.start.year,
              customDateRange!.start.month,
              customDateRange!.start.day,
            );
            final end = DateTime(
              customDateRange!.end.year,
              customDateRange!.end.month,
              customDateRange!.end.day,
              23,
              59,
              59,
            );
            if (tarih.isBefore(start) || tarih.isAfter(end)) {
              return false;
            }
          }
        }

        return true;
      }).toList();
    });
  }

  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String tempSelectedTransactionType = selectedTransactionType;
        String tempSelectedStatus = selectedStatus;
        String tempSelectedDateRange = selectedDateRange;
        DateTimeRange? tempCustomDateRange = customDateRange;
        final size = MediaQuery.of(context).size;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final backgroundColor = isDark
                ? const Color(0xFF2D3748)
                : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF1A202C);
            final primaryColor = const Color(0xFF6366F1);

            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size.width * 0.06),
                  topRight: Radius.circular(size.width * 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      size.height * 0.025,
                  top: size.height * 0.025,
                  left: size.width * 0.06,
                  right: size.width * 0.06,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          color: textColor.withOpacity(0.8),
                          size: size.width * 0.06,
                        ),
                        SizedBox(width: size.width * 0.03),
                        Text(
                          'Filtrele',
                          style: TextStyle(
                            fontSize: size.width * 0.055,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSelectedTransactionType = 'Tümü';
                              tempSelectedStatus = 'Tümü';
                              tempSelectedDateRange = 'Tüm Zamanlar';
                              tempCustomDateRange = null;
                            });
                          },
                          child: Text(
                            'Sıfırla',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: size.width * 0.04,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: size.height * 0.03),
                    Text(
                      'İşlem Türü',
                      style: TextStyle(
                        fontSize: size.width * 0.04,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: size.height * 0.015),
                    Wrap(
                      spacing: size.width * 0.02,
                      runSpacing: size.height * 0.01,
                      children: ['Tümü', 'Sadece Borçlar', 'Sadece Alacaklar']
                          .map(
                            (label) => _buildFilterChip(
                              label,
                              tempSelectedTransactionType,
                              primaryColor,
                              (value) => setModalState(
                                () => tempSelectedTransactionType = value,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: size.height * 0.025),
                    if (_currentPage == 0) ...[
                      Text(
                        'Durum',
                        style: TextStyle(
                          fontSize: size.width * 0.04,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: size.height * 0.015),
                      Wrap(
                        spacing: size.width * 0.02,
                        runSpacing: size.height * 0.01,
                        children: ['Tümü', 'Onaylananlar', 'Notlar']
                            .map(
                              (label) => _buildFilterChip(
                                label,
                                tempSelectedStatus,
                                primaryColor,
                                (value) => setModalState(
                                  () => tempSelectedStatus = value,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      SizedBox(height: size.height * 0.025),
                    ],
                    Text(
                      'Tarih Aralığı',
                      style: TextStyle(
                        fontSize: size.width * 0.04,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: size.height * 0.015),
                    Wrap(
                      spacing: size.width * 0.02,
                      runSpacing: size.height * 0.01,
                      children:
                          [
                                'Tüm Zamanlar',
                                'Son 1 Hafta',
                                'Son 1 Ay',
                                'Tarih Seç',
                              ]
                              .map(
                                (label) => _buildFilterChip(
                                  label,
                                  tempSelectedDateRange,
                                  primaryColor,
                                  (value) async {
                                    if (value == 'Tarih Seç') {
                                      final result =
                                          await showCustomDateRangePicker(
                                            context,
                                            initialDateRange:
                                                tempCustomDateRange,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now(),
                                            helpText:
                                                'Analiz için tarih aralığı seçin',
                                            cancelText: 'İptal',
                                            confirmText: 'Uygula',
                                          );
                                      if (result != null) {
                                        setModalState(() {
                                          tempSelectedDateRange = value;
                                          tempCustomDateRange = result;
                                        });
                                      }
                                    } else {
                                      setModalState(() {
                                        tempSelectedDateRange = value;
                                        tempCustomDateRange = null;
                                      });
                                    }
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    SizedBox(height: size.height * 0.04),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedTransactionType =
                                tempSelectedTransactionType;
                            selectedStatus = tempSelectedStatus;
                            selectedDateRange = tempSelectedDateRange;
                            customDateRange = tempCustomDateRange;
                            _applyFilters();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: size.height * 0.02,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              size.width * 0.04,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Filtreyi Uygula',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: size.width * 0.04,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    String selectedValue,
    Color primaryColor,
    Function(String) onTap,
  ) {
    final isSelected = selectedValue == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.01,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.grey[700] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(size.width * 0.05),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: size.width * 0.035,
          ),
        ),
      ),
    );
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
    _hideCurrentTooltip();
    _pageController.dispose();
    super.dispose();
  }

  /// Ana analiz verilerini getiren metod
  Future<void> fetchUserAnalysis() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final analysisData = await _loadUserAnalysisData(currentUserId);

      if (mounted) {
        setState(() {
          toplamBorclarim = analysisData.borclarim;
          toplamAlacaklarim = analysisData.alacaklarim;
          toplamNotBorclarim = analysisData.notBorclarim;
          toplamNotAlacaklarim = analysisData.notAlacaklarim;
          onayliToplamBorclarim = analysisData.onayliBorclarim;
          onayliToplamAlacaklarim = analysisData.onayliAlacaklarim;
          tumIslemler = analysisData.islemler;
          filteredIslemler = List.from(tumIslemler);
          isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      print('Analysis fetch error: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veriler yüklenirken hata oluştu.')),
        );
      }
    }
  }

  /// Kullanıcı analiz verilerini yükleyen metod
  Future<_AnalysisData> _loadUserAnalysisData(String currentUserId) async {
    double tempBorclarim = 0;
    double tempAlacaklarim = 0;
    double tempNotBorclarim = 0;
    double tempNotAlacaklarim = 0;
    double tempOnayliBorclarim = 0;
    double tempOnayliAlacaklarim = 0;
    List<Map<String, dynamic>> tempIslemler = [];
    final Map<String, String> nameCache = {};

    final allDebtsSnap = await FirebaseFirestore.instance
        .collection('debts')
        .where('visibleto', arrayContains: currentUserId)
        .get();

    for (var doc in allDebtsSnap.docs) {
      final data = doc.data();
      final borcluId = data['borcluId'] as String?;
      final alacakliId = data['alacakliId'] as String?;

      // Skip if user is not involved
      if (borcluId != currentUserId && alacakliId != currentUserId) continue;

      final debtInfo = await _processDebtDocument(
        doc.id,
        data,
        currentUserId,
        nameCache,
      );

      // Update totals
      _updateTotals(
        debtInfo,
        currentUserId,
        tempBorclarim: () => tempBorclarim += debtInfo.miktar,
        tempAlacaklarim: () => tempAlacaklarim += debtInfo.miktar,
        tempNotBorclarim: () => tempNotBorclarim += debtInfo.miktar,
        tempNotAlacaklarim: () => tempNotAlacaklarim += debtInfo.miktar,
        tempOnayliBorclarim: () => tempOnayliBorclarim += debtInfo.miktar,
        tempOnayliAlacaklarim: () => tempOnayliAlacaklarim += debtInfo.miktar,
      );

      if (debtInfo.status == 'approved' || debtInfo.status == 'note') {
        tempIslemler.add(debtInfo.toMap());
      }
    }

    return _AnalysisData(
      borclarim: tempBorclarim,
      alacaklarim: tempAlacaklarim,
      notBorclarim: tempNotBorclarim,
      notAlacaklarim: tempNotAlacaklarim,
      onayliBorclarim: tempOnayliBorclarim,
      onayliAlacaklarim: tempOnayliAlacaklarim,
      islemler: tempIslemler,
    );
  }

  /// Borç belgesini işleyen metod
  Future<_DebtInfo> _processDebtDocument(
    String docId,
    Map<String, dynamic> data,
    String currentUserId,
    Map<String, String> nameCache,
  ) async {
    final borcluId = data['borcluId'] as String?;
    final alacakliId = data['alacakliId'] as String?;
    final status = data['status']?.toString().toLowerCase() ?? '';
    final miktar = (data['miktar'] as num?)?.toDouble() ?? 0;

    // Parse transaction date
    DateTime? islemTarihi;
    final dynamic islemTarihiData = data['islemTarihi'];
    if (islemTarihiData is Timestamp) {
      islemTarihi = islemTarihiData.toDate();
    } else if (islemTarihiData is String) {
      islemTarihi = DateTime.tryParse(islemTarihiData);
    }

    // Get other party name with caching
    final String otherPartyId = borcluId == currentUserId
        ? (alacakliId ?? '')
        : (borcluId ?? '');

    String otherPartyName = 'Bilinmeyen Kullanıcı';
    if (otherPartyId.isNotEmpty) {
      if (nameCache.containsKey(otherPartyId)) {
        otherPartyName = nameCache[otherPartyId]!;
      } else {
        otherPartyName = await _firestoreService.getUserNameById(otherPartyId);
        nameCache[otherPartyId] = otherPartyName;
      }
    }

    return _DebtInfo(
      debtId: docId,
      miktar: miktar,
      tarih: islemTarihi,
      status: status,
      aciklama: data['aciklama'] ?? '',
      borcluId: borcluId,
      alacakliId: alacakliId,
      otherPartyName: otherPartyName,
    );
  }

  /// Toplamları güncelleyen metod
  void _updateTotals(
    _DebtInfo debtInfo,
    String currentUserId, {
    required VoidCallback tempBorclarim,
    required VoidCallback tempAlacaklarim,
    required VoidCallback tempNotBorclarim,
    required VoidCallback tempNotAlacaklarim,
    required VoidCallback tempOnayliBorclarim,
    required VoidCallback tempOnayliAlacaklarim,
  }) {
    final status = debtInfo.status;
    final borcluId = debtInfo.borcluId;
    final alacakliId = debtInfo.alacakliId;

    if (status == 'note') {
      if (borcluId == currentUserId) {
        tempNotBorclarim();
      } else if (alacakliId == currentUserId) {
        tempNotAlacaklarim();
      }
    } else if (status == 'approved') {
      if (borcluId == currentUserId) {
        tempBorclarim();
        tempOnayliBorclarim();
      } else if (alacakliId == currentUserId) {
        tempAlacaklarim();
        tempOnayliAlacaklarim();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bgColor = isDark ? const Color(0xFF181A20) : const Color(0xFFF7F8FC);
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
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
            fontSize: size.width * 0.05,
            fontWeight: FontWeight.w600,
            color: textMain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.description_outlined,
              color: iconShare,
              size: size.width * 0.055,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GenerateDocumentScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: size.height * 0.02),
                      Text(
                        'Analiz yükleniyor...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size.width * 0.04,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    SizedBox(height: size.height * 0.12), // AppBar space
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.05,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: size.height * 0.4,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PageView(
                                    controller: _pageController,
                                    onPageChanged: (page) {
                                      setState(() {
                                        _currentPage = page;
                                        selectedStatus = 'Tümü';
                                        _applyFilters();
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
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Visibility(
                                      visible: _currentPage > 0,
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          left: size.width * 0.02,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.arrow_back_ios_new_rounded,
                                            color: Colors.white,
                                            size: size.width * 0.045,
                                          ),
                                          onPressed: () =>
                                              _pageController.previousPage(
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeInOut,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Visibility(
                                      visible: _currentPage < 2,
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right: size.width * 0.02,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Colors.white,
                                            size: size.width * 0.045,
                                          ),
                                          onPressed: () =>
                                              _pageController.nextPage(
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeInOut,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: size.height * 0.02),
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: size.width * 0.01,
                                ),
                                padding: EdgeInsets.all(size.width * 0.05),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(
                                    size.width * 0.04,
                                  ),
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
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          listTitle,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: size.width * 0.045,
                                            color: textMain,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _showFilterPanel,
                                          child: Row(
                                            children: [
                                              Text(
                                                '${filteredIslemler.length} işlem',
                                                style: TextStyle(
                                                  fontSize: size.width * 0.035,
                                                  color: textSec,
                                                ),
                                              ),
                                              SizedBox(
                                                width: size.width * 0.02,
                                              ),
                                              Icon(
                                                Icons.filter_list,
                                                color: textSec,
                                                size: size.width * 0.05,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: size.height * 0.015),
                                    Expanded(
                                      child: filteredIslemler.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.search_off_rounded,
                                                    size: size.width * 0.15,
                                                    color: textSec.withOpacity(
                                                      0.5,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height: size.height * 0.02,
                                                  ),
                                                  Text(
                                                    'İşlem Bulunamadı',
                                                    style: TextStyle(
                                                      fontSize:
                                                          size.width * 0.045,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: textMain
                                                          .withOpacity(0.8),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height: size.height * 0.005,
                                                  ),
                                                  Text(
                                                    'Bu kritere uygun işlem kaydı yok.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize:
                                                          size.width * 0.035,
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
    final size = MediaQuery.of(context).size;
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
        bottom: index == filteredIslemler.length - 1 ? 0 : size.height * 0.015,
      ),
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: cardInnerColor,
        borderRadius: BorderRadius.circular(size.width * 0.04),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: size.width * 0.055,
            backgroundColor: (isAlacak ? green : red).withOpacity(0.1),
            child: Text(
              otherPartyName.isNotEmpty ? otherPartyName[0].toUpperCase() : '?',
              style: TextStyle(
                color: isAlacak ? green : red,
                fontWeight: FontWeight.bold,
                fontSize: size.width * 0.045,
              ),
            ),
          ),
          SizedBox(width: size.width * 0.03),
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
                          fontSize: size.width * 0.04,
                          color: textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final tooltipKey = GlobalKey();
                        return GestureDetector(
                          onLongPress: () => _showCustomTooltip(
                            context,
                            '${isAlacak ? '+' : '-'}${miktar.toStringAsFixed(2)}₺',
                            title: isAlacak ? 'Alacağınız' : 'Borcunuz',
                            targetKey: tooltipKey,
                          ),
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
                                  targetKey: tooltipKey,
                                );
                              }
                            },
                            child: AutoSizeText(
                              key: tooltipKey,
                              '${isAlacak ? '+' : '-'}${formatNumber(miktar).replaceAll('₺', '')}₺',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: size.width * 0.04,
                                color: isAlacak ? green : red,
                              ),
                              maxLines: 1,
                              minFontSize: 10,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.005),
                Text(
                  aciklama.isNotEmpty ? aciklama : 'Açıklama bulunamadı 🤔',
                  style: TextStyle(
                    fontSize: size.width * 0.035,
                    color: textSec,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: size.height * 0.01),
                Row(
                  children: [
                    Text(
                      tarih != null
                          ? DateFormat('d MMMM yyyy', 'tr_TR').format(tarih)
                          : 'Tarih yok',
                      style: TextStyle(
                        fontSize: size.width * 0.03,
                        color: textSec.withOpacity(0.8),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.025,
                        vertical: size.height * 0.005,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(size.width * 0.03),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: size.width * 0.028,
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
    final size = MediaQuery.of(context).size;

    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(size.width * 0.04),
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
              fontSize: size.width * 0.045,
              color: textMain,
            ),
          ),
          SizedBox(height: size.height * 0.02),
          SizedBox(
            height: size.height * 0.14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: size.width * 0.1,
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
                          radius: size.width * 0.13,
                        ),
                      if (toplamNotAlacaklarim > 0)
                        PieChartSectionData(
                          color: blue,
                          value: toplamNotAlacaklarim,
                          showTitle: false,
                          radius: size.width * 0.13,
                        ),
                      if (toplamBorclarim > 0)
                        PieChartSectionData(
                          color: red,
                          value: toplamBorclarim,
                          showTitle: false,
                          radius: size.width * 0.13,
                        ),
                      if (toplamNotBorclarim > 0)
                        PieChartSectionData(
                          color: orange,
                          value: toplamNotBorclarim,
                          showTitle: false,
                          radius: size.width * 0.13,
                        ),
                      if (toplamBorclarim == 0 &&
                          toplamAlacaklarim == 0 &&
                          toplamNotAlacaklarim == 0 &&
                          toplamNotBorclarim == 0)
                        PieChartSectionData(
                          color: isDark ? Colors.grey[800]! : Colors.grey,
                          value: 1,
                          showTitle: false,
                          radius: size.width * 0.13,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(size.width * 0.02),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final tooltipKey = GlobalKey();
                          return GestureDetector(
                            onLongPress: () {
                              final fullAmount =
                                  (toplamAlacaklarim + toplamNotAlacaklarim) -
                                  (toplamBorclarim + toplamNotBorclarim);
                              _showCustomTooltip(
                                context,
                                '${fullAmount.toStringAsFixed(2)}₺',
                                title: 'Net Bakiye',
                                targetKey: tooltipKey,
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
                                      (toplamAlacaklarim +
                                          toplamNotAlacaklarim) -
                                      (toplamBorclarim + toplamNotBorclarim);
                                  _showCustomTooltip(
                                    context,
                                    '${fullAmount.toStringAsFixed(2)}₺',
                                    title: 'Net Bakiye',
                                    targetKey: tooltipKey,
                                  );
                                }
                              },
                              child: AutoSizeText(
                                key: tooltipKey,
                                formatNumber(
                                  (toplamAlacaklarim + toplamNotAlacaklarim) -
                                      (toplamBorclarim + toplamNotBorclarim),
                                ),
                                style: TextStyle(
                                  fontSize: size.width * 0.045,
                                  fontWeight: FontWeight.bold,
                                  color: textMain,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                minFontSize: 10,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: size.height * 0.0025),
                      AutoSizeText(
                        (toplamAlacaklarim + toplamNotAlacaklarim) -
                                    (toplamBorclarim + toplamNotBorclarim) >=
                                0
                            ? 'Alacaklısın'
                            : 'Borçlusun',
                        style: TextStyle(
                          fontSize: size.width * 0.022,
                          color: textSec,
                        ),
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
          const Spacer(),
          if (toplamAlacaklarim > 0 || toplamBorclarim > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                SizedBox(width: size.width * 0.05),
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
            SizedBox(height: size.height * 0.015),
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
                SizedBox(width: size.width * 0.05),
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
    final size = MediaQuery.of(context).size;
    final factor = total > 0 ? amount / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: size.height * 0.01,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(size.width * 0.01),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: factor,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size.width * 0.01),
              ),
            ),
          ),
        ),
        SizedBox(height: size.height * 0.01),
        AutoSizeText(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: size.width * 0.028,
            color: textSec,
          ),
          maxLines: 1,
          minFontSize: 8,
          overflow: TextOverflow.ellipsis,
        ),
        Builder(
          builder: (context) {
            final tooltipKey = GlobalKey();
            return GestureDetector(
              onLongPress: () => _showCustomTooltip(
                context,
                '${amount.toStringAsFixed(2)}₺',
                title: title,
                targetKey: tooltipKey,
              ),
              child: MouseRegion(
                onEnter: (_) {
                  if (Theme.of(context).platform == TargetPlatform.windows ||
                      Theme.of(context).platform == TargetPlatform.macOS ||
                      Theme.of(context).platform == TargetPlatform.linux) {
                    _showCustomTooltip(
                      context,
                      '${amount.toStringAsFixed(2)}₺',
                      title: title,
                      targetKey: tooltipKey,
                    );
                  }
                },
                child: AutoSizeText(
                  key: tooltipKey,
                  formatNumber(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: size.width * 0.033,
                    color: textMain,
                  ),
                  maxLines: 1,
                  minFontSize: 9,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
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
    final size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(size.width * 0.04),
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
              fontSize: size.width * 0.045,
              color: textMain,
            ),
          ),
          SizedBox(height: size.height * 0.02),
          SizedBox(
            height: size.height * 0.14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: size.width * 0.1,
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
                          radius: size.width * 0.13,
                          showTitle: false,
                        ),
                      if (onayliToplamAlacaklarim > 0)
                        PieChartSectionData(
                          color: green,
                          value: onayliToplamAlacaklarim,
                          title: '',
                          radius: size.width * 0.13,
                          showTitle: false,
                        ),
                      if (onayliToplamBorclarim == 0 &&
                          onayliToplamAlacaklarim == 0)
                        PieChartSectionData(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          value: 1,
                          title: '',
                          radius: size.width * 0.13,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(size.width * 0.02),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final tooltipKey = GlobalKey();
                          return GestureDetector(
                            onLongPress: () {
                              final fullAmount =
                                  onayliToplamAlacaklarim -
                                  onayliToplamBorclarim;
                              _showCustomTooltip(
                                context,
                                '${fullAmount.toStringAsFixed(2)}₺',
                                title: 'Onaylı Net Durum',
                                targetKey: tooltipKey,
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
                                    targetKey: tooltipKey,
                                  );
                                }
                              },
                              child: AutoSizeText(
                                key: tooltipKey,
                                formatNumber(
                                  onayliToplamAlacaklarim -
                                      onayliToplamBorclarim,
                                ),
                                style: TextStyle(
                                  fontSize: size.width * 0.05,
                                  fontWeight: FontWeight.bold,
                                  color: textMain,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                minFontSize: 12,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: size.height * 0.0025),
                      AutoSizeText(
                        'Net Durum',
                        style: TextStyle(
                          fontSize: size.width * 0.022,
                          color: textSec,
                        ),
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
          const Spacer(),
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
                SizedBox(width: size.width * 0.05),
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
    final size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(size.width * 0.04),
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
              fontSize: size.width * 0.045,
              color: textMain,
            ),
          ),
          SizedBox(height: size.height * 0.02),
          SizedBox(
            height: size.height * 0.14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: size.width * 0.1,
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
                          radius: size.width * 0.13,
                          showTitle: false,
                        ),
                      if (toplamNotBorclarim > 0)
                        PieChartSectionData(
                          color: orange,
                          value: toplamNotBorclarim,
                          title: '',
                          radius: size.width * 0.13,
                          showTitle: false,
                        ),
                      if (toplamNotAlacaklarim == 0 && toplamNotBorclarim == 0)
                        PieChartSectionData(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          value: 1,
                          title: '',
                          radius: size.width * 0.13,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(size.width * 0.02),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final tooltipKey = GlobalKey();
                          return GestureDetector(
                            onLongPress: () {
                              final fullAmount =
                                  toplamNotAlacaklarim - toplamNotBorclarim;
                              _showCustomTooltip(
                                context,
                                '${fullAmount.toStringAsFixed(2)}₺',
                                title: 'Not Net Durum',
                                targetKey: tooltipKey,
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
                                    targetKey: tooltipKey,
                                  );
                                }
                              },
                              child: AutoSizeText(
                                key: tooltipKey,
                                formatNumber(
                                  toplamNotAlacaklarim - toplamNotBorclarim,
                                ),
                                style: TextStyle(
                                  fontSize: size.width * 0.05,
                                  fontWeight: FontWeight.bold,
                                  color: textMain,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                minFontSize: 12,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: size.height * 0.0025),
                      AutoSizeText(
                        'Not Net Durum',
                        style: TextStyle(
                          fontSize: size.width * 0.022,
                          color: textSec,
                        ),
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
          const Spacer(),
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
                SizedBox(width: size.width * 0.05),
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

// 🎨 Modern Baloncuk Tooltip Widget
class _BubbleTooltip extends StatefulWidget {
  final Offset position;
  final Size targetSize;
  final String fullAmount;
  final String? title;
  final bool isDark;
  final VoidCallback onDismiss;

  const _BubbleTooltip({
    required this.position,
    required this.targetSize,
    required this.fullAmount,
    this.title,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<_BubbleTooltip> createState() => _BubbleTooltipState();
}

class _BubbleTooltipState extends State<_BubbleTooltip>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon kontrolcüsü
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Büyüme animasyonu
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Opacity animasyonu
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Animasyonu başlat
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ekran boyutları
    final screenSize = MediaQuery.of(context).size;

    // Baloncuk boyutları
    const tooltipWidth = 160.0;
    const tooltipHeight = 60.0;
    const arrowHeight = 8.0;

    // Target'ın merkezi
    final targetCenter = Offset(
      widget.position.dx + (widget.targetSize.width / 2),
      widget.position.dy + (widget.targetSize.height / 2),
    );

    // Baloncuk pozisyonunu hesapla (target'ın üstünde)
    double tooltipX = targetCenter.dx - (tooltipWidth / 2);
    double tooltipY = widget.position.dy - tooltipHeight - arrowHeight - 8;

    // Ekran sınırları kontrolü
    if (tooltipX < 16) tooltipX = 16;
    if (tooltipX + tooltipWidth > screenSize.width - 16) {
      tooltipX = screenSize.width - tooltipWidth - 16;
    }

    // Eğer üstte yer yoksa alt tarafa yerleştir
    bool showBelow = false;
    if (tooltipY < 50) {
      tooltipY =
          widget.position.dy + widget.targetSize.height + arrowHeight + 8;
      showBelow = true;
    }

    // Ok pozisyonu (her zaman target'ın merkezini gösterir)
    final arrowX = targetCenter.dx - tooltipX;

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Stack(
              children: [
                // Baloncuk
                Positioned(
                  left: tooltipX,
                  top: tooltipY,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                        width: tooltipWidth,
                        height: tooltipHeight,
                        child: Stack(
                          children: [
                            // Ana baloncuk gövdesi
                            Container(
                              width: tooltipWidth,
                              height: tooltipHeight,
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? const Color(0xFF2D3748).withOpacity(0.95)
                                    : Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.isDark
                                      ? Colors.grey.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      widget.isDark ? 0.4 : 0.15,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (widget.title != null) ...[
                                    Text(
                                      widget.title!,
                                      style: TextStyle(
                                        color: widget.isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    widget.fullAmount,
                                    style: TextStyle(
                                      color: widget.isDark
                                          ? Colors.white
                                          : const Color(0xFF1A202C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            // Ok (Pointer)
                            Positioned(
                              left: arrowX.clamp(8.0, tooltipWidth - 16.0) - 8,
                              top: showBelow ? -arrowHeight : tooltipHeight,
                              child: CustomPaint(
                                painter: _ArrowPainter(
                                  color: widget.isDark
                                      ? const Color(
                                          0xFF2D3748,
                                        ).withOpacity(0.95)
                                      : Colors.white.withOpacity(0.95),
                                  pointsUp: !showBelow,
                                ),
                                size: const Size(16, 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 🎯 Ok Çizer (Arrow Painter)
class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool pointsUp;

  _ArrowPainter({required this.color, required this.pointsUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (pointsUp) {
      // Yukarı ok
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      // Aşağı ok
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Analiz verilerini tutacak data sınıfı
class _AnalysisData {
  final double borclarim;
  final double alacaklarim;
  final double notBorclarim;
  final double notAlacaklarim;
  final double onayliBorclarim;
  final double onayliAlacaklarim;
  final List<Map<String, dynamic>> islemler;

  const _AnalysisData({
    required this.borclarim,
    required this.alacaklarim,
    required this.notBorclarim,
    required this.notAlacaklarim,
    required this.onayliBorclarim,
    required this.onayliAlacaklarim,
    required this.islemler,
  });
}

/// Borç bilgilerini tutacak data sınıfı
class _DebtInfo {
  final String debtId;
  final double miktar;
  final DateTime? tarih;
  final String status;
  final String aciklama;
  final String? borcluId;
  final String? alacakliId;
  final String otherPartyName;

  const _DebtInfo({
    required this.debtId,
    required this.miktar,
    required this.tarih,
    required this.status,
    required this.aciklama,
    required this.borcluId,
    required this.alacakliId,
    required this.otherPartyName,
  });

  Map<String, dynamic> toMap() {
    return {
      'debtId': debtId,
      'miktar': miktar,
      'tarih': tarih,
      'status': status,
      'aciklama': aciklama,
      'borcluId': borcluId,
      'alacakliId': alacakliId,
      'otherPartyName': otherPartyName,
    };
  }
}
