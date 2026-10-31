import 'dart:async';
import 'dart:convert';

import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/language.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';
import '../plans/plan_draft.dart';
import '../plus/entitlement.dart' show entitlementProvider;
import 'coach_contract.dart';
import 'coach_proposal.dart';

/// Why a question got no answer. `unreached`: the request did not get through; the app cannot tell a phone without
/// a connection from a server in trouble, so it never says "Offline". `interrupted`: the app closed while it waited.
/// `busy`: the AI provider is rate limited or overloaded (503 COACH_BUSY), not the person's own limit (429 COACH_LIMIT).
/// `allowance`: this month's AI allowance is used up (429 COACH_LIMIT, reason "monthly"; docs/PLUS_PREVIEW.md).
enum AskProblem { unavailable, limit, unreached, invalid, interrupted, busy, allowance }

/// 429 is the person's own limit: the month's allowance when the server says so, otherwise the daily guard.
AskProblem limitProblem(Object? body) => body is Map && body['reason'] == 'monthly' ? AskProblem.allowance : AskProblem.limit;

class AskFailure implements Exception {
  const AskFailure(this.problem);
  final AskProblem problem;
}

/// The reply language sent with a question: only the server's allowlist ("en" | "fr-CA" | "ar"). The question itself
/// is sent as typed, never translated; earlier messages keep their own words.
String askLanguage(Locale locale) => switch (locale.languageCode) { 'fr' => 'fr-CA', 'ar' => 'ar', _ => 'en' };

/// The `/coach/ask` body for one explicitly sent [question]: the last six [messages] as history (their own words), the
/// context and draft, and the reply language for [locale].
Json askRequestBody(String requestId, String question, List<Json> messages, CoachContext coach, PlanDraft? draft, Locale locale) => {
      'requestId': requestId, 'question': question, 'language': askLanguage(locale),
      'history': [
        for (final m in messages.skip(messages.length > 6 ? messages.length - 6 : 0))
          {'role': m['role'], 'text': (m['text'] as String).length > 1500 ? (m['text'] as String).substring(0, 1500) : m['text']},
      ],
      'context': {
        'label': coach.label, 'focus': coach.focus.name, 'templateId': coach.templateId, 'workoutId': coach.workoutId,
        'occurrenceKey': coach.occurrenceKey, 'catalogKey': coach.catalogKey,
        'draft': draft == null ? null : {for (final k in ['title', 'durationWeeks', 'timeBudgetMinutes', 'schedule', 'workouts']) k: draft.planBody[k]},
        'draftRevision': draft == null ? null : draftRevision(draft),
      },
    };

/// `POST /coach/ask` (docs/COACH.md) through the signed-in owner's [Api]. A read, never a queued command.
class CoachClient {
  CoachClient(this._api, {this.onCharged});
  final Api _api;

  /// Called after an answer or an allowance refusal, so the shown allowance follows the server.
  final void Function()? onCharged;
  static const timeout = Duration(seconds: 25);

  /// The 200 body, or [AskFailure]. A body that is not an answer to [request] counts as unavailable.
  Future<Json> ask(Json request) async {
    final ApiResponse r;
    try {
      r = await _api.send('POST', '/coach/ask', data: request).timeout(timeout);
    } on TimeoutException {
      throw const AskFailure(AskProblem.unavailable);
    } on TransportFailure catch (e) {
      throw AskFailure(e.message.toLowerCase().contains('timeout') ? AskProblem.unavailable : AskProblem.unreached);
    }
    final d = r.data;
    if (r.status == 429) {
      onCharged?.call();
      throw AskFailure(limitProblem(d));
    }
    if (r.status == 400) throw const AskFailure(AskProblem.invalid);
    if (r.status == 503 && d is Map && d['code'] == 'COACH_BUSY') throw const AskFailure(AskProblem.busy);
    if (!r.ok || d is! Map || d['requestId'] != request['requestId'] || d['answer'] is! String || (d['answer'] as String).trim().isEmpty) {
      throw const AskFailure(AskProblem.unavailable);
    }
    onCharged?.call();
    return Map<String, dynamic>.from(d);
  }
}

/// The owner's conversation as stored (record kind `coach_chat`, id `current`):
/// `messages`: `{id, role: user|assistant, text, draftRevision, contextLabel}` (+ assistant: `sources`, `proposal`,
/// `applied: {changes, undone, undoRefused}`); `pending`: the question waiting for or without an answer
/// `{question, requestId, draftRevision, contextLabel, problem}`; `unsent`: the composer's text.
class AskState {
  const AskState({this.messages = const [], this.pending, this.unsent = '', this.sending = false, this.loaded = false});
  final List<Json> messages;
  final Json? pending;
  final String unsent;
  final bool sending, loaded;

  bool get isEmpty => messages.isEmpty && pending == null;
  AskProblem? get problem => AskProblem.values.where((p) => p.name == pending?['problem']).firstOrNull;
  Json toJson() => {'messages': messages, 'pending': pending, 'unsent': unsent};

  AskState copy({List<Json>? messages, Json? pending, bool clearPending = false, String? unsent, bool? sending}) => AskState(
      messages: messages ?? this.messages, pending: clearPending ? null : pending ?? this.pending, unsent: unsent ?? this.unsent,
      sending: sending ?? this.sending, loaded: true);
}

/// The signed-in owner's Ask GoHard conversation. Lives while the screen is open; everything is kept on the phone
/// for that owner only, so it survives closing, a theme change and a cold start and no other account ever sees it.
/// One question at a time: a second Send while one is waiting does nothing. An answer is kept only if it arrives for
/// the same owner, the same sign-in and the question still being waited for; closing the screen or Cancel drops it.
final askConversationProvider = NotifierProvider.autoDispose<AskConversation, AskState>(AskConversation.new);

class AskConversation extends Notifier<AskState> {
  static const _id = 'current', _maxMessages = 60;
  late SyncEngine _sync;
  late SessionManager _sessions;
  /// Made at the first Send: opening Ask GoHard touches no transport.
  CoachClient get _client => CoachClient(ref.read(apiProvider), onCharged: () => ref.read(entitlementProvider.notifier).refresh());
  String? _owner;
  int _turn = 0;
  String _unsent = '';
  Future<void> _saving = Future.value();

  /// The last state, readable while disposing (Riverpod forbids reading [state] then).
  AskState _last = const AskState();

  @override
  AskState build() {
    _turn++;
    _owner = ref.watch(ownerProvider);
    _sessions = ref.watch(sessionsProvider);
    _sync = ref.watch(syncProvider);
    ref.onDispose(_closed);
    if (_owner == null) return _last = const AskState(loaded: true);
    _load(_owner!, _turn);
    return _last = const AskState();
  }

  Future<void> _load(String owner, int turn) async {
    Json? j;
    try {
      final rec = await _sync.get(owner, Kinds.coachChat, _id);
      j = rec == null ? null : jsonDecode(rec.body) as Json;
    } on Object {
      j = null; // an unreadable conversation starts again; nothing else depends on it
    }
    if (!ref.mounted || turn != _turn) return;
    final pending = j?['pending'] is Map ? Map<String, dynamic>.from(j!['pending'] as Map) : null;
    if (pending != null && pending['problem'] == null) pending['problem'] = AskProblem.interrupted.name;
    _unsent = j?['unsent'] as String? ?? '';
    state = _last = AskState(
        messages: [for (final m in j?['messages'] as List? ?? const []) if (m is Map) Map<String, dynamic>.from(m)], pending: pending, unsent: _unsent, loaded: true);
  }

  /// Closing the screen cancels a question still waiting: it goes back into the composer, unsent.
  void _closed() {
    _turn++;
    final s = _last;
    if (!s.sending || _owner == null) return;
    _unsent = s.pending!['question'] as String;
    _write(_owner!, s.copy(clearPending: true, sending: false));
  }

  void _write(String owner, AskState s) {
    final body = s.toJson()..['unsent'] = _unsent;
    _saving = _saving.then((_) => _sync.putLocal(owner, LocalWrite(Kinds.coachChat, _id, body))).catchError((Object _) {});
  }

  void _set(AskState s) {
    state = _last = s;
    if (_owner != null) _write(_owner!, s);
  }

  /// Keeps the composer's text, so it is there again after closing or a restart.
  void setUnsent(String text) {
    if (!state.loaded || text == _unsent) return;
    _unsent = text;
    if (_owner != null) _write(_owner!, state);
  }

  /// Sends [question] about [coach]. With [retry] the waiting question is sent again under the same requestId, so
  /// the server answers it once.
  Future<void> send(String question, CoachContext coach, {bool retry = false}) async {
    final q = question.trim();
    final owner = _owner, session = _sessions.current;
    if (state.sending || !state.loaded || q.isEmpty || owner == null || session == null || (retry && state.pending == null)) return;
    final draft = coach.draft?.call();
    final revision = draft == null ? null : draftRevision(draft);
    final requestId = retry ? state.pending!['requestId'] as String : SyncEngine.newId();
    final pending = <String, dynamic>{'question': q.length > 600 ? q.substring(0, 600) : q, 'requestId': requestId, 'draftRevision': revision, 'contextLabel': coach.label, 'problem': null};
    final turn = ++_turn;
    if (!retry) _unsent = '';
    _set(state.copy(pending: pending, sending: true, unsent: retry ? null : ''));

    final request = askRequestBody(requestId, pending['question'] as String, state.messages, coach, draft, ref.read(appLocaleProvider));
    Json? answer;
    AskProblem? problem;
    try {
      answer = await _client.ask(request);
    } on AskFailure catch (e) {
      problem = e.problem;
    }
    // A late answer for a question no longer waited for, or for another owner or sign-in, is dropped.
    if (!ref.mounted || turn != _turn || _sessions.current?.epoch != session.epoch || _sessions.current?.ownerId != owner) return;
    if (answer == null) {
      _set(state.copy(pending: {...pending, 'problem': problem!.name}, sending: false));
      return;
    }
    final rev = answer['draftRevision'] is String ? answer['draftRevision'] : revision;
    final messages = [
      ...state.messages,
      {'id': '$requestId-q', 'role': 'user', 'text': pending['question'], 'draftRevision': rev, 'contextLabel': coach.label},
      {
        'id': requestId, 'role': 'assistant', 'text': (answer['answer'] as String).trim(), 'draftRevision': rev, 'contextLabel': coach.label,
        'sources': [for (final s in answer['sources'] as List? ?? const []) if (s is String) s],
        'proposal': answer['proposal'] is Map ? answer['proposal'] : null,
      },
    ];
    _set(state.copy(messages: messages.skip(messages.length > _maxMessages ? messages.length - _maxMessages : 0).toList(), clearPending: true, sending: false));
  }

  /// Stops waiting: a late answer is dropped and the question goes back into the composer.
  void cancel() {
    if (!state.sending) return;
    _turn++;
    _unsent = state.pending!['question'] as String;
    _set(state.copy(clearPending: true, unsent: _unsent, sending: false));
  }

  /// Takes a failed question back into the composer to change it.
  void edit() {
    if (state.sending || state.pending == null) return;
    _unsent = state.pending!['question'] as String;
    _set(state.copy(clearPending: true, unsent: _unsent));
  }

  void clear() {
    _turn++;
    _set(state.copy(messages: const [], clearPending: true, sending: false));
  }

  /// Records on the answer that its suggestion was applied ([changes] are what Undo restores), undone, or refused.
  void markApplied(String messageId, {List<Json>? changes, bool? undone, String? undoRefused}) {
    _set(state.copy(messages: [
      for (final m in state.messages)
        if (m['id'] != messageId)
          m
        else
          {
            ...m,
            'applied': {
              'changes': changes ?? (m['applied'] as Map?)?['changes'] ?? const [],
              'undone': undone ?? false,
              'undoRefused': undoRefused,
            },
          },
    ]));
  }
}
