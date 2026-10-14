import 'package:flutter/material.dart';

import 'weather_model.dart';

/// The one bundled photograph: a generated, decorative northern-lake dusk (see docs/WEATHER.md for provenance).
const sceneAsset = 'assets/scenes/scenic-dusk.webp';

/// How one scene key is painted: the photograph, a colour grade for its landscape, and (for the weather scenes) a
/// painted [Sky] that replaces the photograph's own sky and the sky's reflection in the lake. Every scene keeps the
/// same landscape and camera; only light and weather change. A proper art pack replaces this table
/// (key -> asset + treatment) without touching the resolver or the screens.
@immutable
class SceneArt {
  const SceneArt({this.asset = sceneAsset, this.matrix, this.sky});
  final String? asset;

  /// Grade for the landscape (mountains, trees, water). Null = the photograph as it is.
  final List<double>? matrix;

  /// Null = the photograph's own dusk sky.
  final Sky? sky;
}

/// A painted, static sky and weather layer. Colours are opaque; strengths are 0..1. Everything is drawn from fixed
/// seeds, so a scene looks the same every time it is painted.
@immutable
class Sky {
  const Sky({
    required this.zenith,
    required this.horizon,
    required this.water,
    this.sun = 0,
    this.moon = false,
    this.stars = 0,
    this.cloud,
    this.cloudShadow,
    this.clouds = 0,
    this.cloudLow = 0.38,
    this.rain = 0,
    this.snow = 0,
    this.haze = 0,
    this.hazeColor = const Color(0xFFDADCDD),
    this.fog = false,
    this.ground = 0,
    this.groundColor = const Color(0xFFF1F4F8),
  });

  /// Sky gradient, top to the ridge; [water] is the lake below it, near (reflecting the horizon) to deep.
  final Color zenith, horizon;
  final List<Color> water;

  /// Warm glow of a sun high on the right (0 = none).
  final double sun;
  final bool moon;
  final int stars;

  /// Soft cloud masses: lit tops and darker undersides, [clouds] of them down to [cloudLow] of the photo's height.
  final Color? cloud, cloudShadow;
  final int clouds;
  final double cloudLow;

  /// Fine diagonal streaks, small dots of snow, a misty band at the horizon, and for fog many bands hiding the hills.
  final double rain, snow, haze;
  final Color hazeColor;
  final bool fog;

  /// A pale lift over the lower landscape and lake (snow cover).
  final double ground;
  final Color groundColor;

  /// The same weather at a light between this one's and [other]'s, without sun, moon or stars.
  Sky toward(Sky other, double t) => Sky(
      zenith: Color.lerp(zenith, other.zenith, t)!, horizon: Color.lerp(horizon, other.horizon, t)!,
      water: [for (var i = 0; i < water.length; i++) Color.lerp(water[i], other.water[i], t)!],
      cloud: Color.lerp(cloud, other.cloud, t), cloudShadow: Color.lerp(cloudShadow, other.cloudShadow, t),
      clouds: clouds, cloudLow: cloudLow, rain: rain, snow: snow, haze: haze, hazeColor: Color.lerp(hazeColor, other.hazeColor, t)!, fog: fog,
      ground: ground, groundColor: Color.lerp(groundColor, other.groundColor, t)!);
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

/// [grade] with an alpha that keeps the photograph's dark silhouettes (hills, trees) and lets its bright sky and lake
/// reflections through to the painted sky beneath: opaque below luminance [lo], clear above [hi]. The constant term
/// scales with the source alpha, never a fixed offset: a colour filter's layer is unbounded, and an offset would turn
/// every transparent pixel around the photograph opaque.
List<double> silhouette(List<double> grade, {double lo = 0.2, double hi = 0.4}) {
  final k = 1 / (hi - lo);
  return [...grade.sublist(0, 15), -0.2126 * k, -0.7152 * k, -0.0722 * k, hi * k, 0];
}

const _skies = <String, (Sky, Sky)>{
  // Clean blue with a soft sun / deep navy with a moon and a sparse field of stars.
  'clear': (
    Sky(zenith: Color(0xFF2F72C8), horizon: Color(0xFFB8D8F2), water: [Color(0xFF9EC6E8), Color(0xFF2F6299)], sun: 1),
    Sky(zenith: Color(0xFF040A20), horizon: Color(0xFF1C3264), water: [Color(0xFF1B2D58), Color(0xFF040918)], moon: true, stars: 90),
  ),
  // Neutral grey masses over the whole sky: lighter by day, a lit slate by night (town glow on the cloud base).
  'cloudy': (
    Sky(zenith: Color(0xFF7D858F), horizon: Color(0xFFB9BEC4), water: [Color(0xFFA3AAB2), Color(0xFF5E6872)],
        cloud: Color(0xFFDDE0E3), cloudShadow: Color(0xFF6C7580), clouds: 34),
    Sky(zenith: Color(0xFF30353C), horizon: Color(0xFF59606A), water: [Color(0xFF4A515A), Color(0xFF181B20)],
        cloud: Color(0xFF6A727C), cloudShadow: Color(0xFF22262C), clouds: 34),
  ),
  // Low dark cloud with a cold blue-green cast, fine streaks, a misty horizon.
  'rain': (
    Sky(zenith: Color(0xFF3F4C56), horizon: Color(0xFF85929B), water: [Color(0xFF72808A), Color(0xFF323E47)],
        cloud: Color(0xFF66737D), cloudShadow: Color(0xFF34404A), clouds: 30, cloudLow: 0.42, rain: 1, haze: 0.55, hazeColor: Color(0xFF94A2AB)),
    Sky(zenith: Color(0xFF16262C), horizon: Color(0xFF3A525C), water: [Color(0xFF2E444E), Color(0xFF0A161A)],
        cloud: Color(0xFF34505A), cloudShadow: Color(0xFF0E1C22), clouds: 30, cloudLow: 0.42, rain: 1, haze: 0.5, hazeColor: Color(0xFF46626C)),
  ),
  // Pale cool overcast, a whitened shore and lake, small static flakes.
  'snow': (
    Sky(zenith: Color(0xFFB2C0D2), horizon: Color(0xFFE6ECF4), water: [Color(0xFFEAF0F7), Color(0xFFC8D3E0)],
        cloud: Color(0xFFF1F4F8), cloudShadow: Color(0xFFA2B0C2), clouds: 18, snow: 1, haze: 0.3, hazeColor: Color(0xFFE6ECF4), ground: 0.55),
    Sky(zenith: Color(0xFF2A3654), horizon: Color(0xFF66769A), water: [Color(0xFF8494B4), Color(0xFF3C4864)],
        cloud: Color(0xFF55658A), cloudShadow: Color(0xFF1E2840), clouds: 18, snow: 1, haze: 0.3, hazeColor: Color(0xFF7484A6), ground: 0.32, groundColor: Color(0xFFB0BED6)),
  ),
  // Warm grey banks of haze hiding the far hills; low contrast.
  'fog': (
    Sky(zenith: Color(0xFFBDB9B1), horizon: Color(0xFFD9D5CD), water: [Color(0xFFD3CFC7), Color(0xFFA29E96)], fog: true, hazeColor: Color(0xFFDCD8D0)),
    Sky(zenith: Color(0xFF34322F), horizon: Color(0xFF5A5751), water: [Color(0xFF524F4A), Color(0xFF221F1C)], fog: true, hazeColor: Color(0xFF6A665F)),
  ),
  // Very dark slate under heavy cloud and heavier rain; never lightning.
  'storm': (
    Sky(zenith: Color(0xFF252B33), horizon: Color(0xFF5A6470), water: [Color(0xFF4A545F), Color(0xFF181C21)],
        cloud: Color(0xFF4A535E), cloudShadow: Color(0xFF14171B), clouds: 44, cloudLow: 0.44, rain: 1, haze: 0.4, hazeColor: Color(0xFF58626D)),
    Sky(zenith: Color(0xFF020304), horizon: Color(0xFF0E1013), water: [Color(0xFF0C0E11), Color(0xFF010101)],
        cloud: Color(0xFF15181C), cloudShadow: Color(0xFF000000), clouds: 44, cloudLow: 0.44, rain: 0.9, haze: 0.3, hazeColor: Color(0xFF1A1D21)),
  ),
};

/// Landscape grade per family and light (null = the provider did not say day or night).
List<double> _grade(String family, bool? isDay) {
  double light(double d, double n) => isDay == true ? d : isDay == false ? n : (d + n) / 2;
  return switch (family) {
    'clear' => grade(saturation: light(1.05, 0.5), brightness: light(0.1, -0.12),
        gain: isDay == false ? const [0.5, 0.64, 1.0] : const [0.92, 1.02, 1.06]),
    'partly' => grade(saturation: light(0.9, 0.5), brightness: light(0.08, -0.12), gain: isDay == false ? const [0.5, 0.64, 1.0] : const [0.94, 1.0, 1.04]),
    'cloudy' => grade(saturation: 0.3, contrast: 0.85, brightness: light(0.02, -0.06), gain: const [0.98, 0.98, 1.0]),
    'rain' => grade(saturation: 0.25, contrast: 0.85, brightness: light(-0.04, -0.15), gain: const [0.86, 0.96, 1.0]),
    'snow' => grade(saturation: 0.15, contrast: 1.0, brightness: light(0.14, -0.02), gain: const [0.94, 1.0, 1.1]),
    'fog' => grade(saturation: 0.15, contrast: 0.5, brightness: light(0.16, -0.06), gain: const [1.03, 1.0, 0.95]),
    'storm' => grade(saturation: 0.2, brightness: light(-0.14, -0.3), gain: const [0.8, 0.85, 0.92]),
    _ => grade(),
  };
}

SceneArt _art(String family, bool? isDay) {
  // ponytail: partly borrows the clear sky until its own painted sky lands; replace with _skies['partly'].
  final (day, night) = _skies[family] ?? _skies['clear']!;
  // Neutral (the provider did not say day or night): a muted light between the two.
  final sky = switch (isDay) { true => day, false => night, null => day.toward(night, 0.45) };
  return SceneArt(matrix: silhouette(_grade(family, isDay)), sky: sky);
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
