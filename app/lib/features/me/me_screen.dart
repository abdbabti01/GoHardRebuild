import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/appearance.dart';
import '../../core/compatibility.dart';
import '../../core/config.dart';
import '../../core/device_prefs.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../activity/activity_screens.dart';
import 'account_repository.dart';
import 'reminders.dart';
import 'sync_review_screen.dart';

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
      padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 28),
      children: [
        const TabHeader(title: 'Me', overline: 'Your profile'),
        const SizedBox(height: 18),
        GroupCard(children: [
          Semantics(
            button: profile != null,
            child: InkWell(
              key: const Key('me-edit-name'),
              onTap: profile == null ? null : () => push(context, EditNameScreen(profile: profile)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(children: [
                  // An initial, not a photograph: the account has no picture, so none is invented.
                  ExcludeSemantics(
                    child: Container(
                      width: 52, height: 52, alignment: Alignment.center,
                      decoration: BoxDecoration(color: context.c.accentSoft, shape: BoxShape.circle),
                      child: Text(name.isEmpty ? '' : name[0].toUpperCase(), textScaler: TextScaler.noScaling, style: context.sansStyle(22, weight: FontWeight.w700, color: context.c.accent)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 4, children: [
                      Text(name, key: const Key('me-name'), style: context.titleStyle(21)),
                      if (profile != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: Text('Edit profile', style: context.sansStyle(15, weight: FontWeight.w600, color: context.c.accent))),
                          Icon(Icons.chevron_right, size: 22, color: context.c.accent),
                        ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        if (profile == null) const Padding(padding: EdgeInsets.only(top: 10), child: StatusLine(Icons.hourglass_empty, 'Your profile has not loaded on this phone yet.')),

        const _Group('Personal'),
        GroupCard(children: [
          GroupRow(key: const Key('me-body'), icon: Icons.monitor_weight_outlined, title: 'Body measurements', subtitle: 'Weight and body fat', onTap: () => push(context, const BodyMetricsScreen())),
          // Shown unless the server has said it cannot store goals: a goal that silently vanishes is worse than no row.
          if (profile != null && ref.watch(compatibilityProvider).supports('profile.nutrition-goals'))
            GroupRow(
              key: const Key('me-goals'), icon: Icons.restaurant_outlined, title: 'Nutrition goals',
              // Only a goal the person set is shown; nothing is suggested in its place.
              subtitle: profile.calorieGoal == null && profile.proteinGoal == null ? 'None set' : null,
              value: profile.calorieGoal == null && profile.proteinGoal == null
                  ? null
                  : [if (profile.calorieGoal != null) '${profile.calorieGoal} kcal', if (profile.proteinGoal != null) '${profile.proteinGoal} g protein'].join(' · '),
              onTap: () => push(context, NutritionGoalsScreen(profile: profile)),
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
            GroupRow(key: const Key('me-units'), icon: Icons.straighten, title: 'Units', value: LoadUnit.parse(profile.loadUnit) == LoadUnit.kg ? 'Kilograms' : 'Pounds', onTap: chooseUnit),
          GroupRow(key: const Key('me-motion'), icon: Icons.animation, title: 'Motion & haptics', value: motionLabel(prefs), onTap: () => push(context, const MotionHapticsScreen())),
          if (profile != null) ...[
            MergeSemantics(
              child: GroupRow(
                key: const Key('me-reminders'),
                icon: profile.remindersEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                title: 'Workout reminders',
                subtitle: profile.remindersEnabled ? 'On days with a planned workout. None while your plan is paused.' : 'Off',
                trailing: Switch(
                  value: profile.remindersEnabled,
                  onChanged: (on) async {
                    // Permission is asked for only here, when the user turns reminders on.
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
                  },
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
        Text('GoHard 0.1.0 · contract ${AppConfig.contractVersion}\nServer: ${AppConfig.apiBase}', style: context.caption),
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

/// Appearance: two independent choices, applied at once everywhere and remembered on this phone.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final set = ref.read(appearanceProvider.notifier);
    final brightness = Theme.of(context).brightness;
    return AppPage(title: 'Appearance', subtitle: 'Make GoHard feel like you.', children: [
      const SectionHeader('Theme'),
      const SizedBox(height: 10),
      Segmented<ThemeMode>(values: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system], selected: appearance.mode, keyPrefix: 'appearance', label: modeLabel, onChanged: set.setMode),
      const SizedBox(height: 8),
      Text(switch (appearance.mode) {
        ThemeMode.system => 'Matches your phone, and follows it when it changes.',
        ThemeMode.light => 'Always light, whatever your phone is set to.',
        ThemeMode.dark => 'Always dark, whatever your phone is set to.',
      }, style: context.caption),
      const SizedBox(height: 26),
      const SectionHeader('Accent color'),
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final a in Accent.values)
            Expanded(child: _Swatch(accent: a, colors: GoColors.of(a, brightness), selected: a == appearance.accent, onTap: () => set.setAccent(a))),
        ]),
      ),
      const SizedBox(height: 8),
      Text('Selected controls, links and progress use it across Today, Train, Eat and Me.', style: context.caption),
      const SizedBox(height: 26),
      Text('Changes apply immediately and are remembered on this phone.', style: context.caption),
    ]);
  }
}

/// One accent choice. Selected shows as a ring, a check mark and a heavier label, not only as a colour.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.accent, required this.colors, required this.selected, required this.onTap});
  final Accent accent;
  final GoColors colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true, selected: selected, inMutuallyExclusiveGroup: true, label: '${accent.label} accent',
        child: InkWell(
          key: Key('accent-${accent.name}'),
          borderRadius: BorderRadius.circular(Radii.tile),
          onTap: () {
            if (!selected) Haptics.selection();
            onTap();
          },
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                AnimatedContainer(
                  duration: context.motion(Motion.quick),
                  width: 56, height: 56, padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? colors.accent : Colors.transparent, width: 3)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
                    child: selected ? Icon(Icons.check_rounded, size: 24, color: colors.onAccent) : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(accent.label, textAlign: TextAlign.center, style: context.sansStyle(15, weight: selected ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );
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
  late final _calories = TextEditingController(text: widget.profile.calorieGoal?.toString() ?? '');
  late final _protein = TextEditingController(text: widget.profile.proteinGoal?.toString() ?? '');
  String? _error;

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    super.dispose();
  }

  /// Blank is "no goal". Anything else has to be a whole number.
  static int? _whole(String raw, String what) {
    if (raw.trim().isEmpty) return null;
    final v = parsePositiveInt(raw);
    if (v == null) throw AuthFailure('$what is a whole number, or left blank for no goal.');
    return v;
  }

  Future<void> _save() async {
    try {
      // The newest profile on this phone, so a goal change never carries an older name or unit with it.
      final current = ref.read(profileProvider).value ?? widget.profile;
      await ref.read(profileRepositoryProvider).setGoals(current, calorieGoal: _whole(_calories.text, 'A calorie goal'), proteinGoal: _whole(_protein.text, 'A protein goal'));
      if (mounted) Navigator.pop(context);
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } on LocalSaveFailure {
      setState(() => _error = 'Your goals could not be saved on this phone. What you typed is still here.');
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Nutrition goals',
        subtitle: 'Optional. Today and Eat show your progress toward a goal once you set one.',
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
          PrimaryButton('Save goals', key: const Key('goal-save'), onPressed: _save),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ]),
        children: [
          TextField(key: const Key('goal-calories'), controller: _calories, keyboardType: TextInputType.number, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Daily calories', suffixText: 'kcal', hintText: 'No goal', helperText: '500 to 10,000. Leave blank for no calorie goal.')),
          const SizedBox(height: 14),
          TextField(key: const Key('goal-protein'), controller: _protein, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily protein', suffixText: 'g', hintText: 'No goal', helperText: '10 to 500. Leave blank for no protein goal.')),
          const SizedBox(height: 16),
          Text('GoHard does not suggest a goal. If you are unsure what suits you, a dietitian or doctor can help.', style: context.caption),
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
