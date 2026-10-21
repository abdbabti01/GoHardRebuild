import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import 'coach_prefs.dart';

/// The selected guide's look. An appearance preference only: both have the same capabilities.
enum CoachGuide {
  leon('Leon', 'lion'),
  leona('Leona', 'lioness');

  const CoachGuide(this.label, this.animal);

  /// The English wording; shown text comes from [displayName] and [animalName].
  final String label, animal;

  /// The name shown in [l]'s language (Leon / Leona; ليون / ليونا in Arabic). [name] stays the stored ID.
  String displayName(AppLocalizations l) => switch (this) { leon => l.coachNameLeon, leona => l.coachNameLeona };
  String animalName(AppLocalizations l) => switch (this) { leon => l.coachAnimalLion, leona => l.coachAnimalLioness };
}

/// Runtime art (scripts/build-coach-art.ps1): avatars 192 px square, full body 202 × 420. Static pictures: nothing
/// here talks, blinks, walks or "thinks", and the fur is never tinted with the accent.
const _avatarPx = 192, _figurePx = 420;

/// Decoded at the size it is drawn (never larger than the file), so a 40 px avatar never decodes a big image.
int _decode(BuildContext context, double logical, int max) => math.min(max, (logical * MediaQuery.devicePixelRatioOf(context)).ceil());

/// The selected guide's compact head-and-shoulders avatar, [size] logical px. Decorative: it is never announced.
/// A round recessed backdrop keeps the charcoal shirt clear on dark surfaces; the circle keeps the whole head.
class CoachAvatar extends ConsumerWidget {
  const CoachAvatar({super.key, this.size = 40, this.guide});
  final double size;

  /// Shown instead of the selected guide (the Appearance previews).
  final CoachGuide? guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoachGuide g = guide ?? ref.watch(coachPrefsProvider.select<CoachGuide>((p) => p.guide));
    final px = _decode(context, size, _avatarPx);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.c.sunken, shape: BoxShape.circle),
          child: ClipOval(
            child: Image.asset('assets/coach/${g.name}-avatar.png', key: Key('coach-avatar-${g.name}'), width: size, height: size, cacheWidth: px, cacheHeight: px,
                fit: BoxFit.cover, gaplessPlayback: true, excludeFromSemantics: true),
          ),
        ),
      ),
    );
  }
}

/// The selected guide's full-body illustration, [height] logical px high. Decorative. For help and empty states
/// where there is room; never on workout, run or review screens.
class CoachFigure extends ConsumerWidget {
  const CoachFigure({super.key, this.height = 120, this.guide});
  final double height;
  final CoachGuide? guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoachGuide g = guide ?? ref.watch(coachPrefsProvider.select<CoachGuide>((p) => p.guide));
    return ExcludeSemantics(
      child: Image.asset('assets/coach/${g.name}-full.png', key: Key('coach-figure-${g.name}'), height: height, cacheHeight: _decode(context, height, _figurePx),
          fit: BoxFit.contain, gaplessPlayback: true, excludeFromSemantics: true),
    );
  }
}

/// The avatar in a 48 px button, labelled by purpose ("Help with choosing a split"): the coach's help entry
/// (CoachHelpEntry, coach_bubble.dart). Never placed on a screen for recording sets or running except to open help in
/// a sheet, and never on conflict or destructive-change review.
class CoachHelpButton extends StatelessWidget {
  const CoachHelpButton({super.key, required this.semanticLabel, required this.onPressed, this.size = 44});
  final String semanticLabel;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final side = math.max(Targets.minimum, size);
    return IconButton(
      tooltip: semanticLabel,
      onPressed: onPressed,
      constraints: BoxConstraints.tight(Size.square(side)),
      padding: EdgeInsets.zero,
      icon: CoachAvatar(size: side - 8),
    );
  }
}
