import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/language.dart';
import '../../data/models.dart';
import '../today/daily.dart';

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

abstract interface class ReminderScheduler {
  /// Asks for notification permission. Called only when the user turns reminders on, never at startup.
  Future<bool> requestPermission();

  /// Whether the phone currently allows GoHard's notifications, without asking. Null when it cannot say.
  Future<bool?> notificationsAllowed();

  /// Replaces every scheduled reminder with exactly this list at `localTime` ("HH:mm") in the phone's current zone.
  Future<void> replaceAll(List<PlannedReminder> reminders, String localTime);
}

class DeviceReminderScheduler implements ReminderScheduler {
  /// [l10n] is read when reminders are (re)scheduled, so their words follow the app language at that moment.
  DeviceReminderScheduler(this._l10n);
  final AppLocalizations Function() _l10n;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    _ready = true;
  }

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
  Future<void> replaceAll(List<PlannedReminder> reminders, String localTime) {
    final generation = ++_generation;
    return _queue = _queue.catchError((Object _) {}).then((_) => generation == _generation ? _replace(reminders, localTime, generation) : null);
  }

  Future<void> _replace(List<PlannedReminder> reminders, String localTime, int generation) async {
    await _init();
    await _plugin.cancelAll();
    if (reminders.isEmpty) return;
    // The zone is read now, so travelling or a zone change simply re-times future reminders on the next rebuild.
    final location = tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier);
    final parts = localTime.split(':');
    final now = tz.TZDateTime.now(location);
    final l = _l10n();
    for (final r in reminders) {
      final day = parseDayKey(r.dayKey);
      final at = tz.TZDateTime(location, day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
      if (generation != _generation) return; // superseded: the newer request starts from a clean slate
      if (!at.isAfter(now)) continue; // today's time already passed: no late nag
      await _plugin.zonedSchedule(
        id: r.id,
        title: l.reminderNotificationTitle,
        body: r.title,
        scheduledDate: at,
        notificationDetails: NotificationDetails(
          // The channel ID never changes; Android updates the shown name and description in place.
          android: AndroidNotificationDetails('workout_reminders', l.reminderChannelName, channelDescription: l.reminderChannelDescription),
          iOS: const DarwinNotificationDetails(),
        ),
        // Inexact on purpose: a reminder needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => DeviceReminderScheduler(() => ref.read(appL10nProvider)));

/// Keeps the phone's scheduled reminders equal to [plannedReminders]. Watching it is enough; it reschedules
/// whenever the plan, its lifecycle, the preference, the day or the app language changes, and when invalidated on app
/// resume. A language change replaces the same reminders (same IDs, days and time) with reworded ones: replaceAll cancels
/// everything first and skips times already past, so nothing is duplicated or replayed.
final reminderSyncProvider = Provider<String>((ref) {
  ref.watch(appLocaleProvider);
  // Signed out (or account deleted): this phone keeps no reminders for that owner. Decided here, in the one place
  // that schedules, so a late recompute with the previous owner's data can never put them back.
  if (ref.watch(ownerProvider) == null) {
    ref.watch(reminderSchedulerProvider).replaceAll(const [], '18:00').ignore();
    return '';
  }
  final profile = ref.watch(profileProvider).value;
  final reminders = plannedReminders(
    enabled: profile?.remindersEnabled ?? false,
    primary: ref.watch(primaryPlanProvider),
    workouts: ref.watch(workoutListProvider),
    today: ref.watch(todayKeyProvider),
  );
  final time = profile?.reminderLocalTime ?? '18:00';
  final signature = '$time|${reminders.map((r) => '${r.id}@${r.dayKey}').join(',')}';
  // Until the profile has loaded nothing is touched, so a cold start never wipes reminders by mistake.
  if (profile != null) ref.watch(reminderSchedulerProvider).replaceAll(reminders, time).ignore();
  return signature;
});
