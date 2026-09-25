import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../money/money.dart';
import '../text/turkish.dart';

/// Tutar metni. [colorBySign] açıksa pozitif alacak, negatif borç renginde.
class AmountText extends StatelessWidget {
  const AmountText(
    this.money, {
    super.key,
    this.signed = false,
    this.colorBySign = false,
    this.color,
    this.style,
  });

  final Money money;
  final bool signed;
  final bool colorBySign;
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.pacta;
    Color? resolved = color;
    if (resolved == null && colorBySign && !money.isZero) {
      resolved = money.isNegative ? colors.debt : colors.credit;
    }
    return Text(
      money.format(signed: signed),
      style: (style ?? Theme.of(context).textTheme.titleSmall)?.copyWith(
        color: resolved,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

enum ChipTone { credit, debt, pending, dispute, neutral }

extension ToneColors on ChipTone {
  (Color fg, Color bg) colors(PactaColors c, ColorScheme scheme) =>
      switch (this) {
        ChipTone.credit => (c.credit, c.creditSoft),
        ChipTone.debt => (c.debt, c.debtSoft),
        ChipTone.pending => (c.pending, c.pendingSoft),
        ChipTone.dispute => (c.dispute, c.disputeSoft),
        ChipTone.neutral => (c.muted, c.line),
      };
}

/// Yuvarlak durum etiketi ("Onayınız bekleniyor").
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context.pacta, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kişi baş harfleri.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.tone = ChipTone.credit,
    this.size = 40,
    this.square = false,
  });

  final String name;
  final ChipTone tone;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context.pacta, Theme.of(context).colorScheme);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(square ? size * 0.3 : size / 2),
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          color: fg,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Bölüm başlığı ve isteğe bağlı sağdaki eylem.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 12, 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Beyaz, köşeleri yuvarlak içerik kutusu.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Onaylı bakiye kartı (koyu kart, yeşil tutar).
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.net,
    required this.receivable,
    required this.payable,
    this.footnote,
  });

  final Money net;
  final Money receivable;
  final Money payable;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;
    Widget box(String label, Money value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.balanceCardInner,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: c.balanceCardMuted)),
            const SizedBox(height: 2),
            AmountText(value, color: c.balanceCardText),
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.balanceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onaylı bakiye',
            style: TextStyle(fontSize: 13, color: c.balanceCardMuted),
          ),
          const SizedBox(height: 10),
          AmountText(
            net,
            signed: true,
            color: net.isNegative ? c.debt : c.balanceCardAmount,
            style: text.headlineMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              box('Alacağınız', receivable),
              const SizedBox(width: 10),
              box('Borcunuz', payable),
            ],
          ),
          if (footnote != null) ...[
            const SizedBox(height: 12),
            Text(footnote!, style: TextStyle(fontSize: 12, color: c.balanceCardMuted)),
          ],
        ],
      ),
    );
  }
}

/// Boş liste: suçlamaz, yol gösterir.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.creditSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: c.credit),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Yükleme hatası; tekrar deneme düğmesiyle.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Şu an yüklenemedi',
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
    );
  }
}
