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

/// The avatar in a 48 px button, labelled by purpose ("Ask GoHard about this split"). With a [hintId] and
/// [hintText] it may show, once per flow and only while coaching hints are on, a short dismissible bubble anchored
/// to it with an Ask GoHard action and a close button. The bubble never opens chat, moves focus or sends anything.
///
/// Hints exist only on this button, and this button goes only where help is the point (the plan builder, its splits,
/// workouts and exercises, help pages). Never put one on a screen for recording sets, running, reviewing conflicts
/// or reviewing a destructive change: that is how those contexts stay free of unsolicited hints. Without a [hintId]
/// it is a plain help button anywhere.
///
/// The bubble appears only while its route is the current one, the app is in the foreground and no keyboard is up.
/// Appearing marks the hint seen, so it returns only after Me › Appearance › Show coaching hints again. [hintText] is
/// interface copy we wrote, never presented as an answer from the model.
class CoachHelpButton extends ConsumerStatefulWidget {
  const CoachHelpButton({super.key, required this.semanticLabel, required this.onPressed, this.hintId, this.hintText, this.size = 44});
  final String semanticLabel;
  final VoidCallback onPressed;
  final String? hintId, hintText;
  final double size;

  @override
  ConsumerState<CoachHelpButton> createState() => _CoachHelpButtonState();
}

class _CoachHelpButtonState extends ConsumerState<CoachHelpButton> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  late final AppLifecycleListener _life;
  bool _scheduled = false;

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
  /// goes or the app resumes. Shows the bubble after the frame, if everything still allows it.
  void _maybeShow(CoachPrefs prefs) {
    final id = widget.hintId;
    bool allowed() =>
        mounted && id != null && widget.hintText != null && prefs.hintsEnabled && !prefs.dismissed.contains(id) && !_portal.isShowing &&
        (ModalRoute.isCurrentOf(context) ?? true) && _foreground && MediaQuery.viewInsetsOf(context).bottom == 0;
    if (_scheduled || !allowed()) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!allowed()) return;
      _portal.show();
      ref.read(coachPrefsProvider.notifier).dismiss(id!); // seen: never again in this flow until reset
    });
  }

  void _close() => setState(_portal.hide);

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(coachPrefsProvider);
    _maybeShow(prefs);
    final side = math.max(Targets.minimum, widget.size);
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        // Turning hints off hides an open one too.
        overlayChildBuilder: (_) => prefs.hintsEnabled ? _bubble(context) : const SizedBox.shrink(),
        child: IconButton(
          tooltip: widget.semanticLabel,
          onPressed: widget.onPressed,
          constraints: BoxConstraints.tight(Size.square(side)),
          padding: EdgeInsets.zero,
          icon: CoachAvatar(size: side - 8),
        ),
      ),
    );
  }

  /// A compact card under the button, on the side with room, inside the screen edges. It covers only its own
  /// rectangle: everything around it keeps working, and nothing takes focus.
  Widget _bubble(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context);
    final start = box == null || !box.hasSize || box.localToGlobal(box.size.center(Offset.zero)).dx < screen.width / 2;
    final c = context.c;
    return Positioned(
      width: math.min(300.0, screen.width - 32),
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: start ? Alignment.bottomLeft : Alignment.bottomRight,
        followerAnchor: start ? Alignment.topLeft : Alignment.topRight,
        offset: const Offset(0, 6),
        child: TweenAnimationBuilder<double>(
          key: const Key('coach-hint-entrance'),
          tween: Tween(begin: 0, end: 1),
          duration: context.motion(Motion.quick),
          curve: Motion.curve,
          builder: (_, t, child) => Opacity(opacity: t, child: Transform.scale(scale: 0.96 + 0.04 * t, alignment: start ? Alignment.topLeft : Alignment.topRight, child: child)),
          child: Semantics(
            key: const Key('coach-hint'), container: true, label: 'Tip',
            child: Material(
              color: c.raised,
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile), side: BorderSide(color: c.divider)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 0, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(widget.hintText!, style: context.sansStyle(14.5)))),
                    IconButton(key: const Key('coach-hint-close'), tooltip: 'Close hint', onPressed: _close, icon: Icon(Icons.close_rounded, size: 20, color: c.secondary)),
                  ]),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const Key('coach-hint-ask'),
                      onPressed: () {
                        _close();
                        widget.onPressed();
                      },
                      child: const Text('Ask GoHard'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
