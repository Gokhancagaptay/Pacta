// lib/services/contact_analysis_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';

/// Contact analysis işlemleri için optimize edilmiş servis
class ContactAnalysisService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache for analysis data
  static final Map<String, ContactAnalysisData> _analysisCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Contact ile olan tüm işlemleri optimize edilmiş şekilde getirir
  static Future<ContactAnalysisData> getContactAnalysis(
    String contactId,
  ) async {
    final cacheKey = '${FirebaseAuth.instance.currentUser?.uid}_$contactId';

    // Check cache first
    if (_isDataCached(cacheKey)) {
      return _analysisCache[cacheKey]!;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Optimize edilmiş sorgu - sadece gerekli alanları çek
      final query = _db
          .collection(AppConstants.debtsCollection)
          .where('visibleto', arrayContains: currentUserId)
          .where(
            Filter.or(
              Filter.and(
                Filter('borcluId', isEqualTo: currentUserId),
                Filter('alacakliId', isEqualTo: contactId),
              ),
              Filter.and(
                Filter('borcluId', isEqualTo: contactId),
                Filter('alacakliId', isEqualTo: currentUserId),
              ),
            ),
          )
          .orderBy('islemTarihi', descending: true)
          .limit(100); // Limit to improve performance

      final snapshot = await query.get();
      final analysisData = _processAnalysisData(
        snapshot.docs,
        currentUserId,
        contactId,
      );

      // Cache the result
      _analysisCache[cacheKey] = analysisData;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return analysisData;
    } catch (e) {
      print('Error in getContactAnalysis: $e');
      rethrow;
    }
  }

  /// Filtered transactions için optimize edilmiş metod
  static List<Map<String, dynamic>> getFilteredTransactions(
    ContactAnalysisData analysisData, {
    String transactionType = 'Tümü',
    String status = 'Tümü',
    String dateRange = 'Tüm Zamanlar',
    DateTimeRange? customDateRange,
  }) {
    var filtered = List<Map<String, dynamic>>.from(analysisData.transactions);

    // Transaction type filter
    if (transactionType != 'Tümü') {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      filtered = filtered.where((transaction) {
        final isDebt = transaction['borcluId'] == currentUserId;
        return (transactionType == 'Borç' && isDebt) ||
            (transactionType == 'Alacak' && !isDebt);
      }).toList();
    }

    // Status filter
    if (status != 'Tümü') {
      final targetStatus = status == 'Onaylanmış'
          ? AppConstants.statusApproved
          : AppConstants.statusNote;
      filtered = filtered.where((transaction) {
        return transaction['status'] == targetStatus;
      }).toList();
    }

    // Date range filter
    if (dateRange != 'Tüm Zamanlar') {
      final now = DateTime.now();
      DateTime? startDate;

      switch (dateRange) {
        case 'Son 7 Gün':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Son 30 Gün':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case 'Son 3 Ay':
          startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case 'Son 6 Ay':
          startDate = DateTime(now.year, now.month - 6, now.day);
          break;
        case 'Son 1 Yıl':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case 'Özel Aralık':
          if (customDateRange != null) {
            filtered = filtered.where((transaction) {
              final date = transaction['tarih'] as DateTime?;
              return date != null &&
                  date.isAfter(customDateRange.start) &&
                  date.isBefore(
                    customDateRange.end.add(const Duration(days: 1)),
                  );
            }).toList();
          }
          break;
      }

      if (startDate != null) {
        filtered = filtered.where((transaction) {
          final date = transaction['tarih'] as DateTime?;
          return date != null && date.isAfter(startDate!);
        }).toList();
      }
    }

    return filtered;
  }

  /// Cache kontrolü
  static bool _isDataCached(String cacheKey) {
    if (!_analysisCache.containsKey(cacheKey) ||
        !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }

    final timestamp = _cacheTimestamps[cacheKey]!;
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }

  /// Analysis data işleme
  static ContactAnalysisData _processAnalysisData(
    List<QueryDocumentSnapshot> docs,
    String currentUserId,
    String contactId,
  ) {
    double borclarim = 0;
    double alacaklarim = 0;
    double notBorclarim = 0;
    double notAlacaklarim = 0;
    List<Map<String, dynamic>> transactions = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final borcluId = data['borcluId'] as String?;
      final alacakliId = data['alacakliId'] as String?;
      final status = data['status']?.toString() ?? '';
      final miktar = (data['miktar'] as num?)?.toDouble() ?? 0;

      // Parse transaction date
      DateTime? islemTarihi;
      final dynamic islemTarihiData = data['islemTarihi'];
      if (islemTarihiData is Timestamp) {
        islemTarihi = islemTarihiData.toDate();
      } else if (islemTarihiData is String) {
        islemTarihi = DateTime.tryParse(islemTarihiData);
      }

      // Process transaction
      final transaction = {
        'debtId': doc.id,
        'miktar': miktar,
        'tarih': islemTarihi,
        'status': status,
        'aciklama': data['aciklama'] ?? '',
        'borcluId': borcluId,
        'alacakliId': alacakliId,
      };

      // Add to transactions list for approved and note status
      if (status == AppConstants.statusApproved ||
          status == AppConstants.statusNote) {
        transactions.add(transaction);
      }

      // Calculate totals
      if (status == AppConstants.statusNote) {
        if (borcluId == currentUserId) {
          notBorclarim += miktar;
        } else if (alacakliId == currentUserId) {
          notAlacaklarim += miktar;
        }
      } else if (status == AppConstants.statusApproved) {
        if (borcluId == currentUserId) {
          borclarim += miktar;
        } else if (alacakliId == currentUserId) {
          alacaklarim += miktar;
        }
      }
    }

    return ContactAnalysisData(
      borclarim: borclarim,
      alacaklarim: alacaklarim,
      notBorclarim: notBorclarim,
      notAlacaklarim: notAlacaklarim,
      transactions: transactions,
    );
  }

  /// Cache temizleme
  static void clearCache([String? specificContactId]) {
    if (specificContactId != null) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final cacheKey = '${currentUserId}_$specificContactId';
      _analysisCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
    } else {
      _analysisCache.clear();
      _cacheTimestamps.clear();
    }
  }

  /// Real-time updates için stream
  static Stream<ContactAnalysisData> getContactAnalysisStream(
    String contactId,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.error('User not authenticated');
    }

    return _db
        .collection(AppConstants.debtsCollection)
        .where('visibleto', arrayContains: currentUserId)
        .where(
          Filter.or(
            Filter.and(
              Filter('borcluId', isEqualTo: currentUserId),
              Filter('alacakliId', isEqualTo: contactId),
            ),
            Filter.and(
              Filter('borcluId', isEqualTo: contactId),
              Filter('alacakliId', isEqualTo: currentUserId),
            ),
          ),
        )
        .orderBy('islemTarihi', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final analysisData = _processAnalysisData(
            snapshot.docs,
            currentUserId,
            contactId,
          );

          // Update cache
          final cacheKey = '${currentUserId}_$contactId';
          _analysisCache[cacheKey] = analysisData;
          _cacheTimestamps[cacheKey] = DateTime.now();

          return analysisData;
        });
  }
}

/// Contact analysis verilerini tutan sınıf
class ContactAnalysisData {
  final double borclarim;
  final double alacaklarim;
  final double notBorclarim;
  final double notAlacaklarim;
  final List<Map<String, dynamic>> transactions;

  const ContactAnalysisData({
    required this.borclarim,
    required this.alacaklarim,
    required this.notBorclarim,
    required this.notAlacaklarim,
    required this.transactions,
  });

  double get totalDebt => borclarim + notBorclarim;
  double get totalCredit => alacaklarim + notAlacaklarim;
  double get netBalance => totalCredit - totalDebt;
  bool get hasData => totalDebt > 0 || totalCredit > 0;
}
