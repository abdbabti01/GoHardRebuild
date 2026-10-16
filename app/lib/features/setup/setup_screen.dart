import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../coach/coach_avatar.dart';
import '../coach/coach_bubble.dart';
import '../coach/coach_companion.dart';
import '../coach/coach_prefs.dart';
import '../coach/coach_rig.dart' show RigFrame;
import '../me/me_screen.dart' show CoachChoice, setReminders;
import '../weather/weather.dart';

/// The short setup after creating an account on this phone (docs/COACH.md › Setup): choose the coach, then the
/// optional features. Its step is kept per account in the coach preferences, so a restart resumes where it was and
/// finishing or skipping ends it for good; accounts that only sign in never see it. Nothing here asks the phone for
/// access: each feature asks when the person turns it on or uses it. It ends on Today.
class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key, required this.owner, required this.step});
  final String owner, step;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      step == 'features' ? _Features(owner: owner) : _ChooseCoach(owner: owner);
}

class _ChooseCoach extends ConsumerStatefulWidget {
  const _ChooseCoach({required this.owner});
  final String owner;
  @override
  ConsumerState<_ChooseCoach> createState() => _ChooseCoachState();
}

class _ChooseCoachState extends ConsumerState<_ChooseCoach> {
  /// Chosen during this visit: the chosen guide then says hello in its bubble.
  bool _picked = false;

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));
    final prefs = ref.read(coachPrefsProvider.notifier);
    final first = (ref.watch(profileProvider).value?.displayName ?? '').trim().split(' ').first;
    final across = MediaQuery.textScalerOf(context).scale(10) <= 15;
    // The previews are the companion itself, so they blink and look about as on Today (still under Reduce Motion).
    Widget card(CoachGuide g) => CoachChoice(g, key: Key('setup-coach-${g.name}'), selected: g == guide, across: across,
        face: CoachCompanion(guide: g, size: across ? const Size(84, 96) : const Size(56, 64), frame: RigFrame.inline),
        onTap: () {
          prefs.setGuide(g);
          setState(() => _picked = true);
        });
    return AppPage(
      title: 'Choose your coach',
      subtitle: 'Leon or Leona: the same help either way, only the look changes. You can change this later in Appearance.',
      actions: const [_Step(1)],
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton('Continue', key: const Key('setup-continue'), onPressed: () => prefs.setupFeatures(widget.owner)),
        TextButton(key: const Key('setup-skip'), onPressed: () => prefs.finishSetup(widget.owner), child: const Text('Not now')),
      ]),
      children: [
        if (across)
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: card(CoachGuide.leon)), const SizedBox(width: 10), Expanded(child: card(CoachGuide.leona)),
          ]))
        else
          ...[card(CoachGuide.leon), const SizedBox(height: 10), card(CoachGuide.leona)],
        const SizedBox(height: 20),
        if (_picked)
          CoachSpeaker(
            key: ValueKey('setup-hello-${guide.name}'), introduce: true,
            say: CoachSay("I'm ${guide.label}. Tap me on any screen when you'd like a hand.", title: first.isEmpty ? 'Hi!' : 'Hi $first!'),
          ),
      ],
    );
  }
}

class _Features extends ConsumerWidget {
  const _Features({required this.owner});
  final String owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final done = ref.read(coachPrefsProvider.notifier);
    return AppPage(
      title: 'Optional features',
      subtitle: 'Turn on what you want now, or later in Me. The phone asks for access only when you use a feature that needs it.',
      actions: const [_Step(2)],
      bottom: PrimaryButton('Done', key: const Key('setup-done'), onPressed: () => done.finishSetup(owner)),
      children: [
        GroupCard(children: [
          GroupRow(
            key: const Key('setup-weather'), icon: Icons.wb_twilight_outlined, title: 'Weather on Today',
            subtitle: 'Use your approximate location, or choose a city without sharing it.', value: ref.watch(todayBackgroundSummaryProvider),
            onTap: () => push(context, const TodayBackgroundScreen()),
          ),
          if (profile != null)
            MergeSemantics(
              child: GroupRow(
                key: const Key('setup-reminders'), icon: Icons.notifications_none, title: 'Workout reminders',
                subtitle: 'On days with a planned workout. Notifications are asked for when you turn this on.',
                trailing: Switch(value: profile.remindersEnabled, onChanged: (on) => setReminders(context, ref, profile, on)),
              ),
            ),
          const GroupRow(icon: Icons.qr_code_scanner, title: 'Barcode scanning', subtitle: 'Ready in Eat. The camera is asked for the first time you scan.'),
          const GroupRow(icon: Icons.directions_run, title: 'GPS runs', subtitle: 'Ready on Today. Location is asked for when you start a run.'),
        ]),
        const SizedBox(height: 12),
        Text('Anything you allow or refuse can be changed later in the phone\'s Settings; Me › Phone permissions shows what is allowed now.', style: context.caption),
      ],
    );
  }
}

/// "Step 1 of 2" at the top trailing edge of each setup page.
class _Step extends StatelessWidget {
  const _Step(this.n);
  final int n;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(end: context.inset),
        child: Center(child: Text('Step $n of 2', style: context.sansStyle(15, color: context.c.secondary, weight: FontWeight.w500))),
      );
}
