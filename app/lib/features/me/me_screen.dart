import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/go_icon.dart';
import '../../core/appearance.dart';
import '../../core/compatibility.dart';
import '../../core/config.dart';
import '../../core/device_prefs.dart';
import '../../core/clock.dart' show dayKeyOf;
import '../../core/format.dart' show longDate, ltr;
import '../../core/language.dart';
import '../../core/language_picker.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../auth/account_security.dart';
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
    if (context.mounted) toast(context, context.l10n.meRemindersNotAllowed);
    return;
  }
  try {
    await ref.read(profileRepositoryProvider).update(profile, remindersEnabled: on, reminderLocalTime: profile.reminderLocalTime ?? '18:00');
    Haptics.selection();
  } on LocalSaveFailure {
    if (context.mounted) toast(context, context.l10n.mePrefNotSaved);
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
    final l = context.l10n;

    Future<void> setUnit(String loadUnit) async {
      if (profile == null || loadUnit == profile.loadUnit) return;
      try {
        await ref.read(profileRepositoryProvider).update(profile, loadUnit: loadUnit);
      } on LocalSaveFailure {
        if (context.mounted) toast(context, context.l10n.mePrefNotSaved);
      }
    }

    void chooseUnit() => showGoSheet<void>(context, title: l.meUnits, builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final unit in const ['kg', 'lb'])
            ChoiceTile<String>(
              key: Key('unit-$unit'), value: unit, groupValue: profile?.loadUnit ?? 'kg', title: unit == 'kg' ? l.meUnitKilograms : l.meUnitPounds,
              onChanged: (chosen) {
                Navigator.pop(sheet);
                setUnit(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text(l.meUnitsLoadNote, style: context.caption),
          const SizedBox(height: 16),
          Text(l.bodyTitle, style: context.label),
          for (final mass in LoadUnit.values)
            ChoiceTile<LoadUnit>(
              key: Key('unit-body-${mass.name}'), value: mass, groupValue: ref.read(bodyUnitsProvider).mass, title: mass == LoadUnit.kg ? l.meUnitBodyKg : l.meUnitBodyLb,
              onChanged: (chosen) {
                Navigator.pop(sheet);
                setBodyUnits(ref, BodyUnits(chosen, ref.read(bodyUnitsProvider).length));
              },
            ),
          for (final length in LengthUnit.values)
            ChoiceTile<LengthUnit>(
              key: Key('unit-body-${length.name}'), value: length, groupValue: ref.read(bodyUnitsProvider).length, title: length == LengthUnit.cm ? l.meUnitBodyCm : l.meUnitBodyIn,
              onChanged: (chosen) {
                Navigator.pop(sheet);
                setBodyUnits(ref, BodyUnits(ref.read(bodyUnitsProvider).mass, chosen));
              },
            ),
          const SizedBox(height: 4),
          Text(l.meUnitsBodyNote, style: context.caption),
          const SizedBox(height: 16),
          Text(l.meUnitsTemperature, style: context.label),
          for (final f in const [false, true])
            ChoiceTile<bool>(
              key: Key('unit-${f ? 'fahrenheit' : 'celsius'}'), value: f, groupValue: ref.read(weatherPrefsProvider).fahrenheit, title: f ? l.meUnitFahrenheit : l.meUnitCelsius,
              onChanged: (chosen) {
                Navigator.pop(sheet);
                ref.read(weatherPrefsProvider.notifier).setFahrenheit(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text(l.meUnitsTemperatureNote, style: context.caption),
          const SizedBox(height: 16),
          Text(l.meUnitsWater, style: context.label),
          for (final u in VolumeUnit.values)
            ChoiceTile<VolumeUnit>(
              key: Key('unit-water-${u.name}'), value: u, groupValue: ref.read(volumeUnitProvider), title: u == VolumeUnit.ml ? l.meUnitMillilitres : l.meUnitFluidOunces,
              onChanged: (chosen) {
                Navigator.pop(sheet);
                ref.read(trackingPrefsProvider.notifier).setUnit(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text(l.meUnitsWaterNote, style: context.caption),
          const SizedBox(height: 16),
          Text(l.meUnitsRunWalk, style: context.label),
          for (final u in DistanceUnit.values)
            ChoiceTile<DistanceUnit>(
              key: Key('unit-distance-${u.name}'), value: u, groupValue: ref.read(devicePrefsProvider).distance,
              title: u == DistanceUnit.km ? l.meUnitKilometres : l.meUnitMiles,
              onChanged: (chosen) {
                Navigator.pop(sheet);
                ref.read(devicePrefsProvider.notifier).setDistance(chosen);
              },
            ),
          const SizedBox(height: 4),
          Text(l.meUnitsRunWalkNote, style: context.caption),
        ]));

    // What is true about the account right now, in a word and a sentence. "Saved" is said only when nothing is
    // waiting, nothing needs a decision and the last attempt to reach the account did not fail.
    final (syncIcon, syncTone, syncWord, syncDetail) = issues > 0
        ? (Icons.rule, Tone.warning, l.meSyncNeedsReview, l.meSyncNeedsReviewDetail(issues))
        : unreachable
            // With the account out of reach, "everything is saved" would claim more than is known.
            ? (Icons.cloud_off, Tone.neutral, l.meSyncNotSynced, pending > 0 ? l.meSyncUnreachableWaitingDetail(pending) : l.meSyncUnreachableDetail)
            : pending > 0
                ? (Icons.phone_iphone, Tone.neutral, l.meSyncWaiting, l.meSyncWaitingDetail(pending))
                : (Icons.cloud_done_outlined, Tone.success, l.meSyncSaved, l.meSyncSavedDetail);

    final version = AppConfig.build.isEmpty ? 'GoHard 0.1.0' : l.meBuildNumber('GoHard 0.1.0', AppConfig.build);
    return ListView(
      // No scene on Me: the plain page, the title where every tab has it, and room for the floating bar at the end.
      padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        TabHeader(title: l.navMe),
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
                      if (profile != null) Text(l.meEditProfile, style: context.sansStyle(15, color: context.c.secondary)),
                    ]),
                  ),
                  if (profile != null) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Icon(Icons.chevron_right, size: 22, color: context.c.secondary)),
                ]),
              ),
            ),
          ),
        ]),
        if (profile == null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.hourglass_empty, l.meProfileNotLoaded)),

        _Group(l.meGroupPersonal),
        GroupCard(children: [
          GroupRow(key: const Key('me-body'), icon: Icons.monitor_weight_outlined, title: l.bodyTitle, subtitle: l.meBodySubtitle, onTap: () => push(context, const BodyProgressScreen())),
          // Shown unless the server has said it cannot store goals: a goal that silently vanishes is worse than no row.
          if (profile != null && ref.watch(compatibilityProvider).supports('profile.nutrition-goals'))
            GroupRow(
              key: const Key('me-goals'), icon: Icons.restaurant_outlined, title: l.meGoals,
              // Only a goal the person set is shown; nothing is suggested in its place.
              subtitle: goalsSummary(profile, ref.watch(volumeUnitProvider), water: ref.watch(nutritionDisplayProvider).water) == null ? l.meGoalsNoneSet : l.meGoalsSet,
              value: goalsSummary(profile, ref.watch(volumeUnitProvider), water: ref.watch(nutritionDisplayProvider).water),
              onTap: () => push(context, NutritionGoalsScreen(profile: profile)),
            ),
        ]),

        // Steps' one set of controls, the same sheet Today's tile and Run / Walk open (docs/RUN_WALK.md › Steps).
        _Group(l.meGroupActivity),
        GroupCard(children: [
          GroupRow(
            key: const Key('me-steps'), leading: const GoIcon(GoGlyph.steps), title: l.meSteps,
            subtitle: ref.watch(stepsEnabledProvider) ? l.meStepsOnSubtitle : l.meStepsOffSubtitle,
            value: ref.watch(stepsEnabledProvider) ? l.meOn : l.meOff,
            onTap: () => showStepsSheet(context),
          ),
        ]),

        _Group(l.meGroupPreferences),
        GroupCard(children: [
          GroupRow(
            key: const Key('me-appearance'), icon: Icons.palette_outlined, title: l.meAppearance,
            value: '${accentLabel(l, appearance.accent)} · ${modeLabel(l, appearance.mode)}',
            onTap: () => push(context, const AppearanceScreen()),
          ),
          if (profile != null)
            GroupRow(key: const Key('me-units'), icon: Icons.straighten, title: l.meUnits, value: '${LoadUnit.parse(profile.loadUnit) == LoadUnit.kg ? l.meUnitKilograms : l.meUnitPounds} · ${ref.watch(weatherPrefsProvider.select((p) => p.fahrenheit)) ? '°F' : '°C'}', onTap: chooseUnit),
          GroupRow(key: const Key('me-motion'), icon: Icons.animation, title: l.meMotionHaptics, value: motionLabel(l, prefs), onTap: () => push(context, const MotionHapticsScreen())),
          // This phone's language: independent of the account, the look, units and voice.
          GroupRow(
            key: const Key('me-language'), icon: Icons.translate, title: l.languageTitle,
            value: languageValue(l, prefs.language, ref.watch(appLocaleProvider)),
            onTap: () => showLanguagePicker(context, ref),
          ),
          GroupRow(key: const Key('me-permissions'), icon: Icons.verified_user_outlined, title: l.mePermissions, subtitle: l.mePermissionsSubtitle, onTap: () => push(context, const PermissionsScreen())),
          if (profile != null) ...[
            MergeSemantics(
              child: GroupRow(
                key: const Key('me-reminders'),
                icon: profile.remindersEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                title: l.meReminders,
                subtitle: profile.remindersEnabled ? l.meRemindersOnSubtitle : l.meOff,
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
                title: l.meReminderTime,
                subtitle: l.meReminderTimeSubtitle,
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

        _Group(l.meGroupAccount),
        GroupCard(children: [
          // The address and what the server says about it; a server from before verification says nothing, so neither does Me.
          if (profile?.emailVerified case final verified? when session != null)
            GroupRow(
              key: const Key('me-email'), icon: verified ? Icons.verified_outlined : Icons.mark_email_unread_outlined,
              tone: verified ? Tone.success : Tone.warning, title: l.meEmail,
              // The same server-owned state as Today's notice: the deadline, or that uploads wait for verification.
              subtitle: switch (ref.watch(accountAccessProvider).value) {
                final a? when !verified && a.required => '${ltr(session.email)}\n${l.meEmailPaused}',
                final a? when !verified && a.dueAt != null => '${ltr(session.email)}\n${l.meEmailVerifyBy(longDate(dayKeyOf(a.dueAt!)))}',
                _ => ltr(session.email),
              },
              value: verified ? l.meEmailVerified : l.meEmailNotVerified,
              onTap: verified ? null : () => push(context, const VerifyEmailScreen()),
            ),
          if (ref.watch(compatibilityProvider).supports(securityCapability))
            GroupRow(key: const Key('me-password'), icon: Icons.password, title: l.mePassword, subtitle: l.mePasswordSubtitle,
                onTap: () => push(context, const ChangePasswordScreen())),
          // The same words as Today's notice. Tapping the row opens the review, or asks the account again.
          GroupRow(
            key: const Key('me-sync'), icon: syncIcon, tone: syncTone, title: l.meSyncStatus, subtitle: syncDetail, value: syncWord,
            onTap: issues > 0 ? () => push(context, const SyncReviewScreen()) : () => refreshFromAccount(ref),
          ),
          GroupRow(key: const Key('me-delete-account'), icon: Icons.delete_outline, tone: Tone.neutral, title: l.meDeleteAccount, subtitle: l.meDeleteAccountSubtitle, onTap: () => push(context, const DeleteAccountScreen())),
        ]),
        const SizedBox(height: 12),
        GroupCard(children: [
          GroupRow(
            key: const Key('me-sign-out'), icon: Icons.logout, tone: Tone.neutral, title: l.meSignOut, subtitle: session == null ? null : ltr(session.email),
            onTap: () async {
              if (!await confirm(context, title: l.meSignOutConfirmTitle, body: l.meSignOutConfirmBody(pending), action: l.meSignOut)) return;
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ]),
        const SizedBox(height: 16),
        Text(l.meBuildLine(version, ltr(AppConfig.commit), ltr('${AppConfig.contractVersion}'), ltr(AppConfig.apiBase)), key: const Key('me-build'), style: context.caption),
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

String accentLabel(AppLocalizations l, Accent a) => switch (a) { Accent.blue => l.meAccentBlue, Accent.green => l.meAccentGreen, Accent.pink => l.meAccentPink };

String modeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) { ThemeMode.light => l.meModeLight, ThemeMode.dark => l.meModeDark, ThemeMode.system => l.meModeSystem };

/// What Me shows beside "Motion & haptics": the two device preferences as they really are.
String motionLabel(AppLocalizations l, DevicePrefs prefs) => switch ((prefs.motion, prefs.haptics)) {
      (MotionPref.device, HapticsPref.device) => l.motionDevice,
      (MotionPref.reduced, HapticsPref.device) => l.meMotionReducedSummary,
      (MotionPref.device, HapticsPref.off) => l.meHapticsOffSummary,
      (MotionPref.reduced, HapticsPref.off) => l.meMotionReducedHapticsOffSummary,
    };

/// Motion and haptics for this phone. Both apply at once, are remembered here and are never sent to the account.
class MotionHapticsScreen extends ConsumerWidget {
  const MotionHapticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(devicePrefsProvider);
    final set = ref.read(devicePrefsProvider.notifier);
    final l = context.l10n;
    // The phone's own setting, read below the app's override so "Device" can say what it currently means.
    final phoneReduces = View.of(context).platformDispatcher.accessibilityFeatures.disableAnimations;
    return AppPage(title: l.meMotionHaptics, subtitle: l.meMotionSubtitle, children: [
      SectionHeader(l.meMotionSection),
      const SizedBox(height: 10),
      Segmented<MotionPref>(values: MotionPref.values, selected: prefs.motion, keyPrefix: 'motion', label: (m) => m == MotionPref.device ? l.motionDevice : l.motionReduced, onChanged: set.setMotion),
      const SizedBox(height: 8),
      Text(switch (prefs.motion) {
        MotionPref.device => phoneReduces ? l.meMotionDevicePhoneReduces : l.meMotionDevicePhoneMoves,
        MotionPref.reduced => l.meMotionReducedExplanation,
      }, key: const Key('motion-explanation'), style: context.caption),
      const SizedBox(height: 26),
      SectionHeader(l.meHapticsSection),
      const SizedBox(height: 10),
      Segmented<HapticsPref>(values: HapticsPref.values, selected: prefs.haptics, keyPrefix: 'haptics', label: (h) => h == HapticsPref.device ? l.hapticsDevice : l.hapticsOff, onChanged: set.setHaptics),
      const SizedBox(height: 8),
      Text(switch (prefs.haptics) {
        HapticsPref.device => l.meHapticsDeviceExplanation,
        HapticsPref.off => l.meHapticsOffExplanation,
      }, style: context.caption),
      const SizedBox(height: 26),
      Text(l.mePrefsApplyNow, style: context.caption),
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
    final l = context.l10n;
    return AppPage(title: l.meAppearance, subtitle: l.meAppearanceSubtitle, actions: [
      // Help only when asked for: Me stays about the account and its preferences.
      CoachHelpEntry(id: 'me.appearance', label: l.meAppearanceHelp),
    ], children: [
      CoachSpot(
        id: 'me.appearance', padding: const EdgeInsets.only(bottom: 18),
        say: CoachSay(l.meAppearanceCoachSay),
      ),
      const _Preview(),
      const SizedBox(height: 14),
      _Section(l.meAccentTitle, l.meAccentBody, Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final a in Accent.values)
          // Each swatch is that accent as it looks in the current mode.
          Expanded(child: _Swatch(a, color: GoColors.of(a, brightness).accent, selected: a == appearance.accent, onTap: () => set.setAccent(a))),
      ])),
      const SizedBox(height: 12),
      _Section(l.meModeTitle, l.meModeBody, Segmented<ThemeMode>(
        values: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system], selected: appearance.mode, keyPrefix: 'appearance', label: (m) => modeLabel(l, m), onChanged: set.setMode,
      )),
      const SizedBox(height: 12),
      const _CoachSection(),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 20, color: context.c.secondary),
        const SizedBox(width: 10),
        Expanded(child: Text(l.mePrefsApplyNow, style: context.caption)),
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
    final name = accentLabel(context.l10n, accent);
    return Semantics(
      key: Key('accent-${accent.name}'), container: true, button: true, selected: selected, inMutuallyExclusiveGroup: true, label: context.l10n.meAccentSemantics(name),
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
                Text(name, textAlign: TextAlign.center, style: context.sansStyle(15, weight: selected ? FontWeight.w700 : FontWeight.w500)),
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
    final l = context.l10n;
    final guide = coach.guide.displayName(l);
    // Side by side, picture above name, while the names fit; at large text one under another, picture beside name.
    final across = MediaQuery.textScalerOf(context).scale(10) <= 15;
    final cards = [for (final g in CoachGuide.values) CoachChoice(g, selected: g == coach.guide, across: across, onTap: () => set.setGuide(g))];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Section(
        l.meCoachTitle, l.meCoachBody,
        across
            ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cards[0], const SizedBox(height: 10), cards[1]]),
      ),
      const SizedBox(height: 12),
      GroupCard(children: [
        // The companion beside Today's greeting. Off, Ask GoHard and the Quick guide stay exactly where they are.
        MergeSemantics(
          child: GroupRow(
            key: const Key('coach-on-today'), icon: Icons.visibility_outlined, title: l.meCoachOnToday,
            subtitle: coach.onToday ? l.meCoachOnTodayOn(guide) : l.meCoachOnTodayOff(guide),
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
            key: const Key('coach-on-tabs'), icon: Icons.forum_outlined, title: l.meCoachOnTabs,
            subtitle: coach.onTabs ? l.meCoachOnTabsOn(guide) : l.meCoachOnTabsOff(guide),
            trailing: Switch(value: coach.onTabs, onChanged: (on) {
              Haptics.selection();
              set.setOnTabs(on);
            }),
          ),
        ),
        MergeSemantics(
          child: GroupRow(
            key: const Key('coach-hints'), icon: Icons.chat_bubble_outline, title: l.meCoachHints,
            subtitle: coach.hintsEnabled ? l.meCoachHintsOn(guide) : l.meCoachHintsOff,
            trailing: Switch(value: coach.hintsEnabled, onChanged: (on) {
              Haptics.selection();
              set.setHints(on);
            }),
          ),
        ),
        GroupRow(
          key: const Key('coach-hints-reset'), icon: Icons.replay_rounded, title: l.meCoachHintsReset,
          onTap: () {
            set.resetHints(ref.read(ownerProvider) ?? '');
            toast(context, l.meCoachHintsResetDone);
          },
        ),
        GroupRow(
          key: const Key('appearance-motion'), icon: Icons.animation, title: l.meMotionHaptics, value: motionLabel(l, ref.watch(devicePrefsProvider)),
          onTap: () => push(context, const MotionHapticsScreen()),
        ),
        // The scene behind the top of Today. It never changes the accent or mode.
        GroupRow(
          key: const Key('appearance-today-background'), icon: Icons.wb_twilight_outlined, title: l.meTodayBackground, value: ref.watch(todayBackgroundSummaryProvider),
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
    final l = context.l10n;
    final name = guide.displayName(l), animal = guide.animalName(l);
    final align = across ? TextAlign.center : TextAlign.start;
    final names = Column(crossAxisAlignment: across ? CrossAxisAlignment.center : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(name, textAlign: align, style: context.pageTitleStyle(22, color: selected ? p.text : c.text)),
      Text('${animal[0].toUpperCase()}${animal.substring(1)}', textAlign: align, style: context.sansStyle(14, color: selected ? p.secondary : c.secondary)),
    ]);
    return Semantics(
      key: Key('coach-${guide.name}'), button: true, selected: selected, inMutuallyExclusiveGroup: true, label: l.meCoachChoiceSemantics(name, animal),
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
    final l = context.l10n;
    return Semantics(
      key: const Key('appearance-preview'), container: true, image: true, label: l.meAppearancePreviewSemantics,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: PanelTheme(
            child: Builder(builder: (context) {
              final c = context.c;
              return PanelSurface(
                photo: pictured
                    ? Stack(fit: StackFit.expand, children: [
                        const PanelPhoto('assets/scenes/scenic-dusk.webp'),
                        // The guide stands on the trailing side, away from the words; the art itself is never flipped.
                        Align(
                          alignment: AlignmentDirectional.bottomEnd,
                          child: FractionallySizedBox(
                            heightFactor: 0.92,
                            child: Image.asset('assets/coach/${guide.name}-bust.png', fit: BoxFit.contain, alignment: AlignmentDirectional.bottomEnd, cacheHeight: 360,
                                excludeFromSemantics: true, gaplessPlayback: true, errorBuilder: (context, _, _) => const SizedBox.shrink()),
                          ),
                        ),
                      ])
                    : null,
                child: FractionallySizedBox(
                  widthFactor: pictured ? PanelSurface.wordsShare : 1, alignment: AlignmentDirectional.centerStart,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Overline(l.meAppearancePreview),
                    Text(l.navToday, style: context.pageTitleStyle(30)),
                    Text(l.meAppearancePreviewLine, style: context.sansStyle(14.5, color: c.secondary)),
                    const SizedBox(height: 12),
                    // Drawn like the primary button, but it is a picture of one: it has no action at all.
                    Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: c.accentDeep, borderRadius: BorderRadius.circular(Radii.tile)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_arrow_rounded, size: 20, color: c.onAccentDeep),
                        const SizedBox(width: 6),
                        Flexible(child: Text(l.meAppearancePreviewButton, style: context.sansStyle(15, weight: FontWeight.w600, color: c.onAccentDeep))),
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
  // Words to be said, so a language change rewords a message already shown.
  String Function(AppLocalizations l)? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppPage(
      title: l.meEditProfile,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!(l), tone: Tone.error)),
        PrimaryButton(l.meSaveName, key: const Key('name-save'), onPressed: () async {
          try {
            // Saved against the owner captured when this repository was created: a late save can never land on another account.
            await ref.read(profileRepositoryProvider).update(widget.profile, displayName: _name.text);
            if (context.mounted) Navigator.pop(context);
          } on AuthFailure catch (e) {
            setState(() => _error = e.text);
          } on LocalSaveFailure {
            setState(() => _error = (l) => l.meNameNotSaved);
          }
        }),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
      ]),
      children: [
        TextField(key: const Key('name-field'), controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: l.meNameField)),
        if (ref.watch(sessionProvider) case final session?) Padding(padding: const EdgeInsets.only(top: 14), child: StatusLine(Icons.alternate_email, l.meSignedInAs(ltr(session.email)))),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppPage(
      title: l.meGoals,
      actions: [CoachHelpEntry(id: 'me.goals', label: l.meGoalsHelp)],
      children: [
        CoachSpot(
          id: 'me.goals', introduce: true, padding: const EdgeInsets.only(bottom: 16),
          say: CoachSay(l.meGoalsCoachSay),
        ),
        // Words only, no figure: the panel explains goals, it never shows or suggests one.
        PhotoPanel(
          photo: 'assets/images/nutrition-cover.webp',
          content: (context) => [
            Text(context.l10n.meGoalsPanelTitle, style: context.sansStyle(18, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(context.l10n.meGoalsPanelBody, style: context.sansStyle(14.5, color: context.c.secondary)),
          ],
        ),
        const SizedBox(height: 20),
        // The same form Today and Eat open in a sheet: one set of goals, one validation.
        GoalsEditor(profile: widget.profile, onSaved: () => Navigator.pop(context)),
      ],
    );
  }
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
  String Function(AppLocalizations l)? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (_password.text.isEmpty) return setState(() => _error = (l) => l.meDeletePasswordMissing);
    if (!await confirm(context, title: l.meDeleteConfirmTitle, body: l.meDeleteConfirmBody, action: l.meDeleteConfirmAction, destructive: true) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).deleteAccount(_password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      // A wrong password, an unreachable server or an uncertain response all leave the account and local data intact.
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final l = context.l10n;
    return AppPage(
      title: l.meDeleteAccount,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!(l), tone: Tone.error)),
        PrimaryButton(l.meDeleteButton, key: const Key('delete-confirm'), busy: _busy, destructive: true, onPressed: _delete),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.meDeleteKeep)),
      ]),
      children: [
        Text(l.meDeleteExplanation, style: context.body),
        if (pending > 0)
          Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.warning_amber, l.meDeletePendingWarning(pending), tone: Tone.warning)),
        const SizedBox(height: 16),
        TextField(key: const Key('delete-password'), controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: l.meDeletePasswordField)),
      ],
    );
  }
}
