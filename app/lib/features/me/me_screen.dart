import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/appearance.dart';
import '../../core/compatibility.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../activity/activity_screens.dart';
import '../plans/plan_progress.dart';
import '../plans/plan_screens.dart';
import '../shell/home_shell.dart';
import '../today/daily.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'account_repository.dart';
import 'reminders.dart';
import 'sync_review_screen.dart';

/// Me: identity, a real training overview, history, preferences and account lifecycle.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final session = ref.watch(sessionProvider);
    final today = ref.watch(todayKeyProvider);
    final primary = ref.watch(primaryPlanProvider);
    final drafts = ref.watch(planListProvider).where((p) => p.isDraft && !p.isArchived).toList();
    final allWorkouts = ref.watch(workoutListProvider);
    final workouts = [for (final w in allWorkouts) if (!w.isDeleted) w];
    final open = workouts.where((w) => w.isOpen).toList();
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final issues = ref.watch(issuesProvider).value?.length ?? 0;
    final appearance = ref.watch(appearanceProvider);
    final name = profile?.displayName ?? session?.email ?? '';
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);

    Future<void> setUnit(String loadUnit) async {
      if (profile == null) return;
      try {
        await ref.read(profileRepositoryProvider).update(profile, loadUnit: loadUnit);
      } on LocalSaveFailure {
        if (context.mounted) toast(context, 'That preference could not be saved on this phone.');
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 28),
      children: [
        const Heading('Me'),
        const SizedBox(height: 16),
        Row(children: [
          // An initial, not a photograph: the account has no picture, so none is invented.
          ExcludeSemantics(
            child: CircleAvatar(radius: 32, backgroundColor: context.c.accentSoft, child: Text(name.isEmpty ? '' : name[0].toUpperCase(), style: context.sansStyle(26, weight: FontWeight.w700, color: context.c.accent))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, key: const Key('me-name'), style: context.titleStyle(24)),
              if (session != null) Text(session.email, style: context.caption),
            ]),
          ),
        ]),
        if (profile != null)
          Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('me-edit-name'), onPressed: () => push(context, EditNameScreen(profile: profile)), child: const Text('Edit name')))
        else
          const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.hourglass_empty, 'Your profile has not loaded on this phone yet.')),

        const SizedBox(height: 18),
        const SectionHeader('Your training'),
        const SizedBox(height: 10),
        if (primary != null) ...[
          _Overview(plan: primary, today: today, workouts: allWorkouts, onTap: openPlan),
        ] else if (drafts.isNotEmpty)
          ListRow(icon: Icons.event_note, title: drafts.last.title, subtitle: 'Draft · not started', onTap: () => push(context, PlanReviewScreen(planId: drafts.last.id)))
        else
          ListRow(icon: Icons.event_note, title: 'No plan yet', subtitle: 'Create a plan to review', onTap: () => push(context, const PlanSetupScreen())),
        for (final w in open) ListRow(icon: Icons.timelapse, title: w.title, subtitle: 'In progress', onTap: () => resumeWorkout(context, ref, w)),
        ListRow(key: const Key('me-history'), icon: Icons.history, title: 'Workout history', subtitle: workouts.isEmpty ? 'Nothing recorded yet' : '${workouts.length} workout${workouts.length == 1 ? '' : 's'}', onTap: () => push(context, const WorkoutHistoryScreen())),
        ListRow(icon: Icons.insights, title: 'Progress', subtitle: 'Follow-through, consistency and strength', onTap: () => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.progress)),
        ListRow(icon: Icons.directions_run, title: 'Run history', onTap: () => push(context, const RunHistoryScreen())),
        ListRow(icon: Icons.monitor_weight_outlined, title: 'Body measurements', onTap: () => push(context, const BodyMetricsScreen())),

        const SizedBox(height: 26),
        const SectionHeader('Preferences'),
        const SizedBox(height: 4),
        ListRow(
          key: const Key('me-appearance'), icon: Icons.palette_outlined, title: 'Appearance',
          subtitle: '${appearance.accent.label} · ${modeLabel(appearance.mode)}',
          onTap: () => push(context, const AppearanceScreen()),
        ),
        // Shown unless the server has said it cannot store goals: a goal that silently vanishes is worse than no row.
        if (profile != null && ref.watch(compatibilityProvider).supports('profile.nutrition-goals'))
          ListRow(
            key: const Key('me-goals'), icon: Icons.flag_outlined, title: 'Nutrition goals',
            subtitle: profile.calorieGoal == null && profile.proteinGoal == null
                ? 'None set'
                : [if (profile.calorieGoal != null) '${profile.calorieGoal} kcal', if (profile.proteinGoal != null) '${profile.proteinGoal} g protein'].join(' · '),
            onTap: () => push(context, NutritionGoalsScreen(profile: profile)),
          ),
        const SizedBox(height: 14),
        Text('Units', style: context.sansStyle(16, weight: FontWeight.w500)),
        const SizedBox(height: 8),
        Segmented<String>(values: const ['kg', 'lb'], selected: profile?.loadUnit ?? 'kg', keyPrefix: 'unit', label: (v) => v == 'kg' ? 'Kilograms' : 'Pounds', onChanged: setUnit),
        const SizedBox(height: 8),
        Text('Changes how loads are entered and shown. Your recorded training is stored in kilograms and is never rewritten. Time is shown in minutes and seconds.', style: context.caption),
        const SizedBox(height: 6),
        if (profile != null) ...[
          ListRow(
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
                } on LocalSaveFailure {
                  if (context.mounted) toast(context, 'That preference could not be saved on this phone.');
                }
              },
            ),
          ),
          if (profile.remindersEnabled)
            ListRow(
              key: const Key('me-reminder-time'),
              icon: Icons.schedule,
              title: 'Reminder time',
              subtitle: '${profile.reminderLocalTime ?? '18:00'} · this phone\'s local time',
              onTap: () async {
                final parts = (profile.reminderLocalTime ?? '18:00').split(':');
                final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                if (picked == null) return;
                await ref.read(profileRepositoryProvider).update(profile,
                    reminderLocalTime: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
              },
            ),
        ],

        const SizedBox(height: 26),
        const SectionHeader('Account'),
        const SizedBox(height: 4),
        ListRow(
          key: const Key('me-sync'),
          icon: issues > 0 ? Icons.rule : pending > 0 ? Icons.phone_iphone : Icons.cloud_done_outlined,
          title: issues > 0 ? '$issues saved ${issues == 1 ? 'change needs' : 'changes need'} review' : pending > 0 ? '$pending ${pending == 1 ? 'change' : 'changes'} saved on this phone, waiting to sync' : 'Everything is saved to your account',
          subtitle: issues > 0 ? 'Nothing was lost. Tap to review.' : ref.watch(connectionProvider) == false ? 'Offline right now' : null,
          onTap: issues > 0 ? () => push(context, const SyncReviewScreen()) : () => refreshFromAccount(ref),
        ),
        ListRow(
          key: const Key('me-sign-out'), icon: Icons.logout, title: 'Sign out',
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
        ListRow(key: const Key('me-delete-account'), icon: Icons.delete_forever_outlined, title: 'Delete account', subtitle: 'Permanently erases your account and data', onTap: () => push(context, const DeleteAccountScreen())),
        const SizedBox(height: 14),
        Text('GoHard 0.1.0 · contract ${AppConfig.contractVersion}\nServer: ${AppConfig.apiBase}', style: context.caption),
      ],
    );
  }
}

String modeLabel(ThemeMode mode) => switch (mode) { ThemeMode.light => 'Light', ThemeMode.dark => 'Dark', ThemeMode.system => 'System' };

/// The primary plan at a glance, from recorded results only: completion, calendar position, and each week so far.
class _Overview extends StatelessWidget {
  const _Overview({required this.plan, required this.today, required this.workouts, required this.onTap});
  final Plan plan;
  final String today;
  final List<Workout> workouts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final block = Completion.of(plan.occasions, workouts);
    final position = planWeek(plan, today);
    // Weeks that have begun; the three most recent, newest last.
    final begun = [for (final w in planWeeks(plan, today, workouts)) if (w.isPast || w.isCurrent) w];
    final recent = begun.length > 3 ? begun.sublist(begun.length - 3) : begun;
    return Semantics(
      button: true,
      child: Material(
        color: context.c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel), side: BorderSide(color: context.c.divider)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('me-plan'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
                Text(plan.title, style: context.titleStyle(19)),
                Text('${plan.isPaused ? 'Paused · ' : ''}${position == 0 ? 'Starts ${dayMonth(plan.startDate)}' : 'Week $position of ${plan.blockWeeks}'}', style: context.sansStyle(14.5, color: context.c.secondary)),
              ]),
              const SizedBox(height: 10),
              Text('${block.completed} of ${block.eligible} workouts completed', style: context.sansStyle(16, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ProgressRail(block.fraction, label: 'Workouts completed in this plan')),
                const SizedBox(width: 12),
                ExcludeSemantics(child: Text('${(block.fraction * 100).round()}%', style: context.sansStyle(15, weight: FontWeight.w600))),
              ]),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Rule(),
                const SizedBox(height: 12),
                Text('Week history', style: context.label),
                for (final w in recent)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
                      Text('Week ${w.number} · ${w.range}', style: context.sansStyle(15)),
                      Text(w.completion.eligible == 0 ? 'No workouts' : '${w.completion.completed} of ${w.completion.eligible} completed', style: context.sansStyle(15, color: context.c.secondary)),
                    ]),
                  ),
              ],
            ]),
          ),
        ),
      ),
    );
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
    final plan = ref.watch(primaryPlanProvider);
    final today = ref.watch(todayKeyProvider);
    final block = plan == null ? null : Completion.of(plan.occasions, ref.watch(workoutListProvider));
    final position = plan == null ? 0 : planWeek(plan, today);
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
      Row(children: [
        for (final a in Accent.values)
          Expanded(child: _Swatch(accent: a, colors: GoColors.of(a, brightness), selected: a == appearance.accent, onTap: () => set.setAccent(a))),
      ]),
      const SizedBox(height: 8),
      Text('Applies across Today, Train, Eat and Me.', style: context.caption),
      const SizedBox(height: 26),
      const SectionHeader('Preview'),
      const SizedBox(height: 12),
      PassCard(
        title: plan?.title ?? 'No plan yet',
        week: plan == null || position == 0 ? null : 'Week $position of ${plan.blockWeeks}',
        count: block == null ? '0' : '${block.completed} / ${block.eligible}', caption: 'Workouts completed', progress: block?.fraction ?? 0,
      ),
      if (plan != null) ...[
        const SizedBox(height: 14),
        PrimaryButton('View plan', key: const Key('appearance-view-plan'), onPressed: () {
          ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);
          Navigator.of(context).popUntil((r) => r.isFirst);
        }),
      ],
      const SizedBox(height: 12),
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
            if (!selected) HapticFeedback.selectionClick();
            onTap();
          },
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                AnimatedContainer(
                  duration: context.motion(Motion.quick),
                  width: 64, height: 64, padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? colors.accent : Colors.transparent, width: 3)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
                    child: selected ? Icon(Icons.check_rounded, size: 28, color: colors.onAccent) : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(accent.label, style: context.sansStyle(15, weight: selected ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );
}

/// Display name is free text you see in the app. It is not your sign-in email. Save or cancel explicitly.
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
        title: 'Your name',
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
    if (!await confirm(context, title: 'Delete your account?', body: 'Your account and all of its workouts, food, plans and measurements will be permanently erased. This cannot be undone.', action: 'Delete everything') || !mounted) return;
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
        PrimaryButton('Delete my account', key: const Key('delete-confirm'), busy: _busy, onPressed: _delete),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep my account')),
      ]),
      children: [
        Text('This permanently erases your account and everything in it, on the server and on this phone. Signing out is different: it keeps everything.', style: context.body),
        if (pending > 0)
          Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.warning_amber, '$pending change${pending == 1 ? '' : 's'} on this phone ${pending == 1 ? 'has' : 'have'} not synced yet and will be erased too.', tone: Tone.warning)),
        const SizedBox(height: 16),
        TextField(key: const Key('delete-password'), controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Your password')),
      ],
    );
  }
}
