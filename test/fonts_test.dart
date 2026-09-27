import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uygulama yazı tipini internetten indirmez (main.dart:
/// allowRuntimeFetching = false); kullanılan her kalınlık pakette olmalı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Poppins 400/500/600/700 uygulamaya gömülü', () async {
    final assets = (await AssetManifest.loadFromAssetBundle(
      rootBundle,
    )).listAssets();
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      expect(assets, contains('assets/google_fonts/Poppins-$weight.ttf'));
    }
    expect(assets, contains('assets/google_fonts/OFL.txt'));
  });
}
