import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/appearance.dart';
import '../../core/device_prefs.dart';
import '../../core/theme.dart';
import '../me/me_screen.dart';
import '../me/sync_review_screen.dart';
import '../nutrition/eat_screen.dart';
import '../today/today_screen.dart';
import '../plans/train_screen.dart';
import '../weather/weather.dart' show todaySceneProvider;
import '../../core/widgets.dart';

enum TrainView { workouts, plan, progress }

class ShellState {
  const ShellState({this.tab = 0, this.trainView = TrainView.workouts});
  final int tab;
  final TrainView trainView;
}

/// Current destination and the retained Train section. Visiting another tab never resets the Train view.
class ShellController extends Notifier<ShellState> {
  @override
  ShellState build() {
    ref.watch(ownerProvider); // a different signed-in owner always starts on Today, with no navigation state carried over
    return const ShellState();
  }
  void switchTab(int tab, {TrainView? trainView}) => state = ShellState(tab: tab, trainView: trainView ?? state.trainView);
  void selectTrainView(TrainView view) => state = ShellState(tab: state.tab, trainView: view);
}

final shellProvider = NotifierProvider<ShellController, ShellState>(ShellController.new);

/// The four permanent destinations: Today / Train / Eat / Me.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(shellProvider);
    final issues = ref.watch(issuesProvider).value ?? const [];
    return Scaffold(
      // The tabs run under the floating bar too (Today's scene shows around it); each list ends with
      // `MediaQuery.paddingOf(context).bottom`, the bar's height, so its last control is never covered.
      extendBody: true,
      // Every destination stays built, so its state, scroll position and unfinished input wait while you are elsewhere.
      // The tabs reach the top edge: Today lays its scene behind the status bar and every tab insets its own text by
      // `MediaQuery.paddingOf(context).top`. The veil keeps the status bar legible over the scene and over anything
      // scrolled under it. Only Today has a scene; Train and Eat sit on a calm wash, Me on the plain page.
      body: Stack(children: [
        _FadeStack(index: shell.tab, children: const [TodayScreen(), QuietBackground(child: TrainScreen()), QuietBackground(child: EatScreen()), MeScreen()]),
        Positioned(top: 0, left: 0, right: 0, child: _SkyAwareVeil(onToday: shell.tab == 0)),
      ]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        // Attention appears only when saved data cannot converge without a decision. Ordinary pending upload stays quiet.
        if (issues.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(GoNavigationBar.margin, 8, GoNavigationBar.margin, 0),
            child: Material(
              color: context.c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile), side: BorderSide(color: context.c.divider)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => push(context, const SyncReviewScreen()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: StatusLine(Icons.rule, '${issues.length} saved ${issues.length == 1 ? 'change needs' : 'changes need'} your review. Nothing was lost. Tap to review.', tone: Tone.warning),
                ),
              ),
            ),
          ),
        GoNavigationBar(currentIndex: shell.tab, onTap: (i) {
          if (i != shell.tab) Haptics.selection();
          ref.read(shellProvider.notifier).switchTab(i);
        }),
      ]),
    );
  }
}

/// The page colour at [GoColors.scrim] strength behind the status bar: solid over the band where the system icons
/// sit, fading out at the bottom of the inset. The theme's overlay style draws light icons in Dark and dark icons in
/// Light, and the scrim holds them above 3:1 over any pixel of a scene. Zero height where there is no top inset.
/// While Today shows a weather sky the status bar follows that sky, like the header under it: the Dark look's veil
/// and light icons over a night, rain or storm sky, the Light look's over a daylight one, whatever the app's mode.
/// Everywhere else, and for Scenic and Plain, it follows the app.
class _SkyAwareVeil extends ConsumerWidget {
  const _SkyAwareVeil({required this.onToday});
  final bool onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = onToday ? ref.watch(todaySceneProvider) : null;
    if (scene == null || !scene.isWeather) return const StatusBarVeil();
    final look = goTheme(ref.watch(appearanceProvider).accent, scene.dark ? Brightness.dark : Brightness.light, highContrast: MediaQuery.highContrastOf(context));
    return AnnotatedRegion<SystemUiOverlayStyle>(value: look.appBarTheme.systemOverlayStyle!, child: Theme(data: look, child: const StatusBarVeil()));
  }
}

class StatusBarVeil extends StatelessWidget {
  const StatusBarVeil({super.key});

  /// The part of the inset that stays solid; the system icons sit inside it.
  static const solid = 0.8;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top <= 0) return const SizedBox.shrink();
    final scrim = context.c.scrim;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: top,
          child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [scrim, scrim, scrim.withValues(alpha: 0)], stops: const [0, solid, 1])),
          ),
        ),
      ),
    );
  }
}

/// An [IndexedStack] whose newly shown child fades in over [Motion.quick] (at once under Reduce Motion). Every
/// child keeps the same place in the tree whether it is shown or not, so nothing is rebuilt, reset or scrolled.
class _FadeStack extends StatefulWidget {
  const _FadeStack({required this.index, required this.children});
  final int index;
  final List<Widget> children;
  @override
  State<_FadeStack> createState() => _FadeStackState();
}

class _FadeStackState extends State<_FadeStack> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, value: 1);
  late final _eased = CurvedAnimation(parent: _fade, curve: Motion.curve);

  @override
  void didUpdateWidget(_FadeStack old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _fade.duration = context.motion(Motion.quick);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _eased.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IndexedStack(index: widget.index, children: [
        for (final (i, child) in widget.children.indexed) FadeTransition(opacity: i == widget.index ? _eased : kAlwaysCompleteAnimation, child: child),
      ]);
}

/// The four destinations on a rounded bar that floats inset above the bottom edge (and above the home indicator).
/// The chosen one is in the accent, with a filled icon and a heavier label, and is announced as selected; the others
/// are outlined. Each item is at least 58 px high and keyed `nav-today|train|eat|me`. Shown only on the four main
/// tabs; secondary pages have back navigation instead.
class GoNavigationBar extends StatelessWidget {
  const GoNavigationBar({super.key, required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Space between the bar and the screen's side edges.
  static const margin = 12.0;

  // (label, unselected, selected): the selected destination is filled, heavier and in the accent.
  static const _items = [
    ('Today', Icons.home_outlined, Icons.home_rounded),
    ('Train', Icons.fitness_center_outlined, Icons.fitness_center),
    ('Eat', Icons.restaurant_outlined, Icons.restaurant),
    ('Me', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final radius = BorderRadius.circular(26);
    return Padding(
      // Above the home indicator where there is one; a small lift off the edge where there is not.
      padding: EdgeInsets.fromLTRB(margin, 8, margin, bottom > 0 ? bottom : 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.raised, borderRadius: radius, border: Border.all(color: c.divider),
          // One soft, low shadow so the bar reads as floating; no glow.
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Row(children: [
            for (final (i, item) in _items.indexed)
              Expanded(
                child: Semantics(
                  selected: i == currentIndex, button: true, label: item.$1,
                  child: InkWell(
                    key: Key('nav-${item.$1.toLowerCase()}'),
                    onTap: () => onTap(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: Targets.navigation + 6),
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                            Icon(i == currentIndex ? item.$3 : item.$2, size: 25, color: i == currentIndex ? c.accent : c.secondary),
                            const SizedBox(height: 4),
                            Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: context.sansStyle(12.5, color: i == currentIndex ? c.accent : c.secondary, weight: i == currentIndex ? FontWeight.w700 : FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
