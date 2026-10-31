import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Daily Rhythm design tokens: restrained warm surfaces in light, layered charcoal-plum in dark, warm foregrounds and
/// one chosen accent for interactive selection. Every screen reads colours from here; nothing is patched per screen.
enum Accent {
  blue,
  green,
  pink;

  static Accent parse(String? name) => values.asNameMap()[name] ?? blue;
}

@immutable
class GoColors extends ThemeExtension<GoColors> {
  const GoColors({required this.page, required this.surface, required this.sunken, required this.text, required this.secondary, required this.divider,
      required this.outline, required this.accent, required this.onAccent, required this.accentSoft, required this.success, required this.warning, required this.error,
      required this.raised, required this.scrim, required this.accentDeep, required this.onAccentDeep, required this.tint, required this.hue, this.highContrast = false});

  /// The filled button: a deep shade of the accent with a light label, the same in Light and Dark (the approved Today
  /// panels' button, used app-wide).
  final Color accentDeep, onAccentDeep;

  /// The pale accent tint of the photo panels, also the fill of a chosen segment or chip (with [GoColors.panelOf]'s
  /// ink on it).
  final Color tint;

  /// Which accent and contrast these colours were made for, so a panel palette can be derived from them anywhere.
  final Accent hue;
  final bool highContrast;

  /// Per accent: the pale panel tint, the panel's badge/track tint, the deep button colour and the panel's ink.
  static (int tint, int soft, int deep, int ink) _panel(Accent a) => switch (a) {
        Accent.green => (0xFFD4ECDD, 0xFFBADFC8, 0xFF143B2C, 0xFF0E1C17),
        Accent.blue => (0xFFD8E4F1, 0xFFBDD0E6, 0xFF173554, 0xFF0E1724),
        Accent.pink => (0xFFF2DCE6, 0xFFE6C3D3, 0xFF4F1E37, 0xFF20111A),
      };

  /// The photo panels' palette: the pale tint with dark ink and the deep button, the same in Light and Dark. Status
  /// colours are Light's, which hold on the pale tint. Used under [PanelTheme] (widgets.dart).
  static GoColors panelOf(GoColors from) {
    final light = GoColors.of(from.hue, Brightness.light, highContrast: from.highContrast);
    final (tint, soft, deep, ink) = _panel(from.hue);
    final t = Color(tint), text = Color(ink), white = const Color(0xFFFFFFFF);
    Color towardTint(double share) => Color.lerp(text, t, share)!;
    final hc = from.highContrast;
    return GoColors(
        page: t, surface: Color.lerp(t, white, 0.5)!, raised: Color.lerp(t, white, 0.5)!, sunken: Color(soft),
        text: text, secondary: towardTint(hc ? 0.12 : 0.3), divider: towardTint(hc ? 0.5 : 0.8), outline: towardTint(hc ? 0.3 : 0.5),
        accent: Color(deep), onAccent: Color.lerp(white, t, 0.25)!, accentSoft: Color(soft), accentDeep: Color(deep), onAccentDeep: Color.lerp(white, t, 0.25)!, tint: t,
        success: light.success, warning: light.warning, error: light.error, scrim: t.withValues(alpha: scrimOpacity), hue: from.hue, highContrast: hc);
  }

  /// Page behind everything; raised cards; recessed fills (tracks, unselected segments, neutral icon tiles).
  /// Page and surface differ by a small step, so a card reads as raised before its thin border is noticed.
  final Color page, surface, sunken;
  final Color text, secondary;

  /// Decorative separator, and the boundary of a control (at least 3:1 against page and surface).
  final Color divider, outline;

  /// The chosen accent: fills, selected icons and accent-coloured text. [accentSoft] is the selection tint.
  final Color accent, onAccent, accentSoft;

  /// Status colours stay the same whatever the accent, and are always paired with an icon or words.
  /// [error] is also the fill of a destructive action; its label is drawn in [page].
  final Color success, warning, error;

  /// A surface that floats above the page and its cards: the bottom navigation bar.
  final Color raised;

  /// Laid over a scene (a header backdrop) behind text: the page colour, translucent. Text and secondary text in
  /// [text] keep 4.5:1 on it over any pixel at all, black to white, so nothing has to be measured per image.
  final Color scrim;

  factory GoColors.of(Accent accent, Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final (a, soft) = switch ((accent, dark)) {
      (Accent.blue, false) => (0xFF0062CC, 0xFFE6EEF9),
      (Accent.green, false) => (0xFF147644, 0xFFE2F0E7),
      (Accent.pink, false) => (0xFFB0306E, 0xFFF9E7EF),
      (Accent.blue, true) => (0xFF7DB8FF, 0xFF1C2A40),
      (Accent.green, true) => (0xFF72D6A2, 0xFF17302A),
      (Accent.pink, true) => (0xFFF58CB9, 0xFF3D2033),
    };
    final page = Color(dark ? 0xFF16141A : 0xFFF5F2EE);
    final (tint, _, deep, _) = _panel(accent);
    return GoColors(
      accentDeep: Color(deep), onAccentDeep: Color.lerp(const Color(0xFFFFFFFF), Color(tint), 0.25)!, tint: Color(tint), hue: accent, highContrast: highContrast,
      page: page,
      surface: Color(dark ? 0xFF1F1C24 : 0xFFFCFBF9),
      sunken: Color(dark ? 0xFF2C2832 : 0xFFEAE5DF),
      raised: Color(dark ? 0xFF262329 : 0xFFFFFEFC),
      text: Color(dark ? 0xFFF6F1EC : 0xFF1C1A1F),
      // Increased contrast: muted text and separators move toward the primary text and control boundary.
      secondary: Color(highContrast ? (dark ? 0xFFDDD6DC : 0xFF38333B) : (dark ? 0xFFB9B0B9 : 0xFF5B5560)),
      divider: Color(highContrast ? (dark ? 0xFF8F8692 : 0xFF746D76) : (dark ? 0xFF37323D : 0xFFE0DAD3)),
      outline: Color(highContrast ? (dark ? 0xFFBDB4BE : 0xFF4E4851) : (dark ? 0xFF8F8692 : 0xFF7A737C)),
      accent: Color(a), onAccent: dark ? page : const Color(0xFFFFFFFF), accentSoft: Color(soft),
      success: Color(dark ? 0xFF5FD4C4 : 0xFF0C6B63),
      warning: Color(dark ? 0xFFF2C36B : 0xFF7D5200),
      error: Color(dark ? 0xFFFFB4AB : 0xFFB3261E),
      scrim: page.withValues(alpha: scrimOpacity),
    );
  }

  /// Progress against a goal the person chose (calorie and protein bars): green, yellow, red. Never food quality, health
  /// or merit, and always paired with words. The fills hold 3:1 against the recessed track and the texts 4.5:1 against
  /// the page, on the pale photo panels (every accent, Light and Dark: [panelOf] has a pale page) and on Dark's own page.
  /// A true yellow cannot hold 3:1 on a pale panel, so the light "yellow" is a deep gold.
  bool get _darkPage => page.computeLuminance() < 0.2;
  Color get goalGreen => Color(_darkPage ? 0xFF6FCF97 : 0xFF1E7B4A);
  Color get goalYellow => Color(_darkPage ? 0xFFE8B341 : 0xFF9A6700);
  Color get goalRed => Color(_darkPage ? 0xFFFF8A80 : 0xFFB3261E);
  Color get goalGreenText => Color(_darkPage ? 0xFF6FCF97 : 0xFF17663D);
  Color get goalYellowText => Color(_darkPage ? 0xFFE8B341 : 0xFF7D5200);
  Color get goalRedText => Color(_darkPage ? 0xFFFF8A80 : 0xFFB3261E);

  /// How much of the page a [scrim] lets through; 0.66 holds 4.5:1 for [text] over a black or a white pixel.
  static const scrimOpacity = 0.66;

  /// The top of the calm background behind Train and Eat, fading into [page]: halfway between page and recessed fill,
  /// so everything that reads on both reads on it.
  Color get wash => Color.lerp(page, sunken, 0.5)!;

  @override
  GoColors copyWith() => this;

  @override
  GoColors lerp(GoColors? other, double t) {
    if (other == null) return this;
    Color f(Color a, Color b) => Color.lerp(a, b, t)!;
    return GoColors(
        page: f(page, other.page), surface: f(surface, other.surface), sunken: f(sunken, other.sunken), text: f(text, other.text),
        secondary: f(secondary, other.secondary), divider: f(divider, other.divider), outline: f(outline, other.outline), accent: f(accent, other.accent),
        onAccent: f(onAccent, other.onAccent), accentSoft: f(accentSoft, other.accentSoft), success: f(success, other.success),
        warning: f(warning, other.warning), error: f(error, other.error), raised: f(raised, other.raised), scrim: f(scrim, other.scrim),
        accentDeep: f(accentDeep, other.accentDeep), onAccentDeep: f(onAccentDeep, other.onAccentDeep), tint: f(tint, other.tint), hue: t < 0.5 ? hue : other.hue,
        highContrast: t < 0.5 ? highContrast : other.highContrast);
  }
}

const sans = 'Inter';

/// After Inter: Arabic letters (Inter has none) in IBM Plex Sans Arabic, bundled, so Arabic never depends on the
/// phone's own fallback. Latin text in every language stays in Inter.
const sansFallback = ['IBM Plex Sans Arabic', 'Arial', 'sans-serif'];

/// Arabic page titles: Noto Naskh Arabic, the calm Naskh counterpart of the serif (docs/LOCALIZATION.md).
const serifFallback = ['Noto Naskh Arabic', 'Georgia', 'serif'];

/// The one serif, for page titles only (the four tabs, Add food, Appearance and other page titles), always through
/// [GoContext.pageTitleStyle]. Controls, body, labels and figures stay in [sans].
const serif = 'DM Serif Display';

/// Corner radii, smallest to largest: fields and choices, buttons and tiles, cards and dialogs, the top of a sheet.
abstract final class Radii {
  static const field = 12.0, tile = 14.0, panel = 18.0, sheet = 22.0;
}

abstract final class Targets {
  static const minimum = 48.0, primary = 52.0, navigation = 58.0, logging = 88.0;
}

/// The one place for timing. Always pass a duration through `context.motion(...)`, which makes it zero under
/// Reduce Motion (the phone's setting, or Me > Motion & haptics > Reduced). Nothing loops, bounces or pulses.
abstract final class Motion {
  /// Press feedback: a control settles to [pressScale] and back.
  static const press = Duration(milliseconds: 100);

  /// Selection, tab and content changes, and a sheet or a look leaving.
  static const quick = Duration(milliseconds: 200);

  /// A sheet arriving.
  static const sheet = Duration(milliseconds: 280);

  /// A progress rail moving to a new real value. It never plays for a rebuild or a tab coming back.
  static const progress = Duration(milliseconds: 360);

  static const pressScale = 0.98;

  /// Ease-out for anything arriving or changing; [exit] for anything leaving.
  static const Curve curve = Curves.easeOutCubic, exit = Curves.easeInCubic;
}

extension GoContext on BuildContext {
  GoColors get c => Theme.of(this).extension<GoColors>()!;

  /// 20 px content inset, 16 px on phones narrower than 350 logical pixels.
  double get inset => MediaQuery.sizeOf(this).width < 350 ? 16 : 20;

  /// Display type shrinks a little on narrow phones so controls keep their readable size.
  double display(double size) => MediaQuery.sizeOf(this).width < 350 ? size * 0.85 : size;

  /// True under the phone's Reduce Motion, or when Motion is set to Reduced in the app.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Reduce Motion: state still changes, it just does not travel.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;

  /// Arabic is joined script: it gets more line height for its marks and never any letter spacing.
  bool get _arabic => Localizations.maybeLocaleOf(this)?.languageCode == 'ar';

  TextStyle sansStyle(double size, {Color? color, FontWeight weight = FontWeight.w400, double? spacing}) => TextStyle(
      fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: size, height: _arabic ? 1.55 : 1.35, fontWeight: weight, color: color ?? c.text,
      letterSpacing: _arabic ? null : spacing);

  /// Headings and large numbers: bold, tight, with figures that do not jiggle as values change.
  TextStyle titleStyle(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      sansStyle(display(size), color: color, weight: weight, spacing: size >= 24 ? -0.6 : -0.2).copyWith(height: _arabic ? 1.4 : 1.15, fontFeatures: const [FontFeature.tabularFigures()]);

  /// A changing value at reading size ("82.4 kg", "1,480 kcal"): digits keep one width, so nothing shifts as it
  /// updates. For large figures use [titleStyle], which is tabular too.
  TextStyle numStyle(double size, {Color? color, FontWeight weight = FontWeight.w600}) =>
      sansStyle(size, color: color, weight: weight).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  /// A page title in the serif ("Today", "Me", "Appearance"): 30 to 44 px, display-scaled on narrow phones. Figures
  /// never use it; a number stays in [titleStyle] or [numStyle].
  TextStyle pageTitleStyle(double size, {Color? color}) => TextStyle(
      fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: display(_arabic ? size * 0.86 : size), height: _arabic ? 1.45 : 1.1, fontWeight: FontWeight.w400,
      color: color ?? c.text, letterSpacing: _arabic ? null : (size >= 34 ? -0.4 : -0.2));

  TextStyle get body => sansStyle(16);
  TextStyle get caption => sansStyle(13.5, color: c.secondary);
  TextStyle get label => sansStyle(13.5, color: c.secondary, weight: FontWeight.w600);
}

ThemeData goTheme(Accent accent, Brightness brightness, {bool highContrast = false}) =>
    goThemeOf(GoColors.of(accent, brightness, highContrast: highContrast), brightness);

/// The same theme from a given palette: Today's photographic panels use it with their own pale tint (today_screen.dart).
ThemeData goThemeOf(GoColors c, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
      brightness: brightness, primary: c.accent, onPrimary: c.onAccent, primaryContainer: c.accentSoft, onPrimaryContainer: c.text,
      secondary: c.accent, onSecondary: c.onAccent, secondaryContainer: c.accentSoft, onSecondaryContainer: c.text,
      error: c.error, onError: c.page, surface: c.page, onSurface: c.text, onSurfaceVariant: c.secondary,
      surfaceContainerLowest: c.page, surfaceContainerLow: c.surface, surfaceContainer: c.surface, surfaceContainerHigh: c.surface, surfaceContainerHighest: c.sunken,
      outline: c.outline, outlineVariant: c.divider, surfaceTint: Colors.transparent, scrim: Colors.black);
  final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: sans, fontFamilyFallback: sansFallback, scaffoldBackgroundColor: c.page);
  // System bars follow the page, so there is no bright strip above or below a dark screen.
  final bars = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarBrightness: brightness, statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: c.page, systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark, systemNavigationBarDividerColor: Colors.transparent);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide(color: color, width: width));
  // Buttons are rounded rectangles like the cards they sit in; the pill is kept for status labels only.
  final button = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile));
  return base.copyWith(
    extensions: [c],
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: sans, fontFamilyFallback: sansFallback),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(backgroundColor: c.page, foregroundColor: c.text, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, systemOverlayStyle: bars,
        titleTextStyle: TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 17, fontWeight: FontWeight.w600, color: c.text)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      labelStyle: TextStyle(color: c.secondary, fontSize: 16), floatingLabelStyle: TextStyle(color: c.text), hintStyle: TextStyle(color: c.secondary),
      helperStyle: TextStyle(color: c.secondary, fontSize: 13), errorStyle: TextStyle(color: c.error, fontSize: 13.5), errorMaxLines: 3, helperMaxLines: 3,
      suffixStyle: TextStyle(color: c.secondary, fontSize: 15), prefixIconColor: c.secondary,
      border: border(c.outline), enabledBorder: border(c.outline), focusedBorder: border(c.accent, 2), errorBorder: border(c.error), focusedErrorBorder: border(c.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
        // Deep accent with a light label in both modes; on a dark page a thin accent edge keeps its shape visible.
        style: FilledButton.styleFrom(
            backgroundColor: c.accentDeep, foregroundColor: c.onAccentDeep, disabledBackgroundColor: c.sunken, disabledForegroundColor: c.secondary,
            minimumSize: const Size(64, Targets.primary), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: dark ? button.copyWith(side: BorderSide(color: c.accent.withValues(alpha: 0.55))) : button,
            textStyle: const TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 16.5, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: c.text, backgroundColor: c.surface, side: BorderSide(color: c.outline), minimumSize: const Size(64, Targets.primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: button,
            textStyle: const TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 16.5, fontWeight: FontWeight.w600))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: c.accent, minimumSize: const Size(Targets.minimum, Targets.minimum), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 15.5, fontWeight: FontWeight.w600))),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(Targets.minimum, Targets.minimum))),
    dialogTheme: DialogThemeData(
        backgroundColor: c.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel)),
        titleTextStyle: TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 20, fontWeight: FontWeight.w700, color: c.text, letterSpacing: -0.2),
        contentTextStyle: TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 15.5, height: 1.4, color: c.text)),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface, surfaceTintColor: Colors.transparent, showDragHandle: true, dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)))),
    popupMenuTheme: PopupMenuThemeData(color: c.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile)),
        textStyle: TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 16, color: c.text)),
    // The message bar is a neutral inverse surface, so it reads the same under every accent.
    snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFFE8EAED) : const Color(0xFF23262B),
        contentTextStyle: TextStyle(fontFamily: sans, fontFamilyFallback: sansFallback, fontSize: 15, color: dark ? const Color(0xFF121417) : const Color(0xFFF3F4F6)),
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
    // Press feedback is a quiet tint (and a small scale on Pressable and the buttons), not a ripple.
    splashFactory: NoSplash.splashFactory, splashColor: Colors.transparent,
    highlightColor: c.text.withValues(alpha: 0.06), hoverColor: c.text.withValues(alpha: 0.04), focusColor: c.accent.withValues(alpha: 0.14),
  );
}
