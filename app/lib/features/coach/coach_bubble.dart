import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show ownerProvider;
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'coach_avatar.dart';
import 'coach_companion.dart';
import 'coach_contract.dart';
import 'coach_prefs.dart';
import 'coach_rig.dart';

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
  const CoachSay(this.text, {this.title, this.ask, this.onAsk, this.guide, this.primary});
  final String? title;
  final String text;
  final CoachContext? ask;

  /// Instead of [ask]: the page's own way into Ask GoHard (a builder passes its draft and its Apply).
  final VoidCallback? onAsk;
  final CoachGuideAction? guide;

  /// The page's main next step, said by the coach (Train's "Create my plan"): a deep filled button under the words,
  /// so the invitation and the action are one thing. The page does not repeat it.
  final CoachGuideAction? primary;
}

/// The speech bubble's body: the theme's raised surface with a hairline edge, readable over any page or weather scene.
/// Its tail is drawn by [CoachSpeech], from the bubble to the guide's mouth. Its words and buttons are native and reflow
/// at large text. With [announce] it is read out once as it appears (an introduction); it never takes focus.
/// [revealed] (0..1) fades it in as the guide settles; it is neither visible nor in the semantics tree before that.
class CoachBubble extends StatelessWidget {
  const CoachBubble({super.key, required this.say, this.announce = false, this.onClose, this.closeLabel, this.closeKey = const Key('coach-say-close'), this.revealed, this.onAsk});
  final CoachSay say;
  final bool announce;
  final VoidCallback? onClose;

  /// Default: Close, in the app's language.
  final String? closeLabel;
  final Key closeKey;
  final ValueListenable<double>? revealed;

  /// Called as Ask me opens Ask GoHard (the guide reacts: a nod for being asked).
  final VoidCallback? onAsk;

  static const radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l = context.l10n;
    final s = say;
    final open = s.onAsk ?? (s.ask == null ? null : () => openAskGoHard(context, s.ask!));
    final ask = open == null
        ? null
        : () {
            onAsk?.call();
            open();
          };
    // Ask me as the only action: it ends the sentence ("… today? Ask me ›") and the whole bubble is the button, so a
    // short message needs no row of its own. With a guide action as well, the two are buttons under the words.
    final inline = ask != null && s.guide == null && s.primary == null;
    final closeRoom = onClose == null ? 0.0 : 28.0;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.title != null)
          Padding(
            padding: EdgeInsetsDirectional.only(end: closeRoom),
            child: Text(
              s.title!,
              key: const Key('coach-say-title'),
              style: context.sansStyle(17, weight: FontWeight.w600),
            ),
          ),
        Padding(
          padding: EdgeInsetsDirectional.only(end: s.title == null ? closeRoom : 0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: s.text),
                // One unbreakable piece: "Ask me ›" moves to the next line whole, never split (the chevron can come from a
                // fallback font, whose run boundary would otherwise allow a break). Read out as the bubble's button label.
                if (inline) ...[
                  const TextSpan(text: '  '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    // The paragraph already scales its inline widgets by the text size: not twice.
                    child: ExcludeSemantics(
                      child: Text(
                        l.coachAskMeInline,
                        softWrap: false,
                        textScaler: TextScaler.noScaling,
                        style: context.sansStyle(15, color: c.accent, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            key: const Key('coach-say-text'),
            style: context.sansStyle(15, color: c.text),
          ),
        ),
        if (s.primary case final p?)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              PrimaryButton(p.label, key: p.key, expand: false, onPressed: p.onPressed),
              if (ask != null)
                TextButton(key: const Key('coach-say-ask'), style: TextButton.styleFrom(minimumSize: const Size(Targets.minimum, Targets.minimum)), onPressed: ask, child: Text(l.coachAskMe)),
              if (s.guide case final g?)
                TextButton(key: g.key, style: TextButton.styleFrom(minimumSize: const Size(Targets.minimum, Targets.minimum)), onPressed: g.onPressed, child: Text(g.label)),
            ]),
          )
        else if (!inline && (ask != null || s.guide != null))
          // The first button's label starts at the words' starting edge (its padding hangs into the bubble's margin).
          Transform.translate(
            offset: Offset(context.isRtl ? 8 : -8, 0),
            child: Wrap(
              spacing: 4,
              children: [
                if (ask != null)
                  TextButton(
                    key: const Key('coach-say-ask'),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(Targets.minimum, Targets.minimum)),
                    onPressed: ask,
                    child: Text(l.coachAskMe),
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: c.divider),
    );
    Widget content = Padding(padding: EdgeInsets.fromLTRB(14, 10, 14, inline || ask == null && s.guide == null ? 8 : 2), child: words);
    if (inline) {
      // One button the size of the bubble (at least 48 px high), read as its words and "Ask me".
      content = Semantics(
        button: true,
        hint: l.coachAskMe,
        child: InkWell(
          key: const Key('coach-say-ask'),
          customBorder: shape,
          onTap: ask,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.minimum),
            child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: words),
          ),
        ),
      );
    }
    final body = Semantics(
      container: true,
      liveRegion: announce,
      child: Material(
        color: c.raised,
        shape: shape,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        child: Stack(
          children: [
            content,
            // In the corner, over the bubble's own padding: it takes no line of its own.
            if (onClose != null)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: IconButton(
                  key: closeKey,
                  tooltip: closeLabel ?? l.actionClose,
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
          child: Opacity(opacity: Curves.easeOut.transform(t), child: child),
        ),
      ),
    );
  }
}

/// The guide speaking: the small head-and-shoulders portrait right beside its bubble, the bubble's tail running from
/// the bubble's edge to just short of the guide's mouth and following it every frame, so the words come from the
/// guide whatever the head is doing, for either guide, any text length and any width. The portrait's empty side
/// (beyond the muzzle) tucks under the bubble's edge, so only a small deliberate gap is left between the words and the
/// face. [frame] picks the side: [RigFrame.edge] puts the guide on the right, leaning in from past the right edge by
/// [bleed] (Today's screen edge); [RigFrame.inline] puts it on the left, whole. Right to left the guide is on the left
/// in both, as painted (facing its words), [RigFrame.edge] leaning in from past the left edge: the artwork is never
/// flipped, and the tail, the mouth and the gaze are worked out from where things really are.
///
/// The guide's portrait is the Ask GoHard launcher when [onAvatarTap] is given (a button named for what it opens); otherwise
/// it is decorative. The bubble's words stay put while the guide moves.
class CoachSpeech extends ConsumerStatefulWidget {
  const CoachSpeech({
    super.key,
    required this.say,
    required this.portrait,
    this.frame = RigFrame.inline,
    this.bleed = 0,
    this.greet = false,
    this.ack = 0,
    this.attentive = false,
    this.announce = false,
    this.onGreeted,
    this.onClose,
    this.closeLabel,
    this.onAvatarTap,
    this.onAsk,
    this.avatarLabel,
  });
  final CoachSay say;

  /// What the portrait opens, when it is a button (default: Ask GoHard).
  final String? avatarLabel;
  final Size portrait;
  final RigFrame frame;
  final double bleed;
  final bool greet, attentive, announce;
  final int ack;
  final VoidCallback? onGreeted, onClose, onAvatarTap, onAsk;
  final String? closeLabel;

  @override
  ConsumerState<CoachSpeech> createState() => _CoachSpeechState();
}

class _CoachSpeechState extends ConsumerState<CoachSpeech> {
  final _pose = ValueNotifier<RigPose>(RigPose.hidden);
  late final _revealed = ValueNotifier<double>(widget.greet ? 0 : 1);
  final _stack = GlobalKey(), _bubble = GlobalKey(), _face = GlobalKey();

  /// Where the bubble's tail meets the bubble, from its top: about the first line.
  static const _anchor = 30.0;

  /// The space left between the tail's tip and the lips (the muzzle's edge at the mouth's height).
  static const _gap = 4.0;

  @override
  void dispose() {
    _pose.dispose();
    _revealed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));
    final art = RigArt.of(guide);
    final rtl = context.isRtl;
    final edge = widget.frame == RigFrame.edge;
    final geo = RigGeometry(art, widget.frame, widget.portrait, direction: Directionality.of(context));
    // Physical sides from here on: the guide is on the right only for an edge guide left to right.
    final right = edge && !rtl;
    // From the settled pose: the mouth's height in the portrait, and how far the muzzle reaches towards the bubble.
    final mouth = geo.point(art.mouth, RigPose.settled);
    final front = geo.point(Offset(art.front, art.mouth.dy), RigPose.settled);
    final muzzleIn = right ? front.dx : widget.portrait.width - front.dx;
    final under = math.max(0.0, muzzleIn - 10); // the portrait's empty side, under the bubble's edge
    final bubbleTop = math.max(0.0, mouth.dy - _anchor), portraitTop = math.max(0.0, _anchor - mouth.dy);
    final side = widget.portrait.width - under - (edge ? widget.bleed : 0);
    Widget face = CoachCompanion(
      guide: guide,
      size: widget.portrait,
      frame: widget.frame,
      pose: _pose,
      revealed: _revealed,
      greet: widget.greet,
      ack: widget.ack,
      attentive: widget.attentive,
      onGreeted: widget.onGreeted,
    );
    face = widget.onAvatarTap == null
        ? ExcludeSemantics(child: face)
        : Semantics(
            container: true,
            button: true,
            label: widget.avatarLabel ?? context.l10n.coachAskOpenWith(guide.displayName(context.l10n)),
            onTap: widget.onAvatarTap,
            child: GestureDetector(
              key: const Key('coach-avatar-launcher'),
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: widget.onAvatarTap,
              child: ExcludeSemantics(child: face),
            ),
          );
    return Stack(
      key: _stack,
      clipBehavior: Clip.none,
      // A narrow bubble keeps to the guide's side when the guide is on the left right to left (inline, as left to right).
      alignment: rtl && !edge ? Alignment.topLeft : AlignmentDirectional.topStart,
      children: [
        SizedBox(height: portraitTop + widget.portrait.height, width: double.infinity),
        Positioned(key: _face, top: portraitTop, width: widget.portrait.width, height: widget.portrait.height, left: right ? null : (edge ? -widget.bleed : 0), right: right ? -widget.bleed : null, child: face),
        Padding(
          padding: EdgeInsets.only(top: bubbleTop, left: right ? 0 : side, right: right ? side : 0),
          child: KeyedSubtree(
            key: _bubble,
            child: CoachBubble(say: widget.say, announce: widget.announce, onClose: widget.onClose, closeLabel: widget.closeLabel, revealed: _revealed, onAsk: widget.onAsk),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TailPainter(
                stack: _stack,
                bubble: _bubble,
                face: _face,
                geometry: geo,
                pose: _pose,
                revealed: _revealed,
                right: right,
                fill: context.c.raised,
                edge: context.c.divider,
                gap: _gap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The tail: from the bubble's edge (at the mouth's height, kept clear of the bubble's corners) to just short of the
/// mouth, as the head is now. Filled like the bubble and edged on its two sides only, its base overlapping the bubble so
/// the join never shows. It fades in with the bubble.
class _TailPainter extends CustomPainter {
  _TailPainter({
    required this.stack,
    required this.bubble,
    required this.face,
    required this.geometry,
    required this.pose,
    required this.revealed,
    required this.right,
    required this.fill,
    required this.edge,
    required this.gap,
  }) : super(repaint: Listenable.merge([pose, revealed]));
  final GlobalKey stack, bubble, face;
  final RigGeometry geometry;
  final ValueListenable<RigPose> pose;
  final ValueListenable<double> revealed;
  final bool right;
  final Color fill, edge;
  final double gap;

  /// Where the bubble and the mouth are in this painter's box, laid out and posed as they are now. The mouth is taken at
  /// the muzzle's edge, where the lips meet the outline, so the tail stops short of the face instead of covering it.
  ({Rect bubble, Offset mouth})? locate() {
    final s = stack.currentContext?.findRenderObject() as RenderBox?, b = bubble.currentContext?.findRenderObject() as RenderBox?;
    final f = face.currentContext?.findRenderObject() as RenderBox?;
    if (s == null || b == null || f == null || !s.hasSize || !b.hasSize || !f.hasSize || !b.attached || !f.attached) return null;
    final bo = b.localToGlobal(Offset.zero, ancestor: s), fo = f.localToGlobal(Offset.zero, ancestor: s);
    return (bubble: bo & b.size, mouth: fo + geometry.point(Offset(geometry.art.front, geometry.art.mouth.dy), pose.value));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = revealed.value;
    if (t <= 0.01) return;
    final at = locate();
    if (at == null) return;
    final b = at.bubble, m = at.mouth;
    const r = CoachBubble.radius, half = 7.0;
    final baseX = right ? b.right - 1.5 : b.left + 1.5;
    final baseY = m.dy.clamp(b.top + r + half, math.max(b.top + r + half, b.bottom - r - half));
    final tip = Offset(m.dx + (right ? -gap : gap), m.dy);
    // A gently curved wedge, wide at the bubble, pointed at the mouth.
    final path = Path()
      ..moveTo(baseX, baseY - half)
      ..quadraticBezierTo((baseX + tip.dx) / 2, (baseY - half + tip.dy) / 2 - 1, tip.dx, tip.dy)
      ..quadraticBezierTo((baseX + tip.dx) / 2, (baseY + half + tip.dy) / 2 + 1, baseX, baseY + half)
      ..close();
    final alpha = Curves.easeOut.transform(t);
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: fill.a * alpha));
    final sides = Path()
      ..moveTo(baseX, baseY - half)
      ..quadraticBezierTo((baseX + tip.dx) / 2, (baseY - half + tip.dy) / 2 - 1, tip.dx, tip.dy)
      ..quadraticBezierTo((baseX + tip.dx) / 2, (baseY + half + tip.dy) / 2 + 1, baseX, baseY + half);
    canvas.drawPath(
      sides,
      Paint()
        ..color = edge.withValues(alpha: edge.a * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.geometry != geometry || old.fill != fill || old.edge != edge || old.right != right;
}

/// The guide and its bubble in a page or sheet: [CoachSpeech] inline, the guide on the left facing its words. An
/// [introduce]d one peeks in and greets, its words arriving as it settles, and is read out once; help the user asked for
/// is simply there, settled and ready to tap. Where it can answer (Ask me), the guide's portrait opens Ask GoHard too.
/// Used by [CoachSpot] and [showCoachHelpSheet].
class CoachSpeaker extends StatelessWidget {
  const CoachSpeaker({super.key, required this.say, this.introduce = false, this.onClose, this.closeLabel});
  final CoachSay say;
  final bool introduce;
  final VoidCallback? onClose;
  final String? closeLabel;

  static const portrait = Size(62, 72);

  @override
  Widget build(BuildContext context) {
    final ask = say.onAsk ?? (say.ask == null ? null : () => openAskGoHard(context, say.ask!));
    return CoachSpeech(
      key: const Key('coach-speaker'),
      say: say,
      portrait: portrait,
      greet: introduce,
      announce: introduce,
      onClose: onClose,
      closeLabel: closeLabel,
      onAvatarTap: ask,
    );
  }
}

/// Ask GoHard's launcher where there is no bubble to say it: the selected guide's avatar in a 48 px button, labelled
/// by what it does. The same face opens the same conversation everywhere (the Today portrait, Ask me in a bubble, this).
class CoachAskLauncher extends ConsumerWidget {
  const CoachAskLauncher({super.key, required this.ask});
  final CoachContext ask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));
    return CoachHelpButton(key: const Key('coach-ask-launcher'), semanticLabel: context.l10n.coachAskOpenWith(guide.displayName(context.l10n)), onPressed: () => openAskGoHard(context, ask));
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

/// Leon or Leona on Train and Eat (docs/COACH.md › Companion › Train and Eat): Today's bust and mouth-attached bubble,
/// peeking in from the right edge under the tab's title, saying one short thing about the section in view, with at most
/// one main action ([CoachSay.primary]). Shown while Me › Appearance › Show coach on Train and Eat is on; there is no
/// close button. It peeks in once per tab ([id]) for the signed-in session, the first time the tab is really in view;
/// a new message, a rebuild or scrolling it out of the page's lazy list and back changes nothing but the words. The portrait is the
/// page's help entry ([onAvatarTap], named by [avatarLabel]). Opening the tab never asks the AI.
class TabCoach extends ConsumerStatefulWidget {
  const TabCoach({super.key, required this.id, required this.say, required this.onAvatarTap, this.avatarLabel, this.attentive = false});

  /// The tab ('train', 'eat'): its entrance is played once per session.
  final String id;
  final CoachSay say;

  /// A request the user sent is really in flight (as in Ask GoHard): the guide leans in, attentive, until it ends.
  final bool attentive;
  final VoidCallback onAvatarTap;
  final String? avatarLabel;

  /// Smaller than Today's: a compact bust that leaves the section's content in view.
  static Size slot(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 340 ? const Size(60, 74) : width < 380 ? const Size(70, 88) : const Size(80, 100);
  }

  @override
  ConsumerState<TabCoach> createState() => _TabCoachState();
}

/// The tabs whose coach has already peeked in, for the signed-in account; another sign-in starts afresh.
class TabsGreeted extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(ownerProvider);
    return const {};
  }

  void add(String id) {
    if (!state.contains(id)) state = {...state, id};
  }
}

final tabsGreetedProvider = NotifierProvider<TabsGreeted, Set<String>>(TabsGreeted.new);

class _TabCoachState extends ConsumerState<TabCoach> {
  int _ack = 0;

  /// Decided once for this widget: a coach rebuilt after scrolling back is simply there.
  late final bool _greet = !ref.read(tabsGreetedProvider).contains(widget.id);

  @override
  Widget build(BuildContext context) => CoachSpeech(
        say: widget.say,
        portrait: TabCoach.slot(context),
        frame: RigFrame.edge,
        bleed: context.inset,
        greet: _greet,
        onGreeted: () {
          if (mounted) ref.read(tabsGreetedProvider.notifier).add(widget.id); // called after the frame
        },
        ack: _ack,
        attentive: widget.attentive,
        onAsk: () => setState(() => _ack++),
        avatarLabel: widget.avatarLabel,
        onAvatarTap: () {
          setState(() => _ack++);
          widget.onAvatarTap();
        },
      );
}
