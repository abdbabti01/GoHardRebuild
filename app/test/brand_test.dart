import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/features/auth/auth_screen.dart';

import 'ui_support.dart';

/// The original GoHard artwork reaches the platform resources that are really used (docs/BRANDING.md). Checks the
/// outcome — the right picture, at the right size, opaque where it must be, wired where the platform looks — not
/// file names. Exports come from scripts/build-brand-assets.ps1.
const _master = '../design/brand/original-ios-app-icon-1024.png';
const _res = 'android/app/src/main/res';
const _ios = 'ios/Runner';

/// GoHardAPP 357a8b3 assets/logo.png and its iOS 1024 icon decode to these same pixels (SOURCE_MANIFEST.json).
const _masterSha = 'b902bbd79dd7d51fbe52d92b8779c61b39835ffd9704fdfbe79b61dffd6d2ce5';
/// The Flutter template icon the rebuild shipped before.
const _flutterDefaultSha = '7770183009e914112de7d8ef1d235a6a30c5834424858e0d2f8253f6b8d31926';

String _sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

Future<({int w, int h, Uint8List rgba})> _decode(WidgetTester tester, String path) async => (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (w: image.width, h: image.height, rgba: data!.buffer.asUint8List());
    }))!;

extension on ({int w, int h, Uint8List rgba}) {
  int alpha(double fx, double fy) => rgba[(((fy * (h - 1)).round() * w + (fx * (w - 1)).round()) * 4) + 3];
  double luma(double fx, double fy) {
    final i = ((fy * (h - 1)).round() * w + (fx * (w - 1)).round()) * 4;
    return (rgba[i] + rgba[i + 1] + rgba[i + 2]) / 3;
  }
  bool get opaque {
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 255) return false;
    }
    return true;
  }
  /// The original's look at any size: black corners, a bright GH in the middle.
  bool get readsAsOriginal {
    var brightest = 0.0;
    for (var y = 0.35; y <= 0.65; y += 0.05) {
      for (var x = 0.3; x <= 0.7; x += 0.05) {
        if (luma(x, y) > brightest) brightest = luma(x, y);
      }
    }
    return luma(0.02, 0.02) < 20 && luma(0.98, 0.98) < 20 && brightest > 150;
  }
}

void main() {
  test('the master is the unchanged original', () {
    expect(_sha(_master), _masterSha);
  });

  testWidgets('iOS: every app icon the catalog lists is the original, opaque and at its size', (tester) async {
    final set = '$_ios/Assets.xcassets/AppIcon.appiconset';
    final images = (jsonDecode(File('$set/Contents.json').readAsStringSync())['images'] as List).cast<Map<String, dynamic>>();
    expect(images, isNotEmpty);
    for (final i in images) {
      final path = '$set/${i['filename']}';
      final px = (double.parse((i['size'] as String).split('x').first) * double.parse((i['scale'] as String).replaceAll('x', ''))).round();
      final png = await _decode(tester, path);
      expect((png.w, png.h), (px, px), reason: path);
      expect(png.opaque, isTrue, reason: '$path has transparency; iOS rejects it');
      expect(png.readsAsOriginal, isTrue, reason: path);
      expect(_sha(path), isNot(_flutterDefaultSha), reason: path);
    }
    expect(_sha('$set/Icon-App-1024x1024@1x.png'), _masterSha);
    // Release, Profile and Debug all take this catalog.
    final project = File('$_ios/../Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(RegExp('ASSETCATALOG_COMPILER_APPICON_NAME = (\\w+);').allMatches(project).map((m) => m[1]).toSet(), {'AppIcon'});
  });

  testWidgets('Android: the launcher icon is the original badge on every density, whole inside the adaptive mask', (tester) async {
    expect(File('$_res/../AndroidManifest.xml').readAsStringSync(), contains('android:icon="@mipmap/ic_launcher"'));
    final adaptive = File('$_res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(adaptive, allOf(contains('@mipmap/ic_launcher_foreground'), contains('@color/ic_launcher_background')));
    expect(File('$_res/values/colors.xml').readAsStringSync(), contains('<color name="ic_launcher_background">#000000</color>'));
    for (final (d, s) in [('mdpi', 1.0), ('hdpi', 1.5), ('xhdpi', 2.0), ('xxhdpi', 3.0), ('xxxhdpi', 4.0)]) {
      final legacy = await _decode(tester, '$_res/mipmap-$d/ic_launcher.png');
      expect((legacy.w, legacy.readsAsOriginal), ((48 * s).round(), true), reason: d);
      final fg = await _decode(tester, '$_res/mipmap-$d/ic_launcher_foreground.png');
      expect(fg.w, (108 * s).round(), reason: d);
      // Outside the 72 dp viewport: nothing (the black background shows). The GH sits well inside the 66 dp safe circle.
      expect(fg.alpha(0.1, 0.1), 0, reason: d);
      expect(fg.alpha(0.5, 0.5), 255, reason: d);
      expect(fg.luma(0.5, 0.5) > 150 || fg.luma(0.45, 0.5) > 150 || fg.luma(0.55, 0.5) > 150, isTrue, reason: '$d: the GH is not at the centre');
    }
  });

  testWidgets('launch screens show the badge on the page colours, light and dark with the phone', (tester) async {
    final storyboard = File('$_ios/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
    expect(storyboard, allOf(contains('image="LaunchImage"'), contains('<image name="LaunchImage" width="112" height="107"/>'), contains('name="LaunchBackground"')));
    for (final (file, scale) in [('LaunchImage.png', 1), ('LaunchImage@2x.png', 2), ('LaunchImage@3x.png', 3)]) {
      final png = await _decode(tester, '$_ios/Assets.xcassets/LaunchImage.imageset/$file');
      expect((png.w, png.h), (112 * scale, 107 * scale), reason: file);
      _expectBadge(png, file);
    }
    for (final dir in ['drawable', 'drawable-v21']) {
      expect(File('$_res/$dir/launch_background.xml').readAsStringSync(), allOf(contains('@color/launch_background'), contains('@drawable/launch_badge')));
    }
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      _expectBadge(await _decode(tester, '$_res/drawable-$d/launch_badge.png'), d);
    }
    for (final dir in ['values-v31', 'values-night-v31']) {
      expect(File('$_res/$dir/styles.xml').readAsStringSync(), contains('<item name="android:windowSplashScreenBackground">@color/launch_background</item>'), reason: dir);
    }
    // The page colours stay the warm light and the dark the app had.
    expect(File('$_res/values/colors.xml').readAsStringSync(), contains('#F6F6F4'));
    expect(File('$_res/values-night/colors.xml').readAsStringSync(), contains('#101114'));
  });

  testWidgets('sign-in: badge beside the GoHard name, read once, not mirrored in Arabic, fields still in view', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: '2026-10-11')))!, home: const AuthScreen());
    _expectBadge(await _decode(tester, 'assets/images/gohard-badge.png'), 'in-app badge');
    expect(find.bySemanticsLabel('GoHard'), findsOneWidget);
    final ltrBadge = tester.getCenter(find.byType(BrandBadge)).dx, ltrName = tester.getCenter(find.text('GoHard')).dx;
    expect(ltrBadge, lessThan(ltrName));
    container.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse('ar'));
    await tester.pumpAndSettle();
    // The lockup follows the reading direction; the artwork itself is never flipped.
    expect(tester.getCenter(find.byType(BrandBadge)).dx, greaterThan(tester.getCenter(find.text('GoHard')).dx));
    expect(tester.widget<Image>(find.descendant(of: find.byType(BrandBadge), matching: find.byType(Image))).matchTextDirection, isFalse);
    // The email field is still on the first screen of a 390 x 844 phone.
    expect(tester.getBottomLeft(find.byKey(const Key('auth-email'))).dy, lessThan(844));
    semantics.dispose();
  });
}

/// The badge alone: transparent outside its own rounded corners, opaque and dark inside, the GH bright in the middle.
void _expectBadge(({int w, int h, Uint8List rgba}) png, String reason) {
  expect(png.alpha(0, 0), 0, reason: reason);
  expect(png.alpha(1, 1), 0, reason: reason);
  expect(png.alpha(0.5, 0.05), 255, reason: reason);
  expect(png.alpha(0.5, 0.5), 255, reason: reason);
  expect(png.luma(0.5, 0.9), lessThan(60), reason: reason);
  var bright = 0;
  for (var x = 0.2; x <= 0.8; x += 0.02) {
    if (png.luma(x, 0.5) > 170) bright++;
  }
  expect(bright, greaterThanOrEqualTo(5), reason: reason);
}
