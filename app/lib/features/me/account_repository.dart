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
