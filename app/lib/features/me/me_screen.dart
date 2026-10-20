import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/go_icon.dart';
import '../../core/appearance.dart';
import '../../core/compatibility.dart';
import '../../core/config.dart';
import '../../core/device_prefs.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../activity/move_prefs.dart' show stepsEnabledProvider;
import '../activity/steps_ui.dart' show showStepsSheet;
import '../body/body_prefs.dart';
import '../body/body_metrics.dart';
import '../body/body_screens.dart';
import '../coach/coach_avatar.dart';
import '../coach/coach_bubble.dart';
import '../coach/coach_prefs.dart';
// Stand-in for the weather module until it is merged; the lead swaps this for '../weather/weather.dart'.
import '../nutrition/nutrition_tools.dart';
import '../nutrition/water.dart';
import '../weather/weather.dart';
import 'account_repository.dart';
import 'permissions_screen.dart';
import 'reminders.dart';
import 'sync_review_screen.dart';

/// Workout reminders on or off (Me, setup). Notification permission is asked for only here, when they are turned on.
Future<void> setReminders(BuildContext context, WidgetRef ref, Profile profile, bool on) async {
  if (on && !await ref.read(reminderSchedulerProvider).requestPermission()) {
    if (context.mounted) toast(context, 'Notifications are not allowed for GoHard, so reminders stay off. You can allow them in the phone\'s settings.');
    return;
  }
  try {
    await ref.read(profileRepositoryProvider).update(profile, remindersEnabled: on, reminderLocalTime: profile.reminderLocalTime ?? '18:00');
    Haptics.selection();
  } on LocalSaveFailure {
    if (context.mounted) toast(context, 'That preference could not be saved on this phone.');
  }
}

/// Me: who is signed in, personal information, preferences for this phone and the account. Training, history and
/// progress live in Train; nothing here repeats them.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final session = ref.watch(sessionProvider);
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final issues = ref.watch(issuesProvider).value?.length ?? 0;
    final unreachable = ref.watch(connectionProvider) == false;
    final appearance = ref.watch(appearanceProvider);
    final prefs = ref.watch(devicePrefsProvider);
    final name = profile?.displayName ?? session?.email ?? '';

    Future<void> setUnit(String loadUnit) async {
      if (profile == null || loadUnit == profile.loadUnit) return;
      try {
        await ref.read(profileRepositoryProvider).update(profile, loadUnit: loadUnit);
      } on LocalSaveFailure {
        if (context.mounted) toast(context, 'That preference could not be saved on this phone.');
      }
    }

    void chooseUnit() => showGoSheet<void>(context, title: 'Units', builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final unit in const ['kg', 'lb'])
            ChoiceTile<String>(
              key: Key('unit-$unit'), value: unit, groupValue: profile?.loadUnit ?? 'kg', title: unit == 'kg' ? 'Kilograms' : 'Pounds',
              onChanged: (chosen) {
                Navigator.pop(sheet);
                setUnit(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text('Changes how loads are entered and shown. Your recorded training is stored in kilograms and is never rewritten. Time is shown in minutes and seconds.', style: context.caption),
          const SizedBox(height: 16),
          Text('Body progress', style: context.label),
          for (final mass in LoadUnit.values)
            ChoiceTile<LoadUnit>(
              key: Key('unit-body-${mass.name}'), value: mass, groupValue: ref.read(bodyUnitsProvider).mass, title: mass == LoadUnit.kg ? 'Body weight in kilograms' : 'Body weight in pounds',
              onChanged: (chosen) {
                Navigator.pop(sheet);
                setBodyUnits(ref, BodyUnits(chosen, ref.read(bodyUnitsProvider).length));
              },
            ),
          for (final length in LengthUnit.values)
            ChoiceTile<LengthUnit>(
              key: Key('unit-body-${length.name}'), value: length, groupValue: ref.read(bodyUnitsProvider).length, title: length == LengthUnit.cm ? 'Measurements in centimetres (cm)' : 'Measurements in inches (in)',
              onChanged: (chosen) {
                Navigator.pop(sheet);
                setBodyUnits(ref, BodyUnits(ref.read(bodyUnitsProvider).mass, chosen));
              },
            ),
          const SizedBox(height: 4),
          Text('For Body progress only: your lifting unit stays as it is. Stored in kilograms and centimetres, so changing this never changes a measurement. Set on this phone for this account.', style: context.caption),
          const SizedBox(height: 16),
          Text('Temperature', style: context.label),
          for (final f in const [false, true])
            ChoiceTile<bool>(
              key: Key('unit-${f ? 'fahrenheit' : 'celsius'}'), value: f, groupValue: ref.read(weatherPrefsProvider).fahrenheit, title: f ? 'Fahrenheit (°F)' : 'Celsius (°C)',
              onChanged: (chosen) {
                Navigator.pop(sheet);
                ref.read(weatherPrefsProvider.notifier).setFahrenheit(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text('For the weather on Today. Set on this phone.', style: context.caption),
          const SizedBox(height: 16),
          Text('Water', style: context.label),
          for (final u in VolumeUnit.values)
            ChoiceTile<VolumeUnit>(
              key: Key('unit-water-${u.name}'), value: u, groupValue: ref.read(volumeUnitProvider), title: u == VolumeUnit.ml ? 'Millilitres (mL, L)' : 'US fluid ounces (fl oz)',
              onChanged: (chosen) {
                Navigator.pop(sheet);
                ref.read(trackingPrefsProvider.notifier).setUnit(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text('For water you log. Stored in millilitres, so changing this never changes an amount. Fluid ounces are a volume, not a weight. Set on this phone.', style: context.caption),
          const SizedBox(height: 16),
          Text('Run / Walk', style: context.label),
          for (final u in DistanceUnit.values)
            ChoiceTile<DistanceUnit>(
              key: Key('unit-distance-${u.name}'), value: u, groupValue: ref.read(devicePrefsProvider).distance,
              title: u == DistanceUnit.km ? 'Kilometres (min/km, km/h, m)' : 'Miles (min/mi, mph, ft)',
              onChanged: (chosen) {
                Navigator.pop(sheet);
                ref.read(devicePrefsProvider.notifier).setDistance(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text('Distance, pace, speed and elevation. Routes are stored in metres, so changing this never changes a recording. Set on this phone.', style: context.caption),
        ]));

    // What is true about the account right now, in a word and a sentence. "Saved" is said only when nothing is
    // waiting, nothing needs a decision and the last attempt to reach the account did not fail.
    final (syncIcon, syncTone, syncWord, syncDetail) = issues > 0
        ? (Icons.rule, Tone.warning, 'Needs review', '$issues saved ${issues == 1 ? 'change needs' : 'changes need'} review. Nothing was lost. Tap to review.')
        : unreachable
            // With the account out of reach, "everything is saved" would claim more than is known.
            ? (Icons.cloud_off, Tone.neutral, 'Not synced', '${pending > 0 ? '${waitingToSync(pending)}, saved on this phone.\n' : ''}$cantSyncLabel · tap to try again')
            : pending > 0
                ? (Icons.phone_iphone, Tone.neutral, 'Waiting', '$pending ${pending == 1 ? 'change' : 'changes'} saved on this phone, waiting to sync')
                : (Icons.cloud_done_outlined, Tone.success, 'Saved', 'Everything is saved to your account');

    return ListView(
      // No scene on Me: the plain page, the title where every tab has it, and room for the floating bar at the end.
      padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        const TabHeader(title: 'Me'),
        const SizedBox(height: 22),
        GroupCard(children: [
          Semantics(
            button: profile != null,
            child: InkWell(
              key: const Key('me-edit-name'),
              onTap: profile == null ? null : () => push(context, EditNameScreen(profile: profile)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(children: [
                  // An initial, not a photograph: the account has no picture, so none is invented. The pale panel tint
                  // with its dark ink, as on Today's panels.
                  ExcludeSemantics(
                    child: Container(
                      width: 56, height: 56, alignment: Alignment.center,
                      decoration: BoxDecoration(color: context.c.tint, shape: BoxShape.circle),
                      child: Text(name.isEmpty ? '' : name[0].toUpperCase(), textScaler: TextScaler.noScaling,
                          style: context.pageTitleStyle(26, color: GoColors.panelOf(context.c).text)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(name, key: const Key('me-name'), style: context.sansStyle(20, weight: FontWeight.w600)),
                      if (profile != null) Text('Edit profile', style: context.sansStyle(15, color: context.c.secondary)),
                    ]),
                  ),
                  if (profile != null) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right, size: 22, color: context.c.secondary)),
                ]),
              ),
            ),
          ),
        ]),
        if (profile == null) const Padding(padding: EdgeInsets.only(top: 10), child: StatusLine(Icons.hourglass_empty, 'Your profile has not loaded on this phone yet.')),

        const _Group('Personal'),
        GroupCard(children: [
          GroupRow(key: const Key('me-body'), icon: Icons.monitor_weight_outlined, title: 'Body progress', subtitle: 'Weight, measurements and comparisons', onTap: () => push(context, const BodyProgressScreen())),
          // Shown unless the server has said it cannot store goals: a goal that silently vanishes is worse than no row.
          if (profile != null && ref.watch(compatibilityProvider).supports('profile.nutrition-goals'))
            GroupRow(
              key: const Key('me-goals'), icon: Icons.restaurant_outlined, title: 'Nutrition goals',
              // Only a goal the person set is shown; nothing is suggested in its place.
              subtitle: goalsSummary(profile, ref.watch(volumeUnitProvider), water: ref.watch(nutritionDisplayProvider).water) == null ? 'None set' : 'Daily goals you set',
              value: goalsSummary(profile, ref.watch(volumeUnitProvider), water: ref.watch(nutritionDisplayProvider).water),
              onTap: () => push(context, NutritionGoalsScreen(profile: profile)),
            ),
        ]),

        // Steps' one set of controls, the same sheet Today's tile and Run / Walk open (docs/RUN_WALK.md › Steps).
        const _Group('Activity & tracking'),
        GroupCard(children: [
          GroupRow(
            key: const Key('me-steps'), leading: const GoIcon(GoGlyph.steps), title: 'Steps',
            subtitle: ref.watch(stepsEnabledProvider) ? 'Counted with this phone' : 'Off · counted with your phone when on',
            value: ref.watch(stepsEnabledProvider) ? 'On' : 'Off',
            onTap: () => showStepsSheet(context),
          ),
        ]),

        const _Group('Preferences'),
        GroupCard(children: [
          GroupRow(
            key: const Key('me-appearance'), icon: Icons.palette_outlined, title: 'Appearance',
            value: '${appearance.accent.label} · ${modeLabel(appearance.mode)}',
            onTap: () => push(context, const AppearanceScreen()),
          ),
          if (profile != null)
            GroupRow(key: const Key('me-units'), icon: Icons.straighten, title: 'Units', value: '${LoadUnit.parse(profile.loadUnit) == LoadUnit.kg ? 'Kilograms' : 'Pounds'} · ${ref.watch(weatherPrefsProvider.select((p) => p.fahrenheit)) ? '°F' : '°C'}', onTap: chooseUnit),
          GroupRow(key: const Key('me-motion'), icon: Icons.animation, title: 'Motion & haptics', value: motionLabel(prefs), onTap: () => push(context, const MotionHapticsScreen())),
          GroupRow(key: const Key('me-permissions'), icon: Icons.verified_user_outlined, title: 'Phone permissions', subtitle: 'Location, camera and notifications', onTap: () => push(context, const PermissionsScreen())),
          if (profile != null) ...[
            MergeSemantics(
              child: GroupRow(
                key: const Key('me-reminders'),
                icon: profile.remindersEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                title: 'Workout reminders',
                subtitle: profile.remindersEnabled ? 'On days with a planned workout. None while your plan is paused.' : 'Off',
                trailing: Switch(
                  value: profile.remindersEnabled,
                  onChanged: (on) => setReminders(context, ref, profile, on),
                ),
              ),
            ),
            if (profile.remindersEnabled)
              GroupRow(
                key: const Key('me-reminder-time'),
                icon: Icons.schedule,
                title: 'Reminder time',
                subtitle: 'This phone\'s local time',
                value: profile.reminderLocalTime ?? '18:00',
                onTap: () async {
                  final parts = (profile.reminderLocalTime ?? '18:00').split(':');
                  final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                  if (picked == null) return;
                  await ref.read(profileRepositoryProvider).update(profile,
                      reminderLocalTime: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                },
              ),
          ],
        ]),

        const _Group('Account'),
        GroupCard(children: [
          // The same words as Today's notice. Tapping the row opens the review, or asks the account again.
          GroupRow(
            key: const Key('me-sync'), icon: syncIcon, tone: syncTone, title: 'Sync status', subtitle: syncDetail, value: syncWord,
            onTap: issues > 0 ? () => push(context, const SyncReviewScreen()) : () => refreshFromAccount(ref),
          ),
          GroupRow(key: const Key('me-delete-account'), icon: Icons.delete_outline, tone: Tone.neutral, title: 'Delete account', subtitle: 'Permanently erases your account and data', onTap: () => push(context, const DeleteAccountScreen())),
        ]),
        const SizedBox(height: 12),
        GroupCard(children: [
          GroupRow(
            key: const Key('me-sign-out'), icon: Icons.logout, tone: Tone.neutral, title: 'Sign out', subtitle: session?.email,
            onTap: () async {
              if (!await confirm(context,
                  title: 'Sign out?',
                  body: 'Your workouts, food and plans stay saved${pending > 0 ? ', including $pending change${pending == 1 ? '' : 's'} not yet synced' : ''}. They stay private to your account on this phone and continue syncing when you sign in again.',
                  action: 'Sign out')) {
                return;
              }
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ]),
        const SizedBox(height: 16),
        Text('GoHard 0.1.0${AppConfig.build.isEmpty ? '' : ' (build ${AppConfig.build})'} · commit ${AppConfig.commit} · contract ${AppConfig.contractVersion}\nServer: ${AppConfig.apiBase}', key: const Key('me-build'), style: context.caption),
      ],
    );
  }
}

/// The small-capitals label above each group of rows.
class _Group extends StatelessWidget {
  const _Group(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 24, 4, 8), child: Semantics(header: true, child: Overline(title)));
}

String modeLabel(ThemeMode mode) => switch (mode) { ThemeMode.light => 'Light', ThemeMode.dark => 'Dark', ThemeMode.system => 'System' };

/// What Me shows beside "Motion & haptics": the two device preferences as they really are.
String motionLabel(DevicePrefs prefs) => switch ((prefs.motion, prefs.haptics)) {
      (MotionPref.device, HapticsPref.device) => 'Device',
      (MotionPref.reduced, HapticsPref.device) => 'Reduced motion',
      (MotionPref.device, HapticsPref.off) => 'Haptics off',
      (MotionPref.reduced, HapticsPref.off) => 'Reduced · Haptics off',
    };

/// Motion and haptics for this phone. Both apply at once, are remembered here and are never sent to the account.
class MotionHapticsScreen extends ConsumerWidget {
  const MotionHapticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(devicePrefsProvider);
    final set = ref.read(devicePrefsProvider.notifier);
    // The phone's own setting, read below the app's override so "Device" can say what it currently means.
    final phoneReduces = View.of(context).platformDispatcher.accessibilityFeatures.disableAnimations;
    return AppPage(title: 'Motion & haptics', subtitle: 'How GoHard moves and taps on this phone.', children: [
      const SectionHeader('Motion'),
      const SizedBox(height: 10),
      Segmented<MotionPref>(values: MotionPref.values, selected: prefs.motion, keyPrefix: 'motion', label: (m) => m.label, onChanged: set.setMotion),
      const SizedBox(height: 8),
      Text(switch (prefs.motion) {
        MotionPref.device => phoneReduces
            ? 'Follows your phone. Reduce Motion is on there, so screens and progress change without movement.'
            : 'Follows your phone\'s Reduce Motion setting. It is off there, so short transitions are shown.',
        MotionPref.reduced => 'Screens, sheets and progress change without movement, whatever your phone is set to.',
      }, key: const Key('motion-explanation'), style: context.caption),
      const SizedBox(height: 26),
      const SectionHeader('Haptics'),
      const SizedBox(height: 10),
      Segmented<HapticsPref>(values: HapticsPref.values, selected: prefs.haptics, keyPrefix: 'haptics', label: (h) => h.label, onChanged: set.setHaptics),
      const SizedBox(height: 8),
      Text(switch (prefs.haptics) {
        HapticsPref.device => 'A light tap when you make a selection or confirm an action, if your phone allows vibration. Never for syncing or typing.',
        HapticsPref.off => 'GoHard does not vibrate this phone.',
      }, style: context.caption),
      const SizedBox(height: 26),
      Text('Changes apply immediately and are remembered on this phone.', style: context.caption),
    ]);
  }
}

/// Appearance: two independent choices, applied at once everywhere and remembered on this phone. A small preview,
/// then the accent (three swatches), the mode (Light, Dark, System), and the guide's and this phone's settings.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final set = ref.read(appearanceProvider.notifier);
    final brightness = Theme.of(context).brightness;
    return AppPage(title: 'Appearance', subtitle: 'Make GoHard feel like yours.', actions: const [
      // Help only when asked for: Me stays about the account and its preferences.
      CoachHelpEntry(id: 'me.appearance', label: 'Help with these settings'),
    ], children: [
      const CoachSpot(
        id: 'me.appearance', padding: EdgeInsets.only(bottom: 18),
        say: CoachSay('Pick your guide and when I show up. Motion & haptics sets how much I move.'),
      ),
      const _Preview(),
      const SizedBox(height: 14),
      _Section('Accent', 'Used for buttons, highlights and the panels.', Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final a in Accent.values)
          // Each swatch is that accent as it looks in the current mode.
          Expanded(child: _Swatch(a, color: GoColors.of(a, brightness).accent, selected: a == appearance.accent, onTap: () => set.setAccent(a))),
      ])),
      const SizedBox(height: 12),
      _Section('Mode', 'System follows your phone\'s appearance.', Segmented<ThemeMode>(
        values: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system], selected: appearance.mode, keyPrefix: 'appearance', label: modeLabel, onChanged: set.setMode,
      )),
      const SizedBox(height: 12),
      const _CoachSection(),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 20, color: context.c.secondary),
        const SizedBox(width: 10),
        Expanded(child: Text('Changes apply immediately and are remembered on this phone.', style: context.caption)),
      ]),
    ]);
  }
}

/// One Appearance choice on a quiet card: its name, one line, then the control.
class _Section extends StatelessWidget {
  const _Section(this.title, this.body, this.child);
  final String title, body;
  final Widget child;
  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(header: true, child: Text(title, style: context.sansStyle(17, weight: FontWeight.w600))),
          const SizedBox(height: 2),
          Text(body, style: context.caption),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// An accent as a round swatch above its name. The chosen one has a ring, a check and a heavier name, so the choice
/// never rests on colour alone; announced as "Blue accent", a selected button in a mutually exclusive group.
class _Swatch extends StatelessWidget {
  const _Swatch(this.accent, {required this.color, required this.selected, required this.onTap});
  final Accent accent;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      key: Key('accent-${accent.name}'), container: true, button: true, selected: selected, inMutuallyExclusiveGroup: true, label: '${accent.label} accent',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.field),
        onTap: () {
          if (!selected) Haptics.selection();
          onTap();
        },
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 50, height: 50, padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? c.text : Colors.transparent, width: 2)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: selected ? Icon(Icons.check_rounded, size: 22, color: GoColors.of(accent, Theme.of(context).brightness).onAccent) : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(accent.label, textAlign: TextAlign.center, style: context.sansStyle(15, weight: selected ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leon or Leona, the coaching hints, and the other settings for this phone. Choosing a guide applies at once and
/// changes nothing else: not the accent or mode, not an open page, draft or conversation. Never inferred from the profile.
class _CoachSection extends ConsumerWidget {
  const _CoachSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coach = ref.watch(coachPrefsProvider);
    final set = ref.read(coachPrefsProvider.notifier);
    // Side by side, picture above name, while the names fit; at large text one under another, picture beside name.
    final across = MediaQuery.textScalerOf(context).scale(10) <= 15;
    final cards = [for (final g in CoachGuide.values) CoachChoice(g, selected: g == coach.guide, across: across, onTap: () => set.setGuide(g))];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Section(
        'Coach', 'Leon, a lion, or Leona, a lioness. The same coach either way: only the look changes.',
        across
            ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cards[0], const SizedBox(height: 10), cards[1]]),
      ),
      const SizedBox(height: 12),
      GroupCard(children: [
        // The companion beside Today's greeting. Off, Ask GoHard and the Quick guide stay exactly where they are.
        MergeSemantics(
          child: GroupRow(
            key: const Key('coach-on-today'), icon: Icons.visibility_outlined, title: 'Show coach on Today',
            subtitle: coach.onToday ? '${coach.guide.label} beside your greeting.' : 'Off. Ask GoHard is still ${coach.guide.label}, on Train.',
            trailing: Switch(value: coach.onToday, onChanged: (on) {
              Haptics.selection();
              set.setOnToday(on);
            }),
          ),
        ),
        // Its own switch: turning it off never changes Today. Off, Create my plan, Log food and goals stay on the page and
        // the coach's small avatar still opens help.
        MergeSemantics(
          child: GroupRow(
            key: const Key('coach-on-tabs'), icon: Icons.forum_outlined, title: 'Show coach on Train and Eat',
            subtitle: coach.onTabs ? '${coach.guide.label} with a short tip under the title.' : 'Off. Help is still a tap on ${coach.guide.label}\'s avatar.',
            trailing: Switch(value: coach.onTabs, onChanged: (on) {
              Haptics.selection();
              set.setOnTabs(on);
            }),
          ),
        ),
        MergeSemantics(
          child: GroupRow(
            key: const Key('coach-hints'), icon: Icons.chat_bubble_outline, title: 'Coaching hints',
            subtitle: coach.hintsEnabled ? 'A short tip from ${coach.guide.label} beside GoHard\'s help, once each.' : 'Off. Help is still there when you ask.',
            trailing: Switch(value: coach.hintsEnabled, onChanged: (on) {
              Haptics.selection();
              set.setHints(on);
            }),
          ),
        ),
        GroupRow(
          key: const Key('coach-hints-reset'), icon: Icons.replay_rounded, title: 'Show coaching hints again',
          onTap: () {
            set.resetHints(ref.read(ownerProvider) ?? '');
            toast(context, 'Coaching hints you have seen can show again.');
          },
        ),
        GroupRow(
          key: const Key('appearance-motion'), icon: Icons.animation, title: 'Motion & haptics', value: motionLabel(ref.watch(devicePrefsProvider)),
          onTap: () => push(context, const MotionHapticsScreen()),
        ),
        // The scene behind the top of Today. It never changes the accent or mode.
        GroupRow(
          key: const Key('appearance-today-background'), icon: Icons.wb_twilight_outlined, title: 'Today background', value: ref.watch(todayBackgroundSummaryProvider),
          onTap: () => push(context, const TodayBackgroundScreen()),
        ),
      ]),
    ]);
  }
}

/// One guide's card: a 64 px preview (56 px beside the name at large text), the name and "Lion" / "Lioness". Selected:
/// the pale panel tint with its dark ink, an accent border, a heavier name and a check badge, so never colour alone;
/// announced as "Leon, lion", a selected button in a mutually exclusive group. ChoiceCard's icon slot is 36 px, too
/// small to tell the two faces apart.
class CoachChoice extends StatelessWidget {
  const CoachChoice(this.guide, {super.key, required this.selected, required this.across, required this.onTap, this.face});
  final CoachGuide guide;

  /// Shown instead of the still avatar (setup's animated previews).
  final Widget? face;
  final bool selected, across;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = GoColors.panelOf(c);
    final align = across ? TextAlign.center : TextAlign.start;
    final names = Column(crossAxisAlignment: across ? CrossAxisAlignment.center : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(guide.label, textAlign: align, style: context.pageTitleStyle(22, color: selected ? p.text : c.text)),
      Text('${guide.animal[0].toUpperCase()}${guide.animal.substring(1)}', textAlign: align, style: context.sansStyle(14, color: selected ? p.secondary : c.secondary)),
    ]);
    return Semantics(
      key: Key('coach-${guide.name}'), button: true, selected: selected, inMutuallyExclusiveGroup: true, label: '${guide.label}, ${guide.animal}',
      child: Material(
        color: selected ? c.tint : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel), side: BorderSide(color: selected ? c.accent : c.outline, width: selected ? 2 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (!selected) Haptics.selection();
            onTap();
          },
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum),
              child: Stack(children: [
                Padding(
                  padding: across ? const EdgeInsets.fromLTRB(8, 14, 8, 12) : const EdgeInsetsDirectional.fromSTEB(12, 10, 40, 10),
                  child: across
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [face ?? CoachAvatar(size: 64, guide: guide), const SizedBox(height: 8), names]))
                      : Row(children: [face ?? CoachAvatar(size: 56, guide: guide), const SizedBox(width: 12), Expanded(child: names)]),
                ),
                if (selected)
                  PositionedDirectional(
                    top: 8, end: 8,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: c.accentDeep, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 17, color: c.onAccentDeep),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small still picture of Today in the chosen look: the pale panel over a scene, the selected guide, and a deep
/// button. It is not a control: nothing in it can be tapped or focused, and it is announced as one "Preview" image.
class _Preview extends ConsumerWidget {
  const _Preview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));
    final pictured = MediaQuery.textScalerOf(context).scale(10) <= 13;
    return Semantics(
      key: const Key('appearance-preview'), container: true, image: true, label: 'Preview of Today in this appearance',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: PanelTheme(
            child: Builder(builder: (context) {
              final c = context.c;
              return PanelSurface(
                photo: pictured
                    ? Stack(fit: StackFit.expand, children: [
                        const PanelPhoto('assets/scenes/scenic-dusk.webp'),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: FractionallySizedBox(
                            heightFactor: 0.92,
                            child: Image.asset('assets/coach/${guide.name}-bust.png', fit: BoxFit.contain, alignment: Alignment.bottomRight, cacheHeight: 360,
                                excludeFromSemantics: true, gaplessPlayback: true, errorBuilder: (context, _, _) => const SizedBox.shrink()),
                          ),
                        ),
                      ])
                    : null,
                child: FractionallySizedBox(
                  widthFactor: pictured ? PanelSurface.wordsShare : 1, alignment: AlignmentDirectional.centerStart,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Overline('Preview'),
                    Text('Today', style: context.pageTitleStyle(30)),
                    Text('Your accent, your mode.', style: context.sansStyle(14.5, color: c.secondary)),
                    const SizedBox(height: 12),
                    // Drawn like the primary button, but it is a picture of one: it has no action at all.
                    Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: c.accentDeep, borderRadius: BorderRadius.circular(Radii.tile)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_arrow_rounded, size: 20, color: c.onAccentDeep),
                        const SizedBox(width: 6),
                        Flexible(child: Text('Resume workout', style: context.sansStyle(15, weight: FontWeight.w600, color: c.onAccentDeep))),
                      ]),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Edit profile: the display name, free text you see in the app. It is not your sign-in email, which is shown
/// but cannot be changed here. Save or cancel explicitly.
class EditNameScreen extends ConsumerStatefulWidget {
  const EditNameScreen({super.key, required this.profile});
  final Profile profile;
  @override
  ConsumerState<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends ConsumerState<EditNameScreen> {
  late final _name = TextEditingController(text: widget.profile.displayName);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Edit profile',
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
          PrimaryButton('Save name', key: const Key('name-save'), onPressed: () async {
            try {
              // Saved against the owner captured when this repository was created: a late save can never land on another account.
              await ref.read(profileRepositoryProvider).update(widget.profile, displayName: _name.text);
              if (context.mounted) Navigator.pop(context);
            } on AuthFailure catch (e) {
              setState(() => _error = e.message);
            } on LocalSaveFailure {
              setState(() => _error = 'Your name could not be saved on this phone. What you typed is still here.');
            }
          }),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ]),
        children: [
          TextField(key: const Key('name-field'), controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name shown in the app')),
          if (ref.watch(sessionProvider) case final session?) Padding(padding: const EdgeInsets.only(top: 14), child: StatusLine(Icons.alternate_email, 'Signed in as ${session.email}')),
        ],
      );
}

/// Optional daily calorie and protein goals. Both start empty and stay empty until the person types one:
/// the app does not work out, suggest or pre-fill a goal.
class NutritionGoalsScreen extends ConsumerStatefulWidget {
  const NutritionGoalsScreen({super.key, required this.profile});
  final Profile profile;
  @override
  ConsumerState<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends ConsumerState<NutritionGoalsScreen> {
  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Nutrition goals',
        actions: const [CoachHelpEntry(id: 'me.goals', label: 'Help with nutrition goals')],
        children: [
          const CoachSpot(
            id: 'me.goals', introduce: true, padding: EdgeInsets.only(bottom: 16),
            say: CoachSay('These are your daily tracking targets. You can leave either one blank.'),
          ),
          // Words only, no figure: the panel explains goals, it never shows or suggests one.
          PhotoPanel(
            photo: 'assets/images/nutrition-cover.webp',
            content: (context) => [
              Text('Set your own daily targets. Any of them may be left blank.', style: context.sansStyle(18, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('They repeat every day until you change them. Today and Eat show your progress once you set one.', style: context.sansStyle(14.5, color: context.c.secondary)),
            ],
          ),
          const SizedBox(height: 20),
          // The same form Today and Eat open in a sheet: one set of goals, one validation.
          GoalsEditor(profile: widget.profile, onSaved: () => Navigator.pop(context)),
        ],
      );
}

/// Explicit, password-confirmed erasure. Distinct from signing out, needs a connection, and is never queued.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) return setState(() => _error = 'Enter your password to confirm.');
    if (!await confirm(context, title: 'Delete your account?', body: 'Your account and all of its workouts, food, plans and measurements will be permanently erased. This cannot be undone.', action: 'Delete everything', destructive: true) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).deleteAccount(_password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      // A wrong password, an unreachable server or an uncertain response all leave the account and local data intact.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    return AppPage(
      title: 'Delete account',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton('Delete my account', key: const Key('delete-confirm'), busy: _busy, destructive: true, onPressed: _delete),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep my account')),
      ]),
      children: [
        Text('This permanently erases your account and everything in it, on the server and on this phone. Signing out is different: it keeps everything.', style: context.body),
        if (pending > 0)
          Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.warning_amber, '$pending change${pending == 1 ? '' : 's'} on this phone ${pending == 1 ? 'has' : 'have'} not synced yet and will be erased too.', tone: Tone.warning)),
        const SizedBox(height: 16),
        TextField(key: const Key('delete-password'), controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Your password')),
      ],
    );
  }
}
