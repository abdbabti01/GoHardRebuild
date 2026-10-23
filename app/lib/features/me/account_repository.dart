import '../../core/language.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';

/// What went wrong, as a code: the screen says it in the app's language ([AuthFailure.text]).
enum AuthError {
  invalidCredentials, emailInUse, weakPassword, invalidEmail, invalidDisplayName, wrongPassword, tooManyAttempts, unknown, unreachable, unreachableDelete, nameLength, calorieGoal, proteinGoal, waterGoal,
  // Emailed codes and password changes (docs/AUTHENTICATION_EMAIL.md).
  passwordTooLong, passwordMismatch, codeIncomplete, codeInvalid, codeExpired, codeAttempts, cooldown, emailUnavailable, emailBusy, resetExpired, notSupported,
  uncertainReset, uncertainChange,
  // Required verification: a new account cannot be created without a sender.
  registrationUnavailable,
}

class AuthFailure implements Exception {
  /// [text] already in the app's language (a form's own check).
  const AuthFailure(String text) : _text = text, code = null, seconds = null;
  const AuthFailure.of(AuthError this.code, {this.seconds}) : _text = null;
  final String? _text;
  final AuthError? code;

  /// For [AuthError.cooldown]: how long until another code may be asked for.
  final int? seconds;

  /// In the app's current language.
  String get message => text(currentL10n);

  String text(AppLocalizations l) => _text ?? switch (code!) {
        AuthError.invalidCredentials => l.accountErrorInvalidCredentials,
        AuthError.emailInUse => l.accountErrorEmailInUse,
        AuthError.weakPassword => l.accountErrorWeakPassword,
        AuthError.invalidEmail => l.accountErrorInvalidEmail,
        AuthError.invalidDisplayName => l.accountErrorInvalidDisplayName,
        AuthError.wrongPassword => l.accountErrorWrongPassword,
        AuthError.tooManyAttempts => l.accountErrorTooManyAttempts,
        AuthError.unknown => l.errorGeneric,
        AuthError.unreachable => l.accountErrorUnreachable,
        AuthError.unreachableDelete => l.accountErrorUnreachableDelete,
        AuthError.nameLength => l.accountErrorNameLength,
        AuthError.calorieGoal => l.accountErrorCalorieGoal,
        AuthError.proteinGoal => l.accountErrorProteinGoal,
        AuthError.waterGoal => l.accountErrorWaterGoal,
        AuthError.passwordTooLong => l.accountErrorPasswordTooLong,
        AuthError.passwordMismatch => l.accountErrorPasswordMismatch,
        AuthError.codeIncomplete => l.accountErrorCodeIncomplete,
        AuthError.codeInvalid => l.accountErrorCodeInvalid,
        AuthError.codeExpired => l.accountErrorCodeExpired,
        AuthError.codeAttempts => l.accountErrorCodeAttempts,
        AuthError.cooldown => l.accountErrorCooldown(seconds ?? 60),
        AuthError.emailUnavailable => l.accountEmailUnavailable,
        AuthError.emailBusy => l.accountErrorEmailBusy,
        AuthError.resetExpired => l.accountErrorResetExpired,
        AuthError.notSupported => l.accountErrorNotSupported,
        AuthError.uncertainReset => l.accountErrorUncertainReset,
        AuthError.uncertainChange => l.accountErrorUncertainChange,
        AuthError.registrationUnavailable => l.accountErrorRegistrationUnavailable,
      };
}

/// The server's error code mapped to a known message; anything else is the generic one, never the raw details.
AuthFailure _authFailure(ApiResponse r) => AuthFailure.of(seconds: r.data is Map ? (r.data as Map)['retryAfterSeconds'] as int? : null, switch (r.data is Map ? (r.data as Map)['code'] : null) {
      'INVALID_CREDENTIALS' => AuthError.invalidCredentials,
      'EMAIL_IN_USE' => AuthError.emailInUse,
      'WEAK_PASSWORD' => AuthError.weakPassword,
      'INVALID_EMAIL' => AuthError.invalidEmail,
      'INVALID_DISPLAY_NAME' => AuthError.invalidDisplayName,
      'WRONG_PASSWORD' => AuthError.wrongPassword,
      'PASSWORD_TOO_LONG' => AuthError.passwordTooLong,
      'INVALID_CODE' => AuthError.codeInvalid,
      'CODE_EXPIRED' => AuthError.codeExpired,
      'TOO_MANY_ATTEMPTS' => AuthError.codeAttempts,
      'EMAIL_COOLDOWN' => AuthError.cooldown,
      'EMAIL_UNAVAILABLE' => AuthError.emailUnavailable,
      'EMAIL_BUSY' => AuthError.emailBusy,
      'INVALID_RESET_TOKEN' => AuthError.resetExpired,
      // A server from before these routes: say so once, never retry.
      _ when r.status == 404 || r.status == 405 => AuthError.notSupported,
      _ => r.status == 429 ? AuthError.tooManyAttempts : AuthError.unknown,
    });

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
      throw const AuthFailure.of(AuthError.unreachable);
    }
    if (!r.ok) throw _authFailure(r);
    final profile = (r.data as Json)['profile'] as Json;
    onCreated?.call(profile['userId'] as String); // before the app switches to the account
    // Also before: a new account opens on its verification, never on Today first.
    await _sync.adoptAccess(profile['userId'] as String, profile);
    final session = await _sessions.signIn(r.data as Json);
    // Resume only this owner's queue, then load their account state.
    await _sync.flush();
    if (_sessions.current?.epoch == session.epoch) await _sync.pull();
  }

  /// [onCreated] hears the new account's owner id before its session starts (setup is queued for it).
  /// Without a sender the server creates no account (it could never be verified): said as such, not as "recovery".
  Future<void> register(String email, String password, String displayName, {void Function(String ownerId)? onCreated}) async {
    try {
      await _enter('/auth/register', {'email': email.trim(), 'password': password, 'displayName': displayName.trim(), 'language': mailLanguage}, onCreated);
    } on AuthFailure catch (e) {
      throw e.code == AuthError.emailUnavailable ? const AuthFailure.of(AuthError.registrationUnavailable) : e;
    }
  }
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

  // ---- Emailed codes and password changes (docs/AUTHENTICATION_EMAIL.md). Direct calls only: passwords, codes and
  // reset authorizations never enter the outbox, the local database or a log.

  /// The language an email is written in: the app's, never stored on the account.
  static String get mailLanguage => currentLocale.toLanguageTag();

  Future<ApiResponse> _call(String path, Json body, {bool auth = false, AuthError noAnswer = AuthError.unreachable}) async {
    try {
      return await _api.send('POST', path, data: body, auth: auth);
    } on TransportFailure {
      throw AuthFailure.of(noAnswer);
    }
  }

  /// Asks for a reset code. The answer is the same whether or not an account uses [email]. Returns the cooldown.
  Future<int> requestReset(String email) async {
    final r = await _call('/auth/password-reset/request', {'email': email.trim(), 'language': mailLanguage});
    if (r.status != 202) throw _authFailure(r);
    return (r.data as Json)['cooldownSeconds'] as int? ?? 60;
  }

  /// A correct code gives a short-lived reset authorization, kept only in the screen's memory.
  Future<String> verifyReset(String email, String code) async {
    final r = await _call('/auth/password-reset/verify', {'email': email.trim(), 'code': code});
    if (!r.ok) throw _authFailure(r);
    return (r.data as Json)['resetToken'] as String;
  }

  /// No answer is not a failure: the password may have changed ([AuthError.uncertainReset]). Never resent by itself.
  Future<void> completeReset(String resetToken, String newPassword) async {
    final r = await _call('/auth/password-reset/complete', {'resetToken': resetToken, 'newPassword': newPassword, 'language': mailLanguage},
        noAnswer: AuthError.uncertainReset);
    if (r.status != 204) throw _authFailure(r);
  }

  /// Every device is signed out by the server; this one signs out without deleting anything, so signing in again with
  /// the new password finds this account's data, drafts and pending changes where they were.
  Future<void> changePassword(String current, String next) async {
    final r = await _call('/account/password', {'currentPassword': current, 'newPassword': next, 'language': mailLanguage},
        auth: true, noAnswer: AuthError.uncertainChange);
    if (r.status != 204) throw _authFailure(r);
    await _sessions.signOut(code: SignOutReason.passwordChanged);
  }

  /// Sends (or re-sends) the verification code. Returns the cooldown; 0 when the address turned out to be verified already.
  Future<int> requestVerification() async {
    final r = await _call('/account/email-verification/request', {'language': mailLanguage}, auth: true);
    if (r.status == 409) {
      await _sync.pull();
      return 0;
    }
    if (r.status != 202) throw _authFailure(r);
    return (r.data as Json)['cooldownSeconds'] as int? ?? 60;
  }

  /// Confirms the address and keeps the server's answer (the account may now use its data, waiting changes go), then
  /// reads the account again so Me shows what the server now says.
  Future<void> confirmVerification(String code) async {
    final r = await _call('/account/email-verification/confirm', {'code': code}, auth: true);
    if (!r.ok) throw _authFailure(r);
    final owner = _sessions.current?.ownerId;
    if (owner != null && r.data is Json) await _sync.adoptAccess(owner, r.data as Json);
    _sync.kick();
    await _sync.pull();
  }

  /// "Check again": verified on another phone, or a confirmation whose answer was lost. Asks the account; no code.
  Future<void> checkAccess() async {
    if (!await _sync.refreshAccess()) throw const AuthFailure.of(AuthError.unreachable);
    await _sync.pull();
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
      throw const AuthFailure.of(AuthError.unreachableDelete);
    }
    if (r.status != 204) throw _authFailure(r);
    await _sync.eraseOwner(s.ownerId);
    await _sessions.signOut(code: SignOutReason.accountDeleted);
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
    if (calories != null && (calories < calorieGoalRange.$1 || calories > calorieGoalRange.$2)) throw const AuthFailure.of(AuthError.calorieGoal);
    if (protein != null && (protein < proteinGoalRange.$1 || protein > proteinGoalRange.$2)) throw const AuthFailure.of(AuthError.proteinGoal);
  }

  static void validateWaterGoal(int? ml) {
    if (ml != null && (ml < waterGoalRangeMl.$1 || ml > waterGoalRangeMl.$2)) throw const AuthFailure.of(AuthError.waterGoal);
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
    if (name.isEmpty || name.length > 80) throw const AuthFailure.of(AuthError.nameLength);
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
