import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

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
  double borclarim = 0;
  double alacaklarim = 0;
  List<Map<String, dynamic>> islemler = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAnalysis();
  }

  Future<void> fetchAnalysis() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    final debtsSnap = await FirebaseFirestore.instance
        .collection('debts')
        .where('status', whereIn: ['pending', 'approved'])
        .get();
    double borc = 0;
    double alacak = 0;
    List<Map<String, dynamic>> tempIslemler = [];
    for (var doc in debtsSnap.docs) {
      final data = doc.data();
      final borcluId = data['borcluId'];
      final alacakliId = data['alacakliId'];
      // Sadece iki kullanıcı arasındaki işlemler (id ile)
      if ((borcluId == widget.contactId && alacakliId == currentUserId) ||
          (alacakliId == widget.contactId && borcluId == currentUserId)) {
        tempIslemler.add({
          'miktar': data['miktar'],
          'tarih': data['createdAt'],
          'status': data['status'],
          'aciklama': data['aciklama'] ?? '',
          'borcluId': borcluId,
          'alacakliId': alacakliId,
        });
        if (borcluId == currentUserId) {
          borc += (data['miktar'] as num).toDouble();
        } else if (alacakliId == currentUserId) {
          alacak += (data['miktar'] as num).toDouble();
        }
      }
    }
    setState(() {
      borclarim = borc;
      alacaklarim = alacak;
      islemler = tempIslemler;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        title: Text(
          widget.contactName,
          style: const TextStyle(
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1A202C),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pasta Grafik
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 60,
                        sections: [
                          PieChartSectionData(
                            color: Colors.redAccent,
                            value: borclarim,
                            title:
                                'Borçlarım\n${borclarim.toStringAsFixed(2)}₺',
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.green,
                            value: alacaklarim,
                            title:
                                'Alacaklarım\n${alacaklarim.toStringAsFixed(2)}₺',
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Açıklama
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 16, height: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'Borçlarım',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 24),
                      Container(width: 16, height: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Alacaklarım',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // İşlemler Listesi
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'İşlemler',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...islemler.map((islem) {
                    final isBorc =
                        islem['borcluId'] ==
                        FirebaseAuth.instance.currentUser?.uid;
                    final miktar = islem['miktar'] ?? 0;
                    final status = islem['status'] ?? '';
                    final aciklama = islem['aciklama'] ?? '';
                    final tarih = (islem['tarih'] as Timestamp?)?.toDate();
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: Colors.white,
                      child: ListTile(
                        leading: Icon(
                          isBorc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: isBorc ? Colors.redAccent : Colors.green,
                        ),
                        title: Text(
                          '${isBorc ? 'Senin Borcun' : 'Senin Alacağın'}: ${miktar.toString()}₺',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${aciklama.isNotEmpty ? aciklama + '\n' : ''}${tarih != null ? '${tarih.day}.${tarih.month}.${tarih.year} ${tarih.hour}:${tarih.minute.toString().padLeft(2, '0')}' : ''}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'approved'
                                ? Colors.green[100]
                                : status == 'pending'
                                ? Colors.orange[100]
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status == 'approved'
                                ? 'Onaylandı'
                                : status == 'pending'
                                ? 'Beklemede'
                                : 'Reddedildi',
                            style: TextStyle(
                              color: status == 'approved'
                                  ? Colors.green
                                  : status == 'pending'
                                  ? Colors.orange
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
