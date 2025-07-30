// lib/screens/contacts/contact_analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:pacta/widgets/custom_date_range_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> islemler = [];

  String selectedTransactionType = 'Tümü';
  String selectedStatus = 'Tümü';
  String selectedDateRange = 'Tüm Zamanlar';
  DateTimeRange? customDateRange;
  List<Map<String, dynamic>> filteredIslemler = [];

  @override
  void initState() {
    super.initState();
    fetchAnalysis();
  }

  Future<void> fetchAnalysis() async {
    // ... (Mevcut fetchAnalysis mantığınız burada kalacak)
    if (!mounted) return;
    setState(() => isLoading = true);

    await Future.delayed(const Duration(seconds: 1));
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        borclarim = 2184.00;
        alacaklarim = 555.00;
        islemler = [
          {
            'debtId': '1',
            'miktar': 1000.00,
            'tarih': Timestamp.now(),
            'status': 'approved',
            'aciklama': 'Kira ödemesi',
            'borcluId': currentUser.uid,
            'alacakliId': widget.contactId,
          },
          {
            'debtId': '2',
            'miktar': 1184.00,
            'tarih': Timestamp.now(),
            'status': 'rejected',
            'aciklama': 'Market alışverişi',
            'borcluId': currentUser.uid,
            'alacakliId': widget.contactId,
          },
          {
            'debtId': '3',
            'miktar': 555.00,
            'tarih': Timestamp.now(),
            'status': 'approved',
            'aciklama': 'Öğle yemeği',
            'borcluId': widget.contactId,
            'alacakliId': currentUser.uid,
          },
          {
            'debtId': '4',
            'miktar': 250.00,
            'tarih': Timestamp.now(),
            'status': 'pending',
            'aciklama': 'Sinema Biletleri',
            'borcluId': widget.contactId,
            'alacakliId': currentUser.uid,
          },
        ];
        filteredIslemler = islemler;
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    /* ... */
  }
  void _showFilterBottomSheet() {
    /* ... */
  }

  void _showTransactionDetail(Map<String, dynamic> islem) {
    final debt = DebtModel.fromMap(islem, islem['debtId'] as String);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(
          debt: debt,
          userId: FirebaseAuth.instance.currentUser!.uid,
        ),
      ),
    );
  }

  void _shareAnalysis() {
    final netBakiye = alacaklarim - borclarim;
    final durum = netBakiye >= 0
        ? "aramızdaki hesap özetine göre bana ${netBakiye.abs().toStringAsFixed(2)}₺ borcun bulunuyor."
        : "aramızdaki hesap özetine göre sana ${netBakiye.abs().toStringAsFixed(2)}₺ borcum bulunuyor.";
    final mesaj =
        'Merhaba ${widget.contactName}, $durum Detaylar için Pacta uygulamasına göz atabilirsin.';

    Share.share(mesaj);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netBakiye = alacaklarim - borclarim;
    final headerColor = netBakiye >= 0
        ? Colors.green.shade400
        : Colors.red.shade400;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareAnalysis,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildHeader(headerColor, netBakiye),
                Padding(
                  padding: const EdgeInsets.only(top: 200.0),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 100.0),
                    children: [
                      _buildAnalysisCard(theme, netBakiye),
                      const SizedBox(height: 24),
                      _buildTransactionList(theme),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomButton(theme, netBakiye),
    );
  }

  Widget _buildHeader(Color headerColor, double netBakiye) {
    return Container(
      height: 220.0,
      width: double.infinity,
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30.0),
          bottomRight: Radius.circular(30.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                widget.contactName.isNotEmpty
                    ? widget.contactName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.contactName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              netBakiye >= 0 ? 'Sana Borcu Var' : 'Ona Borcun Var',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(ThemeData theme, double netBakiye) {
    return Card(
      elevation: 8.0,
      shadowColor: theme.shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2.0,
                      centerSpaceRadius: 50,
                      sections: (borclarim == 0 && alacaklarim == 0)
                          ? [
                              PieChartSectionData(
                                color: Colors.grey.shade300,
                                value: 1,
                                title: '',
                                radius: 35,
                              ),
                            ]
                          : [
                              if (borclarim > 0)
                                PieChartSectionData(
                                  color: Colors.red.shade400,
                                  value: borclarim,
                                  title: '',
                                  radius: 35,
                                ),
                              if (alacaklarim > 0)
                                PieChartSectionData(
                                  color: Colors.green.shade400,
                                  value: alacaklarim,
                                  title: '',
                                  radius: 35,
                                ),
                            ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Net Bakiye', style: theme.textTheme.bodySmall),
                      Text(
                        '${netBakiye.toStringAsFixed(2)}₺',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            _buildBarIndicator(
              'Borçlarım',
              borclarim,
              alacaklarim + borclarim,
              Colors.red.shade400,
              theme,
            ),
            const SizedBox(height: 16),
            _buildBarIndicator(
              'Alacaklarım',
              alacaklarim,
              alacaklarim + borclarim,
              Colors.green.shade400,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarIndicator(
    String title,
    double value,
    double total,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)}₺',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: total > 0 ? value / total : 0,
            minHeight: 8.0,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'İşlemler',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  '${filteredIslemler.length} İşlem',
                  style: theme.textTheme.bodySmall,
                ),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (filteredIslemler.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48.0),
            child: Center(child: Text('Filtreye uygun işlem bulunamadı.')),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredIslemler.length,
            itemBuilder: (context, index) {
              return _buildTransactionTile(filteredIslemler[index], theme);
            },
          ),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> islem, ThemeData theme) {
    final bool isBorc =
        islem['borcluId'] == FirebaseAuth.instance.currentUser?.uid;
    final Color iconBgColor = isBorc
        ? Colors.red.shade50
        : Colors.green.shade50;
    final Color iconColor = isBorc
        ? Colors.red.shade600
        : Colors.green.shade600;
    final IconData icon = isBorc ? Icons.arrow_upward : Icons.arrow_downward;
    final String status = islem['status'] ?? 'pending';
    final Timestamp timestamp = islem['tarih'] ?? Timestamp.now();
    final String formattedDate = DateFormat(
      'd MMM yyyy',
      'tr_TR',
    ).format(timestamp.toDate());
    final String title = islem['aciklama']?.isNotEmpty ?? false
        ? islem['aciklama']
        : (isBorc ? 'Gönderilen Borç' : 'Alınan Borç');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showTransactionDetail(islem),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconBgColor,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(formattedDate, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isBorc ? '-' : '+'}${islem['miktar'].toStringAsFixed(2)}₺',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isBorc ? Colors.red : Colors.green,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusPill(status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color color;
    String text;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        text = 'Onaylandı';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Reddedildi';
        break;
      default:
        color = Colors.orange;
        text = 'Beklemede';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget? _buildBottomButton(ThemeData theme, double netBakiye) {
    if (netBakiye == 0) return null;

    final String buttonText = netBakiye < 0 ? 'Ödeme Yap' : 'Ödeme Talep Et';
    final Color buttonColor = netBakiye < 0
        ? Colors.red.shade400
        : Colors.green.shade400;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: Text(buttonText),
      ),
    );
  }
}
