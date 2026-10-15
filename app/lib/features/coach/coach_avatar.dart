import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'coach_prefs.dart';

/// The selected guide's look. An appearance preference only: both have the same capabilities.
enum CoachGuide {
  leon('Leon', 'lion'),
  leona('Leona', 'lioness');

  const CoachGuide(this.label, this.animal);
  final String label, animal;
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

/// The avatar in a 48 px button, labelled by purpose ("Ask GoHard about this split"). It goes only where help is the
/// point (the plan builder, its splits, workouts and exercises, help pages); never on a screen for recording sets,
/// running, reviewing conflicts or reviewing a destructive change.
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

/// A one-time coaching hint, laid out in the page where it is placed (under the help button's row), so it moves
/// content down rather than covering a field, an action, the keyboard or the navigation. It has an Ask GoHard action
/// and a close button, and it never opens chat, moves focus or sends anything.
///
/// It appears only while coaching hints are on and [hintId] has not been seen, its route is the current one, the app
/// is in the foreground and no keyboard is up. Appearing marks it seen, so it returns only after Me › Appearance ›
/// Show coaching hints again; turning hints off hides it at once. [text] is interface copy we wrote, never presented
/// as an answer from the model. Like [CoachHelpButton], it is never placed on workout, run or review screens.
class CoachHint extends ConsumerStatefulWidget {
  const CoachHint({super.key, required this.hintId, required this.text, required this.onAsk});
  final String hintId, text;
  final VoidCallback onAsk;

  @override
  ConsumerState<CoachHint> createState() => _CoachHintState();
}

class _CoachHintState extends ConsumerState<CoachHint> {
  late final AppLifecycleListener _life;
  bool _showing = false, _scheduled = false;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => setState(() {})); // back in the foreground: check again
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  bool get _foreground => switch (WidgetsBinding.instance.lifecycleState) { null || AppLifecycleState.resumed => true, _ => false };

  /// Called from build, which re-runs when the route becomes current again, the preference changes, the keyboard
  /// goes or the app resumes. Shows the hint after the frame, if everything still allows it.
  void _maybeShow(CoachPrefs prefs) {
    bool allowed() =>
        mounted && !_showing && prefs.hintsEnabled && !prefs.dismissed.contains(widget.hintId) &&
        (ModalRoute.isCurrentOf(context) ?? true) && _foreground && MediaQuery.viewInsetsOf(context).bottom == 0;
    if (_scheduled || !allowed()) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!allowed()) return;
      setState(() => _showing = true);
      ref.read(coachPrefsProvider.notifier).dismiss(widget.hintId); // seen: never again in this flow until reset
    });
  }

  void _close() => setState(() => _showing = false);

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(coachPrefsProvider);
    _maybeShow(prefs);
    // Turning hints off hides an open one too.
    if (!_showing || !prefs.hintsEnabled) return const SizedBox.shrink();
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TweenAnimationBuilder<double>(
        key: const Key('coach-hint-entrance'),
        tween: Tween(begin: 0, end: 1),
        duration: context.motion(Motion.quick),
        curve: Motion.curve,
        builder: (_, t, child) => Opacity(opacity: t, child: Transform.scale(scale: 0.96 + 0.04 * t, alignment: Alignment.topRight, child: child)),
        child: Semantics(
          key: const Key('coach-hint'), container: true, label: 'Tip',
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(Radii.tile), border: Border.all(color: c.divider)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 0, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(widget.text, style: context.sansStyle(14.5)))),
                  IconButton(key: const Key('coach-hint-close'), tooltip: 'Close hint', onPressed: _close, icon: Icon(Icons.close_rounded, size: 20, color: c.secondary)),
                ]),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const Key('coach-hint-ask'),
                    onPressed: () {
                      _close();
                      widget.onAsk();
                    },
                    child: const Text('Ask GoHard'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
