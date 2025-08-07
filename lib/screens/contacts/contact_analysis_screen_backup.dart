// lib/screens/contacts/contact_analysis_screen_optimized.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/services/contact_analysis_service.dart';
import 'package:pacta/widgets/analysis/balance_chart_widget.dart';
import 'package:pacta/widgets/analysis/summary_cards_widget.dart';
import 'package:pacta/widgets/analysis/transaction_filters_widget.dart';
import 'package:pacta/widgets/analysis/transaction_list_widget.dart';
import 'package:pacta/widgets/common/loading_widget.dart';
import 'package:pacta/widgets/common/empty_state_widget.dart';
import 'package:pacta/screens/analysis/generate_document_screen.dart';

/// Contact Analysis ekranı - Responsive ve optimize edilmiş
class ContactAnalysisScreenBackup extends StatefulWidget {
  final String contactId;
  final String contactName;

  const ContactAnalysisScreenBackup({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  @override
  State<ContactAnalysisScreenBackup> createState() =>
      _ContactAnalysisScreenBackupState();
}

class _ContactAnalysisScreenBackupState
    extends State<ContactAnalysisScreenBackup>
    with TickerProviderStateMixin {
  late TabController _tabController;
  ContactAnalysisData? _analysisData;
  bool _isLoading = true;
  String? _errorMessage;

  // Filter states
  String _selectedTransactionType = 'Tümü';
  String _selectedStatus = 'Tümü';
  String _selectedDateRange = 'Tüm Zamanlar';
  DateTimeRange? _customDateRange;

  // Chart interaction
  int? _touchedChartIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalysisData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Analysis verilerini yükle (cache'li)
  Future<void> _loadAnalysisData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final analysisData = await ContactAnalysisService.getContactAnalysis(
        widget.contactId,
      );

      if (mounted) {
        setState(() {
          _analysisData = analysisData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Filtrelenmiş işlemleri getir
  List<Map<String, dynamic>> get _filteredTransactions {
    if (_analysisData == null) return [];

    return ContactAnalysisService.getFilteredTransactions(
      _analysisData!,
      transactionType: _selectedTransactionType,
      status: _selectedStatus,
      dateRange: _selectedDateRange,
      customDateRange: _customDateRange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.contactName),
      elevation: 0,
      actions: [
        if (_analysisData?.hasData == true) ...[
          IconButton(
            icon: const Icon(Icons.description_outlined),
            onPressed: _navigateToDocumentGeneration,
            tooltip: 'Rapor Oluştur',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Yenile',
          ),
        ],
      ],
      bottom: _analysisData?.hasData == true
          ? TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Özet', icon: Icon(Icons.pie_chart)),
                Tab(text: 'Filtreler', icon: Icon(Icons.filter_list)),
                Tab(text: 'İşlemler', icon: Icon(Icons.list)),
              ],
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Analiz verileri yükleniyor...');
    }

    if (_errorMessage != null) {
      return EmptyStateWidget.error(
        subtitle: _errorMessage,
        onActionPressed: _refreshData,
      );
    }

    if (_analysisData?.hasData != true) {
      return EmptyStateWidget.noDebts(
        actionText: 'İşlem Ekle',
        onActionPressed: () {
          // Navigate to add transaction
          Navigator.pop(context);
        },
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSummaryTab(),
        _buildFiltersTab(),
        _buildTransactionsTab(),
      ],
    );
  }

  Widget _buildSummaryTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Summary cards
            SummaryCardsWidget(
              borclarim: _analysisData!.borclarim,
              alacaklarim: _analysisData!.alacaklarim,
              notBorclarim: _analysisData!.notBorclarim,
              notAlacaklarim: _analysisData!.notAlacaklarim,
              contactName: widget.contactName,
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Net balance card
            NetBalanceCard(
              borclarim: _analysisData!.borclarim,
              alacaklarim: _analysisData!.alacaklarim,
              contactName: widget.contactName,
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Balance chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Denge Grafiği',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: BalanceChartWidget(
                            borclarim: _analysisData!.borclarim,
                            alacaklarim: _analysisData!.alacaklarim,
                            touchedIndex: _touchedChartIndex,
                            onTouchedIndexChanged: (index) {
                              setState(() {
                                _touchedChartIndex = index;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppConstants.defaultPadding),
                        Expanded(
                          child: ChartLegendWidget(
                            borclarim: _analysisData!.borclarim,
                            alacaklarim: _analysisData!.alacaklarim,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          TransactionFiltersWidget(
            selectedTransactionType: _selectedTransactionType,
            selectedStatus: _selectedStatus,
            selectedDateRange: _selectedDateRange,
            customDateRange: _customDateRange,
            onTransactionTypeChanged: (value) {
              setState(() {
                _selectedTransactionType = value;
              });
            },
            onStatusChanged: (value) {
              setState(() {
                _selectedStatus = value;
              });
            },
            onDateRangeChanged: (value) {
              setState(() {
                _selectedDateRange = value;
              });
            },
            onCustomDateRangeChanged: (range) {
              setState(() {
                _customDateRange = range;
              });
            },
          ),

          const SizedBox(height: AppConstants.defaultPadding),

          // Filter results summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      '${_filteredTransactions.length} işlem bulundu',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (_hasActiveFilters())
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Filtreleri Temizle'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: TransactionListWidget(
        transactions: _filteredTransactions,
        isLoading: false,
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedTransactionType != 'Tümü' ||
        _selectedStatus != 'Tümü' ||
        _selectedDateRange != 'Tüm Zamanlar';
  }

  void _clearFilters() {
    setState(() {
      _selectedTransactionType = 'Tümü';
      _selectedStatus = 'Tümü';
      _selectedDateRange = 'Tüm Zamanlar';
      _customDateRange = null;
    });
  }

  Future<void> _refreshData() async {
    // Clear cache for this contact
    ContactAnalysisService.clearCache(widget.contactId);
    await _loadAnalysisData();
  }

  void _navigateToDocumentGeneration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GenerateDocumentScreen()),
    );
  }
}
