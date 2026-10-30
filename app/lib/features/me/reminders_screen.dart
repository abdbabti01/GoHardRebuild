import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/device_prefs.dart' show Haptics;
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../nutrition/food_repository.dart' show mealLabel;
import '../nutrition/meal_habits_ui.dart' show usualLogTimeProvider;
import '../shell/home_shell.dart' show shellProvider;
import '../weather/weather.dart' show weatherLocatorProvider;
import 'reminders.dart';

/// Me › Reminders (docs/MEAL_HABITS_REMINDERS.md › Reminders): the one place for workout, meal, medication and supplement
/// reminders. Nothing is scheduled until the person adds a reminder and leaves it on; notification permission is asked
/// for only then.

/// "8:30 AM" or "08:30", as the phone says times.
String timeLabel(BuildContext context, String hhmm) {
  final p = hhmm.split(':');
  return MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
}

String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String categoryLabel(AppLocalizations l, ReminderCategory c) => switch (c) {
      ReminderCategory.meal => l.reminderCategoryMeal,
      ReminderCategory.medication => l.reminderCategoryMedication,
      ReminderCategory.supplement => l.reminderCategorySupplement,
    };

IconData _icon(ReminderCategory c) => switch (c) {
      ReminderCategory.meal => Icons.restaurant_outlined,
      ReminderCategory.medication => Icons.medication_outlined,
      ReminderCategory.supplement => Icons.eco_outlined,
    };

/// "Every day", "Weekdays", or the days themselves in the week's order.
String daysLabel(AppLocalizations l, List<int> days) => days.length == 7
    ? l.reminderEveryDay
    : days.length == 5 && days.every((d) => d <= 5)
        ? l.reminderWeekdays
        : days.map(weekdayShort).join(', ');

/// Workout reminders on or off (Reminders, setup). Notification permission is asked for only here, when they are turned on.
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

/// Turns one of the person's reminders on or off. On asks for notification permission first; a refusal keeps the
/// reminder and says how to allow notifications.
Future<void> setReminderOn(BuildContext context, WidgetRef ref, Reminder r, bool on) async {
  if (on && !await ref.read(reminderSchedulerProvider).requestPermission() && context.mounted) toast(context, context.l10n.reminderNotAllowed);
  await ref.read(reminderRepositoryProvider).setEnabled(r, on);
}

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  // Read from the phone each time the page opens and on return from Settings, never assumed.
  late final AppLifecycleListener _life = AppLifecycleListener(onResume: _read);
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _life;
    _read();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    bool? allowed;
    try {
      allowed = await ref.read(reminderSchedulerProvider).notificationsAllowed();
    } on Object {
      allowed = null;
    }
    if (mounted) setState(() => _allowed = allowed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.watch(profileProvider).value;
    final own = ref.watch(remindersProvider).value ?? const <Reminder>[];
    final logs = ref.watch(doseLogsProvider).value ?? const <String, DoseLog>{};
    final today = ref.watch(todayKeyProvider);
    final through = ref.watch(reminderHorizonProvider);
    final anyOn = (profile?.remindersEnabled ?? false) || own.any((r) => r.enabled);
    final doses = [for (final r in own) if (r.isDose && r.enabled && r.weekdays.contains(parseDayKey(today).weekday)) r];

    return AppPage(
      title: l.remindersTitle,
      subtitle: l.remindersSubtitle,
      children: [
        if (anyOn && _allowed == false) ...[
          Panel(
            key: const Key('reminders-denied'),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StatusLine(Icons.notifications_off_outlined, l.reminderDenied, tone: Tone.warning),
              const SizedBox(height: 8),
              SecondaryButton(l.permissionsOpenSettings, key: const Key('reminders-open-settings'), onPressed: ref.read(weatherLocatorProvider).openAppSettings),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (doses.isNotEmpty) ...[
          SectionHeader(l.reminderTodayHeading),
          GroupCard(children: [
            for (final r in doses)
              GroupRow(
                key: Key('dose-${r.id}'), icon: _icon(r.category), title: r.name, subtitle: timeLabel(context, r.time),
                value: _statusLabel(l, logs[r.occurrence(today)]), onTap: () => showDoseSheet(context, r, today),
              ),
          ]),
          const SizedBox(height: 8),
        ],
        SectionHeader(l.reminderWorkoutHeading),
        if (profile != null)
          GroupCard(children: [
            MergeSemantics(
              child: GroupRow(
                key: const Key('me-reminders'),
                icon: profile.remindersEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                title: l.meReminders,
                subtitle: profile.remindersEnabled ? l.meRemindersOnSubtitle : l.meOff,
                trailing: Switch(value: profile.remindersEnabled, onChanged: (on) => setReminders(context, ref, profile, on)),
              ),
            ),
            if (profile.remindersEnabled)
              GroupRow(
                key: const Key('me-reminder-time'), icon: Icons.schedule, title: l.meReminderTime, subtitle: l.meReminderTimeSubtitle,
                value: timeLabel(context, profile.reminderLocalTime ?? '18:00'),
                onTap: () async {
                  final parts = (profile.reminderLocalTime ?? '18:00').split(':');
                  final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                  if (picked == null) return;
                  await ref.read(profileRepositoryProvider).update(profile, reminderLocalTime: _hhmm(picked));
                },
              ),
          ]),
        const SizedBox(height: 8),
        SectionHeader(l.reminderOwnHeading),
        if (own.isEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(l.reminderNone, key: const Key('reminders-empty'), style: context.caption))
        else
          GroupCard(children: [
            for (final r in own)
              MergeSemantics(
                child: GroupRow(
                  key: Key('reminder-${r.id}'), icon: _icon(r.category), title: r.name,
                  subtitle: [categoryLabel(l, r.category), timeLabel(context, r.time), daysLabel(l, r.weekdays), if (!r.enabled) l.reminderPaused].join(' · '),
                  onTap: () => push(context, ReminderEditorScreen(existing: r)),
                  trailing: Switch(key: Key('reminder-switch-${r.id}'), value: r.enabled, onChanged: (on) => setReminderOn(context, ref, r, on)),
                ),
              ),
          ]),
        const SizedBox(height: 12),
        SecondaryButton(l.reminderAdd, key: const Key('reminder-add'), icon: Icons.add, onPressed: () => push(context, const ReminderEditorScreen())),
        const SizedBox(height: 18),
        if (through != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusLine(Icons.event_available, l.reminderThrough(longDate(through)), key: const Key('reminders-through'))),
        Text(l.reminderPolicy, key: const Key('reminders-policy'), style: context.caption),
      ],
    );
  }
}

/// Unconfirmed until the person says otherwise: never "not taken".
String _statusLabel(AppLocalizations l, DoseLog? log) => switch (log?.status) {
      null => l.reminderUnconfirmed,
      DoseStatus.taken => l.reminderStatusTaken,
      DoseStatus.skipped => l.reminderStatusSkipped,
      DoseStatus.snoozed => l.reminderStatusSnoozed,
    };

/// The confirmation for one occurrence of a medication or supplement reminder: Taken, Snooze or Skip. Opening it, or
/// closing it, records nothing.
Future<void> showDoseSheet(BuildContext context, Reminder r, String day) => showGoSheet<void>(context, title: r.name, builder: (sheet) => Consumer(builder: (sheet, ref, _) {
      final l = sheet.l10n;
      final log = ref.watch(doseLogsProvider).value?[r.occurrence(day)];
      Future<void> answer(DoseStatus s) async {
        await ref.read(reminderRepositoryProvider).answer(r, day, s);
        if (sheet.mounted) Navigator.pop(sheet);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.reminderOccurrence(longDate(day), timeLabel(sheet, r.time)), style: sheet.body),
        if (r.instructions.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.instructions.trim(), key: const Key('dose-instructions'), style: sheet.caption)),
        const SizedBox(height: 10),
        StatusLine(Icons.info_outline, _statusLabel(l, log), key: const Key('dose-status')),
        const SizedBox(height: 14),
        PrimaryButton(l.reminderTaken, key: const Key('dose-taken'), onPressed: () => answer(DoseStatus.taken)),
        const SizedBox(height: 8),
        SecondaryButton(l.reminderSnoozeFor(snoozeFor.inMinutes), key: const Key('dose-snooze'), onPressed: () => answer(DoseStatus.snoozed)),
        TextButton(key: const Key('dose-skip'), onPressed: () => answer(DoseStatus.skipped), child: Text(l.reminderSkip)),
      ]);
    }));

/// A reminder being made or changed. A suggested meal time appears only when the records support it, beside Choose my
/// own time; it never replaces a time the person chose.
class ReminderEditorScreen extends ConsumerStatefulWidget {
  const ReminderEditorScreen({super.key, this.existing, this.category, this.meal});
  final Reminder? existing;
  final ReminderCategory? category;
  final String? meal;
  @override
  ConsumerState<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  Reminder? get _r => widget.existing;
  late ReminderCategory _category = _r?.category ?? widget.category ?? ReminderCategory.meal;
  late String _meal = _r?.meal ?? widget.meal ?? meals.first;
  late String? _time = _r?.time;
  late final Set<int> _days = {...(_r?.weekdays ?? const [1, 2, 3, 4, 5, 6, 7])};
  late bool _private = _r?.private ?? _category == ReminderCategory.medication;
  late bool _on = _r?.enabled ?? true;
  late final _name = TextEditingController(text: _r?.name);
  late final _instructions = TextEditingController(text: _r?.instructions);
  bool _named = false, _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A new meal reminder starts with a name the person can change ("Log breakfast").
    if (_r == null && !_named && _category == ReminderCategory.meal) _name.text = context.l10n.reminderMealDefaultName(mealLabel(context.l10n, _meal).toLowerCase());
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final p = (_time ?? '08:00').split(':');
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
    if (picked != null) setState(() => _time = _hhmm(picked));
  }

  Future<void> _save() async {
    if (_busy) return;
    final l = context.l10n, name = _name.text.trim();
    final problem = name.isEmpty || name.length > 60 ? l.reminderProblemName : _time == null ? l.reminderProblemTime : _days.isEmpty ? l.reminderProblemDays : null;
    if (problem != null) return setState(() => _error = problem);
    setState(() => _busy = true);
    final allowed = !_on || await ref.read(reminderSchedulerProvider).requestPermission();
    try {
      await ref.read(reminderRepositoryProvider).put({
        ...?_r?.j,
        'name': name, 'category': _category.name, 'meal': _category == ReminderCategory.meal ? _meal : null, 'time': _time, 'weekdays': (_days.toList()..sort()),
        'enabled': _on, 'instructions': _instructions.text.trim(), 'private': _private,
      });
    } on LocalSaveFailure {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.mePrefNotSaved;
        });
      }
      return;
    }
    if (!mounted) return;
    toast(context, allowed ? l.reminderSaved : l.reminderNotAllowed);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await confirm(context, title: l.reminderDeleteTitle(_r!.name), body: l.reminderDeleteBody, action: l.actionDelete, destructive: true)) return;
    await ref.read(reminderRepositoryProvider).remove(_r!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final meal = _category == ReminderCategory.meal;
    // Only for a new meal reminder with no time chosen yet: a learnt time never overwrites one.
    final suggested = meal && _r == null && _time == null ? ref.watch(usualLogTimeProvider(_meal)) : null;
    // Monday first unless the phone's week starts on Sunday.
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex == 0 ? 7 : 1;
    final order = [for (var i = 0; i < 7; i++) (first + i - 1) % 7 + 1];
    return AppPage(
      title: _r == null ? l.reminderNewTitle : l.reminderEditTitle,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, key: const Key('reminder-error'), tone: Tone.error)),
        PrimaryButton(l.actionSave, key: const Key('reminder-save'), busy: _busy, onPressed: _save),
        if (_r != null) TextButton.icon(key: const Key('reminder-delete'), onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline, size: 18), label: Text(l.actionDelete)),
      ]),
      children: [
        if (_r == null) ...[
          Segmented<ReminderCategory>(
            keyPrefix: 'reminder-category', values: ReminderCategory.values, selected: _category, label: (c) => categoryLabel(l, c),
            onChanged: (c) => setState(() {
              _category = c;
              _private = c == ReminderCategory.medication;
              if (!_named) _name.text = c == ReminderCategory.meal ? l.reminderMealDefaultName(mealLabel(l, _meal).toLowerCase()) : '';
            }),
          ),
          const SizedBox(height: 14),
        ],
        if (meal) ...[
          DropdownButtonFormField<String>(
            key: const Key('reminder-meal'), initialValue: _meal, isExpanded: true, dropdownColor: context.c.surface,
            decoration: InputDecoration(labelText: l.foodMealLabel),
            items: [for (final m in meals) DropdownMenuItem(value: m, child: Text(mealLabel(l, m)))],
            onChanged: (m) => setState(() {
              _meal = m ?? _meal;
              if (!_named && _r == null) _name.text = l.reminderMealDefaultName(mealLabel(l, _meal).toLowerCase());
            }),
          ),
          const SizedBox(height: 14),
        ],
        TextField(key: const Key('reminder-name'), controller: _name, maxLength: 60, textCapitalization: TextCapitalization.sentences, onChanged: (_) => _named = true,
            decoration: InputDecoration(labelText: meal ? l.reminderNameLabel : l.reminderDoseNameLabel)),
        const SizedBox(height: 6),
        if (suggested != null)
          Panel(
            key: const Key('reminder-suggested'),
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.reminderSuggestedTime(mealLabel(l, _meal).toLowerCase(), timeLabel(context, suggested)), style: context.body),
              Wrap(spacing: 4, children: [
                TextButton(key: const Key('reminder-use-suggested'), onPressed: () => setState(() => _time = suggested), child: Text(l.reminderUseTime(timeLabel(context, suggested)))),
                TextButton(key: const Key('reminder-own-time'), onPressed: _pickTime, child: Text(l.reminderOwnTime)),
              ]),
            ]),
          )
        else
          GroupCard(children: [
            GroupRow(key: const Key('reminder-time'), icon: Icons.schedule, title: l.reminderTimeLabel, value: _time == null ? l.reminderOwnTime : timeLabel(context, _time!), onTap: _pickTime),
          ]),
        const SizedBox(height: 16),
        Text(l.reminderDaysLabel, style: context.label),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in order)
            FilterChip(
              key: Key('reminder-day-$d'), label: Text(weekdayShort(d)), tooltip: weekdayName(d), selected: _days.contains(d),
              onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(key: const Key('reminder-instructions'), controller: _instructions, maxLength: 200, maxLines: 3, minLines: 1, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.reminderInstructionsLabel, helperText: meal ? null : l.reminderInstructionsHelp, helperMaxLines: 3)),
        const SizedBox(height: 8),
        GroupCard(children: [
          MergeSemantics(
            child: GroupRow(key: const Key('reminder-private'), icon: Icons.lock_outline, title: l.reminderPrivateLabel, subtitle: l.reminderPrivateHelp,
                trailing: Switch(value: _private, onChanged: (v) => setState(() => _private = v))),
          ),
          MergeSemantics(
            child: GroupRow(key: const Key('reminder-on'), icon: Icons.notifications_active_outlined, title: l.reminderOnLabel, subtitle: _on ? l.meOn : l.reminderPaused,
                trailing: Switch(value: _on, onChanged: (v) => setState(() => _on = v))),
          ),
        ]),
        const SizedBox(height: 12),
        Text(meal ? l.reminderMealNote : l.reminderDoseNote, style: context.caption),
      ],
    );
  }
}

/// Answers a tap on one of GoHard's notifications once the account it belongs to is signed in here. A button records
/// that answer for that occurrence and shows it; the notification itself opens the confirmation (a medication or
/// supplement) or Eat (a meal). A notification of another account is ignored.
class NoticeResponder extends ConsumerStatefulWidget {
  const NoticeResponder({super.key});
  @override
  ConsumerState<NoticeResponder> createState() => _NoticeResponderState();
}

class _NoticeResponderState extends ConsumerState<NoticeResponder> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(noticeResponseProvider, (_, r) {
      if (r != null) WidgetsBinding.instance.addPostFrameCallback((_) => _handle(r));
    }, fireImmediately: true);
  }

  Future<void> _handle(NoticeResponse response) async {
    ref.read(noticeResponseProvider.notifier).handled();
    final p = switch (jsonDecode(response.payload)) { final Map m => m, _ => const {} };
    if (p['o'] != ref.read(ownerProvider) || p['k'] is! String) return;
    final parts = (p['k'] as String).split('|');
    if (parts.length != 3) return;
    final r = (await ref.read(remindersProvider.future)).where((r) => r.id == p['r']).firstOrNull;
    if (r == null || !mounted) return;
    final day = parts[1];
    if (!r.isDose) {
      ref.read(shellProvider.notifier).switchTab(2); // a meal reminder: Eat, where logging is
      return;
    }
    final status = switch (response.action) { 'taken' => DoseStatus.taken, 'skip' => DoseStatus.skipped, 'snooze' => DoseStatus.snoozed, _ => null };
    if (status != null) await ref.read(reminderRepositoryProvider).answer(r, day, status);
    if (!mounted) return;
    if (status != null) {
      push(context, const RemindersScreen());
    } else {
      showDoseSheet(context, r, day);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
