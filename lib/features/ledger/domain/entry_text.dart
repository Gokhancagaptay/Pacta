import 'package:flutter/material.dart';

import '../../../core/ui/widgets.dart';
import 'models.dart';

/// Kayıtları kullanıcının bakış açısından anlatan metinler.
///
/// Terimler tasarım kurallarındaki sözlüğe uyar: "borç yazdı",
/// "ödeme bildirdi", "onayla / itiraz et / reddet", "düzeltildi".
class EntryText {
  EntryText._();

  /// Liste başlığı: "Borç verdiniz", "Ödeme aldınız"...
  static String title(LedgerEntry e, Side me) {
    final mine = e.deltaFor(me);
    return switch (e.kind) {
      EntryKind.reversal => 'Düzeltme',
      EntryKind.debt => mine > 0 ? 'Borç verdiniz' : 'Borç aldınız',
      EntryKind.payment => mine < 0 ? 'Ödeme aldınız' : 'Ödeme yaptınız',
    };
  }

  /// Ayrıntı cümlesi: "Mert Kaya size 400,00 ₺ borç yazdı."
  static String sentence(LedgerEntry e, Side me, String otherName) {
    final amount = e.amount.format();
    final mine = e.deltaFor(me);
    final byMe = e.proposedBy == me;
    switch (e.kind) {
      case EntryKind.reversal:
        return byMe
            ? 'Bir kaydı düzelttiniz: $amount.'
            : '$otherName bir kaydı düzeltti: $amount.';
      case EntryKind.debt:
        if (byMe) {
          return mine > 0
              ? 'Borç verdiğinizi kaydettiniz: $amount.'
              : 'Borç aldığınızı kaydettiniz: $amount.';
        }
        return mine < 0
            ? '$otherName size $amount borç yazdı.'
            : '$otherName, sizden $amount borç aldığını kaydetti.';
      case EntryKind.payment:
        if (byMe) {
          return mine < 0
              ? 'Ödeme aldığınızı kaydettiniz: $amount.'
              : 'Ödeme yaptığınızı kaydettiniz: $amount.';
        }
        return mine < 0
            ? '$otherName size $amount ödeme yaptığını bildirdi.'
            : '$otherName, sizden $amount ödeme aldığını kaydetti.';
    }
  }

  /// Durum etiketi ve rengi.
  static ({String label, ChipTone tone, IconData icon}) status(
    LedgerEntry e,
    Side me, {
    bool isPrivate = false,
  }) {
    switch (e.state) {
      case EntryState.pending:
        return e.awaitingSide == me
            ? (label: 'Onayınız bekleniyor', tone: ChipTone.pending, icon: Icons.schedule_rounded)
            : (label: 'Karşı tarafın onayı bekleniyor', tone: ChipTone.pending, icon: Icons.schedule_rounded);
      case EntryState.disputed:
        return e.awaitingSide == me
            ? (label: 'İtiraz edildi · düzeltmeniz bekleniyor', tone: ChipTone.dispute, icon: Icons.edit_note_rounded)
            : (label: 'İtirazınız iletildi', tone: ChipTone.dispute, icon: Icons.edit_note_rounded);
      case EntryState.rejected:
        return (label: 'Reddedildi', tone: ChipTone.debt, icon: Icons.block_rounded);
      case EntryState.cancelled:
        return (label: 'Geri çekildi', tone: ChipTone.neutral, icon: Icons.undo_rounded);
      case EntryState.confirmed:
        if (e.reversedBy != null) {
          return (label: 'Düzeltildi', tone: ChipTone.neutral, icon: Icons.history_rounded);
        }
        if (e.reversalPendingId != null) {
          return (label: 'Düzeltme onay bekliyor', tone: ChipTone.pending, icon: Icons.schedule_rounded);
        }
        return (
          label: isPrivate ? 'Kaydedildi' : 'Onaylı',
          tone: ChipTone.credit,
          icon: Icons.check_circle_rounded,
        );
    }
  }

  static const disputeReasons = {
    'amount': 'Tutar yanlış',
    'date': 'Tarih yanlış',
    'description': 'Açıklama yanlış',
    'duplicate': 'Mükerrer kayıt',
    'other': 'Diğer',
  };

  static const rejectReasons = {
    'notAgreed': 'Böyle bir anlaşmamız yok',
    'unknownPerson': 'Bu kişiyi tanımıyorum',
    'other': 'Diğer',
  };

  static String eventLabel(String type) => switch (type) {
    'created' => 'Kaydedildi',
    'confirmed' => 'Onaylandı',
    'disputed' => 'İtiraz edildi',
    'revised' => 'Düzeltildi',
    'rejected' => 'Reddedildi',
    'cancelled' => 'Geri çekildi',
    _ => type,
  };
}
