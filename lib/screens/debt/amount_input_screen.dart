import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_debt_screen.dart';

final amountProvider = StateProvider.autoDispose<String>((ref) => '');

class AmountInputScreen extends ConsumerWidget {
  final String? availableBalance;
  final String? selectedPersonEmail;
  final bool isPactaAl;
  const AmountInputScreen({
    Key? key,
    this.availableBalance,
    this.selectedPersonEmail,
    this.isPactaAl = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = ref.watch(amountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;
    final green = const Color(0xFF4ADE80);
    final darkGreen = const Color(0xFF14532D);
    final darkGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFF14532D), const Color(0xFF1E293B)],
    );
    final bg = isDark ? null : green;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final buttonShadow = [
      BoxShadow(
        color: green.withOpacity(0.18),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
    final isActive =
        amount.isNotEmpty &&
        double.tryParse(amount.replaceAll(',', '.')) != null;
    return Scaffold(
      body: Container(
        decoration: isDark
            ? BoxDecoration(gradient: darkGradient)
            : BoxDecoration(color: green),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SafeArea(
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: textMain,
                    size: width * 0.07,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  'Tutar Gir',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textMain,
                    fontSize: width * 0.055,
                  ),
                ),
                centerTitle: true,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${amount.isEmpty ? '0,00' : amount}₺',
                  style: TextStyle(
                    fontSize: width * 0.13,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.06,
                vertical: height * 0.01,
              ),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: buttonShadow,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isActive
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddDebtScreen(
                                  initialPersonEmail: selectedPersonEmail,
                                  initialAmount: amount,
                                  isPactaAl: isPactaAl,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive
                          ? (isDark ? Colors.white : Colors.white)
                          : (isDark ? Colors.white10 : green),
                      foregroundColor: isActive
                          ? (isDark ? darkGreen : green)
                          : (isDark ? Colors.white54 : Colors.white),
                      minimumSize: Size(double.infinity, height * 0.07),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Devam Et',
                      style: TextStyle(
                        fontSize: width * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23262F) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(width * 0.08),
                  topRight: Radius.circular(width * 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.25)
                        : const Color(0x22000000),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _CustomNumberPad(isDark: isDark, width: width),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomNumberPad extends ConsumerWidget {
  final bool isDark;
  final double width;
  const _CustomNumberPad({this.isDark = false, required this.width});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = ref.watch(amountProvider);
    final keyText = isDark ? Colors.white : const Color(0xFF111827);
    final keyFont = width * 0.07;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        bottom: width * 0.06,
        top: width * 0.04,
        left: width * 0.02,
        right: width * 0.02,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            [',', '0', '<'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((c) {
                if (c == '<') {
                  return IconButton(
                    icon: Icon(
                      Icons.backspace_outlined,
                      color: keyText,
                      size: keyFont,
                    ),
                    onPressed: () {
                      if (amount.isNotEmpty) {
                        ref.read(amountProvider.notifier).state = amount
                            .substring(0, amount.length - 1);
                      }
                    },
                    iconSize: keyFont + 4,
                    splashRadius: keyFont,
                  );
                }
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: width * 0.015,
                    horizontal: width * 0.01,
                  ),
                  child: TextButton(
                    onPressed: () {
                      if (amount.length < 9) {
                        if (c == ',' && amount.contains(',')) return;
                        if (c == ',' && amount.isEmpty) return;
                        ref.read(amountProvider.notifier).state += c;
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: keyText,
                      textStyle: TextStyle(
                        fontSize: keyFont,
                        fontWeight: FontWeight.bold,
                      ),
                      minimumSize: Size(width * 0.13, width * 0.13),
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: keyFont,
                        fontWeight: FontWeight.bold,
                        color: keyText,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
