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

/// A painted sky and weather layer. Colours are opaque; strengths are 0..1. Everything is drawn from fixed seeds; the
/// clouds, stars, fog, rain and snow move gently (sky_painter.dart, SkyMotionPainter) unless motion is reduced.
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
    this.puffy = false,
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

  /// Separate fair-weather clouds (a few rounded puffs) instead of a deck of soft banks.
  final bool puffy;

  /// Fine diagonal streaks (1 = steady rain, more = heavier), flakes of snow, a misty band at the horizon, and for
  /// fog many bands hiding the hills.
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
      clouds: clouds, cloudLow: cloudLow, puffy: puffy, rain: rain, snow: snow, haze: haze, hazeColor: Color.lerp(hazeColor, other.hazeColor, t)!, fog: fog,
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

// Skies for the scenes whose SceneSpec.dark is false (clear, partly, cloudy, fog and snow by day) stay light enough
// for dark header text; night, rain and storm stay dark enough for light text, in either app mode
// (test/weather_distinct_test.dart measures both).
const _skies = <String, (Sky, Sky)>{
  // Clean bright blue with a soft sun / deep navy with a moon and a twinkling field of stars.
  'clear': (
    Sky(zenith: Color(0xFF5C9EE4), horizon: Color(0xFFD2E7F7), water: [Color(0xFFB4D5EF), Color(0xFF4A80B8)], sun: 1),
    Sky(zenith: Color(0xFF040A20), horizon: Color(0xFF1C3264), water: [Color(0xFF1B2D58), Color(0xFF040918)], moon: true, stars: 90),
  ),
  // Blue with a few bright, puffy clouds drifting across / navy with fewer stars between slow, moonlit clouds.
  'partly': (
    Sky(zenith: Color(0xFF6CA6DE), horizon: Color(0xFFD9E7F1), water: [Color(0xFFBCD6EA), Color(0xFF5585B4)], sun: 0.7,
        cloud: Color(0xFFFFFFFF), cloudShadow: Color(0xFFAFC0D2), clouds: 9, cloudLow: 0.4, puffy: true),
    Sky(zenith: Color(0xFF07102A), horizon: Color(0xFF22345E), water: [Color(0xFF1E2E55), Color(0xFF050A1A)], moon: true, stars: 50,
        cloud: Color(0xFF6A7898), cloudShadow: Color(0xFF1A2236), clouds: 10, cloudLow: 0.4, puffy: true),
  ),
  // Soft light grey masses over the whole sky by day; a lit slate by night (town glow on the cloud base).
  'cloudy': (
    Sky(zenith: Color(0xFFA9B0B8), horizon: Color(0xFFD5D9DD), water: [Color(0xFFC0C6CC), Color(0xFF79838D)],
        cloud: Color(0xFFE9EBED), cloudShadow: Color(0xFF959DA6), clouds: 24),
    Sky(zenith: Color(0xFF262A30), horizon: Color(0xFF474D56), water: [Color(0xFF3C424A), Color(0xFF131518)],
        cloud: Color(0xFF575E68), cloudShadow: Color(0xFF1A1D22), clouds: 24),
  ),
  // Low dark cloud with a cold blue-green cast, fine streaks, a misty horizon.
  'rain': (
    Sky(zenith: Color(0xFF2E3A43), horizon: Color(0xFF5A6770), water: [Color(0xFF55636C), Color(0xFF26313A)],
        cloud: Color(0xFF52606A), cloudShadow: Color(0xFF242E36), clouds: 22, cloudLow: 0.42, rain: 1, haze: 0.45, hazeColor: Color(0xFF6E7C86)),
    Sky(zenith: Color(0xFF12202A), horizon: Color(0xFF2E4650), water: [Color(0xFF263C46), Color(0xFF081216)],
        cloud: Color(0xFF2C4650), cloudShadow: Color(0xFF0A161C), clouds: 22, cloudLow: 0.42, rain: 1, haze: 0.45, hazeColor: Color(0xFF3C5862)),
  ),
  // Pale cool overcast, a whitened shore and lake, slowly falling flakes.
  'snow': (
    Sky(zenith: Color(0xFFBCC9DA), horizon: Color(0xFFE9EEF5), water: [Color(0xFFEAF0F7), Color(0xFFC8D3E0)],
        cloud: Color(0xFFF3F6FA), cloudShadow: Color(0xFFAAB8CA), clouds: 14, snow: 1, haze: 0.3, hazeColor: Color(0xFFE6ECF4), ground: 0.55),
    Sky(zenith: Color(0xFF1E2944), horizon: Color(0xFF4A5A7E), water: [Color(0xFF6A7A9C), Color(0xFF2E3A54)],
        cloud: Color(0xFF45557A), cloudShadow: Color(0xFF161E34), clouds: 14, snow: 1, haze: 0.3, hazeColor: Color(0xFF5E6E92), ground: 0.28, groundColor: Color(0xFF9AA8C2)),
  ),
  // Warm grey banks of haze hiding the far hills, drifting slowly; low contrast.
  'fog': (
    Sky(zenith: Color(0xFFC9C5BD), horizon: Color(0xFFE0DCD4), water: [Color(0xFFD8D4CC), Color(0xFFA8A49C)], fog: true, hazeColor: Color(0xFFE2DED6)),
    Sky(zenith: Color(0xFF282624), horizon: Color(0xFF45423D), water: [Color(0xFF423F3A), Color(0xFF1A1816)], fog: true, hazeColor: Color(0xFF4A4741)),
  ),
  // Very dark slate under heavy cloud and heavier rain; never lightning.
  'storm': (
    Sky(zenith: Color(0xFF1E232A), horizon: Color(0xFF434C56), water: [Color(0xFF3C4550), Color(0xFF14181C)],
        cloud: Color(0xFF3E4650), cloudShadow: Color(0xFF101317), clouds: 28, cloudLow: 0.44, rain: 1.4, haze: 0.4, hazeColor: Color(0xFF48525C)),
    Sky(zenith: Color(0xFF020304), horizon: Color(0xFF0E1013), water: [Color(0xFF0C0E11), Color(0xFF010101)],
        cloud: Color(0xFF181B20), cloudShadow: Color(0xFF000000), clouds: 28, cloudLow: 0.44, rain: 1.2, haze: 0.3, hazeColor: Color(0xFF1A1D21)),
  ),
};

/// Landscape grade per family and light (null = the provider did not say day or night).
List<double> _grade(String family, bool? isDay) {
  double light(double d, double n) => isDay == true ? d : isDay == false ? n : (d + n) / 2;
  return switch (family) {
    'clear' => grade(saturation: light(1.05, 0.5), brightness: light(0.1, -0.12),
        gain: isDay == false ? const [0.5, 0.64, 1.0] : const [0.92, 1.02, 1.06]),
    'partly' => grade(saturation: light(0.95, 0.5), brightness: light(0.1, -0.12),
        gain: isDay == false ? const [0.5, 0.64, 1.0] : const [0.94, 1.0, 1.04]),
    'cloudy' => grade(saturation: 0.3, contrast: 0.85, brightness: light(0.02, -0.06), gain: const [0.98, 0.98, 1.0]),
    'rain' => grade(saturation: 0.25, contrast: 0.85, brightness: light(-0.04, -0.15), gain: const [0.86, 0.96, 1.0]),
    'snow' => grade(saturation: 0.15, contrast: 1.0, brightness: light(0.14, -0.02), gain: const [0.94, 1.0, 1.1]),
    'fog' => grade(saturation: 0.15, contrast: 0.5, brightness: light(0.16, -0.06), gain: const [1.03, 1.0, 0.95]),
    'storm' => grade(saturation: 0.2, brightness: light(-0.14, -0.3), gain: const [0.8, 0.85, 0.92]),
    _ => grade(),
  };
}

SceneArt _art(String family, bool? isDay) {
  final (day, night) = _skies[family]!;
  // Neutral (the provider did not say day or night): a muted light, close to the side SceneSpec.dark puts it
  // (overcast, rain, storm and fog read as dark; clear, partly and snow as light), without sun, moon or stars.
  final darkNeutral = const {'cloudy', 'rain', 'storm', 'fog'}.contains(family);
  final sky = switch (isDay) { true => day, false => night, null => day.toward(night, darkNeutral ? 0.92 : 0.12) };
  return SceneArt(matrix: silhouette(_grade(family, isDay ?? !darkNeutral)), sky: sky);
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
