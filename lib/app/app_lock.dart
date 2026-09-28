import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ledger/application/providers.dart';
import '../services/auth_service.dart';
import 'theme.dart';

/// Cihazın kendi kilidiyle doğrulama: parmak izi, yüz ya da telefon PIN'i.
abstract class DeviceAuth {
  /// Cihazda ekran kilidi (biyometrik ya da PIN) tanımlı mı.
  Future<bool> isAvailable();

  /// Doğrulama penceresini açar; başarılıysa true.
  Future<bool> authenticate(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // PIN/desen de kabul edilir (biometricOnly: false): parmak izi
      // tanımlı olmayan ya da okumayan cihazda kullanıcı kilitli kalmasın.
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Kilit doğrulaması yapılamadı: $e');
      return false;
    }
  }
}

final deviceAuthProvider = Provider<DeviceAuth>((ref) => LocalDeviceAuth());

/// Testlerde saat verilebilsin diye.
final appLockClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Oturum açık mı (kilit yalnızca oturum varken anlamlıdır).
final signedInProvider = Provider<bool>(
  (ref) => ref.watch(authUserProvider).valueOrNull != null,
);

@immutable
class AppLockState {
  const AppLockState({this.enabled = false, this.locked = false});

  final bool enabled;
  final bool locked;
}

/// Uygulama kilidi: açıksa uygulama açılırken ve arka planda
/// [AppLockController.grace] süresinden uzun kaldıktan sonra cihaz
/// doğrulaması ister. Ayar yalnızca bu cihazda tutulur.
class AppLockController extends StateNotifier<AppLockState> {
  /// [initiallyEnabled] verilirse ayar önceden okunmuştur (main): uygulama
  /// ilk karesinden itibaren kilitli açılır, içerik bir an bile görünmez.
  AppLockController(this._auth, this._clock, {bool? initiallyEnabled})
    : _loaded = initiallyEnabled != null,
      super(
        AppLockState(
          enabled: initiallyEnabled ?? false,
          locked: initiallyEnabled ?? false,
        ),
      );

  static const prefsKey = 'appLock.enabled';

  /// Kısa geçişlerde (bildirime bakıp dönme) tekrar sorulmaz.
  static const grace = Duration(minutes: 1);

  final DeviceAuth _auth;
  final DateTime Function() _clock;
  DateTime? _backgroundSince;
  bool _authenticating = false;
  bool _loaded;

  /// Kayıtlı ayar (main, runApp'tan önce okur).
  static Future<bool> readEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ayar önceden okunmadıysa okur; kilit açıksa uygulama kilitlenir.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(prefsKey) ?? false;
      if (mounted) state = AppLockState(enabled: enabled, locked: enabled);
    } catch (_) {
      // Ayar okunamazsa kilit kapalı sayılır.
    }
  }

  void onBackground() {
    // Doğrulama penceresi (PIN ekranı) uygulamayı arka plana atar; bu
    // geçiş sayılmaz.
    if (!state.enabled || _authenticating) return;
    _backgroundSince ??= _clock();
  }

  void onForeground() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (!state.enabled || _authenticating || since == null) return;
    if (_clock().difference(since) >= grace) {
      state = AppLockState(enabled: true, locked: true);
    }
  }

  Future<bool> _verify(String reason) async {
    if (_authenticating) return false;
    _authenticating = true;
    try {
      return await _auth.authenticate(reason);
    } finally {
      _authenticating = false;
      _backgroundSince = null;
    }
  }

  /// Kilidi açar; başarılıysa true.
  Future<bool> unlock() async {
    final ok = await _verify("Pacta'yı açmak için kimliğinizi doğrulayın");
    if (ok && mounted) state = AppLockState(enabled: state.enabled);
    return ok;
  }

  /// Oturum kapanınca kilit ekranı kalkar (giriş ekranında kilit yok).
  void release() {
    _backgroundSince = null;
    state = AppLockState(enabled: state.enabled);
  }

  /// Kilidi açar/kapatır; her ikisi de cihaz doğrulaması ister (telefonu
  /// eline alan biri kilidi kapatamasın). Sonuç kullanıcıya gösterilecek
  /// hata ya da başarıda null.
  Future<String?> setEnabled(bool value) async {
    if (value && !await _auth.isAvailable()) {
      return 'Bu cihazda ekran kilidi (parmak izi, yüz ya da PIN) tanımlı '
          'değil. Önce telefonun ayarlarından ekran kilidi ekleyin.';
    }
    final ok = await _verify(
      value
          ? 'Uygulama kilidini açmak için kimliğinizi doğrulayın'
          : 'Uygulama kilidini kapatmak için kimliğinizi doğrulayın',
    );
    if (!ok) return 'Doğrulanamadı; ayar değişmedi.';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (_) {
      return 'Ayar kaydedilemedi.';
    }
    if (mounted) state = AppLockState(enabled: value);
    return null;
  }
}

/// main'de runApp'tan önce okunan ayar (null: okunmadı, gate okur).
final appLockInitiallyEnabledProvider = Provider<bool?>((ref) => null);

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(
    ref.watch(deviceAuthProvider),
    ref.watch(appLockClockProvider),
    initiallyEnabled: ref.watch(appLockInitiallyEnabledProvider),
  ),
);

/// Tüm sayfaların üstünde durur: kilitliyken içerik gizlenir (durumu
/// korunur) ve kilit ekranı gösterilir.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(appLockProvider.notifier).load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        lock.onBackground();
      case AppLifecycleState.resumed:
        lock.onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked =
        ref.watch(appLockProvider.select((s) => s.locked)) &&
        ref.watch(signedInProvider);
    // Ağaç yapısı değişmez: içerik (sayfa yığını) kilitliyken de yaşar.
    return Stack(
      children: [
        Offstage(offstage: locked, child: widget.child),
        if (locked) const _LockScreen(),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Ekran açılınca doğrulama kendiliğinden sorulur.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await ref.read(appLockProvider.notifier).unlock();
    if (!ok && mounted) setState(() => _failed = true);
  }

  Future<void> _signOut() async {
    ref.read(appLockProvider.notifier).release();
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.creditSoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.lock_rounded, size: 34, color: c.credit),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pacta kilitli',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _failed
                      ? 'Doğrulanamadı. Tekrar deneyin.'
                      : 'Devam etmek için parmak izi, yüz ya da telefon '
                            'şifrenizle doğrulayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Kilidi aç'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _signOut, child: const Text('Çıkış yap')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
