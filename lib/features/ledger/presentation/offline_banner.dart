import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../application/providers.dart';

/// Şeridin metni; ekran okuyucu da bunu okur.
const offlineBannerTitle = 'Çevrimdışısınız.';
const offlineBannerBody =
    'Son bilinen veriler gösteriliyor. Bağlantı gelene kadar yeni kayıt ve '
    'onay gönderilemez.';

// Şerit zamanlaması. Firestore bağlantı kopunca hemen "önbellekten" demez;
// yeniden bağlanma da başarısız olunca der. Bir anlık kopmalar çoğu zaman
// buraya hiç ulaşmaz, kalanları bu süreler süzer.

/// Açılışta (ve uygulamaya dönünce) ilk veri önce önbellekten gelir, sunucu
/// yanıtı normal bağlantıda 1-2 saniyede, yavaş mobil bağlantıda birkaç
/// saniyede gelir. Bu süre dolmadan şerit çıkmaz.
const offlineStartGrace = Duration(seconds: 8);

/// Sunucuyla eşitlendikten sonra bağlantı bu kadar kopuk kalırsa şerit
/// çıkar; asansör, baz istasyonu değişimi gibi kısa kopmalar görünmez.
const offlineShowAfter = Duration(seconds: 3);

/// Bağlantı bu kadar süre geri gelmiş kalırsa şerit kalkar; bir an gelip
/// giden bağlantı şeridi yakıp söndürmez.
const offlineHideAfter = Duration(seconds: 2);

/// Ana kabuğun içeriği ve çevrimdışıyken üstünde ince bir uyarı şeridi.
/// Şerit bağlantı gelince kendiliğinden kalkar.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with WidgetsBindingObserver {
  bool _visible = false;

  /// Bu açılışta (ya da dönüşte) sunucudan güncel veri geldi mi.
  bool _synced = false;
  bool _foreground = true;

  /// Bekleyen değişim; süre durumun ilk değiştiği andan sayılır.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      serverSyncProvider,
      (_, _) => _update(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      // Arka planda bağlantı kapanmış olabilir; yeniden bağlanırken
      // açılıştaki gibi beklenir (dönüşte şerit bir an yanıp sönmesin).
      _synced = false;
      _update();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Arka planda karar verilmez; şerit olduğu gibi kalır.
      _foreground = false;
      _cancel();
    }
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _update() {
    final value = ref.read(serverSyncProvider);
    // Hata ya da henüz yanıt yok: durum bilinmiyor, şerit gösterilmez.
    final synced = value.hasError ? null : value.valueOrNull;
    if (synced == true) _synced = true;
    if (!_foreground) return;
    final offline = synced == false;
    if (offline == _visible) {
      _cancel();
      return;
    }
    if (_timer != null) return;
    final wait = !offline
        ? offlineHideAfter
        : _synced
        ? offlineShowAfter
        : offlineStartGrace;
    _timer = Timer(wait, () {
      _timer = null;
      if (mounted) setState(() => _visible = offline);
    });
  }

  @override
  Widget build(BuildContext context) {
    // İçerik ağaçta yerini korur (sekme ve kaydırma durumu kaybolmaz).
    return Column(
      children: [
        if (_visible) const _Band() else const SizedBox.shrink(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            // Şerit durum çubuğu boşluğunu kendisi bırakır.
            removeTop: _visible,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band();

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: c.pending, height: 1.35);
    // Canlı bölge: şerit çıkınca ekran okuyucu kendiliğinden okur.
    return Semantics(
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: c.pendingSoft,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_rounded, size: 18, color: c.pending),
                const SizedBox(width: 10),
                // Satır sınırı yok: büyük yazıda şerit uzar, taşmaz.
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: offlineBannerTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' $offlineBannerBody'),
                      ],
                    ),
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
