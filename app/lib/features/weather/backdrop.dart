import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../shell/home_shell.dart' show shellProvider;
import 'scene_art.dart';
import 'sky_painter.dart';
import 'weather_model.dart';
import 'weather_service.dart';

/// Fills its parent (a bounded header region). Paints the scene for the Today background preference and fresh
/// weather, fading at the bottom into the page colour. Asks for a refresh-if-stale when it first appears, when the
/// app resumes and when the Today tab is selected again; never blocks, never shows an error, never repeats on a
/// rebuild. Excluded from semantics. Its weather sky moves only while Today is the tab on screen.
class TodayBackdrop extends ConsumerWidget {
  const TodayBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Refresher(
      child: SceneBackdrop(spec: ref.watch(todaySceneProvider), animate: ref.watch(shellProvider.select((s) => s.tab == 0))));
}

/// The same frame and fade, static: the decorative dusk scene, or the plain page colour when the preference is
/// Plain. For the Train and Eat headers. Never weather-driven, never requests anything.
class ScenicBackdrop extends ConsumerWidget {
  const ScenicBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SceneBackdrop(
      spec: ref.watch(weatherPrefsProvider.select((p) => p.background)) == TodayBackground.plain ? SceneSpec.plain : SceneSpec.dusk);
}

class _Refresher extends ConsumerStatefulWidget {
  const _Refresher({required this.child});
  final Widget child;
  @override
  ConsumerState<_Refresher> createState() => _RefresherState();
}

class _RefresherState extends ConsumerState<_Refresher> with WidgetsBindingObserver {
  void _refresh() {
    if (mounted) ref.read(weatherProvider.notifier).refresh().ignore();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellProvider.select((s) => s.tab), (before, now) {
      if (now == 0 && before != 0) _refresh();
    });
    return widget.child;
  }
}

/// Paints one [SceneSpec]: the (graded) photograph decoded at the size it is shown, a stable scrim the header text
/// sits on, and a fade into the page colour at the bottom. Crossfades only when [SceneSpec.key] changes, and
/// switches instantly under reduced motion. A photograph that cannot be decoded leaves the plain page colour.
///
/// A weather scene's clouds, stars, fog, rain and snow move gently (one clock for the whole sky, repainting only its
/// own layer) while [animate] is true, motion is not reduced (the phone's setting or the app's), tickers are enabled
/// here, the app is in the foreground and no route covers this one; otherwise it is one still frame and no clock
/// runs. Dusk and Plain are always still.
class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({super.key, required this.spec, this.animate = true});
  final SceneSpec spec;
  final bool animate;

  /// The veil over the top of the scene, as (colour, opacity); it rises to the full page colour at the bottom. The
  /// header text is protected by TabHeader's own scrim behind its lines, not by this veil.
  ///
  /// Dusk keeps a light veil of page colour. A weather sky carries its own light, like Apple Weather's: no page veil,
  /// so a night stays night in Light mode and a bright day stays bright (the header draws light text over a
  /// [SceneSpec.dark] scene and dark text over the others). Dark mode only takes the edge off a bright sky with a
  /// faint black veil, keeping it light enough for dark text.
  static (Color, double) veil(SceneSpec spec, bool darkMode, Color page) {
    if (!spec.isWeather) return (page, darkMode ? 0.18 : 0.34);
    return (Colors.black, darkMode && !spec.dark ? 0.08 : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final page = context.c.page;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final art = sceneArt[spec.key] ?? sceneArt['dusk']!;
    return ExcludeSemantics(
      child: LayoutBuilder(builder: (context, box) {
        final size = MediaQuery.sizeOf(context);
        final w = box.maxWidth.isFinite ? box.maxWidth : size.width, h = box.maxHeight.isFinite ? box.maxHeight : size.height;
        // BoxFit.cover needs whichever is larger: the width, or the height at the photograph's aspect ratio.
        final cacheWidth = math.min(1536, (math.max(w, h * photoAspect) * MediaQuery.devicePixelRatioOf(context)).ceil()).clamp(1, 1536);
        return Stack(fit: StackFit.expand, children: [
          ColoredBox(color: page),
          AnimatedSwitcher(
            duration: context.motion(Motion.progress),
            switchInCurve: Motion.curve,
            switchOutCurve: Motion.exit,
            layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: KeyedSubtree(
              key: ValueKey(spec.key),
              child: art.asset == null
                  ? const SizedBox.expand()
                  : Stack(fit: StackFit.expand, children: [
                      // Painted once: the scene is static, and repaints only when its key changes.
                      _Photo(art: art, cacheWidth: cacheWidth, animate: animate),
                      // The veil (see [veil]) and the fade into the page colour, so an undecodable photograph leaves
                      // exactly the page colour and the scene ends softly above the modules below. A weather sky keeps
                      // its own colour down to where the fade begins.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: switch (veil(spec, dark, page)) {
                            (final color, final a) when spec.isWeather => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                stops: const [0, 0.74, 0.9, 1], colors: [color.withValues(alpha: a), color.withValues(alpha: a), Color.lerp(color.withValues(alpha: a), page, 0.5)!, page]),
                            (final color, final a) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.55, 1],
                                colors: [color.withValues(alpha: a), color.withValues(alpha: a + 0.15), page]),
                          },
                        ),
                      ),
                    ]),
            ),
          ),
        ]);
      }),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.art, required this.cacheWidth, required this.animate});
  final SceneArt art;
  final int cacheWidth;
  final bool animate;

  @override
  Widget build(BuildContext context) => Image.asset(
        art.asset!,
        key: const ValueKey('scene-photo'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        // The grade and the painted sky belong to the photograph: without it (still decoding, or failed) there is only
        // the page. With a sky, the graded photograph's bright parts (its dusk sky and the lake's reflection of it) are
        // see-through, so the painted sky shows behind the hills and trees, which keep their silhouette.
        frameBuilder: (context, child, frame, sync) {
          if (frame == null && !sync) return const SizedBox.expand();
          final graded = art.matrix == null ? child : ColorFiltered(colorFilter: ColorFilter.matrix(art.matrix!), child: child);
          final sky = art.sky;
          // The photograph and the still layers are painted once, in their own boundary; only the motion layer above
          // them repaints on each frame.
          if (sky == null) return RepaintBoundary(child: graded);
          return Stack(fit: StackFit.expand, children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: SkyPainter(sky, SkyLayer.back),
                foregroundPainter: SkyPainter(sky, SkyLayer.front),
                child: Stack(fit: StackFit.expand, children: [graded, CustomPaint(painter: SkyPainter(sky, SkyLayer.top))]),
              ),
            ),
            SkyMotion(sky: sky, animate: animate),
          ]);
        },
        errorBuilder: (context, _, _) => const SizedBox.expand(key: ValueKey('scene-failed')),
      );
}

/// The moving layer of a weather sky: one [AnimationController] repeating over [SkyMotionPainter.period] drives
/// [SkyMotionPainter] through `repaint:`, inside its own [RepaintBoundary], so a frame never rebuilds a widget. The
/// clock runs only while everything allows it (see [SceneBackdrop]); otherwise it is stopped where it is, one still
/// frame. Nothing to move (a clear day) never starts it.
class SkyMotion extends StatefulWidget {
  const SkyMotion({super.key, required this.sky, this.animate = true});
  final Sky sky;
  final bool animate;

  @override
  State<SkyMotion> createState() => _SkyMotionState();
}

class _SkyMotionState extends State<SkyMotion> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _clock = AnimationController(vsync: this, duration: SkyMotionPainter.period);
  late var _painter = SkyMotionPainter(widget.sky, _clock);
  var _foreground = true, _allowed = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allowed = !context.reduceMotion && TickerMode.valuesOf(context).enabled && (ModalRoute.isCurrentOf(context) ?? true);
    _sync();
  }

  @override
  void didUpdateWidget(SkyMotion old) {
    super.didUpdateWidget(old);
    if (old.sky != widget.sky) _painter = SkyMotionPainter(widget.sky, _clock);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final run = widget.animate && _allowed && _foreground && _painter.moves;
    if (run && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!run && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(key: const ValueKey('sky-motion'), painter: _painter, size: Size.infinite));
}
