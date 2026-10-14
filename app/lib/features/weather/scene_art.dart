import 'package:flutter/material.dart';

import 'weather_model.dart';

/// The one bundled photograph: a generated, decorative northern-lake dusk (see docs/WEATHER.md for provenance).
const sceneAsset = 'assets/scenes/scenic-dusk.webp';

/// How one scene key is painted: the photograph, a colour grade, and an optional restrained tint/mist layer.
/// The weather scenes are graded treatments of that same photograph, not separate photographs. A proper art pack
/// replaces this table (key -> asset + treatment) without touching the resolver or the screens.
@immutable
class SceneArt {
  const SceneArt({this.asset = sceneAsset, this.matrix, this.wash = const []});
  final String? asset;
  final List<double>? matrix;

  /// A vertical gradient laid over the graded photograph (top to bottom). Empty = none.
  final List<Color> wash;
}

/// A 5x4 colour matrix: saturation, then per-channel gain, contrast around mid-grey, and a brightness lift
/// (-1..1 of full scale).
List<double> grade({double saturation = 1, double brightness = 0, double contrast = 1, List<double> gain = const [1, 1, 1]}) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = saturation, sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  final rows = [
    [sr + s, sg, sb],
    [sr, sg + s, sb],
    [sr, sg, sb + s],
  ];
  final offset = brightness * 255 + (1 - contrast) * 128;
  return [
    for (var i = 0; i < 3; i++) ...[for (final v in rows[i]) v * gain[i] * contrast, 0, offset],
    0, 0, 0, 1, 0,
  ];
}

SceneArt _art(String family, bool? isDay) {
  // Neutral (the provider did not say day or night): the family's mood on the dusk light as it is.
  final day = isDay == true, night = isDay == false;
  double light(double d, double n, [double neutral = 0]) => day ? d : night ? n : neutral;
  return switch (family) {
    'clear' => SceneArt(
        matrix: grade(saturation: light(0.95, 0.55, 1), brightness: light(0.10, -0.14), gain: day ? const [0.92, 1.0, 1.1] : night ? const [0.62, 0.72, 1.0] : const [1, 1, 1]),
        wash: day ? const [Color(0x405A9BD8), Color(0x00000000)] : night ? const [Color(0x500A1636), Color(0x00000000)] : const []),
    'cloudy' => SceneArt(
        matrix: grade(saturation: 0.35, contrast: 0.85, brightness: light(0.04, -0.12, -0.04), gain: const [0.96, 0.98, 1.02]),
        wash: night ? const [Color(0x40202630), Color(0x00000000)] : const [Color(0x38A0A8B4), Color(0x00000000)]),
    'rain' => SceneArt(
        matrix: grade(saturation: 0.3, contrast: 0.88, brightness: light(-0.04, -0.16, -0.08), gain: const [0.86, 0.93, 1.02]),
        wash: night ? const [Color(0x30101820), Color(0x407A8896)] : const [Color(0x206E7C8A), Color(0x50A6B2BE)]),
    'snow' => SceneArt(
        matrix: grade(saturation: 0.2, contrast: 0.8, brightness: light(0.16, -0.04, 0.06), gain: const [0.95, 1.0, 1.08]),
        wash: night ? const [Color(0x40C8D2E0), Color(0x20283040)] : const [Color(0x60F2F5FA), Color(0x30F2F5FA)]),
    'fog' => SceneArt(
        matrix: grade(saturation: 0.25, contrast: 0.6, brightness: light(0.12, -0.06, 0.04)),
        wash: night ? const [Color(0x50707880), Color(0x60707880)] : const [Color(0x70DDE1E6), Color(0x80DDE1E6)]),
    'storm' => SceneArt(
        matrix: grade(saturation: 0.3, contrast: 1.05, brightness: light(-0.18, -0.28, -0.22), gain: const [0.75, 0.8, 0.9]),
        wash: const [Color(0x502A323C), Color(0x10000000)]),
    _ => const SceneArt(),
  };
}

/// Scene key -> how to paint it. Every key the resolver can return has an entry.
final Map<String, SceneArt> sceneArt = {
  'dusk': const SceneArt(),
  'plain': const SceneArt(asset: null),
  for (final f in weatherFamilies) ...{
    '$f-day': _art(f, true),
    '$f-night': _art(f, false),
    '$f-neutral': _art(f, null),
  },
};
