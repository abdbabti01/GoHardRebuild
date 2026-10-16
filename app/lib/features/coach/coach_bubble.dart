import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show ownerProvider;
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'coach_avatar.dart';
import 'coach_companion.dart';
import 'coach_contract.dart';
import 'coach_prefs.dart';

/// The coach speaking (docs/COACH.md › Companion › Speech bubbles): the selected guide beside an attached bubble of
/// native text, with "Ask me" and at most one existing guide action. Screens describe what to say ([CoachSay]) and
/// where ([CoachSpot] in the page, [showCoachHelpSheet] over a focused activity); when it appears is decided here
/// and in [CoachPrefs], never by the animation.

/// One built-in guide action in a bubble ("Compare splits", "About this exercise").
typedef CoachGuideAction = ({String label, Key key, VoidCallback onPressed});

/// What the coach says in one place: a short [text] (one or two sentences), an optional [title] line, "Ask me"
/// when [ask] is given (Ask GoHard about that context; nothing is sent until the user asks) and one [guide] action.
@immutable
class CoachSay {
  const CoachSay(this.text, {this.title, this.ask, this.onAsk, this.guide});
  final String? title;
  final String text;
  final CoachContext? ask;

  /// Instead of [ask]: the page's own way into Ask GoHard (a builder passes its draft and its Apply).
  final VoidCallback? onAsk;
  final CoachGuideAction? guide;
}

/// Where a bubble's tail points: towards the guide's face, left or right of the bubble.
enum CoachTail { left, right }

/// The speech bubble: the theme's raised surface with a hairline edge, readable over any page or weather scene, and
/// a small tail towards the face at [tailY] (from the top, or from the bottom with [tailFromBottom], for a face level
/// with the bubble's foot). Its words and buttons are native and reflow at large text. With [announce] it is read out
/// once as it appears (an introduction); it never takes focus. [revealed] (0..1) fades and grows it from the tail as the
/// guide settles, and it is neither visible nor in the semantics tree until it has mostly arrived.
class CoachBubble extends StatelessWidget {
  const CoachBubble({
    super.key,
    required this.say,
    required this.tail,
    this.tailY = 30,
    this.tailFromBottom = false,
    this.announce = false,
    this.onClose,
    this.closeLabel = 'Close',
    this.closeKey = const Key('coach-say-close'),
    this.revealed,
  });
  final CoachSay say;
  final CoachTail tail;
  final double tailY;
  final bool tailFromBottom, announce;
  final VoidCallback? onClose;
  final String closeLabel;
  final Key closeKey;
  final ValueListenable<double>? revealed;

  static const _tailWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = say;
    final ask = s.onAsk ?? (s.ask == null ? null : () => openAskGoHard(context, s.ask!));
    // Ask me as the only action: it ends the sentence ("… today? Ask me ›") and the whole bubble is the button, so a
    // short message needs no row of its own. With a guide action as well, the two are buttons under the words.
    final inline = ask != null && s.guide == null;
    final closeRoom = onClose == null ? 0.0 : 28.0;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.title != null)
          Padding(
            padding: EdgeInsets.only(right: closeRoom),
            child: Text(
              s.title!,
              key: const Key('coach-say-title'),
              style: context.sansStyle(17, weight: FontWeight.w600),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(right: s.title == null ? closeRoom : 0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: s.text),
                // Non-breaking spaces: "Ask me ›" moves to the next line as one piece, never split after "Ask".
                if (inline)
                  TextSpan(
                    text: '  Ask me ›',
                    semanticsLabel: '',
                    style: context.sansStyle(15, color: c.accent, weight: FontWeight.w600),
                  ),
              ],
            ),
            key: const Key('coach-say-text'),
            style: context.sansStyle(15, color: c.text),
          ),
        ),
        if (!inline && (ask != null || s.guide != null))
          // The first button's label starts at the words' left edge (its padding hangs into the bubble's margin).
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Wrap(
              spacing: 4,
              children: [
                if (ask != null)
                  TextButton(
                    key: const Key('coach-say-ask'),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(Targets.minimum, Targets.minimum)),
                    onPressed: ask,
                    child: const Text('Ask me'),
                  ),
                if (s.guide case final g?)
                  TextButton(
                    key: g.key,
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(Targets.minimum, Targets.minimum)),
                    onPressed: g.onPressed,
                    child: Text(g.label),
                  ),
              ],
            ),
          ),
      ],
    );
    final left = tail == CoachTail.left ? _tailWidth : 0.0, right = tail == CoachTail.right ? _tailWidth : 0.0;
    final radius = BorderRadius.circular(16);
    Widget content = Padding(padding: EdgeInsets.fromLTRB(left + 14, 10, right + 14, inline || ask == null && s.guide == null ? 8 : 2), child: words);
    if (inline) {
      // One button the size of the bubble (at least 48 px high), read as its words and "Ask me".
      content = Semantics(
        button: true,
        hint: 'Ask me',
        child: Padding(
          padding: EdgeInsets.only(left: left, right: right),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const Key('coach-say-ask'),
              borderRadius: radius,
              onTap: ask,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Targets.minimum),
                child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: words),
              ),
            ),
          ),
        ),
      );
    }
    final body = Semantics(
      container: true,
      liveRegion: announce,
      child: CustomPaint(
        painter: _BubblePainter(fill: c.raised, edge: c.divider, tail: tail, tailY: tailY, fromBottom: tailFromBottom),
        child: Stack(
          children: [
            content,
            // In the corner, over the bubble's own padding: it takes no line of its own.
            if (onClose != null)
              Positioned(
                top: 0,
                right: right,
                child: IconButton(
                  key: closeKey,
                  tooltip: closeLabel,
                  onPressed: onClose,
                  constraints: const BoxConstraints.tightFor(width: Targets.minimum, height: Targets.minimum),
                  icon: Icon(Icons.close_rounded, size: 18, color: c.secondary),
                ),
              ),
          ],
        ),
      ),
    );
    final r = revealed;
    if (r == null) return body;
    return ValueListenableBuilder<double>(
      valueListenable: r,
      child: body,
      builder: (context, t, child) => ExcludeSemantics(
        excluding: t < 0.5,
        child: IgnorePointer(
          ignoring: t < 0.5,
          child: Opacity(
            opacity: Curves.easeOut.transform(t),
            child: Transform.scale(scale: 0.94 + 0.06 * t, alignment: tail == CoachTail.left ? Alignment.centerLeft : Alignment.centerRight, child: child),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle with a small tail on one side, filled and edged in one path so the joint never shows.
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.fill, required this.edge, required this.tail, required this.tailY, this.fromBottom = false});
  final Color fill, edge;
  final CoachTail tail;
  final double tailY;
  final bool fromBottom;

  @override
  void paint(Canvas canvas, Size size) {
    const w = CoachBubble._tailWidth, h = 14.0, r = 16.0;
    final left = tail == CoachTail.left ? w : 0.0, right = size.width - (tail == CoachTail.right ? w : 0.0);
    final y = (fromBottom ? size.height - tailY : tailY).clamp(r + h / 2, math.max(r + h / 2, size.height - r - h / 2));
    final rect = RRect.fromLTRBR(left, 0, right, size.height, const Radius.circular(r));
    final tailPath = Path();
    if (tail == CoachTail.left) {
      tailPath
        ..moveTo(left + 1, y - h / 2)
        ..quadraticBezierTo(left - w * 0.4, y - 1, 0, y + 1)
        ..quadraticBezierTo(left - w * 0.2, y + h / 2 - 1, left + 1, y + h / 2)
        ..close();
    } else {
      tailPath
        ..moveTo(right - 1, y - h / 2)
        ..quadraticBezierTo(right + w * 0.4, y - 1, size.width, y + 1)
        ..quadraticBezierTo(right + w * 0.2, y + h / 2 - 1, right - 1, y + h / 2)
        ..close();
    }
    final shape = Path.combine(PathOperation.union, Path()..addRRect(rect), tailPath);
    canvas
      ..drawShadow(shape, Colors.black.withValues(alpha: 0.5), 2, false)
      ..drawPath(shape, Paint()..color = fill)
      ..drawPath(
        shape,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.fill != fill || old.edge != edge || old.tail != tail || old.tailY != tailY || old.fromBottom != fromBottom;
}

/// The guide and its bubble in a page or sheet: a small round portrait on the left (the bubble's tail points at its
/// face) and the words. An [introduce]d one peeks in and greets, its words arriving as it settles, and is read out
/// once; help the user asked for is simply there, settled and ready to tap. Used by [CoachSpot] and
/// [showCoachHelpSheet].
class CoachSpeaker extends ConsumerStatefulWidget {
  const CoachSpeaker({super.key, required this.say, this.introduce = false, this.onClose, this.closeLabel = 'Close'});
  final CoachSay say;
  final bool introduce;
  final VoidCallback? onClose;
  final String closeLabel;

  @override
  ConsumerState<CoachSpeaker> createState() => _CoachSpeakerState();
}

class _CoachSpeakerState extends ConsumerState<CoachSpeaker> {
  late final _revealed = ValueNotifier<double>(widget.introduce ? 0 : 1);

  @override
  void dispose() {
    _revealed.dispose();
    super.dispose();
  }

  static const _face = 52.0;

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));
    return Row(
      key: const Key('coach-speaker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: ColoredBox(
            color: context.c.sunken,
            child: CoachCompanion(guide: guide, size: const Size.square(_face), greet: widget.introduce, revealed: widget.introduce ? _revealed : null),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: CoachBubble(
            say: widget.say,
            tail: CoachTail.left,
            tailY: _face / 2,
            announce: widget.introduce,
            onClose: widget.onClose,
            closeLabel: widget.closeLabel,
            revealed: _revealed,
          ),
        ),
      ],
    );
  }
}

/// The one bubble open in the app at a time, by its context id: opening another replaces it, so two never stack.
class CoachHelp extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(ownerProvider); // another sign-in starts closed
    return null;
  }

  void show(String id) => state = id;
  void close(String id) {
    if (ref.mounted && state == id) state = null; // also called just after a page (or a whole test app) went away
  }

  void toggle(String id) => state = state == id ? null : id;
}

final coachHelpProvider = NotifierProvider<CoachHelp, String?>(CoachHelp.new);

/// The help entry for a context: the guide's avatar in a 48 px button, labelled by purpose. It opens (or closes)
/// that context's [CoachSpot] whatever the Coaching hints setting: asking for help is always allowed.
class CoachHelpEntry extends ConsumerWidget {
  const CoachHelpEntry({super.key, required this.id, required this.label});
  final String id, label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Open, the guide is already speaking beside its bubble: the entry steps back (one character on screen, not two)
    // and says it is expanded; pressing it again closes the bubble.
    final open = ref.watch(coachHelpProvider) == id;
    return Semantics(
      expanded: open,
      child: AnimatedOpacity(
        opacity: open ? 0.35 : 1,
        duration: context.motion(Motion.quick),
        child: CoachHelpButton(key: Key('coach-help-$id'), semanticLabel: label, onPressed: () => ref.read(coachHelpProvider.notifier).toggle(id)),
      ),
    );
  }
}

/// Where the coach speaks about one context ([id], stable, such as `builder.structure`), in the page's own flow:
/// opening moves the content below it down and covers nothing; it scrolls with the page.
///
/// It opens when its [CoachHelpEntry] is pressed, and once by itself ([introduce]) the first time the context is
/// really in view for this account: Coaching hints on, its route the current one and its tab selected, the app in the foreground, no
/// keyboard up and the spot on screen (a spot built off screen, or in a list's cache, is not seen). If the keyboard was
/// up it waits for the next visit, rather than popping in as the keyboard closes under a finger. Appearing marks
/// it seen for this account; it does not come back by itself until "Show coaching hints again", and never daily.
class CoachSpot extends ConsumerStatefulWidget {
  const CoachSpot({super.key, required this.id, required this.say, this.introduce = false, this.padding = const EdgeInsets.only(top: 12)});
  final String id;
  final CoachSay say;
  final bool introduce;
  final EdgeInsets padding;

  @override
  ConsumerState<CoachSpot> createState() => _CoachSpotState();
}

class _CoachSpotState extends ConsumerState<CoachSpot> {
  late final CoachHelp _help = ref.read(coachHelpProvider.notifier);
  late final AppLifecycleListener _life = AppLifecycleListener(onResume: _check);
  ScrollPosition? _scroll;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _life;
    _help; // read now: dispose() may not use ref
  }

  /// Whether this spot opened itself (an introduction) rather than being asked for.
  bool _introduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_check);
      _scroll = scroll?..addListener(_check);
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_check);
    _life.dispose();
    final id = widget.id;
    Future.microtask(() => _help.close(id)); // a bubble belongs to its page; not while the tree is unmounting
    super.dispose();
  }

  /// The view's own inset: inside a Scaffold the page's MediaQuery has the keyboard taken out of it already.
  bool get _keyboard => View.of(context).viewInsets.bottom > 0;

  bool get _foreground => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed => true,
    _ => false,
  };

  /// Shows the introduction after this frame if everything still allows it (see [CoachSpot]).
  void _check() {
    if (!widget.introduce || _scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final owner = ref.read(ownerProvider);
      final prefs = ref.read(coachPrefsProvider);
      if (owner == null || !prefs.mayIntroduce(owner, widget.id) || ref.read(coachHelpProvider) != null) return;
      // Its tab selected too: the shell builds every tab, and a hidden one is not "in view".
      if (!(ModalRoute.isCurrentOf(context) ?? true) || !TickerMode.valuesOf(context).enabled || !_foreground || _keyboard) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top < 0 || top + 40 > MediaQuery.sizeOf(context).height) return; // its start must be on screen
      _introduced = true;
      _help.show(widget.id);
      ref.read(coachPrefsProvider.notifier).markSeen(owner, widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the check runs again when hints are turned on, the keyboard goes or the route becomes current.
    ref.watch(coachPrefsProvider.select((p) => p.hintsEnabled));
    ModalRoute.of(context);
    TickerMode.valuesOf(context);
    final open = ref.watch(coachHelpProvider) == widget.id;
    if (!open) {
      _introduced = false;
      _check();
    }
    final child = !open
        ? const SizedBox(width: double.infinity)
        : Padding(
            key: Key('coach-spot-${widget.id}'),
            padding: widget.padding,
            child: CoachSpeaker(say: widget.say, introduce: _introduced, onClose: () => _help.close(widget.id)),
          );
    // Under Reduce Motion the page simply makes room (AnimatedSize must not run with no duration).
    if (context.reduceMotion) return child;
    return AnimatedSize(duration: Motion.quick, curve: Motion.curve, alignment: Alignment.topCenter, child: child);
  }
}

/// Help over a focused activity (recording sets, a run): the same guide and bubble in a sheet, opened only by the
/// user, so nothing pops over a field, a timer, the run controls or the keyboard. Ask GoHard opens over the sheet and
/// closing it comes back here: the activity underneath keeps its input, focus, timers and drafts.
Future<void> showCoachHelpSheet(BuildContext context, {required String title, required CoachSay say}) => showGoSheet<void>(
  context,
  title: title,
  builder: (sheet) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: CoachSpeaker(key: const Key('coach-help-sheet'), say: say),
  ),
);
