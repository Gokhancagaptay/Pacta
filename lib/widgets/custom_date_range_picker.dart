import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';

/// Overlay tarih aralığı seçici - Sayfa üstünde açılır
///
/// İlk tıklama başlangıç, ikinci tıklama bitiş tarihi olur
Future<DateTimeRange?> showCustomDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
  String? helpText,
  String? cancelText,
  String? confirmText,
}) async {
  return await showDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black54,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: CalendarDateRangePicker(
          initialDateRange: initialDateRange,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime.now(),
          helpText: helpText ?? 'Tarih aralığı seçin',
          cancelText: cancelText ?? 'İptal',
          confirmText: confirmText ?? 'Uygula',
        ),
      );
    },
  );
}

/// Calendar tarih seçici widget'ı
class CalendarDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;
  final String cancelText;
  final String confirmText;

  const CalendarDateRangePicker({
    Key? key,
    this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
  }) : super(key: key);

  @override
  State<CalendarDateRangePicker> createState() =>
      _CalendarDateRangePickerState();
}

class _CalendarDateRangePickerState extends State<CalendarDateRangePicker> {
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _currentMonth = DateTime.now();
  bool _isSelectingEndDate = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDateRange?.start;
    _endDate = widget.initialDateRange?.end;
    _currentMonth = _startDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = Colors.green.shade600;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF7F8FC);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve ay navigasyonu
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.largeBorderRadius),
                topRight: Radius.circular(AppConstants.largeBorderRadius),
              ),
            ),
            child: Column(
              children: [
                Text(
                  widget.helpText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                            _currentMonth.year,
                            _currentMonth.month - 1,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Text(
                      _formatMonth(_currentMonth),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                            _currentMonth.year,
                            _currentMonth.month + 1,
                          );
                        });
                      },
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Takvim
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Haftanın günleri
                Row(
                  children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),

                // Takvim günleri
                ..._buildCalendarWeeks(),

                // Seçilen aralık gösterimi
                if (_startDate != null || _endDate != null) ...[
                  const SizedBox(height: AppConstants.defaultPadding),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      AppConstants.smallPadding * 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(
                        AppConstants.defaultBorderRadius,
                      ),
                      border: Border.all(
                        color: primaryColor.withOpacity(isDark ? 0.4 : 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getSelectionText(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Aksiyon butonları
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(widget.cancelText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startDate != null && _endDate != null
                            ? () {
                                Navigator.of(context).pop(
                                  DateTimeRange(
                                    start: _startDate!,
                                    end: _endDate!,
                                  ),
                                );
                              }
                            : null,
                        child: Text(widget.confirmText),
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

  List<Widget> _buildCalendarWeeks() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startDate = firstDay.subtract(
      Duration(days: (firstDay.weekday - 1) % 7),
    );

    List<Widget> weeks = [];
    DateTime currentWeekStart = startDate;

    while (currentWeekStart.isBefore(lastDay) ||
        currentWeekStart.month == _currentMonth.month) {
      weeks.add(_buildWeekRow(currentWeekStart));
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    return weeks;
  }

  Widget _buildWeekRow(DateTime weekStart) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          return Expanded(child: _buildDayCell(date));
        }),
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = Colors.green.shade600;

    final isCurrentMonth = date.month == _currentMonth.month;
    final isSelected = _isDateSelected(date);
    final isInRange = _isDateInRange(date);
    final isToday = _isToday(date);
    final isEnabled = _isDateEnabled(date);

    return GestureDetector(
      onTap: isEnabled ? () => _onDateTapped(date) : null,
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getDateBackgroundColor(isSelected, isInRange, isToday),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: isToday && !isSelected
              ? Border.all(color: primaryColor, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            date.day.toString(),
            style: TextStyle(
              color: _getDateTextColor(isCurrentMonth, isSelected, isEnabled),
              fontWeight: isSelected || isToday
                  ? FontWeight.w600
                  : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _onDateTapped(DateTime date) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // İlk seçim veya yeniden başlama
        _startDate = date;
        _endDate = null;
        _isSelectingEndDate = true;
      } else if (_endDate == null) {
        // İkinci seçim
        if (date.isBefore(_startDate!)) {
          // Eğer ikinci seçim ilkinden önceyse, yer değiştir
          _endDate = _startDate;
          _startDate = date;
        } else {
          _endDate = date;
        }
        _isSelectingEndDate = false;
      }
    });
  }

  bool _isDateSelected(DateTime date) {
    return (_startDate != null && _isSameDay(date, _startDate!)) ||
        (_endDate != null && _isSameDay(date, _endDate!));
  }

  bool _isDateInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return date.isAfter(_startDate!) && date.isBefore(_endDate!);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDateEnabled(DateTime date) {
    return !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
  }

  Color _getDateBackgroundColor(bool isSelected, bool isInRange, bool isToday) {
    final primaryColor = Colors.green.shade600;

    if (isSelected) {
      return primaryColor;
    } else if (isInRange) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return primaryColor.withOpacity(isDark ? 0.3 : 0.2);
    }
    return Colors.transparent;
  }

  Color _getDateTextColor(
    bool isCurrentMonth,
    bool isSelected,
    bool isEnabled,
  ) {
    if (isSelected) {
      return Colors.white;
    } else if (!isEnabled) {
      return Theme.of(context).disabledColor;
    } else if (!isCurrentMonth) {
      return Theme.of(context).hintColor;
    }
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
  }

  String _getSelectionText() {
    if (_startDate != null && _endDate != null) {
      final days = _endDate!.difference(_startDate!).inDays + 1;
      return '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)} ($days gün)';
    } else if (_startDate != null) {
      return 'Başlangıç: ${_formatDate(_startDate!)} (Bitiş tarihi seçin)';
    }
    return 'Başlangıç tarihini seçin';
  }

  String _formatMonth(DateTime date) {
    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
