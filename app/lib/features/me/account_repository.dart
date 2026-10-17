import '../../core/clock.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

String _authMessage(ApiResponse r) => switch (r.data is Map ? (r.data as Map)['code'] : null) {
      'INVALID_CREDENTIALS' => 'That email and password do not match an account.',
      'EMAIL_IN_USE' => 'An account with that email already exists. Sign in instead.',
      'WEAK_PASSWORD' => 'Use a password of at least 8 characters.',
      'INVALID_EMAIL' => 'Enter a valid email address.',
      'INVALID_DISPLAY_NAME' => 'Enter the name you want to see in the app.',
      'WRONG_PASSWORD' => 'That password is not correct. Your account was not deleted.',
      _ => r.status == 429 ? 'Too many attempts. Wait a minute and try again.' : 'The server could not complete that (${r.status}).',
    };

/// Registration, sign-in, non-destructive sign-out and confirmed account erasure.
class AuthRepository {
  AuthRepository(this._api, this._sessions, this._sync);
  final Api _api;
  final SessionManager _sessions;
  final SyncEngine _sync;

  Future<void> _enter(String path, Json body, [void Function(String ownerId)? onCreated]) async {
    ApiResponse r;
    try {
      r = await _api.send('POST', path, data: body, auth: false);
    } on TransportFailure {
      throw const AuthFailure('The server cannot be reached. Check your connection and try again; nothing you typed was lost.');
    }
    if (!r.ok) throw AuthFailure(_authMessage(r));
    onCreated?.call(((r.data as Json)['profile'] as Json)['userId'] as String); // before the app switches to the account
    final session = await _sessions.signIn(r.data as Json);
    // Resume only this owner's queue, then load their account state.
    await _sync.flush();
    if (_sessions.current?.epoch == session.epoch) await _sync.pull();
  }

  /// [onCreated] hears the new account's owner id before its session starts (setup is queued for it).
  Future<void> register(String email, String password, String displayName, {void Function(String ownerId)? onCreated}) =>
      _enter('/auth/register', {'email': email.trim(), 'password': password, 'displayName': displayName.trim()}, onCreated);
  Future<void> signIn(String email, String password) => _enter('/auth/login', {'email': email.trim(), 'password': password});

  /// Ends the session without deleting anything: this owner's records and pending work stay on the phone,
  /// hidden from every other account, and continue syncing when the same owner signs in again.
  Future<void> signOut() async {
    final s = _sessions.current;
    if (s == null) return;
    try {
      await _api.send('POST', '/auth/logout', data: {'refreshToken': s.refreshToken});
    } on TransportFailure {
      // Offline sign-out still ends the local session; the refresh token simply expires on its own.
    }
    await _sessions.signOut();
  }

  /// Explicit, password-confirmed erasure. It is never queued offline and a timeout is never treated as
  /// success: local data is erased only after the server confirms the account is gone.
  Future<void> deleteAccount(String password) async {
    final s = _sessions.current;
    if (s == null) return;
    ApiResponse r;
    try {
      r = await _api.send('DELETE', '/account', data: {'password': password});
    } on TransportFailure {
      throw const AuthFailure('The server cannot be reached, so nothing was deleted. Account deletion needs a connection.');
    }
    if (r.status != 204) throw AuthFailure(_authMessage(r));
    await _sync.eraseOwner(s.ownerId);
    await _sessions.signOut(reason: 'Your account and its data were deleted.');
  }
}

/// Profile and shared preferences. Display name is free text and is never the sign-in identity.
class ProfileRepository {
  ProfileRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static const calorieGoalRange = (500, 10000), proteinGoalRange = (10, 500), waterGoalRangeMl = (100, 10000);

  /// Goals are whole numbers the person chose. Null means no goal; nothing is ever suggested in its place.
  static void validateGoals(int? calories, int? protein) {
    if (calories != null && (calories < calorieGoalRange.$1 || calories > calorieGoalRange.$2)) throw const AuthFailure('A calorie goal is a whole number from 500 to 10,000, or left blank.');
    if (protein != null && (protein < proteinGoalRange.$1 || protein > proteinGoalRange.$2)) throw const AuthFailure('A protein goal is a whole number from 10 to 500 grams, or left blank.');
  }

  static void validateWaterGoal(int? ml) {
    if (ml != null && (ml < waterGoalRangeMl.$1 || ml > waterGoalRangeMl.$2)) throw const AuthFailure('A water goal is from 100 mL to 10 L (about 3.4 to 338 fl oz), or left blank.');
  }

  /// Sets both goals; null clears one. The clearing is sent as an explicit null, which is what tells the server
  /// "remove it" from "an older app that does not know about goals".
  /// [waterGoalMl] travels only when [withWater]: a form that does not show it never touches the stored one.
  Future<Receipt> setGoals(Profile current, {required int? calorieGoal, required int? proteinGoal, bool withWater = false, int? waterGoalMl}) {
    validateGoals(calorieGoal, proteinGoal);
    if (withWater) validateWaterGoal(waterGoalMl);
    return update(current, goals: {'calorieGoal': calorieGoal, 'proteinGoal': proteinGoal, if (withWater) 'waterGoalMl': waterGoalMl});
  }

  /// What the account shows in its nutrition. All three travel together, so another phone receives the whole choice.
  /// Only sent where the server declares `profile.tracking-display`.
  Future<Receipt> setDisplay(Profile current, {required bool water, required bool carbs, required bool fat}) =>
      update(current, goals: {'showWater': water, 'showCarbs': carbs, 'showFat': fat});

  Future<Receipt> update(Profile current, {String? displayName, String? appearance, String? loadUnit, bool? remindersEnabled, String? reminderLocalTime, Json? goals}) {
    final name = (displayName ?? current.displayName).trim();
    if (name.isEmpty || name.length > 80) throw const AuthFailure('Enter a name of 1 to 80 characters.');
    final fields = {
      'displayName': name, 'appearance': appearance ?? current.appearance, 'loadUnit': loadUnit ?? current.loadUnit,
      'remindersEnabled': remindersEnabled ?? current.remindersEnabled, 'reminderLocalTime': reminderLocalTime ?? current.reminderLocalTime,
      // Goals and display choices travel only when they are the thing being changed. Left out, the server keeps what it has.
      ...?goals,
    };
    return _sync.submit(_owner, kind: 'profile.update', method: 'PUT', path: '/me', targetKind: Kinds.profile, targetId: _owner,
        writes: [LocalWrite(Kinds.profile, _owner, {...current.j, ...fields})],
        payload: {'expectedRevision': {r'$rev': [Kinds.profile, _owner]}, ...fields});
  }
}

/// Supporting activity: manually timed runs and optional body measurements.
class ActivityRepository {
  ActivityRepository(this._sync, this._owner, this._clock);
  final SyncEngine _sync;
  final String _owner;
  final AppClock _clock;

  /// Creates the owned run record first; callers navigate only once this has succeeded.
  Future<Run> startRun(String dayKey) async {
    final id = SyncEngine.newId();
    final at = _clock.utcNow().toIso8601String();
    final body = <String, dynamic>{'id': id, 'dayKey': dayKey, 'startedAtUtc': at, 'finishedAtUtc': null, 'activeDurationSeconds': null, 'distanceMeters': null, 'revision': 0, 'isDeleted': false};
    await _sync.submit(_owner, kind: 'run.start', path: '/runs', targetKind: Kinds.run, targetId: id,
        writes: [LocalWrite(Kinds.run, id, body, dayKey: dayKey)], payload: {'runId': id, 'dayKey': dayKey, 'startedAtUtc': at});
    return Run(body);
  }

  /// Distance is optional and only ever what the user typed; no GPS route or estimate is invented.
  Future<void> finishRun(Run run, {required int activeSeconds, double? distanceMeters}) {
    final at = _clock.utcNow().toIso8601String();
    return _sync.submit(_owner, kind: 'run.finish', path: '/runs/${run.id}/finish', targetKind: Kinds.run, targetId: run.id,
        writes: [LocalWrite(Kinds.run, run.id, copyJson(run.j)..addAll({'finishedAtUtc': at, 'activeDurationSeconds': activeSeconds, 'distanceMeters': distanceMeters}), dayKey: run.dayKey)],
        payload: {'expectedRevision': {r'$rev': [Kinds.run, run.id]}, 'activeDurationSeconds': activeSeconds, 'distanceMeters': distanceMeters, 'finishedAtUtc': at});
  }

  Future<void> deleteRun(Run run) => _sync.submit(_owner, kind: 'run.delete', path: '/runs/${run.id}/delete', targetKind: Kinds.run, targetId: run.id,
      writes: [LocalWrite(Kinds.run, run.id, copyJson(run.j)..['isDeleted'] = true, dayKey: run.dayKey)], payload: {'expectedRevision': {r'$rev': [Kinds.run, run.id]}});

  Future<void> addMetric(String dayKey, {double? weightKg, double? bodyFatPercent, String? note}) {
    if (weightKg == null && bodyFatPercent == null) throw const AuthFailure('Enter a weight or a body-fat value.');
    if ((weightKg != null && (weightKg <= 0 || weightKg > 700)) || (bodyFatPercent != null && (bodyFatPercent < 0 || bodyFatPercent > 100))) {
      throw const AuthFailure('That measurement is out of range.');
    }
    final id = SyncEngine.newId();
    final fields = {'dayKey': dayKey, 'weightKg': weightKg, 'bodyFatPercent': bodyFatPercent, 'note': note};
    return _sync.submit(_owner, kind: 'metric.create', path: '/body-metrics', targetKind: Kinds.metric, targetId: id,
        writes: [LocalWrite(Kinds.metric, id, {'id': id, ...fields, 'revision': 0, 'isDeleted': false}, dayKey: dayKey)], payload: {'metricId': id, ...fields});
  }

  Future<void> deleteMetric(BodyMetric m) => _sync.submit(_owner, kind: 'metric.delete', path: '/body-metrics/${m.id}/delete', targetKind: Kinds.metric, targetId: m.id,
      writes: [LocalWrite(Kinds.metric, m.id, copyJson(m.j)..['isDeleted'] = true, dayKey: m.dayKey)], payload: {'expectedRevision': {r'$rev': [Kinds.metric, m.id]}});
}
