import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// The supplied vector glyphs for the Steps and Run / Walk controls (assets/icons, 24 × 24, stroke 2, round caps;
/// GoHard_Steps_RunWalk_UX_Corrections/icons/README.md). One family for these controls only; the rest of the app keeps
/// its Material icons.
enum GoGlyph {
  autoPause('auto-pause'),
  back('back'),
  chevronRight('chevron-right'),
  expandMap('expand-map'),
  history('history'),
  intervals('intervals'),
  minus('minus'),
  play('play'),
  plus('plus'),
  recenter('recenter'),
  steps('steps'),
  voice('voice');

  const GoGlyph(this.file);
  final String file;
}

/// A [GoGlyph] tinted from the theme (the SVG's `currentColor`): the surrounding [IconTheme]'s colour, or [color].
/// Decorative unless [semanticLabel] is given; the control around it carries the name and the touch target.
class GoIcon extends StatelessWidget {
  const GoIcon(this.glyph, {super.key, this.size, this.color, this.semanticLabel});
  final GoGlyph glyph;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    return SvgPicture.asset(
      'assets/icons/${glyph.file}.svg',
      width: s, height: s,
      theme: SvgTheme(currentColor: color ?? theme.color ?? context.c.text),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
