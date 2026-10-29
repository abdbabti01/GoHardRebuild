import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/language.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../coach/day_coach.dart' show fingerprint;
import '../nutrition/food_repository.dart' show mealLabel;
import '../today/daily.dart';

/// Reminders (docs/MEAL_HABITS_REMINDERS.md › Reminders): workout reminders from the accepted plan, and the person's own
/// meal-logging, medication and supplement reminders. One list of phone notifications is worked out from them here and
/// handed to the scheduler, which replaces everything scheduled with exactly that list. Nothing here calls a server or
/// an AI, at scheduling time or when a reminder fires.

/// One reminder for one real commitment: an accepted, still-pending planned workout.
class PlannedReminder {
  const PlannedReminder(this.id, this.dayKey, this.title);
  final int id;
  final String dayKey, title;
}

/// Which reminders should exist. Pure: it reads accepted plan state and never infers or changes anything.
///
/// Only an ACTIVE primary plan produces reminders: a paused, closed or draft plan produces none. Skipped,
/// recorded and in-progress workouts are left out. Plan dates are floating calendar dates and are never rewritten
/// here; the wall-clock time is applied by the scheduler in whatever zone the phone is in at that moment.
List<PlannedReminder> plannedReminders({required bool enabled, required Plan? primary, required List<Workout> workouts, required String today, int limit = 30}) {
  if (!enabled || primary == null || !primary.isActive) return const [];
  return [
    for (final o in primary.occasions)
      if (o.scheduledDate.compareTo(today) >= 0 && const [OccasionStatus.due, OccasionStatus.upcoming].contains(statusOf(o, primary, today, workouts)))
        PlannedReminder(o.id.hashCode & 0x3fffffff, o.scheduledDate, o.title),
  ].take(limit).toList();
}

// ---------------------------------------------------------------------------- the person's own reminders

enum ReminderCategory { meal, medication, supplement }

/// A reminder the person made. Its time is a wall-clock time ("08:30") in whatever zone the phone is in on that day.
/// Kept on this phone for this account only ([Kinds.reminder]): never sent to the account or to any AI.
extension type Reminder(Json j) {
  String get id => j['id'] as String;
  String get name => j['name'] as String? ?? '';
  ReminderCategory get category => ReminderCategory.values.asNameMap()[j['category']] ?? ReminderCategory.meal;
  bool get isDose => category != ReminderCategory.meal;

  /// For a meal reminder: the meal it is about (Breakfast …), whose logging suppresses that day's reminder.
  String? get meal => meals.contains(j['meal']) ? j['meal'] as String : null;
  String get time => j['time'] as String? ?? '08:00';
  int get minute => int.parse(time.split(':')[0]) * 60 + int.parse(time.split(':')[1]);

  /// ISO weekdays (1 = Monday). Empty never happens for a saved reminder.
  List<int> get weekdays => [for (final d in j['weekdays'] as List? ?? const [1, 2, 3, 4, 5, 6, 7]) d as int]..sort();
  bool get enabled => j['enabled'] as bool? ?? false;
  String get instructions => j['instructions'] as String? ?? '';

  /// Lock-screen discretion: the notification says only "GoHard reminder", never the name or instructions.
  bool get private => j['private'] as bool? ?? false;

  /// The key of one occurrence of this reminder: confirmations are stored against it.
  String occurrence(String day) => '$id|$day|$time';
}

enum DoseStatus { taken, skipped, snoozed }

/// What the person said about one occurrence of a medication or supplement reminder ([Kinds.reminderLog], id = the
/// occurrence key). No record means Unconfirmed: never "not taken".
extension type DoseLog(Json j) {
  String get reminderId => j['reminderId'] as String;
  String get day => j['day'] as String;
  String get time => j['time'] as String;
  DoseStatus get status => DoseStatus.values.asNameMap()[j['status']] ?? DoseStatus.snoozed;
  DateTime? get snoozeUntil => DateTime.tryParse(j['snoozeUntilUtc'] as String? ?? '');
}

/// How long Snooze waits. It moves only that one occurrence: the recurring schedule is unchanged.
const snoozeFor = Duration(minutes: 10);

/// The most notifications GoHard keeps scheduled at once. iOS keeps at most 64 per app; some room is left.
const noticeBudget = 60;

/// How many days ahead a person's own reminders are scheduled. Opening GoHard schedules the following days.
const horizonDays = 7;

enum NoticeChannel { workout, meal, dose }

/// One phone notification, with everything the scheduler needs. [day] + [time] is a wall-clock moment in the phone's
/// zone at scheduling time; [atUtc] (a snooze) is an instant.
class Notice {
  const Notice({required this.id, required this.title, required this.body, this.day, this.time, this.atUtc, this.payload, this.channel = NoticeChannel.workout, this.private = false});
  final int id;
  final String title, body;
  final String? day, time, payload;
  final DateTime? atUtc;
  final NoticeChannel channel;
  final bool private;

  /// Sorts by when it fires (a snooze first: it is always soon).
  String get order => atUtc != null ? '0' : '1$day $time';
}

int noticeId(String key) => int.parse(fingerprint(key), radix: 16) & 0x3fffffff;

/// The notifications for [reminders] from [today] for [horizonDays] days, earliest first:
/// * paused reminders and other weekdays give none; an occurrence earlier today than [nowMinute] is left out;
/// * a meal reminder is left out for today once that meal is in today's journal ([loggedToday]);
/// * a dose occurrence answered Taken or Skipped is left out; one snoozed until later gets one notification then.
/// The words follow [l]; a private reminder says only that there is a reminder.
List<Notice> reminderNotices(List<Reminder> reminders, {required Map<String, DoseLog> logs, required String today, required int nowMinute, required DateTime nowUtc,
    required Set<String> loggedToday, required String owner, required AppLocalizations l}) {
  final out = <Notice>[];
  for (final r in reminders) {
    if (!r.enabled || r.weekdays.isEmpty) continue;
    for (var i = 0; i < horizonDays; i++) {
      final day = addDays(today, i);
      if (!r.weekdays.contains(parseDayKey(day).weekday)) continue;
      if (i == 0 && r.minute <= nowMinute) continue;
      if (i == 0 && r.meal != null && loggedToday.contains(r.meal)) continue;
      final key = r.occurrence(day), log = logs[key];
      if (r.isDose && log != null && log.status != DoseStatus.snoozed) continue;
      out.add(_notice(r, key, day: day, owner: owner, l: l));
    }
  }
  for (final log in logs.values) {
    final until = log.snoozeUntil;
    final r = reminders.where((r) => r.id == log.reminderId).firstOrNull;
    if (log.status != DoseStatus.snoozed || until == null || !until.isAfter(nowUtc) || r == null || !r.enabled) continue;
    out.add(_notice(r, '${r.id}|${log.day}|${log.time}', snoozeUntil: until, owner: owner, l: l));
  }
  return out;
}

Notice _notice(Reminder r, String key, {String? day, DateTime? snoozeUntil, required String owner, required AppLocalizations l}) {
  final meal = r.meal;
  final hidden = r.private;
  return Notice(
    id: noticeId(snoozeUntil == null ? key : 'snooze|$key'),
    title: hidden ? l.reminderPrivateTitle : r.name,
    body: hidden
        ? l.reminderPrivateBody
        : r.instructions.trim().isNotEmpty
            ? r.instructions.trim()
            : switch (r.category) {
                ReminderCategory.meal => l.reminderMealBody(mealLabel(l, meal ?? 'Breakfast').toLowerCase()),
                ReminderCategory.medication => l.reminderDoseBody,
                ReminderCategory.supplement => l.reminderDoseBody,
              },
    day: day, time: r.time, atUtc: snoozeUntil,
    payload: jsonEncode({'o': owner, 'r': r.id, 'k': key}),
    channel: r.isDose ? NoticeChannel.dose : NoticeChannel.meal,
    private: hidden,
  );
}

/// Every notice in when-it-fires order, at most [noticeBudget]: what is left out is the latest, scheduled when the
/// app is next opened. Returns the notices and the last day fully scheduled (null when nothing was left out).
({List<Notice> notices, String? through}) withinBudget(List<Notice> all) {
  final sorted = [...all]..sort((a, b) => a.order.compareTo(b.order));
  if (sorted.length <= noticeBudget) return (notices: sorted, through: null);
  final kept = sorted.take(noticeBudget).toList();
  final firstLeft = sorted[noticeBudget].day!;
  return (notices: kept.where((n) => n.day == null || n.day!.compareTo(firstLeft) < 0).toList(), through: addDays(firstLeft, -1));
}

/// A tap on a notification or one of its buttons ('taken', 'snooze', 'skip'; null = the notification itself).
typedef NoticeResponse = ({String payload, String? action});

abstract interface class ReminderScheduler {
  /// Asks for notification permission. Called only when the user turns a reminder on, never at startup.
  Future<bool> requestPermission();

  /// Whether the phone currently allows GoHard's notifications, without asking. Null when it cannot say.
  Future<bool?> notificationsAllowed();

  /// Replaces every scheduled notification with exactly [notices].
  Future<void> replaceAll(List<Notice> notices);
}

class DeviceReminderScheduler implements ReminderScheduler {
  /// [l10n] is read when reminders are (re)scheduled, so their words follow the app language at that moment.
  /// [onResponse] receives taps on GoHard's notifications, including the one that launched the app.
  DeviceReminderScheduler(this._l10n, this._onResponse);
  final AppLocalizations Function() _l10n;
  final void Function(NoticeResponse) _onResponse;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;

  static const _doseCategory = 'gohard.dose';

  void _respond(NotificationResponse r) {
    if (r.payload case final p? when p.isNotEmpty) _onResponse((payload: p, action: r.actionId));
  }

  Future<void> _init() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    final l = _l10n();
    // Every button opens GoHard, where the answer is recorded and shown: nothing is recorded in the background.
    DarwinNotificationAction button(String id, String title) => DarwinNotificationAction.plain(id, title, options: {DarwinNotificationActionOption.foreground});
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false, notificationCategories: [
          DarwinNotificationCategory(_doseCategory, actions: [button('taken', l.reminderTaken), button('snooze', l.reminderSnooze), button('skip', l.reminderSkip)]),
        ]),
      ),
      onDidReceiveNotificationResponse: _respond,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      if (launch!.notificationResponse case final r?) _respond(r);
    }
  }

  /// Called at startup so a tap that launched the app is seen.
  Future<void> start() => _init();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<bool?> notificationsAllowed() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return android.areNotificationsEnabled();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return (await ios?.checkPermissions())?.isEnabled;
  }

  Future<void> _queue = Future.value();
  int _generation = 0;

  /// Replacements run one at a time and a newer request abandons an older one, so a slow "schedule 24" can never
  /// re-add reminders after a later "remove all" (sign-out, pause).
  @override
  Future<void> replaceAll(List<Notice> notices) {
    final generation = ++_generation;
    return _queue = _queue.catchError((Object _) {}).then((_) => generation == _generation ? _replace(notices, generation) : null);
  }

  Future<void> _replace(List<Notice> notices, int generation) async {
    await _init();
    await _plugin.cancelAll();
    if (notices.isEmpty) return;
    // The zone is read now, so travelling or a zone change simply re-times future reminders on the next rebuild.
    final location = tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier);
    final now = tz.TZDateTime.now(location);
    final l = _l10n();
    for (final n in notices) {
      if (generation != _generation) return; // superseded: the newer request starts from a clean slate
      final at = noticeTime(n, location);
      if (!at.isAfter(now)) continue; // already passed: no late nag
      final (channel, name, description) = switch (n.channel) {
        // The channel IDs never change; Android updates the shown name and description in place.
        NoticeChannel.workout => ('workout_reminders', l.reminderChannelName, l.reminderChannelDescription),
        NoticeChannel.meal => ('meal_reminders', l.reminderMealChannelName, l.reminderMealChannelDescription),
        NoticeChannel.dose => ('dose_reminders', l.reminderDoseChannelName, l.reminderDoseChannelDescription),
      };
      final dose = n.channel == NoticeChannel.dose;
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: at,
        payload: n.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(channel, name, channelDescription: description,
              visibility: n.private ? NotificationVisibility.private : NotificationVisibility.public,
              actions: dose
                  ? [
                      AndroidNotificationAction('taken', l.reminderTaken, showsUserInterface: true, cancelNotification: true),
                      AndroidNotificationAction('snooze', l.reminderSnooze, showsUserInterface: true, cancelNotification: true),
                      AndroidNotificationAction('skip', l.reminderSkip, showsUserInterface: true, cancelNotification: true),
                    ]
                  : null),
          iOS: DarwinNotificationDetails(categoryIdentifier: dose ? _doseCategory : null),
        ),
        // Inexact on purpose: a reminder needs no exact-alarm permission, and the phone may deliver it a little late.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

/// When [n] fires in [location]. A wall-clock time that does not exist that day (the hour skipped when clocks go
/// forward) becomes the same time after the change; a time that happens twice (clocks go back) fires once, at the first.
tz.TZDateTime noticeTime(Notice n, tz.Location location) {
  if (n.atUtc != null) return tz.TZDateTime.from(n.atUtc!, location);
  final day = parseDayKey(n.day!), parts = n.time!.split(':');
  return tz.TZDateTime(location, day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
}

/// The last notification tap not yet handled. The shell takes it once the right account is in.
class NoticeResponses extends Notifier<NoticeResponse?> {
  @override
  NoticeResponse? build() => null;
  void received(NoticeResponse r) => state = r;
  void handled() => state = null;
}

final noticeResponseProvider = NotifierProvider<NoticeResponses, NoticeResponse?>(NoticeResponses.new);

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final s = DeviceReminderScheduler(() => ref.read(appL10nProvider), (r) => ref.read(noticeResponseProvider.notifier).received(r));
  s.start().ignore();
  return s;
});

/// This account's own reminders on this phone, by name.
final remindersProvider = StreamProvider<List<Reminder>>((ref) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return Stream.value(const []);
  return ref.watch(syncProvider).watch(owner, Kinds.reminder).map((rows) => [for (final r in rows) Reminder(jsonDecode(r.body) as Json)]
    ..sort((a, b) => a.minute != b.minute ? a.minute.compareTo(b.minute) : a.name.toLowerCase().compareTo(b.name.toLowerCase())));
});

/// This account's answers to medication and supplement occurrences, by occurrence key.
final doseLogsProvider = StreamProvider<Map<String, DoseLog>>((ref) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return Stream.value(const {});
  return ref.watch(syncProvider).watch(owner, Kinds.reminderLog).map((rows) => {for (final r in rows) r.id: DoseLog(jsonDecode(r.body) as Json)});
});

/// Saves, removes and answers this account's reminders on this phone. Local only: nothing is queued for the account.
class ReminderRepository {
  ReminderRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  Future<String> put(Json body) async {
    final id = body['id'] as String? ?? SyncEngine.newId();
    await _sync.putLocal(_owner, LocalWrite(Kinds.reminder, id, {...body, 'id': id}));
    return id;
  }

  Future<void> setEnabled(Reminder r, bool on) => put({...r.j, 'enabled': on});

  /// Removes the reminder. Answers already given stay in this phone's history.
  Future<void> remove(Reminder r) => _sync.deleteLocal(_owner, Kinds.reminder, r.id);

  /// Records one answer for one occurrence. The same answer twice is one record; a later answer replaces an earlier one.
  Future<void> answer(Reminder r, String day, DoseStatus status, {DateTime? nowUtc}) {
    final now = nowUtc ?? DateTime.now().toUtc();
    return _sync.putLocal(_owner, LocalWrite(Kinds.reminderLog, r.occurrence(day), {
      'reminderId': r.id, 'day': day, 'time': r.time, 'status': status.name, 'atUtc': now.toIso8601String(),
      if (status == DoseStatus.snoozed) 'snoozeUntilUtc': now.add(snoozeFor).toIso8601String(),
    }));
  }
}

final reminderRepositoryProvider = Provider((ref) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) throw StateError('No signed-in owner');
  return ReminderRepository(ref.watch(syncProvider), owner);
});

/// The last day of the person's own reminders that is fully scheduled, when the budget left some out.
final reminderHorizonProvider = Provider<String?>((ref) => ref.watch(reminderSyncProvider).through);

/// Keeps the phone's scheduled notifications equal to the workout reminders and the person's own reminders. Watching
/// it is enough; it reschedules whenever the plan, a reminder, an answer, today's journal, the day or the app language
/// changes, and when invalidated on app resume. replaceAll cancels everything first and skips times already past, so
/// nothing is duplicated or replayed after a restart, a sign-in or an edit.
final reminderSyncProvider = Provider<({String signature, String? through})>((ref) {
  ref.watch(appLocaleProvider);
  // Signed out (or account deleted): this phone keeps no reminders for that owner. Decided here, in the one place
  // that schedules, so a late recompute with the previous owner's data can never put them back.
  final owner = ref.watch(ownerProvider);
  if (owner == null) {
    ref.watch(reminderSchedulerProvider).replaceAll(const []).ignore();
    return (signature: '', through: null);
  }
  final profile = ref.watch(profileProvider).value;
  final today = ref.watch(todayKeyProvider);
  final l = ref.watch(appL10nProvider);
  final workouts = plannedReminders(
    enabled: profile?.remindersEnabled ?? false,
    primary: ref.watch(primaryPlanProvider),
    workouts: ref.watch(workoutListProvider),
    today: today,
  );
  final time = profile?.reminderLocalTime ?? '18:00';
  final own = ref.watch(remindersProvider), logs = ref.watch(doseLogsProvider);
  final food = ref.watch(foodProvider(today)).value;
  final local = DateTime.now();
  final mine = reminderNotices(own.value ?? const [], logs: logs.value ?? const {}, today: today, nowMinute: local.hour * 60 + local.minute, nowUtc: local.toUtc(),
      loggedToday: {for (final r in food ?? const <Stored<FoodEntry>>[]) if (!r.value.isDeleted) r.value.meal}, owner: owner, l: l);
  final all = withinBudget([
    for (final r in workouts) Notice(id: r.id, title: l.reminderNotificationTitle, body: r.title, day: r.dayKey, time: time),
    ...mine,
  ]);
  final signature = all.notices.map((n) => '${n.id}@${n.day ?? n.atUtc}').join(',');
  // Until the profile, the reminders, their answers and today's journal have loaded nothing is touched, so a cold start
  // never wipes or re-adds reminders by mistake.
  if (profile != null && own.hasValue && logs.hasValue && food != null) ref.watch(reminderSchedulerProvider).replaceAll(all.notices).ignore();
  return (signature: signature, through: all.through);
});
