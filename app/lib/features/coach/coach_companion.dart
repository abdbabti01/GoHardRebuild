import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme.dart';
import 'coach_avatar.dart';
import 'coach_rig.dart';

/// The companion's motion (docs/COACH.md › Companion): which pose the rig should be in, and how it gets there.
/// Driven by plain properties so the page decides only what happens ([greet], [attentive], [ack]) and never how:
/// every change starts from the pose on screen, so a quick tap, a theme change or a new guide blends instead of
/// snapping or stacking. Under Reduce Motion (the phone's or the app's) it is a still, settled portrait.
///
/// While it can be seen it is alive but quiet: the eyes look at the user and now and then at its speech bubble (the
/// head turning a touch with them), drift a little and come back, and blink at irregular intervals; between those
/// moments nothing ticks. It moves only while it can be seen: its tab selected ([TickerMode]), its route the current
/// one, the app in the foreground and its place on screen.
class CoachCompanion extends StatefulWidget {
  const CoachCompanion({super.key, required this.guide, required this.size, this.frame = RigFrame.edge, this.pose, this.greet = false, this.attentive = false, this.ack = 0, this.onGreeted, this.revealed});
  final CoachGuide guide;
  final Size size;
  final RigFrame frame;

  /// The pose it writes, when the page needs it too (a bubble's tail follows the mouth through it).
  final ValueNotifier<RigPose>? pose;

  /// Peek in and greet the first time it can be seen; otherwise it is simply there, settled.
  final bool greet;

  /// A real request is waiting: an attentive pose, held until this turns false.
  final bool attentive;

  /// Each new value plays one acknowledgement (a small smile and a nod, looking at the user).
  final int ack;

  /// The greeting has started playing (or, under Reduce Motion, has been shown): it is not to be played again.
  final VoidCallback? onGreeted;

  /// Written with how far the guide has arrived for what it says (0 hidden, 1 settled): an attached speech bubble
  /// listens to it, so the words appear as the character settles.
  final ValueNotifier<double>? revealed;

  @override
  State<CoachCompanion> createState() => CoachCompanionState();
}

/// One pose value easing towards a target as a damped spring: interrupted at any moment, it carries on from where it
/// is, at the speed it has. [w] is its natural frequency, [z] its damping (below 1 settles with a slight overshoot).
class _Spring {
  _Spring(this.x, this.w, this.z) : target = x;
  double x, target, v = 0, w, z;

  void step(double dt) {
    final a = w * w * (target - x) - 2 * z * w * v;
    v += a * dt;
    x += v * dt;
  }

  bool get resting => (target - x).abs() < 0.0015 && v.abs() < 0.01;

  void snap() {
    x = target;
    v = 0;
  }
}

@visibleForTesting
class CoachCompanionState extends State<CoachCompanion> with SingleTickerProviderStateMixin {
  // Timings (seconds) from docs/COACH.md › Companion › Motion.
  static const _greetReveal = 0.55, _greetTilt = 0.30, _nodDown = 0.62, _nodUp = 0.80, _greetBlink = 1.05, _greetSettle = 1.55, _settleFor = 7.0;

  late final ValueNotifier<RigPose> pose = widget.pose ?? ValueNotifier<RigPose>(RigPose.hidden);
  late final Ticker _ticker = createTicker(_tick);
  late final AppLifecycleListener _life = AppLifecycleListener(onStateChange: (_) => _refreshActive());
  final _random = math.Random();

  final _slide = _Spring(0, 14, 0.78), _lean = _Spring(0.2, 12, 0.85), _tilt = _Spring(0, 9, 0.9), _nod = _Spring(0, 18, 0.8);
  final _brow = _Spring(0, 10, 0.9), _smile = _Spring(0, 9, 0.95), _breath = _Spring(0, 4, 1), _reveal = _Spring(0, 11, 1);
  // The eyes move quickly but never snap: about 0.15 s to a new point, no overshoot.
  final _gazeX = _Spring(0, 26, 1), _gazeY = _Spring(0, 26, 1);
  List<_Spring> get _springs => [_slide, _lean, _tilt, _nod, _brow, _smile, _breath, _reveal, _gazeX, _gazeY];

  /// When (motion time) the eyes next move by themselves while it is moving anyway, and how long it has rested.
  double? _nextLook;
  int _restWakes = 0;

  /// Motion time: advances only while it moves, so a pause never skips part of a sequence.
  double _t = 0;
  Duration? _lastElapsed;
  final _events = <(double, VoidCallback)>[];
  double? _blinkStart, _nextBlink;
  Timer? _wake;

  bool _started = false, _measured = false, _tickerOn = true, _routeCurrent = true, _onscreen = true;
  ScrollPosition? _scroll;

  /// For tests: true while frames are being produced.
  @visibleForTesting
  bool get ticking => _ticker.isActive;

  bool get _reduce => MediaQuery.disableAnimationsOf(context);
  bool get _foreground => switch (WidgetsBinding.instance.lifecycleState) { null || AppLifecycleState.resumed => true, _ => false };
  bool get _active => _tickerOn && _routeCurrent && _foreground && _onscreen && !_reduce;

  @override
  void initState() {
    super.initState();
    _life; // created now, so it hears every change from here on
    // Nothing starts before its place on screen is known: a header built off screen (in the list's cache, or under a
    // restored scroll offset) must not spend the day's greeting unseen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measured = true;
      _checkOnscreen();
      _refreshActive();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerOn = TickerMode.valuesOf(context).enabled;
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_checkOnscreen);
      _scroll = scroll?..addListener(_checkOnscreen);
    }
    if (_reduce) _still();
    _refreshActive();
  }

  @override
  void didUpdateWidget(CoachCompanion oldWidget) {
    final old = oldWidget;
    super.didUpdateWidget(old);
    if (widget.attentive != old.attentive) _attend(widget.attentive);
    if (widget.ack != old.ack) _acknowledge();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkOnscreen);
    _wake?.cancel();
    _life.dispose();
    _ticker.dispose();
    if (widget.pose == null) pose.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ when it may move

  void _checkOnscreen() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final on = top + box.size.height > 0 && top < MediaQuery.sizeOf(context).height;
    if (on != _onscreen) {
      _onscreen = on;
      _refreshActive();
    }
  }

  void _refreshActive() {
    if (!mounted) return;
    if (!_started && _measured && _onscreen && (_active || _reduce) && _foreground && _routeCurrent && _tickerOn) _start();
    if (_active) {
      _run();
    } else {
      _ticker.stop();
      _lastElapsed = null;
      _wake?.cancel();
    }
  }

  // ------------------------------------------------------------------ cues

  /// The first time it can be seen: the greeting, or simply settled in place.
  void _start() {
    _started = true;
    if (_reduce || !widget.greet) {
      _set(RigPose.settled);
      for (final s in _springs) {
        s.snap();
      }
      _publish();
      if (widget.greet) _afterFrame(widget.onGreeted);
      if (widget.attentive) _attend(true);
      _scheduleRest();
      return;
    }
    _afterFrame(widget.onGreeted);
    // Peek in from behind the edge, settling a hair past and back (the slide spring is a little under-damped).
    _events.clear();
    _slide.target = 1;
    _lean.target = 0;
    _breath.target = 1;
    _at(_greetTilt, () {
      _tilt.target = -1;
      _brow.target = 1;
    });
    _at(_nodDown, () => _nod.target = 1);
    _at(_nodUp, () => _nod.target = 0);
    _at(_greetBlink, _blink);
    _at(_greetReveal, () {
      _reveal.target = 1; // the words arrive with the nod, as the guide settles
      _look(-1, 0.3); // a glance at them as they appear
    });
    _at(_greetSettle, () {
      _tilt.target = RigPose.settled.tilt;
      _brow.target = 0;
      _smile.target = 0.55; // a small smile for what was just said
      _look(0, 0); // and back to the user
    });
    _at(_greetSettle + 0.8, () => _smile.target = 0);
    _nextLook = _greetSettle + 1.6;
    _at(_settleFor, () => _breath.target = 0);
  }

  void _acknowledge() {
    if (_reduce || !_started) return;
    _events.clear();
    _look(0, 0);
    _smile.target = 1;
    _brow.target = 0.6;
    _breath.target = 1;
    _at(0.12, () => _nod.target = 1);
    _at(0.32, () => _nod.target = 0);
    _at(1.1, () {
      _smile.target = 0;
      _brow.target = 0;
      _tilt.target = widget.attentive ? 0.6 : RigPose.settled.tilt;
    });
    _at(5.0, () => _breath.target = 0);
    _run();
  }

  /// Waiting on a real request: the head turns a little the other way, brows up, leaning in. Released: back to the
  /// welcoming settled pose, with a brief smile.
  void _attend(bool on) {
    if (!_started) return;
    _events.clear();
    _breath.target = 0; // its scheduled fade went with the events; never left breathing (and ticking) for good
    _look(0, 0); // at the user, waiting with them
    if (on) {
      _tilt.target = 0.6;
      _brow.target = 0.5;
      _lean.target = -0.03;
    } else {
      _tilt.target = RigPose.settled.tilt;
      _brow.target = 0;
      _lean.target = 0;
      _smile.target = 0.5;
      _at(0.8, () => _smile.target = 0);
    }
    if (_reduce) {
      for (final s in _springs) {
        s.snap();
      }
      _smile.x = _smile.target = 0;
      _publish();
      return;
    }
    _run();
  }

  /// The page reacts by changing a preference, which may not happen while the tree is building.
  void _afterFrame(VoidCallback? f) {
    if (f != null) WidgetsBinding.instance.addPostFrameCallback((_) => f());
  }

  void _at(double after, VoidCallback f) => _events.add((_t + after, f));

  void _blink() {
    _blinkStart = _t;
    // Now and then a double blink; otherwise the next one comes at an irregular interval.
    _nextBlink = _t + (_random.nextDouble() < 0.15 ? 0.32 : 2.5 + _random.nextDouble() * 3.5);
  }

  /// The eyes to a point: 0, 0 is the user; x -1 is the bubble. Looking at the bubble turns the head a touch with
  /// the eyes; looking back at the user brings it back to its settled tilt.
  void _look(double x, double y) {
    _gazeX.target = x;
    _gazeY.target = y;
    if (widget.attentive) return;
    _tilt.target = x <= -0.8 ? -0.7 : RigPose.settled.tilt;
  }

  /// One natural moment: a blink, the eyes drifting a little and coming back, or a glance at the bubble with the
  /// head. Never the same rhythm twice.
  void _liveliness() {
    final r = _random.nextDouble();
    if (r < 0.35) {
      _blink();
      _nextBlink = null;
      return;
    }
    if (r < 0.75) {
      _look((_random.nextDouble() - 0.5) * 0.9, (_random.nextDouble() - 0.5) * 0.8);
    } else {
      _look(-1, 0.25);
    }
    // Back to the user after a moment, sometimes with a blink on the way.
    _at(0.6 + _random.nextDouble() * 0.9, () {
      _look(0, 0);
      if (_random.nextDouble() < 0.3) _blink();
    });
  }

  /// At rest nothing ticks; a timer wakes it for a moment of life: every 2.5 to 6 s at first, then every 5 to 11 s.
  void _scheduleRest() {
    _wake?.cancel();
    if (!_active) return;
    final ms = _restWakes < 12 ? 2500 + _random.nextInt(3500) : 5000 + _random.nextInt(6000);
    _wake = Timer(Duration(milliseconds: ms), () {
      if (!mounted || !_active) return;
      _restWakes++;
      _liveliness();
      _run();
    });
  }

  // ------------------------------------------------------------------ the frame loop

  void _run() {
    if (!_active) return;
    _wake?.cancel();
    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    // Clamped, so a frame after a pause or a jank spike never makes a jump.
    final dt = _lastElapsed == null ? 1 / 60 : ((elapsed - _lastElapsed!).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _lastElapsed = elapsed;
    _t += dt;
    for (final e in [..._events]) {
      if (e.$1 <= _t) {
        _events.remove(e);
        e.$2();
      }
    }
    if (_breath.target > 0 && _nextBlink != null && _t >= _nextBlink!) _blink();
    // While it moves anyway (the greeting's settling), the eyes move by themselves too.
    if (_breath.target > 0 && _nextLook != null && _t >= _nextLook!) {
      _liveliness();
      _nextLook = _t + 1.4 + _random.nextDouble() * 2.2;
    }
    for (var i = 0; i < 2; i++) {
      for (final s in _springs) {
        s.step(dt / 2);
      }
    }
    _publish();
    final blinking = _blinkStart != null && _t - _blinkStart! < 0.26;
    if (!blinking) _blinkStart = null;
    if (_events.isEmpty && !blinking && _breath.target == 0 && _springs.every((s) => s.resting)) {
      for (final s in _springs) {
        s.snap();
      }
      _publish();
      _ticker.stop();
      _scheduleRest();
    }
  }

  /// A blink: closes in 70 ms, holds 30 ms, opens in 140 ms.
  double get _closure {
    final b = _blinkStart;
    if (b == null) return 0;
    final u = _t - b;
    if (u < 0.07) return Curves.easeIn.transform(u / 0.07);
    if (u < 0.10) return 1;
    if (u < 0.24) return 1 - Curves.easeOut.transform((u - 0.10) / 0.14);
    return 0;
  }

  void _set(RigPose p) {
    _slide.target = p.slide;
    _lean.target = p.lean;
    _tilt.target = p.tilt;
    _nod.target = p.nod;
    _brow.target = p.brow;
    _smile.target = p.smile;
    _breath.target = 0;
    _reveal.target = p.slide;
    _gazeX.target = p.gazeX;
    _gazeY.target = p.gazeY;
  }

  void _still() {
    _events.clear();
    _blinkStart = null;
    _ticker.stop();
    _wake?.cancel();
    _set(RigPose.settled);
    for (final s in _springs) {
      s.snap();
    }
    _publish();
    if (_started && widget.attentive) _attend(true); // still attentive, just without travel
  }

  void _publish() {
    pose.value = RigPose(
      slide: _slide.x, lean: _lean.x, tilt: _tilt.x, nod: _nod.x, brow: _brow.x, smile: _smile.x, blink: _closure,
      breath: _breath.x * math.sin(_t * 2 * math.pi / 4.2), gazeX: _gazeX.x, gazeY: _gazeY.x,
    );
    final revealed = widget.revealed, v = _reveal.x.clamp(0.0, 1.0);
    if (revealed == null || revealed.value == v) return;
    // Its listeners rebuild; not while the tree is building (the first pose is published from didChangeDependencies).
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) revealed.value = _reveal.x.clamp(0.0, 1.0);
      });
    } else {
      revealed.value = v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final portrait = AnimatedSwitcher(
      // A new guide crossfades in the same pose; nothing restarts.
      duration: context.motion(Motion.quick),
      child: RigPortrait(key: ValueKey(widget.guide), guide: widget.guide, pose: pose, size: widget.size, frame: widget.frame),
    );
    return portrait;
  }
}
