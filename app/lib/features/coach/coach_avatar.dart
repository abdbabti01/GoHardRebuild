import 'package:flutter/material.dart';

/// Contract stub: replaced by the avatar work (Leon and Leona artwork, preference, hints). Signatures are fixed.

/// The selected guide's look. An appearance preference only: both have the same capabilities.
enum CoachGuide { leon, leona }

/// The selected guide's compact head-and-shoulders avatar, [size] logical px. Decorative: it is never announced.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({super.key, this.size = 40, this.guide});
  final double size;

  /// Shown instead of the selected guide (the Appearance previews).
  final CoachGuide? guide;
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size);
}

/// The selected guide's full-body illustration, [height] logical px high. Decorative.
class CoachFigure extends StatelessWidget {
  const CoachFigure({super.key, this.height = 120});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// The avatar in a 48 px button, labelled by purpose ("Ask GoHard about this split"). With a [hintId] and
/// [hintText] it may show, once per flow and only while coaching hints are on, a short dismissible bubble anchored
/// to it with an Ask GoHard action and a close button. The bubble never opens chat, moves focus or sends anything.
class CoachHelpButton extends StatelessWidget {
  const CoachHelpButton({super.key, required this.semanticLabel, required this.onPressed, this.hintId, this.hintText, this.size = 44});
  final String semanticLabel;
  final VoidCallback onPressed;
  final String? hintId, hintText;
  final double size;
  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: semanticLabel, onPressed: onPressed, icon: CoachAvatar(size: size - 8));
}
