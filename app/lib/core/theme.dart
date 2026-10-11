import 'package:flutter/material.dart';

/// Evening Club design tokens (GoHard_Phase_3_Design_Tokens.json). Dark is the default appearance.
@immutable
class EveningColors extends ThemeExtension<EveningColors> {
  const EveningColors({required this.canvas, required this.text, required this.secondary, required this.input, required this.divider,
      required this.action, required this.actionText, required this.selected, required this.chart, required this.error, required this.warning,
      required this.nutritionSurface, required this.nutritionText, required this.nutritionSecondary});

  final Color canvas, text, secondary, input, divider, action, actionText, selected, chart, error, warning;

  /// The nutrition surface stays pale in both appearances.
  final Color nutritionSurface, nutritionText, nutritionSecondary;

  static const light = EveningColors(
      canvas: Color(0xFFF6F2EA), text: Color(0xFF1D1C19), secondary: Color(0xFF625E55), input: Color(0xFFECE7DC), divider: Color(0xFFD0C8B9),
      action: Color(0xFF22221D), actionText: Color(0xFFF5EDDD), selected: Color(0xFFE4DCCB), chart: Color(0xFF6F684E), error: Color(0xFFA32E39),
      warning: Color(0xFF755817), nutritionSurface: Color(0xFFEBE5DA), nutritionText: Color(0xFF20201C), nutritionSecondary: Color(0xFF5E5D55));

  static const dark = EveningColors(
      canvas: Color(0xFF191918), text: Color(0xFFF5EDDC), secondary: Color(0xFFBDBBB4), input: Color(0xFF252521), divider: Color(0xFF41413B),
      action: Color(0xFFF1E7D3), actionText: Color(0xFF1C1C18), selected: Color(0xFF343229), chart: Color(0xFFCFC4A6), error: Color(0xFFFFB6B6),
      warning: Color(0xFFE1C482), nutritionSurface: Color(0xFFE5DFD3), nutritionText: Color(0xFF20201C), nutritionSecondary: Color(0xFF5E5D55));

  @override
  EveningColors copyWith() => this;
  @override
  EveningColors lerp(EveningColors? other, double t) => t < 0.5 ? this : other ?? this;
}

const serif = 'Source Serif 4';
const sans = 'Inter';

abstract final class Radii {
  static const field = 13.0, action = 26.0, panel = 17.0, nutrition = 18.0, week = 12.0;
}

abstract final class Targets {
  static const minimum = 44.0, primary = 48.0, navigation = 58.0, logging = 88.0;
}

extension EveningContext on BuildContext {
  EveningColors get ec => Theme.of(this).extension<EveningColors>()!;

  /// 22 px content inset, 16 px on phones narrower than 350 logical pixels.
  double get inset => MediaQuery.sizeOf(this).width < 350 ? 16 : 22;

  /// Display type shrinks a little on narrow phones so controls keep their readable size.
  double display(double size) => MediaQuery.sizeOf(this).width < 350 ? size * 0.82 : size;

  TextStyle serifStyle(double size, {Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: serif, fontFamilyFallback: const ['Georgia', 'serif'], fontSize: display(size), height: 1.12, fontWeight: weight, color: color ?? ec.text, letterSpacing: -0.2);
  TextStyle sansStyle(double size, {Color? color, FontWeight weight = FontWeight.w400, double? spacing}) =>
      TextStyle(fontFamily: sans, fontFamilyFallback: const ['Arial', 'sans-serif'], fontSize: size, height: 1.35, fontWeight: weight, color: color ?? ec.text, letterSpacing: spacing);
  TextStyle get body => sansStyle(15);
  TextStyle get caption => sansStyle(13, color: ec.secondary);
  TextStyle get label => sansStyle(11, color: ec.secondary, weight: FontWeight.w500, spacing: 1.6);
}

ThemeData eveningTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? EveningColors.dark : EveningColors.light;
  final scheme = ColorScheme(
      brightness: brightness, primary: c.action, onPrimary: c.actionText, secondary: c.chart, onSecondary: c.canvas, error: c.error, onError: c.canvas,
      surface: c.canvas, onSurface: c.text, surfaceContainerHighest: c.input, outline: c.secondary, outlineVariant: c.divider);
  final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: sans, scaffoldBackgroundColor: c.canvas);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide(color: color, width: width));
  return base.copyWith(
    extensions: [c],
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: sans),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(backgroundColor: c.canvas, foregroundColor: c.text, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: serif, fontSize: 22, color: c.text)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.input, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: c.secondary, fontSize: 15), floatingLabelStyle: TextStyle(color: c.text), hintStyle: TextStyle(color: c.secondary),
      helperStyle: TextStyle(color: c.secondary, fontSize: 12), errorStyle: TextStyle(color: c.error, fontSize: 13), errorMaxLines: 3, helperMaxLines: 3,
      border: border(c.secondary), enabledBorder: border(c.secondary), focusedBorder: border(c.text, 2), errorBorder: border(c.error), focusedErrorBorder: border(c.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: c.action, foregroundColor: c.actionText, disabledBackgroundColor: c.input, disabledForegroundColor: c.secondary,
            minimumSize: const Size(64, Targets.primary), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.action)),
            textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: c.text, side: BorderSide(color: c.secondary), minimumSize: const Size(64, Targets.primary),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.action)),
            textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w500))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: c.text, minimumSize: const Size(Targets.minimum, Targets.minimum), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontFamily: sans, fontSize: 15, fontWeight: FontWeight.w500))),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(Targets.minimum, Targets.minimum))),
    dialogTheme: DialogThemeData(
        backgroundColor: c.canvas, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel)),
        titleTextStyle: TextStyle(fontFamily: serif, fontSize: 24, color: c.text), contentTextStyle: TextStyle(fontFamily: sans, fontSize: 15, height: 1.4, color: c.text)),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.canvas, surfaceTintColor: Colors.transparent, showDragHandle: true, dragHandleColor: c.divider),
    snackBarTheme: SnackBarThemeData(backgroundColor: c.action, contentTextStyle: TextStyle(fontFamily: sans, fontSize: 14, color: c.actionText), actionTextColor: c.actionText, behavior: SnackBarBehavior.floating),
    radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(c.text)),
    checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.action : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.actionText), side: BorderSide(color: c.secondary, width: 1.5)),
    switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.actionText : c.secondary),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.action : c.input),
        trackOutlineColor: WidgetStatePropertyAll(c.secondary)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.text, linearTrackColor: c.input),
    datePickerTheme: DatePickerThemeData(backgroundColor: c.canvas, surfaceTintColor: Colors.transparent),
    splashFactory: InkSparkle.splashFactory,
  );
}
