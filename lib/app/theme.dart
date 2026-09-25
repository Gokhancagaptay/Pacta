import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tasarım kuralları (A · Güven Yeşili) için anlamsal renkler.
///
/// Ekranlar renkleri buradan okur; açık/koyu tema aynı rollerin farklı
/// değerleridir. Maketler: plan §14.3.
@immutable
class PactaColors extends ThemeExtension<PactaColors> {
  const PactaColors({
    required this.credit,
    required this.creditSoft,
    required this.debt,
    required this.debtSoft,
    required this.pending,
    required this.pendingSoft,
    required this.pendingDot,
    required this.dispute,
    required this.disputeSoft,
    required this.muted,
    required this.line,
    required this.balanceCard,
    required this.balanceCardInner,
    required this.balanceCardText,
    required this.balanceCardMuted,
    required this.balanceCardAmount,
  });

  /// Alacak / olumlu tutar metni.
  final Color credit;
  final Color creditSoft;

  /// Borç / olumsuz tutar metni.
  final Color debt;
  final Color debtSoft;

  /// Onay bekleyen.
  final Color pending;
  final Color pendingSoft;
  final Color pendingDot;

  /// İtiraz.
  final Color dispute;
  final Color disputeSoft;

  /// İkincil metin (açık zeminde en az 4.5:1).
  final Color muted;

  /// Kart içi ayırıcı çizgi.
  final Color line;

  final Color balanceCard;
  final Color balanceCardInner;
  final Color balanceCardText;
  final Color balanceCardMuted;
  final Color balanceCardAmount;

  static const light = PactaColors(
    credit: Color(0xFF15803D),
    creditSoft: Color(0xFFDCFCE7),
    debt: Color(0xFFDC2626),
    debtSoft: Color(0xFFFEE2E2),
    pending: Color(0xFFB45309),
    pendingSoft: Color(0xFFFFF3E0),
    pendingDot: Color(0xFFFFA726),
    dispute: Color(0xFF6D28D9),
    disputeSoft: Color(0xFFF3F0FF),
    muted: Color(0xFF6B7280),
    line: Color(0xFFF1F2F6),
    balanceCard: Color(0xFF111827),
    balanceCardInner: Color(0xFF1F2937),
    balanceCardText: Color(0xFFFFFFFF),
    balanceCardMuted: Color(0xFF9CA3AF),
    balanceCardAmount: Color(0xFF4ADE80),
  );

  static const dark = PactaColors(
    credit: Color(0xFF4ADE80),
    creditSoft: Color(0xFF163323),
    debt: Color(0xFFF87171),
    debtSoft: Color(0xFF3B1D1D),
    pending: Color(0xFFFBBF24),
    pendingSoft: Color(0xFF3A2A12),
    pendingDot: Color(0xFFFFA726),
    dispute: Color(0xFFC4B5FD),
    disputeSoft: Color(0xFF2E2548),
    muted: Color(0xFF9CA3AF),
    line: Color(0xFF2C303A),
    balanceCard: Color(0xFF23262F),
    balanceCardInner: Color(0xFF181A20),
    balanceCardText: Color(0xFFF3F4F6),
    balanceCardMuted: Color(0xFF9CA3AF),
    balanceCardAmount: Color(0xFF4ADE80),
  );

  @override
  PactaColors copyWith() => this;

  @override
  PactaColors lerp(ThemeExtension<PactaColors>? other, double t) {
    if (other is! PactaColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PactaColors(
      credit: l(credit, other.credit),
      creditSoft: l(creditSoft, other.creditSoft),
      debt: l(debt, other.debt),
      debtSoft: l(debtSoft, other.debtSoft),
      pending: l(pending, other.pending),
      pendingSoft: l(pendingSoft, other.pendingSoft),
      pendingDot: l(pendingDot, other.pendingDot),
      dispute: l(dispute, other.dispute),
      disputeSoft: l(disputeSoft, other.disputeSoft),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      balanceCard: l(balanceCard, other.balanceCard),
      balanceCardInner: l(balanceCardInner, other.balanceCardInner),
      balanceCardText: l(balanceCardText, other.balanceCardText),
      balanceCardMuted: l(balanceCardMuted, other.balanceCardMuted),
      balanceCardAmount: l(balanceCardAmount, other.balanceCardAmount),
    );
  }
}

extension PactaThemeX on BuildContext {
  PactaColors get pacta => Theme.of(this).extension<PactaColors>()!;
}

class PactaTheme {
  PactaTheme._();

  /// Yeşil dolgu (#4ADE80) ve üstündeki yazı (#052E16) iki temada aynıdır.
  static const brandFill = Color(0xFF4ADE80);
  static const onBrandFill = Color(0xFF052E16);

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scaffold: const Color(0xFFF7F8FC),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF111827),
    outline: const Color(0xFFE5E7EB),
    error: const Color(0xFFDC2626),
    colors: PactaColors.light,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scaffold: const Color(0xFF181A20),
    surface: const Color(0xFF23262F),
    onSurface: const Color(0xFFF3F4F6),
    outline: const Color(0xFF3A3F4B),
    error: const Color(0xFFF87171),
    colors: PactaColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color onSurface,
    required Color outline,
    required Color error,
    required PactaColors colors,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: brandFill,
      onPrimary: onBrandFill,
      secondary: colors.credit,
      onSecondary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: colors.muted,
      outline: outline,
      outlineVariant: colors.line,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
    );
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );
    final radius14 = BorderRadius.circular(14);

    return base.copyWith(
      textTheme: textTheme,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandFill,
          foregroundColor: onBrandFill,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.credit,
          minimumSize: const Size(44, 44),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: colors.credit, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: error),
        ),
        hintStyle: TextStyle(color: colors.muted),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.credit
              : const Color(0xFF8A919E),
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scaffold,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
