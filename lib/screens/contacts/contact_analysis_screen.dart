// lib/screens/contacts/contact_analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:pacta/widgets/custom_date_range_picker.dart';
import 'package:pacta/screens/analysis/generate_document_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:async';

class ContactAnalysisScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  const ContactAnalysisScreen({
    Key? key,
    required this.contactId,
    required this.contactName,
  }) : super(key: key);

  @override
  State<ContactAnalysisScreen> createState() => _ContactAnalysisScreenState();
}

class _ContactAnalysisScreenState extends State<ContactAnalysisScreen> {
  bool isLoading = true;
  double borclarim = 0;
  double alacaklarim = 0;
  double notlarim = 0; // Notlar için yeni değişken
  double notAlacaklarim = 0; // Not alacakları için
  double notBorclarim = 0; // Not borçları için
  List<Map<String, dynamic>> islemler = [];

  // Filtreleme değişkenleri
  String selectedTransactionType = 'Tümü';
  String selectedStatus = 'Tümü';
  String selectedDateRange = 'Tüm Zamanlar';
  DateTimeRange? customDateRange;
  List<Map<String, dynamic>> filteredIslemler = [];

  @override
  void dispose() {
    _hideCurrentTooltip();
    super.dispose();
  }

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
        'Contact Pie Chart tooltip tetiklendi: $name - ${value.toStringAsFixed(2)}₺',
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

      print('Modern contact pie tooltip gösterildi: $name');
    } catch (e) {
      print('Contact pie tooltip hatası: $e');

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
    print('ContactAnalysisScreen: initState başladı');
    print('ContactAnalysisScreen: contactId: ${widget.contactId}');
    print('ContactAnalysisScreen: contactName: ${widget.contactName}');
    print('ContactAnalysisScreen: isLoading başlangıç: $isLoading');
    fetchAnalysis();
    print('ContactAnalysisScreen: fetchAnalysis() çağrıldı');
  }

  Future<void> fetchAnalysis() async {
    print('DEBUG: ContactAnalysisScreen: fetchAnalysis() başladı');
    print('DEBUG: ContactAnalysisScreen: isLoading başlangıç: $isLoading');

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      print(
        'DEBUG: ContactAnalysisScreen: currentUserId alındı: $currentUserId',
      );

      if (currentUserId == null) {
        print('DEBUG: ContactAnalysisScreen: currentUserId null!');
        setState(() {
          isLoading = false;
        });
        return;
      }

      print('DEBUG: ContactAnalysisScreen: Veri çekme başladı');
      print('DEBUG: ContactAnalysisScreen: currentUserId: $currentUserId');
      print('DEBUG: ContactAnalysisScreen: contactId: ${widget.contactId}');

      // ContactId email ise, kullanıcı ID'sini bul
      String? actualContactId = widget.contactId;
      if (widget.contactId.contains('@')) {
        // Email ile kullanıcı ID'sini bul
        print(
          'ContactAnalysisScreen: Email ile kullanici araniyor: ${widget.contactId}',
        );
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: widget.contactId)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          actualContactId = userQuery.docs.first.id;
          print(
            'ContactAnalysisScreen: Kullanici ID bulundu: $actualContactId',
          );
        } else {
          // Kullanıcı bulunamadı, email'i ID olarak kullan (not modu için)
          actualContactId = widget.contactId;
          print(
            'ContactAnalysisScreen: Kullanici bulunamadi, email ID olarak kullaniliyor: $actualContactId',
          );
        }
      }

      // Basit test - sadece tüm borçları çek
      print('DEBUG: ContactAnalysisScreen: Firestore sorgusu baslıyor...');

      print(
        'DEBUG: ContactAnalysisScreen: FirebaseFirestore.instance alinıyor...',
      );
      final firestore = FirebaseFirestore.instance;
      print('DEBUG: ContactAnalysisScreen: Firestore instance alındı');

      print('DEBUG: ContactAnalysisScreen: debts koleksiyonu alinıyor...');
      final debtsCollection = firestore.collection('debts');
      print('DEBUG: ContactAnalysisScreen: debts koleksiyonu alındı');

      print('DEBUG: ContactAnalysisScreen: get() cagrılıyor...');
      final allDebtsSnap = await debtsCollection.get();
      print('DEBUG: ContactAnalysisScreen: get() tamamlandı');

      print(
        'DEBUG: ContactAnalysisScreen: Tüm borçlar: ${allDebtsSnap.docs.length}',
      );

      // Tüm status'leri kontrol et
      final allStatuses = <String>{};
      for (final doc in allDebtsSnap.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? '';
        allStatuses.add(status);
        print('ContactAnalysisScreen: Borç status - ${data['status']}');
      }
      print('ContactAnalysisScreen: Tüm status\'ler: $allStatuses');

      // Değişkenleri tanımla
      double borc = 0;
      double alacak = 0;
      double notlar = 0;
      List<Map<String, dynamic>> tempIslemler = [];

      // Önce note status'lü borçları bul
      for (final doc in allDebtsSnap.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? '';
        final borcluId = data['borcluId'];
        final alacakliId = data['alacakliId'];

        if (status == 'note' || status == 'not' || status == 'notes') {
          // Sadece mevcut kullanıcı ile seçili kişi arasındaki notları al
          if ((borcluId == actualContactId && alacakliId == currentUserId) ||
              (alacakliId == actualContactId && borcluId == currentUserId) ||
              // Email ile de eşleşme kontrolü (not modu için)
              (borcluId == widget.contactId && alacakliId == currentUserId) ||
              (alacakliId == widget.contactId && borcluId == currentUserId)) {
            print(
              'ContactAnalysisScreen: Note borç bulundu - miktar: ${data['miktar']}, borcluId: $borcluId, alacakliId: $alacakliId',
            );

            tempIslemler.add({
              'debtId': doc.id,
              'miktar': data['miktar'],
              'tarih': data['islemTarihi'],
              'status': data['status'] ?? 'note',
              'aciklama': data['aciklama'] ?? '',
              'borcluId': borcluId,
              'alacakliId': alacakliId,
            });

            // Borçlu/alacaklı ayrımı yap
            if (borcluId == currentUserId) {
              // Ben borçluyum
              notBorclarim += (data['miktar'] as num).toDouble();
              print(
                'ContactAnalysisScreen: Not borç eklendi - miktar: ${data['miktar']}, toplam not borç: $notBorclarim',
              );
            } else if (alacakliId == currentUserId) {
              // Ben alacaklıyım
              notAlacaklarim += (data['miktar'] as num).toDouble();
              print(
                'ContactAnalysisScreen: Not alacak eklendi - miktar: ${data['miktar']}, toplam not alacak: $notAlacaklarim',
              );
            }
          }
        }
      }

      // Sonra normal borçları işle
      for (var doc in allDebtsSnap.docs) {
        final data = doc.data();
        final borcluId = data['borcluId'];
        final alacakliId = data['alacakliId'];
        final status = data['status']?.toString().toLowerCase() ?? '';

        print(
          'ContactAnalysisScreen: Borç kontrol ediliyor - borcluId: $borcluId, alacakliId: $alacakliId',
        );

        // Sadece iki kullanıcı arasındaki işlemler (note hariç)
        if ((borcluId == actualContactId && alacakliId == currentUserId) ||
            (alacakliId == actualContactId && borcluId == currentUserId) ||
            // Email ile de eşleşme kontrolü (not modu için)
            (borcluId == widget.contactId && alacakliId == currentUserId) ||
            (alacakliId == widget.contactId && borcluId == currentUserId)) {
          // Note status'ü zaten işlendi, tekrar işleme
          if (status == 'note' || status == 'not' || status == 'notes') {
            continue;
          }

          // Sadece onaylı işlemleri göster
          if (status == 'approved') {
            print(
              'ContactAnalysisScreen: Eşleşen borç bulundu - miktar: ${data['miktar']}, status: ${data['status']}, borcluId: $borcluId, alacakliId: $alacakliId',
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

            if (borcluId == currentUserId) {
              print(
                'ContactAnalysisScreen: Status kontrolü - status: "${data['status']}", type: ${data['status'].runtimeType}',
              );
              borc += (data['miktar'] as num).toDouble();
              print(
                'ContactAnalysisScreen: Borç eklendi - miktar: ${data['miktar']}, toplam borç: $borc',
              );
            } else if (alacakliId == currentUserId) {
              alacak += (data['miktar'] as num).toDouble();
              print(
                'ContactAnalysisScreen: Alacak eklendi - miktar: ${data['miktar']}, toplam alacak: $alacak',
              );
            }
          }
        }
      }

      print(
        'ContactAnalysisScreen: Final hesaplama - borç: $borc, alacak: $alacak, işlem sayısı: ${tempIslemler.length}',
      );

      setState(() {
        borclarim = borc;
        alacaklarim = alacak;
        notlarim = notAlacaklarim + notBorclarim; // Toplam notlar
        islemler = tempIslemler;
        filteredIslemler = tempIslemler;
        isLoading = false;
      });

      print('ContactAnalysisScreen: setState tamamlandı');
    } catch (e) {
      print('ContactAnalysisScreen: HATA! $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _shareAnalysis() {
    final netBakiye = alacaklarim - borclarim;
    final durum = netBakiye >= 0 ? 'alacaklısın' : 'borçlusun';
    final mesaj =
        'Merhaba ${widget.contactName}, aramızdaki hesap özeti:\n\n'
        '💰 Net Bakiye: ${netBakiye.abs().toStringAsFixed(2)}₺\n'
        '📊 Durum: ${durum}\n\n'
        '📈 Detaylar:\n'
        '• Borçlarım: ${borclarim.toStringAsFixed(2)}₺\n'
        '• Alacaklarım: ${alacaklarim.toStringAsFixed(2)}₺\n'
        '• Toplam İşlem: ${islemler.length} adet\n\n'
        'Detaylı analiz için uygulamaya göz atabilirsin.';

    // Paylaşım seçenekleri
    showModalBottomSheet(
      context: context,
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
            children: [
              // Başlık
              Row(
                children: [
                  const Icon(Icons.share, color: Color(0xFF667eea)),
                  const SizedBox(width: 8),
                  const Text(
                    'Paylaş',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Paylaşım seçenekleri
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    icon: Icons.chat_bubble_outline,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () {
                      Navigator.pop(context);
                      _shareToWhatsApp(mesaj);
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.sms,
                    label: 'SMS',
                    color: const Color(0xFF667eea),
                    onTap: () {
                      Navigator.pop(context);
                      _shareToSMS(mesaj);
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.copy,
                    label: 'Kopyala',
                    color: Colors.grey[600]!,
                    onTap: () {
                      Navigator.pop(context);
                      _copyToClipboard(mesaj);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _shareToWhatsApp(String message) {
    final url = 'whatsapp://send?text=${Uri.encodeComponent(message)}';
    // TODO: Implement WhatsApp sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp paylaşımı yakında eklenecek')),
    );
  }

  void _shareToSMS(String message) {
    // TODO: Implement SMS sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SMS paylaşımı yakında eklenecek')),
    );
  }

  void _copyToClipboard(String message) {
    // TODO: Implement clipboard functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Panoya kopyalandı')));
  }

  void _showFilterBottomSheet() {
    // Geçici seçimleri tutmak için state değişkenleri
    String tempSelectedTransactionType = selectedTransactionType;
    String tempSelectedStatus = selectedStatus;
    String tempSelectedDateRange = selectedDateRange;
    DateTimeRange? tempCustomDateRange = customDateRange;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomSheetColor = isDark ? const Color(0xFF2D303A) : Colors.white;
    final textColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bottomSheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Helper function for date range picker
            Future<void> selectDateRange() async {
              final picked = await showDialog<DateTimeRange>(
                context: context,
                builder: (context) => CustomDateRangePicker(
                  initialDateRange: tempCustomDateRange,
                ),
              );

              if (picked != null) {
                setModalState(() {
                  tempCustomDateRange = picked;
                  tempSelectedDateRange = 'Özel';
                });
              }
            }

            Widget buildChoiceChip(
              String label,
              String groupValue,
              Function(String) onSelected,
            ) {
              final bool isSelected = label == groupValue;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    onSelected(label);
                  }
                },
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                selectedColor: primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? primaryColor : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 24,
                right: 24,
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
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Filtrele',
                        style: TextStyle(
                          fontSize: 22,
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
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'İşlem Türü',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: ['Tümü', 'Sadece Borçlar', 'Sadece Alacaklar']
                        .map(
                          (type) => buildChoiceChip(
                            type,
                            tempSelectedTransactionType,
                            (newValue) => setModalState(
                              () => tempSelectedTransactionType = newValue,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Durum',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: ['Tümü', 'Onaylananlar', 'Notlar']
                        .map(
                          (status) => buildChoiceChip(
                            status,
                            tempSelectedStatus,
                            (newValue) => setModalState(
                              () => tempSelectedStatus = newValue,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tarih Aralığı',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ...['Tüm Zamanlar', 'Son 1 Hafta', 'Son 1 Ay'].map(
                        (range) => buildChoiceChip(
                          range,
                          tempSelectedDateRange,
                          (newValue) => setModalState(() {
                            tempSelectedDateRange = newValue;
                            tempCustomDateRange = null;
                          }),
                        ),
                      ),
                      // Custom Date Range Chip
                      ActionChip(
                        label: Text(
                          tempSelectedDateRange == 'Özel' &&
                                  tempCustomDateRange != null
                              ? '${tempCustomDateRange!.start.day}/${tempCustomDateRange!.start.month}/${tempCustomDateRange!.start.year} - ${tempCustomDateRange!.end.day}/${tempCustomDateRange!.end.month}/${tempCustomDateRange!.end.year}'
                              : 'Tarih Seç',
                        ),
                        onPressed: selectDateRange,
                        backgroundColor: tempSelectedDateRange == 'Özel'
                            ? primaryColor
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        labelStyle: TextStyle(
                          color: tempSelectedDateRange == 'Özel'
                              ? Colors.white
                              : textColor,
                          fontWeight: tempSelectedDateRange == 'Özel'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: tempSelectedDateRange == 'Özel'
                                ? primaryColor
                                : Colors.transparent,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Seçimleri uygula ve paneli kapat
                        setState(() {
                          selectedTransactionType = tempSelectedTransactionType;
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Filtreyi Uygula',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      filteredIslemler = islemler.where((islem) {
        final status = islem['status']?.toString().toLowerCase() ?? '';
        final isBorc =
            islem['borcluId'] == FirebaseAuth.instance.currentUser?.uid;

        // Onaylanmamış (pending, rejected vb.) işlemleri en başta ele
        if (selectedStatus != 'Tümü' && selectedStatus != 'Notlar') {
          if (status != 'approved') return false;
        }

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
          if (islemTarihi == null) return false; // Tarihi olmayanları ele

          DateTime? tarih;
          try {
            if (islemTarihi is String) {
              tarih = DateTime.parse(islemTarihi);
            } else if (islemTarihi is Timestamp) {
              tarih = islemTarihi.toDate();
            }
          } catch (e) {
            print('ContactAnalysisScreen: Tarih parse hatası: $e');
          }

          if (tarih == null) return false;

          final now = DateTime.now();
          if (selectedDateRange == 'Son 1 Hafta') {
            if (tarih.isBefore(now.subtract(const Duration(days: 7)))) {
              return false;
            }
          } else if (selectedDateRange == 'Son 1 Ay') {
            if (tarih.isBefore(now.subtract(const Duration(days: 30)))) {
              return false;
            }
          } else if (selectedDateRange == 'Özel' && customDateRange != null) {
            // customDateRange'in başlangıcını günün başlangıcı (00:00)
            // bitişini ise günün sonu (23:59:59) olarak alıyoruz.
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

  void _handleAction() {
    final netBakiye = alacaklarim - borclarim;
    if (netBakiye > 0) {
      // Ödeme Talep Et
      print('ContactAnalysisScreen: Ödeme Talep Et butonuna tıklandı');
      // TODO: Implement payment request logic
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme Talep Et butonuna tıklandı (yakında)')),
      );
    } else if (netBakiye < 0) {
      // Ödeme Yap
      print('ContactAnalysisScreen: Ödeme Yap butonuna tıklandı');
      // TODO: Implement payment logic
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme Yap butonuna tıklandı (yakında)')),
      );
    }
  }

  void _showTransactionDetail(Map<String, dynamic> islem) {
    print('ContactAnalysisScreen: İşlem detayına tıklandı: $islem');
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

      print('ContactAnalysisScreen: DebtModel için hazırlanan veri: $debtData');

      final debt = DebtModel.fromMap(debtData);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransactionDetailScreen(debt: debt, userId: currentUserId),
        ),
      );
    } catch (e) {
      print('ContactAnalysisScreen: İşlem detayına geçiş hatası: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem detayı açılamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ContactAnalysisScreen: build() çağrıldı - isLoading: $isLoading');
    print(
      'ContactAnalysisScreen: borclarim: $borclarim, alacaklarim: $alacaklarim, notlarim: $notlarim',
    );
    print('ContactAnalysisScreen: islemler.length: ${islemler.length}');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF23262F) : theme.cardColor;
    final cardInnerColor = isDark ? const Color(0xFF2D303A) : Colors.grey[50];
    final textMain = isDark ? Colors.white : const Color(0xFF1A202C);
    final textSec = isDark ? Colors.white70 : Colors.grey[600];
    final iconMain = isDark ? Colors.white : const Color(0xFF1A202C);
    final iconShare = isDark ? Colors.white : const Color(0xFF1A202C);
    final red = isDark ? const Color(0xFFEF5350) : const Color(0xFFF87171);
    final green = isDark ? const Color(0xFF66BB6A) : const Color(0xFF4ADE80);
    final blue = isDark ? const Color(0xFF42A5F5) : const Color(0xFF3B82F6);
    final orange = isDark ? Colors.orangeAccent : Colors.orange;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: iconMain),
        title: Text(
          '${widget.contactName} - Borç Analizi',
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
                  builder: (context) => GenerateDocumentScreen(
                    selectedContactId: widget.contactId,
                    selectedContactName: widget.contactName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: alacaklarim - borclarim != 0
          ? Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: FloatingActionButton.extended(
                onPressed: () => _handleAction(),
                backgroundColor: alacaklarim - borclarim > 0
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
                foregroundColor: Colors.white,
                elevation: 4,
                icon: Icon(
                  alacaklarim - borclarim > 0
                      ? Icons.payment_rounded
                      : Icons.account_balance_wallet_rounded,
                  size: 20,
                ),
                label: Text(
                  alacaklarim - borclarim > 0 ? 'Ödeme Talep Et' : 'Ödeme Yap',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                    height: 420, // Yüksekliği artırdım
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Grafik
                        SizedBox(
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Debug logları
                              Builder(
                                builder: (context) {
                                  print(
                                    'ContactAnalysisScreen: Pie chart debug - borclarim: $borclarim, alacaklarim: $alacaklarim, notlarim: $notlarim',
                                  );
                                  return const SizedBox.shrink();
                                },
                              ),
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 45,
                                  pieTouchData: PieTouchData(
                                    enabled: true,
                                    touchCallback:
                                        (FlTouchEvent event, pieTouchResponse) {
                                          if (event is FlTapUpEvent ||
                                              event is FlLongPressEnd) {
                                            _showPieTooltip(
                                              context,
                                              pieTouchResponse,
                                              [
                                                {
                                                  'name': 'Borçlarım',
                                                  'value': borclarim,
                                                  'color': red,
                                                },
                                                {
                                                  'name': 'Alacaklarım',
                                                  'value': alacaklarim,
                                                  'color': green,
                                                },
                                                {
                                                  'name': 'Not Alacaklarım',
                                                  'value': notAlacaklarim,
                                                  'color': blue,
                                                },
                                                {
                                                  'name': 'Not Borçlarım',
                                                  'value': notBorclarim,
                                                  'color': orange,
                                                },
                                              ],
                                            );
                                          }
                                        },
                                  ),
                                  sections: [
                                    if (borclarim > 0)
                                      PieChartSectionData(
                                        color: red,
                                        value: borclarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (alacaklarim > 0)
                                      PieChartSectionData(
                                        color: green,
                                        value: alacaklarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (notAlacaklarim > 0)
                                      PieChartSectionData(
                                        color: blue,
                                        value: notAlacaklarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (notBorclarim > 0)
                                      PieChartSectionData(
                                        color: orange,
                                        value: notBorclarim,
                                        title: '',
                                        radius: 60,
                                        showTitle: false,
                                      ),
                                    if (borclarim == 0 &&
                                        alacaklarim == 0 &&
                                        notAlacaklarim == 0 &&
                                        notBorclarim == 0)
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
                                    GestureDetector(
                                      child: Builder(
                                        builder: (context) {
                                          final tooltipKey = GlobalKey();

                                          return GestureDetector(
                                            onLongPress: () {
                                              final fullAmount =
                                                  alacaklarim - borclarim;
                                              _showCustomTooltip(
                                                context,
                                                '${fullAmount.toStringAsFixed(2)}₺',
                                                title: 'Net Bakiye',
                                                targetKey: tooltipKey,
                                              );
                                            },
                                            child: MouseRegion(
                                              onEnter: (_) {
                                                if (Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform
                                                            .windows ||
                                                    Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform.macOS ||
                                                    Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform.linux) {
                                                  final fullAmount =
                                                      alacaklarim - borclarim;
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
                                                  alacaklarim - borclarim,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1A202C),
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
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      alacaklarim - borclarim >= 0
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
                        const SizedBox(height: 24),
                        // Bar Grafiği
                        Column(
                          children: [
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
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor:
                                              borclarim > 0 ||
                                                  alacaklarim > 0 ||
                                                  notlarim > 0
                                              ? borclarim /
                                                    (borclarim +
                                                        alacaklarim +
                                                        notlarim)
                                              : 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: red,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Borçlarım',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                          color: textSec,
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final tooltipKey = GlobalKey();

                                          return GestureDetector(
                                            onLongPress: () {
                                              _showCustomTooltip(
                                                context,
                                                '${borclarim.toStringAsFixed(2)}₺',
                                                title: 'Borçlarım',
                                                targetKey: tooltipKey,
                                              );
                                            },
                                            child: MouseRegion(
                                              onEnter: (_) {
                                                if (Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform
                                                            .windows ||
                                                    Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform.macOS ||
                                                    Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform.linux) {
                                                  _showCustomTooltip(
                                                    context,
                                                    '${borclarim.toStringAsFixed(2)}₺',
                                                    title: 'Borçlarım',
                                                    targetKey: tooltipKey,
                                                  );
                                                }
                                              },
                                              child: AutoSizeText(
                                                key: tooltipKey,
                                                formatNumber(borclarim),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
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
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor:
                                              borclarim > 0 ||
                                                  alacaklarim > 0 ||
                                                  notlarim > 0
                                              ? alacaklarim /
                                                    (borclarim +
                                                        alacaklarim +
                                                        notlarim)
                                              : 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: green,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Alacaklarım',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                          color: textSec,
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final tooltipKey = GlobalKey();

                                          return GestureDetector(
                                            onLongPress: () {
                                              _showCustomTooltip(
                                                context,
                                                '${alacaklarim.toStringAsFixed(2)}₺',
                                                title: 'Alacaklarım',
                                                targetKey: tooltipKey,
                                              );
                                            },
                                            child: MouseRegion(
                                              onEnter: (_) {
                                                if (Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform
                                                            .windows ||
                                                    Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform.macOS ||
                                                    Theme.of(
                                                          context,
                                                        ).platform ==
                                                        TargetPlatform.linux) {
                                                  _showCustomTooltip(
                                                    context,
                                                    '${alacaklarim.toStringAsFixed(2)}₺',
                                                    title: 'Alacaklarım',
                                                    targetKey: tooltipKey,
                                                  );
                                                }
                                              },
                                              child: AutoSizeText(
                                                key: tooltipKey,
                                                formatNumber(alacaklarim),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
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
                                  ),
                                ),
                              ],
                            ),
                            if (notAlacaklarim > 0 || notBorclarim > 0) ...[
                              const SizedBox(height: 16),
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
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: notAlacaklarim > 0
                                                ? notAlacaklarim /
                                                      (notAlacaklarim +
                                                          notBorclarim)
                                                : 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: blue,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Not Alacaklarım',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                            color: textSec,
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final tooltipKey = GlobalKey();

                                            return GestureDetector(
                                              onLongPress: () {
                                                _showCustomTooltip(
                                                  context,
                                                  '${notAlacaklarim.toStringAsFixed(2)}₺',
                                                  title: 'Not Alacaklarım',
                                                  targetKey: tooltipKey,
                                                );
                                              },
                                              child: MouseRegion(
                                                onEnter: (_) {
                                                  if (Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .windows ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .macOS ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .linux) {
                                                    _showCustomTooltip(
                                                      context,
                                                      '${notAlacaklarim.toStringAsFixed(2)}₺',
                                                      title: 'Not Alacaklarım',
                                                      targetKey: tooltipKey,
                                                    );
                                                  }
                                                },
                                                child: AutoSizeText(
                                                  key: tooltipKey,
                                                  formatNumber(notAlacaklarim),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: textMain,
                                                  ),
                                                  maxLines: 1,
                                                  minFontSize: 9,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            );
                                          },
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
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: notBorclarim > 0
                                                ? notBorclarim /
                                                      (notAlacaklarim +
                                                          notBorclarim)
                                                : 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: orange,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Not Borçlarım',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                            color: textSec,
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final tooltipKey = GlobalKey();

                                            return GestureDetector(
                                              onLongPress: () {
                                                _showCustomTooltip(
                                                  context,
                                                  '${notBorclarim.toStringAsFixed(2)}₺',
                                                  title: 'Not Borçlarım',
                                                  targetKey: tooltipKey,
                                                );
                                              },
                                              child: MouseRegion(
                                                onEnter: (_) {
                                                  if (Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .windows ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .macOS ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .linux) {
                                                    _showCustomTooltip(
                                                      context,
                                                      '${notBorclarim.toStringAsFixed(2)}₺',
                                                      title: 'Not Borçlarım',
                                                      targetKey: tooltipKey,
                                                    );
                                                  }
                                                },
                                                child: AutoSizeText(
                                                  key: tooltipKey,
                                                  formatNumber(notBorclarim),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: textMain,
                                                  ),
                                                  maxLines: 1,
                                                  minFontSize: 9,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // İşlemler Listesi
                  Container(
                    height: 450, // Yüksekliği artırdım
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
                              'İşlemler',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: textMain,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filteredIslemler.length} işlem',
                              style: TextStyle(fontSize: 12, color: textSec),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showFilterBottomSheet(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.filter_list_rounded,
                                  color: theme.primaryColor,
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
                                        'Bu kişi ile henüz borç/alacak işlemi yapılmamış',
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
                                  padding: EdgeInsets
                                      .zero, // Üst ve alt padding'i kaldırdım
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
                                        'ContactAnalysisScreen: Tarih parse hatası: $e',
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
                                              : 12, // Son öğe için margin yok
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
                                                              ? 'Not Borcun: ${formatNumber(miktar).replaceAll('₺', '')}₺'
                                                              : 'Senin Borcun: ${formatNumber(miktar).replaceAll('₺', '')}₺')
                                                        : (islem['status'] ==
                                                                  'note'
                                                              ? 'Not Alacağın: ${formatNumber(miktar).replaceAll('₺', '')}₺'
                                                              : 'Senin Alacağın: ${formatNumber(miktar).replaceAll('₺', '')}₺'),
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

// 🎨 Modern Baloncuk Tooltip Widget - Contact Analysis için
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

// 🎯 Ok Çizer (Arrow Painter) - Contact Analysis için
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
