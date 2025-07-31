import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  const CustomDateRangePicker({Key? key, this.initialDateRange})
    : super(key: key);

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialDateRange?.start;
    _rangeEnd = widget.initialDateRange?.end;
    if (widget.initialDateRange != null) {
      _focusedDay = widget.initialDateRange!.start;
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tarih Aralığı Seç',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime(2020),
              lastDay: DateTime.now(),
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              onRangeSelected: _onRangeSelected,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: textColor, fontSize: 16),
                leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
              ),
              calendarStyle: CalendarStyle(
                rangeHighlightColor: primaryColor.withOpacity(0.2),
                rangeStartDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                withinRangeTextStyle: TextStyle(color: textColor),
                todayDecoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(color: textColor),
                weekendTextStyle: TextStyle(color: textColor.withOpacity(0.7)),
                outsideTextStyle: TextStyle(color: textColor.withOpacity(0.4)),
              ),
              calendarBuilders: CalendarBuilders(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('İptal', style: TextStyle(color: textColor)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_rangeStart != null && _rangeEnd != null) {
                      Navigator.of(context).pop(
                        DateTimeRange(start: _rangeStart!, end: _rangeEnd!),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Onayla'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
