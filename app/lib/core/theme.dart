import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Calm Momentum design tokens: pearl surfaces in light, graphite layers in dark, and one chosen accent.
/// Every screen reads colours from here; nothing is patched per screen.
enum Accent {
  blue('Blue'),
  green('Green'),
  pink('Pink');

  const Accent(this.label);
  final String label;
  static Accent parse(String? name) => values.asNameMap()[name] ?? blue;
}

@immutable
class GoColors extends ThemeExtension<GoColors> {
  const GoColors({required this.page, required this.surface, required this.sunken, required this.text, required this.secondary, required this.divider,
      required this.outline, required this.accent, required this.onAccent, required this.accentSoft, required this.passTop, required this.passBottom,
      required this.passFill, required this.success, required this.warning, required this.error});

  /// Page behind everything; raised cards; recessed fills (inputs, tracks, unselected segments).
  final Color page, surface, sunken;
  final Color text, secondary;

  /// Decorative separator, and the boundary of a control (at least 3:1 against page and surface).
  final Color divider, outline;

  /// The chosen accent: fills, selected icons and accent-coloured text. [accentSoft] is the selection tint.
  final Color accent, onAccent, accentSoft;

  /// The training pass: a deep shade of the accent, never the bright control colour. Text on it is [onPass].
  final Color passTop, passBottom, passFill;

  /// Status colours stay the same whatever the accent, and are always paired with an icon or words.
  final Color success, warning, error;

  static const onPass = Color(0xFFFFFFFF);

  factory GoColors.of(Accent accent, Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final (a, soft, top, bottom, fill) = switch ((accent, dark)) {
      (Accent.blue, false) => (0xFF0062CC, 0xFFE7F0FC, 0xFF0A63CB, 0xFF073F8C, 0xFFA8D2FF),
      (Accent.green, false) => (0xFF147644, 0xFFE2F2E9, 0xFF147A46, 0xFF0B4A2A, 0xFF9AE6BC),
      (Accent.pink, false) => (0xFFB32E70, 0xFFFBE9F1, 0xFFB52F72, 0xFF761A49, 0xFFFFB3D3),
      (Accent.blue, true) => (0xFF77B6FF, 0xFF172C47, 0xFF15457F, 0xFF0C2748, 0xFF8CC2FF),
      (Accent.green, true) => (0xFF6BD39C, 0xFF143527, 0xFF125536, 0xFF0A2E1E, 0xFF7EDDAA),
      (Accent.pink, true) => (0xFFF58CB9, 0xFF3F1E33, 0xFF7A2552, 0xFF43122C, 0xFFF9A3C7),
    };
    return GoColors(
      page: Color(dark ? 0xFF101114 : 0xFFF6F6F4),
      surface: Color(dark ? 0xFF1C1F24 : 0xFFFFFFFF),
      sunken: Color(dark ? 0xFF272B32 : 0xFFECECE8),
      text: Color(dark ? 0xFFF3F4F6 : 0xFF121417),
      // Increased contrast: muted text and separators move toward the primary text and control boundary.
      secondary: Color(highContrast ? (dark ? 0xFFD5D9DF : 0xFF33383F) : (dark ? 0xFFADB3BC : 0xFF555B63)),
      divider: Color(highContrast ? (dark ? 0xFF8A919B : 0xFF6E747D) : (dark ? 0xFF2E3239 : 0xFFE0E0DB)),
      outline: Color(highContrast ? (dark ? 0xFFB4BAC3 : 0xFF4A5059) : (dark ? 0xFF8A919B : 0xFF6E747D)),
      accent: Color(a), onAccent: Color(dark ? 0xFF101114 : 0xFFFFFFFF), accentSoft: Color(soft),
      passTop: Color(top), passBottom: Color(bottom), passFill: Color(fill),
      success: Color(dark ? 0xFF5FD4C4 : 0xFF0C6B63),
      warning: Color(dark ? 0xFFF2C36B : 0xFF7D5200),
      error: Color(dark ? 0xFFFFB4AB : 0xFFB3261E),
    );
  }

  @override
  GoColors copyWith() => this;

  @override
  GoColors lerp(GoColors? other, double t) {
    if (other == null) return this;
    Color f(Color a, Color b) => Color.lerp(a, b, t)!;
    return GoColors(
        page: f(page, other.page), surface: f(surface, other.surface), sunken: f(sunken, other.sunken), text: f(text, other.text),
        secondary: f(secondary, other.secondary), divider: f(divider, other.divider), outline: f(outline, other.outline), accent: f(accent, other.accent),
        onAccent: f(onAccent, other.onAccent), accentSoft: f(accentSoft, other.accentSoft), passTop: f(passTop, other.passTop),
        passBottom: f(passBottom, other.passBottom), passFill: f(passFill, other.passFill), success: f(success, other.success),
        warning: f(warning, other.warning), error: f(error, other.error));
  }
}

const sans = 'Inter';

/// Corner radii, smallest to largest: controls, tiles, cards, the hero and the pass.
abstract final class Radii {
  static const field = 12.0, tile = 14.0, panel = 20.0, hero = 26.0;
}

abstract final class Targets {
  static const minimum = 48.0, primary = 52.0, navigation = 58.0, logging = 88.0;
}

/// Small state changes, and larger presentations.
abstract final class Motion {
  static const quick = Duration(milliseconds: 200), large = Duration(milliseconds: 300);
}

extension GoContext on BuildContext {
  GoColors get c => Theme.of(this).extension<GoColors>()!;

  /// 20 px content inset, 16 px on phones narrower than 350 logical pixels.
  double get inset => MediaQuery.sizeOf(this).width < 350 ? 16 : 20;

  /// Display type shrinks a little on narrow phones so controls keep their readable size.
  double display(double size) => MediaQuery.sizeOf(this).width < 350 ? size * 0.85 : size;

  /// Reduce Motion: state still changes, it just does not travel.
  Duration motion(Duration d) => MediaQuery.disableAnimationsOf(this) ? Duration.zero : d;

  TextStyle sansStyle(double size, {Color? color, FontWeight weight = FontWeight.w400, double? spacing}) =>
      TextStyle(fontFamily: sans, fontFamilyFallback: const ['Arial', 'sans-serif'], fontSize: size, height: 1.35, fontWeight: weight, color: color ?? c.text, letterSpacing: spacing);

  /// Headings and large numbers: bold, tight, with figures that do not jiggle as values change.
  TextStyle titleStyle(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      sansStyle(display(size), color: color, weight: weight, spacing: size >= 24 ? -0.6 : -0.2).copyWith(height: 1.15, fontFeatures: const [FontFeature.tabularFigures()]);
  TextStyle get body => sansStyle(16);
  TextStyle get caption => sansStyle(13.5, color: c.secondary);
  TextStyle get label => sansStyle(13.5, color: c.secondary, weight: FontWeight.w600);
}

ThemeData goTheme(Accent accent, Brightness brightness, {bool highContrast = false}) {
  final c = GoColors.of(accent, brightness, highContrast: highContrast);
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
      brightness: brightness, primary: c.accent, onPrimary: c.onAccent, primaryContainer: c.accentSoft, onPrimaryContainer: c.text,
      secondary: c.accent, onSecondary: c.onAccent, secondaryContainer: c.accentSoft, onSecondaryContainer: c.text,
      error: c.error, onError: c.page, surface: c.page, onSurface: c.text, onSurfaceVariant: c.secondary,
      surfaceContainerLowest: c.page, surfaceContainerLow: c.surface, surfaceContainer: c.surface, surfaceContainerHigh: c.surface, surfaceContainerHighest: c.sunken,
      outline: c.outline, outlineVariant: c.divider, surfaceTint: Colors.transparent, scrim: Colors.black);
  final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: sans, scaffoldBackgroundColor: c.page);
  // System bars follow the page, so there is no bright strip above or below a dark screen.
  final bars = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarBrightness: brightness, statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: c.page, systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark, systemNavigationBarDividerColor: Colors.transparent);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide(color: color, width: width));
  const pill = StadiumBorder();
  return base.copyWith(
    extensions: [c],
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: sans),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(backgroundColor: c.page, foregroundColor: c.text, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, systemOverlayStyle: bars,
        titleTextStyle: TextStyle(fontFamily: sans, fontSize: 17, fontWeight: FontWeight.w600, color: c.text)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      labelStyle: TextStyle(color: c.secondary, fontSize: 16), floatingLabelStyle: TextStyle(color: c.text), hintStyle: TextStyle(color: c.secondary),
      helperStyle: TextStyle(color: c.secondary, fontSize: 13), errorStyle: TextStyle(color: c.error, fontSize: 13.5), errorMaxLines: 3, helperMaxLines: 3,
      suffixStyle: TextStyle(color: c.secondary, fontSize: 15), prefixIconColor: c.secondary,
      border: border(c.outline), enabledBorder: border(c.outline), focusedBorder: border(c.accent, 2), errorBorder: border(c.error), focusedErrorBorder: border(c.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: c.accent, foregroundColor: c.onAccent, disabledBackgroundColor: c.sunken, disabledForegroundColor: c.secondary,
            minimumSize: const Size(64, Targets.primary), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: pill,
            textStyle: const TextStyle(fontFamily: sans, fontSize: 16.5, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: c.text, side: BorderSide(color: c.outline), minimumSize: const Size(64, Targets.primary),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: pill,
            textStyle: const TextStyle(fontFamily: sans, fontSize: 16.5, fontWeight: FontWeight.w600))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: c.accent, minimumSize: const Size(Targets.minimum, Targets.minimum), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontFamily: sans, fontSize: 15.5, fontWeight: FontWeight.w600))),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(Targets.minimum, Targets.minimum))),
    dialogTheme: DialogThemeData(
        backgroundColor: c.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel)),
        titleTextStyle: TextStyle(fontFamily: sans, fontSize: 20, fontWeight: FontWeight.w700, color: c.text, letterSpacing: -0.2),
        contentTextStyle: TextStyle(fontFamily: sans, fontSize: 15.5, height: 1.4, color: c.text)),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface, surfaceTintColor: Colors.transparent, showDragHandle: true, dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.hero)))),
    popupMenuTheme: PopupMenuThemeData(color: c.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile)),
        textStyle: TextStyle(fontFamily: sans, fontSize: 16, color: c.text)),
    // The message bar is a neutral inverse surface, so it reads the same under every accent.
    snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFFE8EAED) : const Color(0xFF23262B),
        contentTextStyle: TextStyle(fontFamily: sans, fontSize: 15, color: dark ? const Color(0xFF121417) : const Color(0xFFF3F4F6)),
        actionTextColor: dark ? const Color(0xFF0A4FA3) : const Color(0xFF9CCBFF), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile))),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.outline)),
    checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onAccent), side: BorderSide(color: c.outline, width: 1.5)),
    switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.outline),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.sunken),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.outline)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.sunken, circularTrackColor: Colors.transparent),
    datePickerTheme: DatePickerThemeData(backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    timePickerTheme: TimePickerThemeData(backgroundColor: c.surface),
    listTileTheme: ListTileThemeData(iconColor: c.secondary, textColor: c.text),
    splashFactory: InkSparkle.splashFactory,
  );
}
