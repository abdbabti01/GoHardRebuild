import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../activity/activity_screens.dart';
import '../plans/plan_screens.dart';
import '../shell/home_shell.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'account_repository.dart';
import 'sync_review_screen.dart';

/// Me: identity, the current training setup, history, shared preferences and account lifecycle.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final session = ref.watch(sessionProvider);
    final primary = ref.watch(primaryPlanProvider);
    final drafts = ref.watch(planListProvider).where((p) => p.isDraft && !p.isArchived).toList();
    final workouts = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w];
    final open = workouts.where((w) => w.isOpen).toList();
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final issues = ref.watch(issuesProvider).value?.length ?? 0;
    final name = profile?.displayName ?? session?.email ?? '';

    Future<void> setPreference({String? appearance, String? loadUnit}) async {
      if (profile == null) return;
      try {
        await ref.read(profileRepositoryProvider).update(profile, appearance: appearance, loadUnit: loadUnit);
      } on LocalSaveFailure {
        if (context.mounted) toast(context, 'That preference could not be saved on this phone.');
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(context.inset, 12, context.inset, 28),
      children: [
        const Serif('Me'),
        const SizedBox(height: 16),
        Row(children: [
          ExcludeSemantics(
            child: CircleAvatar(radius: 30, backgroundColor: context.ec.selected, child: Text(name.isEmpty ? '' : name[0].toUpperCase(), style: context.sansStyle(24, weight: FontWeight.w600))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, key: const Key('me-name'), style: context.serifStyle(30)),
              if (session != null) Text(session.email, style: context.caption),
            ]),
          ),
        ]),
        if (profile != null)
          Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('me-edit-name'), onPressed: () => push(context, EditNameScreen(profile: profile)), child: const Text('Edit name')))
        else
          const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.hourglass_empty, 'Your profile has not loaded on this phone yet.')),

        const SizedBox(height: 22),
        const Serif('Your training', size: 27),
        const SizedBox(height: 8),
        if (primary != null)
          ListRow(icon: Icons.event_note, title: primary.title, subtitle: '${primary.isPaused ? 'Paused · ' : ''}${primary.setup == null ? 'Your own plan' : setupSummary(primary.setup!)}',
              onTap: () => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan))
        else if (drafts.isNotEmpty)
          ListRow(icon: Icons.event_note, title: drafts.last.title, subtitle: 'Draft · not started', onTap: () => push(context, PlanReviewScreen(planId: drafts.last.id)))
        else
          ListRow(icon: Icons.event_note, title: 'No plan yet', subtitle: 'Create a plan to review', onTap: () => push(context, const PlanSetupScreen())),
        for (final w in open) ListRow(icon: Icons.timelapse, title: w.title, subtitle: 'In progress', onTap: () => resumeWorkout(context, ref, w)),
        ListRow(key: const Key('me-history'), icon: Icons.history, title: 'Workout history', subtitle: workouts.isEmpty ? 'Nothing recorded yet' : '${workouts.length} workout${workouts.length == 1 ? '' : 's'}', onTap: () => push(context, const WorkoutHistoryScreen())),
        ListRow(icon: Icons.insights, title: 'Progress', onTap: () => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.progress)),
        ListRow(icon: Icons.directions_run, title: 'Run history', onTap: () => push(context, const RunHistoryScreen())),
        ListRow(icon: Icons.monitor_weight_outlined, title: 'Body measurements', onTap: () => push(context, const BodyMetricsScreen())),

        const SizedBox(height: 22),
        const Serif('Appearance', size: 27),
        const SizedBox(height: 10),
        for (final (value, label) in const [('dark', 'Dark'), ('light', 'Light'), ('system', 'Match this phone')])
          ChoiceTile(key: Key('appearance-$value'), value: value, groupValue: ref.watch(appearanceProvider), title: label, onChanged: (v) => setPreference(appearance: v)),

        const SizedBox(height: 14),
        const Serif('Units', size: 27),
        const SizedBox(height: 10),
        for (final (value, label) in const [('kg', 'Kilograms'), ('lb', 'Pounds')])
          ChoiceTile(key: Key('unit-$value'), value: value, groupValue: profile?.loadUnit ?? 'kg', title: label, onChanged: (v) => setPreference(loadUnit: v)),
        Text('Changes how loads are entered and shown. Your recorded training is stored in kilograms and is never rewritten. Time is shown in minutes and seconds.', style: context.caption),

        const SizedBox(height: 22),
        const Serif('Account', size: 27),
        const SizedBox(height: 8),
        ListRow(
          key: const Key('me-sync'),
          icon: issues > 0 ? Icons.rule : pending > 0 ? Icons.phone_iphone : Icons.cloud_done_outlined,
          title: issues > 0 ? '$issues saved ${issues == 1 ? 'change needs' : 'changes need'} review' : pending > 0 ? '$pending ${pending == 1 ? 'change' : 'changes'} saved on this phone, waiting to sync' : 'Everything is saved to your account',
          subtitle: issues > 0 ? 'Nothing was lost. Tap to review.' : ref.watch(connectionProvider) == false ? 'Offline right now' : null,
          onTap: issues > 0 ? () => push(context, const SyncReviewScreen()) : () => refreshFromAccount(ref),
        ),
        if (!Capabilities.deviceReminders) const ListRow(icon: Icons.notifications_off_outlined, title: 'Workout reminders', subtitle: 'Not available in this build'),
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
  Widget build(BuildContext context) => EveningPage(
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
    return EveningPage(
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
