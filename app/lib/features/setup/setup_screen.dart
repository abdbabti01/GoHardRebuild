import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/language.dart';
import '../../core/language_picker.dart';
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
/// optional features. A new account reaches it only once its email is verified (docs/AUTHENTICATION_EMAIL.md). Its step is kept per account in the coach preferences, so a restart resumes where it was and
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
    final l = context.l10n;
    return AppPage(
      title: l.setupCoachTitle,
      subtitle: l.setupCoachSubtitle,
      actions: const [_Step(1)],
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(l.actionContinue, key: const Key('setup-continue'), onPressed: () => prefs.setupFeatures(widget.owner)),
        TextButton(key: const Key('setup-skip'), onPressed: () => prefs.finishSetup(widget.owner), child: Text(l.setupNotNow)),
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
            say: CoachSay(l.setupCoachHello(guide.displayName(l)), title: first.isEmpty ? l.setupHi : l.setupHiName(first)),
          ),
        const SizedBox(height: 8),
        // The language, without a step of its own: nothing is asked for or sent.
        const Align(alignment: AlignmentDirectional.centerStart, child: LanguageButton()),
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
    final l = context.l10n;
    return AppPage(
      title: l.setupFeaturesTitle,
      subtitle: l.setupFeaturesSubtitle,
      actions: const [_Step(2)],
      bottom: PrimaryButton(l.actionDone, key: const Key('setup-done'), onPressed: () => done.finishSetup(owner)),
      children: [
        GroupCard(children: [
          GroupRow(
            key: const Key('setup-weather'), icon: Icons.wb_twilight_outlined, title: l.setupWeatherTitle,
            subtitle: l.setupWeatherSubtitle, value: ref.watch(todayBackgroundSummaryProvider),
            onTap: () => push(context, const TodayBackgroundScreen()),
          ),
          if (profile != null)
            MergeSemantics(
              child: GroupRow(
                key: const Key('setup-reminders'), icon: Icons.notifications_none, title: l.setupRemindersTitle,
                subtitle: l.setupRemindersSubtitle,
                trailing: Switch(value: profile.remindersEnabled, onChanged: (on) => setReminders(context, ref, profile, on)),
              ),
            ),
          GroupRow(icon: Icons.qr_code_scanner, title: l.setupBarcodeTitle, subtitle: l.setupBarcodeSubtitle),
          GroupRow(icon: Icons.directions_run, title: l.setupGpsTitle, subtitle: l.setupGpsSubtitle),
        ]),
        const SizedBox(height: 12),
        Text(l.setupPermissionsFootnote, style: context.caption),
        const SizedBox(height: 8),
        const Align(alignment: AlignmentDirectional.centerStart, child: LanguageButton()),
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
        child: Center(child: Text(context.l10n.setupStep(n, 2), style: context.sansStyle(15, color: context.c.secondary, weight: FontWeight.w500))),
      );
}
