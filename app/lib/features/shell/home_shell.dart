import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../me/me_screen.dart';
import '../me/sync_review_screen.dart';
import '../nutrition/eat_screen.dart';
import '../today/today_screen.dart';
import '../plans/train_screen.dart';
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
      // IndexedStack keeps each destination's state, scroll position and unfinished input while you are elsewhere.
      body: SafeArea(bottom: false, child: IndexedStack(index: shell.tab, children: const [TodayScreen(), TrainScreen(), EatScreen(), MeScreen()])),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        // Attention appears only when saved data cannot converge without a decision. Ordinary pending upload stays quiet.
        if (issues.isNotEmpty)
          Material(
            color: context.c.sunken,
            child: InkWell(
              onTap: () => push(context, const SyncReviewScreen()),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.inset, vertical: 12),
                child: StatusLine(Icons.rule, '${issues.length} saved ${issues.length == 1 ? 'change needs' : 'changes need'} your review. Nothing was lost. Tap to review.', tone: Tone.warning),
              ),
            ),
          ),
        GoNavigationBar(currentIndex: shell.tab, onTap: (i) => ref.read(shellProvider.notifier).switchTab(i)),
      ]),
    );
  }
}

class GoNavigationBar extends StatelessWidget {
  const GoNavigationBar({super.key, required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  // (label, unselected, selected): the selected destination is filled, heavier and in the accent.
  static const _items = [
    ('Today', Icons.home_outlined, Icons.home_rounded),
    ('Train', Icons.fitness_center_outlined, Icons.fitness_center),
    ('Eat', Icons.restaurant_outlined, Icons.restaurant),
    ('Me', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: context.c.surface, border: Border(top: BorderSide(color: context.c.divider))),
        child: SafeArea(
          top: false,
          child: Row(children: [
            for (final (i, item) in _items.indexed)
              Expanded(
                child: Semantics(
                  selected: i == currentIndex, button: true, label: item.$1,
                  child: InkWell(
                    key: Key('nav-${item.$1.toLowerCase()}'),
                    onTap: () => onTap(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: Targets.navigation),
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                            Icon(i == currentIndex ? item.$3 : item.$2, size: 25, color: i == currentIndex ? context.c.accent : context.c.secondary),
                            const SizedBox(height: 3),
                            Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: context.sansStyle(12.5, color: i == currentIndex ? context.c.accent : context.c.secondary, weight: i == currentIndex ? FontWeight.w700 : FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}
