import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_debt_screen.dart';

import 'package:pacta/models/saved_contact_model.dart';

final amountProvider = StateProvider.autoDispose<String>((ref) => '');

class AmountInputScreen extends ConsumerWidget {
  final SavedContactModel selectedContact;
  final bool isPactaAl;
  final bool isNote;

  const AmountInputScreen({
    Key? key,
    required this.selectedContact,
    this.isPactaAl = false,
    this.isNote = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = ref.watch(amountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;

    final Color themeColor = isNote
        ? const Color(0xFFFACC15) // Sarı (Not)
        : (isPactaAl
              ? const Color(0xFF4ADE80)
              : const Color(0xFFF87171)); // Yeşil (Al) / Kırmızı (Ver)

    final Color darkThemeColor = isNote
        ? const Color(0xFFB45309) // Koyu Sarı
        : (isPactaAl
              ? const Color(0xFF14532D) // Koyu Yeşil
              : const Color(0xFF7F1D1D)); // Koyu Kırmızı

    final darkGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [darkThemeColor, const Color(0xFF1E293B)],
    );

    final bg = isDark ? null : themeColor;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);

    final buttonShadow = [
      BoxShadow(
        color: themeColor.withOpacity(0.18),
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
            : BoxDecoration(color: bg),
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
                  isNote ? 'Not için Tutar Gir' : 'Tutar Gir',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textMain,
                    fontSize: width * 0.055,
                  ),
                ),
                centerTitle: true,
              ),
            ),
            if (isNote)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bu bir nottur ve karşı tarafa bildirim gitmez.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
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
              child: GestureDetector(
                onTap: () {
                  if (!isActive) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDebtScreen(
                        amount: amount.replaceAll(',', '.'),
                        selectedContact: selectedContact,
                        isPactaAl: isPactaAl,
                        isNote: isNote,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: height * 0.075,
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isDark ? Colors.white : darkThemeColor)
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isActive ? buttonShadow : null,
                  ),
                  child: Center(
                    child: Text(
                      'Devam Et',
                      style: TextStyle(
                        fontSize: width * 0.05,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? (isDark ? darkThemeColor : Colors.white)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _NumericKeypad(
              onKeyPressed: (key) {
                ref.read(amountProvider.notifier).update((state) {
                  if (key == '⌫') {
                    return state.isNotEmpty
                        ? state.substring(0, state.length - 1)
                        : '';
                  }
                  if (key == ',' && state.contains(',')) return state;
                  if (state.isEmpty && key == ',') return '0,';
                  // Virgülden sonra en fazla 2 basamak
                  if (state.contains(',') && state.split(',')[1].length >= 2) {
                    return state;
                  }
                  return state + key;
                });
              },
              textColor: textMain,
            ),
          ],
        ),
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final Color textColor;

  const _NumericKeypad({
    Key? key,
    required this.onKeyPressed,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2 / 1.3,
      children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫']
          .map(
            (key) => TextButton(
              onPressed: () => onKeyPressed(key),
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
