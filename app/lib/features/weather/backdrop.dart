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
/// rebuild. Excluded from semantics.
class TodayBackdrop extends ConsumerWidget {
  const TodayBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Refresher(child: SceneBackdrop(spec: ref.watch(todaySceneProvider)));
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
class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({super.key, required this.spec});
  final SceneSpec spec;

  /// A light veil of page colour over the top of the scene, so the scene stays visible above and around the header.
  /// It rises to the full page at the bottom. The header text is protected by TabHeader's own scrim behind its lines,
  /// not by this veil: test/weather_contrast_test.dart measures the two together where the text sits.
  static double scrim(SceneSpec spec, bool dark) {
    final bright = spec.isDay == true || spec.family == 'snow' || spec.family == 'fog';
    final dim = spec.isDay == false || spec.family == 'storm' || spec.family == 'rain';
    // Dark mode dims bright scenes a little more, Light mode lifts dark ones; the scene stays what it is. The painted
    // weather skies carry their own light, so Light mode lifts them less than the photograph's dusk (0.34), or night
    // and storm would turn grey.
    if (spec.key == 'dusk') return dark ? 0.18 : 0.34;
    return dark ? (bright ? 0.32 : 0.18) : (dim ? 0.22 : 0.16);
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
                      RepaintBoundary(child: _Photo(art: art, cacheWidth: cacheWidth)),
                      // Page-tinted, so the theme's own text colours stay readable over any scene, and an undecodable
                      // photograph leaves exactly the page colour. Dark mode dims a bright (daylight, snow, fog) scene
                      // further and Light mode a dark one; the scene itself stays what it is.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.55, 1], colors: [
                            page.withValues(alpha: scrim(spec, dark)),
                            page.withValues(alpha: scrim(spec, dark) + 0.15),
                            page,
                          ]),
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
  const _Photo({required this.art, required this.cacheWidth});
  final SceneArt art;
  final int cacheWidth;

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
          if (sky == null) return graded;
          return CustomPaint(
            painter: SkyPainter(sky, SkyLayer.back),
            foregroundPainter: SkyPainter(sky, SkyLayer.front),
            child: Stack(fit: StackFit.expand, children: [graded, CustomPaint(painter: SkyPainter(sky, SkyLayer.top))]),
          );
        },
        errorBuilder: (context, _, _) => const SizedBox.expand(key: ValueKey('scene-failed')),
      );
}
