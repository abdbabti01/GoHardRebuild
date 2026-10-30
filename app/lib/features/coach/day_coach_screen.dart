import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/format.dart' show longDate;
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart' show formatNumber;
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';
import '../nutrition/eat_screen.dart' show eatDayRequestProvider;
import '../nutrition/eating_out_screen.dart' show openEatingOut;
import '../nutrition/food_form.dart' show FoodFormScreen;
import '../nutrition/food_repository.dart' show FoodDraft;
import '../nutrition/food_repository.dart' show SavedFood;
import '../nutrition/nutrient_coverage.dart' show Nutrient;
import '../nutrition/log_food_screen.dart' show LogFoodScreen;
import '../nutrition/nutrition_surface.dart' show formatKcal;
import '../nutrition/saved_meals.dart';
import '../nutrition/saved_meals_screens.dart' show MealReviewScreen, openMealsLibrary;
import '../shell/home_shell.dart' show WorkoutFocus, shellProvider;
import 'coach_avatar.dart';
import 'coach_client.dart' show AskFailure, AskProblem, AskState, askLanguage;
import 'coach_companion.dart';
import 'coach_contract.dart';
import 'coach_prefs.dart';
import 'coach_rig.dart' show RigFrame;
import 'day_coach.dart';
import 'meal_ideas.dart';
import '../nutrition/food_discovery.dart' show LookupFailure;
import '../nutrition/food_item.dart' show FoodItem;
import '../nutrition/food_search.dart' show CommonFood, foodLang;
import '../nutrition/meal_habits_ui.dart' show usualMealProvider, reviewUsualMeal;

/// Opens help with today and food about [day] over [context]'s page. Opening it sends nothing and changes nothing; the
/// page underneath (a workout being recorded, a food form) keeps everything typed in it.
/// [start]: a built-in request answered as it opens (Eat's What could I eat?), on the phone and with no AI.
Future<void> openDayCoach(BuildContext context, {required String day, (DayIntent, String)? start}) => push<void>(context, DayCoachScreen(day: day, start: start));

/// The meal a suggestion starts on, from the time of day (changeable in the review).
String mealAt(DateTime t) => t.hour < 11 ? 'Breakfast' : t.hour < 16 ? 'Lunch' : t.hour < 21 ? 'Dinner' : 'Snack';

// ---------------------------------------------------------------------------- the server

/// `POST /coach/daily` through the signed-in owner's [Api]: typed words → a checked intent. A read, never queued.
class DayCoachClient {
  DayCoachClient(this._api);
  final Api _api;
  static const timeout = Duration(seconds: 25);

  Future<DayIntent> interpret(Json request) async {
    final ApiResponse r;
    try {
      r = await _api.send('POST', '/coach/daily', data: request).timeout(timeout);
    } on TimeoutException {
      throw const AskFailure(AskProblem.unavailable);
    } on TransportFailure catch (e) {
      throw AskFailure(e.message.toLowerCase().contains('timeout') ? AskProblem.unavailable : AskProblem.unreached);
    }
    final d = r.data;
    if (r.status == 429) throw const AskFailure(AskProblem.limit);
    if (r.status == 400) throw const AskFailure(AskProblem.invalid);
    if (r.status == 503 && d is Map && d['code'] == 'COACH_BUSY') throw const AskFailure(AskProblem.busy);
    final intent = d is Map && r.ok && d['requestId'] == request['requestId'] ? DayIntent.fromJson(d['intent'], ai: true) : null;
    if (intent == null) throw const AskFailure(AskProblem.unavailable);
    return intent;
  }
}

final dayCoachClientProvider = Provider((ref) => DayCoachClient(ref.watch(apiProvider)));

/// Whether the account's server reads typed requests. Unknown counts as no: an older server never gets the request.
final dayCoachAvailableProvider = Provider<bool>((ref) => ref.watch(compatibilityProvider).capabilities?.contains('coach.daily') ?? false);

/// Whether the account's server proposes new meal ideas (`coach.ideas`). Without it the request carries no
/// `features`, and What could I eat? stays with the person's own meals, Find food and Eating out.
final dayIdeasAvailableProvider = Provider<bool>((ref) => ref.watch(compatibilityProvider).capabilities?.contains('coach.ideas') ?? false);

// ---------------------------------------------------------------------------- the conversation

/// The owner's conversation (record kind `coach_chat`, id `daily`), kept on this phone for that owner only:
/// `messages` (`{id, role: user, text}` and `{id, role: assistant, reply}`), `pending` (a typed request waiting for or
/// without an answer: `{question, requestId, problem}`) and `unsent`. It survives closing, a language change and a cold
/// start; nothing in it is sent anywhere except the last six turns' words with a typed request.
final dayConversationProvider = NotifierProvider.autoDispose<DayConversation, AskState>(DayConversation.new);

class DayConversation extends Notifier<AskState> {
  static const _id = 'daily', _maxMessages = 60;
  late SyncEngine _sync;
  late SessionManager _sessions;
  String? _owner;
  int _turn = 0;
  String _unsent = '';
  Future<void> _saving = Future.value();
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
    state = _last = AskState(messages: [for (final m in j?['messages'] as List? ?? const []) if (m is Map) Map<String, dynamic>.from(m)], pending: pending, unsent: _unsent, loaded: true);
  }

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

  void setUnsent(String text) {
    if (!state.loaded || text == _unsent) return;
    _unsent = text;
    if (_owner != null) _write(_owner!, state);
  }

  /// The last reply's portion cards: what "smaller" or "that one" refers to.
  List<Json> get focus {
    final last = state.messages.lastWhere((m) => m['role'] == 'assistant', orElse: () => const {});
    return [for (final c in (last['reply'] as Map?)?['cards'] as List? ?? const []) if (c is Map && c['choice'] != true) Map<String, dynamic>.from(c)];
  }

  void _answer(String id, String said, Json reply) {
    final messages = [...state.messages, {'id': '$id-q', 'role': 'user', 'text': said}, {'id': id, 'role': 'assistant', 'reply': reply}];
    _set(state.copy(messages: messages.skip(messages.length > _maxMessages ? messages.length - _maxMessages : 0).toList(), clearPending: true, sending: false));
  }

  /// A built-in request ([said] is its words): answered here from the records, with no network and no AI.
  void ask(DayIntent intent, String said, DayRecords records, AppLocalizations l) {
    if (state.sending || !state.loaded) return;
    _answer(SyncEngine.newId(), said, resolveDay(intent, records, l, focus: focus));
  }

  /// Sends typed words to be read. [records] is read when the answer arrives, so the reply uses the records as they are
  /// then. With [retry] the waiting request is sent again under the same requestId (the server answers it once).
  /// [match] turns the model's ideas (words) into ideas matched to real food records; nothing else uses it.
  Future<void> send(String question, DayRecords Function() records, AppLocalizations l, {bool retry = false, bool ideas = false,
      Future<List<Json>> Function(Object? raw)? match}) async {
    final q = question.trim();
    final owner = _owner, session = _sessions.current;
    if (state.sending || !state.loaded || q.isEmpty || owner == null || session == null || (retry && state.pending == null)) return;
    final requestId = retry ? state.pending!['requestId'] as String : SyncEngine.newId();
    final pending = <String, dynamic>{'question': q.length > 600 ? q.substring(0, 600) : q, 'requestId': requestId, 'problem': null};
    final turn = ++_turn;
    if (!retry) _unsent = '';
    _set(state.copy(pending: pending, sending: true, unsent: retry ? null : ''));
    // Changes still on this phone go first, so the account's list of saved items is the one the person sees. Never
    // waits long, and a failure only means the reply says some changes are still on the phone.
    try {
      await _sync.flush().timeout(const Duration(seconds: 6));
    } on Object {
      // keeps going
    }
    if (!ref.mounted || turn != _turn) return;
    final r = records();
    final history = [
      for (final m in state.messages.skip(state.messages.length > 6 ? state.messages.length - 6 : 0))
        {'role': m['role'], 'text': _clip(m['role'] == 'user' ? m['text'] as String : replyText(Map<String, dynamic>.from(m['reply'] as Map), l))},
    ];
    final request = {
      'requestId': requestId, 'question': pending['question'], 'language': askLanguage(ref.read(appLocaleProvider)), 'dayKey': r.shown, 'isToday': r.shown == r.today,
      'history': history, 'focus': [for (final c in focus.take(3)) if (c['kind'] != 'idea' && c['kind'] != 'usual') {'kind': c['kind'], 'id': c['id']}], 'contextRevision': dayRevision(r, r.shown),
      // Only to a server that declared it: an older one is never sent what it cannot take.
      if (ideas) 'features': const ['ideas'],
    };
    DayIntent? intent;
    AskProblem? problem;
    try {
      intent = await ref.read(dayCoachClientProvider).interpret(request);
      if (intent.kind == 'ideas') intent = intent.withIdeas(match == null ? const [] : await match(intent.proposed));
    } on AskFailure catch (e) {
      problem = e.problem;
    }
    // A late answer for a request no longer waited for, or for another owner or sign-in, is dropped.
    if (!ref.mounted || turn != _turn || _sessions.current?.epoch != session.epoch || _sessions.current?.ownerId != owner) return;
    if (intent == null) return _set(state.copy(pending: {...pending, 'problem': problem!.name}, sending: false));
    _answer(requestId, pending['question'] as String, resolveDay(intent, records(), l, focus: focus));
  }

  static String _clip(String s) => s.length > 1500 ? s.substring(0, 1500) : s;

  /// Works a reply out again from the records as they are now (same request, same follow-up target). No AI.
  void recalculate(String messageId, DayRecords records, AppLocalizations l) => _rework(messageId, records, l, (intent) => intent);

  /// The person's answer to one confirmation of an idea (a record chosen, or an amount chosen in the amount form). The
  /// reply is worked out again from the records as they are now. No AI.
  void confirmIdea(String messageId, int idea, int index, DayRecords records, AppLocalizations l, {int? option, Json? part}) => _rework(messageId, records, l,
      (intent) => idea < 0 || idea >= intent.ideas.length ? intent : intent.withIdeas([...intent.ideas]..[idea] = confirmIdeaFood(intent.ideas[idea], index, option: option, part: part)));

  void _rework(String messageId, DayRecords records, AppLocalizations l, DayIntent Function(DayIntent) change) {
    final i = state.messages.indexWhere((m) => m['id'] == messageId);
    if (i < 0) return;
    final reply = Map<String, dynamic>.from(state.messages[i]['reply'] as Map);
    final intent = DayIntent.fromJson(reply['intent']);
    if (intent == null) return;
    final earlier = state.messages.take(i).lastWhere((m) => m['role'] == 'assistant', orElse: () => const {});
    final focus = [for (final c in (earlier['reply'] as Map?)?['cards'] as List? ?? const []) if (c is Map && c['choice'] != true) Map<String, dynamic>.from(c)];
    _set(state.copy(messages: [...state.messages]..[i] = {...state.messages[i], 'reply': resolveDay(change(intent), records, l, focus: focus)}));
  }

  void cancel() {
    if (!state.sending) return;
    _turn++;
    _unsent = state.pending!['question'] as String;
    _set(state.copy(clearPending: true, unsent: _unsent, sending: false));
  }

  void edit() {
    if (state.sending || state.pending == null) return;
    _unsent = state.pending!['question'] as String;
    _set(state.copy(clearPending: true, unsent: _unsent));
  }

  void clear() {
    _turn++;
    _set(state.copy(messages: const [], clearPending: true, sending: false));
  }
}

// ---------------------------------------------------------------------------- the screen

class DayCoachScreen extends ConsumerStatefulWidget {
  const DayCoachScreen({super.key, required this.day, this.start});
  final (DayIntent, String)? start;

  /// The day being looked at where it was opened (Today: today; Eat: the day shown there).
  final String day;
  @override
  ConsumerState<DayCoachScreen> createState() => _DayCoachScreenState();
}

class _DayCoachScreenState extends ConsumerState<DayCoachScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _arrivedKey = GlobalKey();
  String? _arrived;
  bool _started = false;

  DayConversation get _convo => ref.read(dayConversationProvider.notifier);

  @override
  void initState() {
    super.initState();
    ref.listenManual<AskState>(dayConversationProvider, (prev, next) {
      if (next.loaded && !_started && widget.start != null) {
        _started = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _builtIn(widget.start!.$1, widget.start!.$2) : null);
      }
      if (next.loaded && (prev?.loaded != true || next.unsent != prev?.unsent) && _text.text != next.unsent) _text.text = next.unsent;
      final last = next.messages.lastOrNull;
      if (prev != null && prev.loaded && last?['role'] == 'assistant' && last?['id'] != prev.messages.lastOrNull?['id']) {
        setState(() => _arrived = last!['id'] as String);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final c = _arrivedKey.currentContext;
          if (c != null && c.mounted) Scrollable.ensureVisible(c);
        });
      }
    }, fireImmediately: true);
    _text.addListener(() => _convo.setUnsent(_text.text));
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The records as they are now on this phone.
  DayRecords _records() {
    final today = ref.read(todayKeyProvider);
    final profile = ref.read(profileProvider).value;
    List<FoodEntry>? entries(String day) {
      final rows = ref.read(foodProvider(day));
      return rows.hasValue ? [for (final r in rows.value!) if (!r.value.isDeleted) r.value] : null;
    }

    return DayRecords(
      today: today, shown: widget.day, snapshot: ref.read(dailySnapshotProvider), workouts: ref.read(workoutListProvider), entries: entries,
      calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal,
      items: coachItems([for (final r in ref.read(savedMealsProvider).value ?? const <Stored<SavedMeal>>[]) r.value],
          [for (final r in ref.read(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) r.value]),
      pending: ref.read(pendingCountProvider).value ?? 0, runOpen: (ref.read(runsProvider).value ?? const <Stored<Run>>[]).any((r) => r.value.isOpen && !r.value.isDeleted),
      mealNow: mealAt(DateTime.now()),
      usual: ref.read(usualMealProvider(mealAt(DateTime.now()))),
    );
  }

  /// Where an idea's foods are matched (features/coach/meal_ideas.dart): everyday foods, the person's own saved foods,
  /// foods seen on this phone, then at most three searches of the account's food search.
  Future<List<Json>> _match(Object? raw) async {
    final lang = foodLang(context.l10n);
    // Loaded on demand: nothing may have read the bundled foods or the phone's seen foods yet (a fresh start).
    Future<T?> loaded<T>(Future<T> f) async {
      try {
        return await f.timeout(const Duration(seconds: 5));
      } on Object {
        return null;
      }
    }
    final common = (await loaded(ref.read(commonFoodsProvider.future)))?.foods ?? const <CommonFood>[];
    final seen = await loaded(ref.read(seenFoodsProvider.future)) ?? const <FoodItem>[];
    if (!mounted) return const [];
    final discovery = ref.read(foodDiscoveryProvider);
    return resolveIdeas(ideasOf(raw), IdeaSources(
      common: [for (final c in common) (item: c.item, fields: c.fields, name: c.nameIn(lang), detail: c.qualifierIn(lang), startUnit: c.unitId)],
      mine: [for (final r in ref.read(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) if (!r.value.isDeleted) candidateOf(r.value.item)],
      seen: [for (final i in seen) candidateOf(i)],
      search: (q) async {
        try {
          return await discovery.search(q).timeout(const Duration(seconds: 8));
        } on LookupFailure {
          return const [];
        }
      },
    ));
  }

  void _builtIn(DayIntent intent, String said) {
    _convo.ask(intent, said, _records(), context.l10n);
    _toEnd();
  }

  void _send(String question, {bool retry = false}) {
    if (!retry) _text.clear();
    _convo.send(question, _records, context.l10n, retry: retry, ideas: ref.read(dayIdeasAvailableProvider), match: _match);
    _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  List<(String, DayIntent)> _chips(AppLocalizations l, AskState s) {
    final focus = _convo.focus;
    return [
      if (focus.length == 1) (l.dcChipSmaller, const DayIntent('portion', change: 'smaller')),
      (l.dcChipToday, const DayIntent('today', today: true)),
      (l.dcChipRecorded, const DayIntent('recorded', today: true)),
      (l.dcChipProtein, const DayIntent('goal', nutrient: Nutrient.protein, today: true)),
      (l.dcChipSaved, const DayIntent('suggest')),
      (l.ebIdeas, const DayIntent('eat')),
    ];
  }

  /// Ready requests for new ideas (typed requests, so they need the server's ideas): shown after What could I eat?.
  List<String> _ideaRequests(AppLocalizations l) => [l.dcIdeaQuickProtein, l.dcIdeaSweet, l.dcIdeaNoCooking, l.dcIdeaVegetarian, if (_records().usual != null) l.dcIdeaDifferent];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(dayConversationProvider);
    final l = context.l10n;
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));
    final available = ref.watch(dayCoachAvailableProvider);
    // Watched so a reply made earlier is seen as changed the moment the records change.
    for (final p in [profileProvider, savedMealsProvider, savedFoodsProvider, pendingCountProvider]) {
      ref.watch(p);
    }
    ref.watch(dailySnapshotProvider);
    for (final d in {widget.day, ref.watch(todayKeyProvider), for (final m in s.messages) if (m['reply'] is Map) (m['reply'] as Map)['dayKey'] as String}) {
      ref.watch(foodProvider(d));
    }
    final records = _records();
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(key: const Key('day-close'), tooltip: l.actionClose, icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context)),
        actions: [
          if (!s.isEmpty)
            IconButton(key: const Key('day-clear'), tooltip: l.coachAskClearTooltip, icon: const Icon(Icons.delete_sweep_outlined), onPressed: s.sending ? null : () async {
              if (await confirm(context, title: l.coachAskClearTitle, body: l.coachAskClearBody, action: l.coachAskClearAction)) _convo.clear();
            }),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Row(children: [
                  ClipOval(
                    child: ColoredBox(
                      color: context.c.sunken,
                      child: CoachCompanion(key: const Key('day-companion'), guide: guide, size: const Size.square(48), frame: RigFrame.inline, attentive: s.sending),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Heading(l.dcTitle, size: 30, serif: true),
                      Text(guide.displayName(l), style: context.sansStyle(14, weight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(l.dcAboutDay(longDate(widget.day)), key: const Key('day-context'), style: context.sansStyle(15, weight: FontWeight.w600)),
                if (widget.day != records.today) Text(l.dcEarlierDay, key: const Key('day-earlier'), style: context.caption),
                const SizedBox(height: 6),
                Text(l.dcPrivacy, key: const Key('day-privacy'), style: context.caption),
                if (s.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l.dcIntro, style: context.sansStyle(15, color: context.c.secondary)),
                ],
                for (final m in s.messages)
                  if (m['role'] == 'user') _question(m['text'] as String) else _answer(m, records),
                if (s.pending != null) ..._pending(s),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final (said, intent) in _chips(l, s))
                    // An outlined pill whose words wrap (a chip would clip them at large text on a narrow phone).
                    OutlinedButton(
                        key: Key('day-chip-${intent.kind}${intent.change ?? ''}'),
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel)), side: BorderSide(color: context.c.outline), minimumSize: const Size(48, 48),
                            foregroundColor: context.c.text, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                        onPressed: s.sending || !s.loaded ? null : () => _builtIn(intent, said),
                        child: Text(said)),
                  // After What could I eat?: new ideas, each a typed request the server reads (only when it can).
                  if (ref.watch(dayIdeasAvailableProvider) && available && (s.messages.lastOrNull?['reply'] as Map?)?['intent'] is Map &&
                      const {'eat', 'ideas'}.contains(((s.messages.last['reply'] as Map)['intent'] as Map)['kind']))
                    for (final (i, words) in _ideaRequests(l).indexed)
                      OutlinedButton(
                          key: Key('day-idea-$i'),
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel)), side: BorderSide(color: context.c.accent), minimumSize: const Size(48, 48),
                              foregroundColor: context.c.text, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                          onPressed: s.sending || !s.loaded ? null : () => _send(words),
                          child: Text(words)),
                ]),
              ],
            ),
          ),
          _composer(s, large, available),
        ]),
      ),
    );
  }

  Widget _composer(AskState s, bool large, bool available) => Container(
        decoration: BoxDecoration(color: context.c.page, border: Border(top: BorderSide(color: context.c.divider))),
        padding: EdgeInsets.fromLTRB(context.inset, 8, context.inset, 8),
        child: !available
            ? Text(context.l10n.dcNoAi, key: const Key('day-no-ai'), style: context.caption)
            : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    key: const Key('day-input'), controller: _text, minLines: 1, maxLines: large ? 2 : 4, maxLength: 600,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => currentLength < 500 ? null : Text('$currentLength / $maxLength'),
                    textInputAction: TextInputAction.send, textCapitalization: TextCapitalization.sentences, onSubmitted: (v) => _send(v),
                    decoration: InputDecoration(hintText: context.l10n.dcInputHint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(26))),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder(
                  valueListenable: _text,
                  builder: (context, v, _) => IconButton.filled(
                      key: const Key('day-send'), tooltip: context.l10n.coachAskSend, iconSize: 24, constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                      style: IconButton.styleFrom(backgroundColor: context.c.accentDeep, foregroundColor: context.c.onAccentDeep, disabledBackgroundColor: context.c.sunken, disabledForegroundColor: context.c.secondary),
                      onPressed: s.sending || !s.loaded || v.text.trim().isEmpty ? null : () => _send(_text.text), icon: const Icon(Icons.send_rounded)),
                ),
              ]),
      );

  Widget _question(String text) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsetsDirectional.only(top: 16, start: 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: context.c.surface, border: Border.all(color: context.c.outline), borderRadius: BorderRadius.circular(Radii.panel)),
          child: Semantics(label: context.l10n.coachAskYouAsked(text), excludeSemantics: true, child: Text(text, style: context.body)),
        ),
      );

  List<Widget> _pending(AskState s) {
    final p = s.pending!, l = context.l10n, problem = s.problem ?? AskProblem.unavailable;
    return [
      _question(p['question'] as String),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: s.sending
            ? Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                Text(l.dcWaiting, key: const Key('day-sending'), style: context.sansStyle(15, color: context.c.secondary)),
                TextButton(key: const Key('day-cancel'), onPressed: _convo.cancel, child: Text(l.actionCancel)),
              ])
            : Semantics(
                liveRegion: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StatusLine(Icons.info_outline, switch (problem) {
                    AskProblem.limit => l.dcProblemLimit,
                    AskProblem.busy => l.dcProblemBusy,
                    AskProblem.unreached => l.dcProblemUnreached,
                    AskProblem.invalid => l.coachAskProblemInvalid,
                    AskProblem.interrupted => l.dcProblemInterrupted,
                    AskProblem.unavailable => l.dcProblemUnavailable,
                  }, key: const Key('day-problem'), tone: Tone.warning),
                  Text(l.dcStillWorks, style: context.caption),
                  Wrap(spacing: 8, children: [
                    if (problem != AskProblem.invalid) TextButton(key: const Key('day-retry'), onPressed: () => _send(p['question'] as String, retry: true), child: Text(l.coachAskRetry)),
                    TextButton(key: const Key('day-edit'), onPressed: _convo.edit, child: Text(l.coachAskEditQuestion)),
                  ]),
                ]),
              ),
      ),
    ];
  }

  /// Whether [reply] was made from records that have changed since.
  bool _stale(Json reply, DayRecords r) =>
      dayRevision(r, reply['dayKey'] as String, itemIds: [for (final c in reply['cards'] as List? ?? const []) (c as Map)['id'] as String], training: reply['training'] == true) != reply['revision'];

  Widget _answer(Json m, DayRecords records) {
    final l = context.l10n;
    final id = m['id'] as String;
    final reply = Map<String, dynamic>.from(m['reply'] as Map);
    final cards = [for (final c in reply['cards'] as List? ?? const []) Map<String, dynamic>.from(c as Map)];
    final actions = [for (final a in reply['actions'] as List? ?? const []) Map<String, dynamic>.from(a as Map)];
    final stale = _stale(reply, records);
    final arrived = id == _arrived;
    final day = reply['dayKey'] as String;
    return Padding(
      key: arrived ? _arrivedKey : null,
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        container: true, liveRegion: arrived,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CoachAvatar(size: 26),
            const SizedBox(width: 8),
            Flexible(child: Text(reply['ai'] == true ? l.dcAiRead : l.dcBuiltIn, key: Key('day-label-$id'), style: context.caption)),
          ]),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(day == records.today ? l.dcBasisToday(longDate(day)) : l.dcBasisDay(longDate(day)), style: context.caption)),
          if (stale)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                StatusLine(Icons.history, l.dcStale, key: Key('day-stale-$id'), tone: Tone.warning),
                TextButton(key: Key('day-recalc-$id'), onPressed: () => _convo.recalculate(id, _records(), l), child: Text(l.dcRecalculate)),
              ]),
            ),
          // Lines of fact in the pale panel; a reply that is only a card has none, and no empty bubble.
          if ((reply['lines'] as List? ?? const []).isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsetsDirectional.only(end: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: context.c.tint, borderRadius: BorderRadius.circular(Radii.panel)),
            child: Text((reply['lines'] as List? ?? const []).join('\n'), key: Key('day-answer-$id'), style: context.body.copyWith(color: GoColors.panelOf(context.c).text)),
          ),
          ],
          for (final (i, c) in cards.indexed) _card(id, i, c, reply, actions, stale),
          // Actions not tied to a card: one row of quiet buttons, each naming what it opens.
          Wrap(spacing: 4, children: [
            for (final a in actions)
              if (a['card'] == null) TextButton(key: Key('day-act-${a['id']}-$id'), onPressed: () => _act(a, reply, stale), child: Text(_actionLabel(l, a))),
          ]),
        ]),
      ),
    );
  }

  Widget _card(String id, int i, Json c, Json reply, List<Json> actions, bool stale) {
    final l = context.l10n;
    final action = actions.where((a) => a['card'] == i).firstOrNull;
    if (c['choice'] == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SecondaryButton(c['name'] as String, key: Key('day-choose-$id-$i'), onPressed: action == null ? null : () => _act(action, reply, stale)),
      );
    }
    if (c['kind'] == 'idea') return _ideaCard(id, i, c, reply, action, stale);
    final kcal = Map<String, dynamic>.from(c['kcal'] as Map), protein = Map<String, dynamic>.from(c['protein'] as Map);
    final misses = [
      if (c['overKcal'] is num) l.dcMissOverKcal(formatKcal(c['overKcal'] as num)),
      if (c['underProtein'] is num) l.dcMissUnderProtein(formatNumber((c['underProtein'] as num).ceil())),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(key: Key('day-card-$id-$i'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(c['name'] as String, style: context.sansStyle(16, weight: FontWeight.w600)),
          Text(c['amount'] as String, style: context.caption),
          const SizedBox(height: 4),
          Text('${kcalSaid(l, kcal)} · ${proteinSaid(l, protein)}', key: Key('day-values-$id-$i'), style: context.numStyle(15, weight: FontWeight.w500)),
          if (misses.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l.dcMisses(misses.join(l.dcAnd)), style: context.caption)),
          if (c['toward'] is String) Padding(padding: const EdgeInsets.only(top: 2), child: Text(c['toward'] as String, style: context.caption)),
          if (action != null) ...[
            const SizedBox(height: 10),
            PrimaryButton(l.dcActionReview, key: Key('day-review-$id-$i'), icon: Icons.fact_check_outlined, onPressed: () => _act(action, reply, stale)),
          ],
        ]),
      ),
    );
  }

  /// An idea: what it is made of and how much, and which of three it is: calculated from food records, still needing
  /// a food match (no totals), or calculated but not meeting what was asked.
  Widget _ideaCard(String id, int i, Json c, Json reply, Json? action, bool stale) {
    final l = context.l10n;
    final unmatched = [for (final u in c['unmatched'] as List? ?? const []) '$u'];
    final confirm = [for (final x in c['confirm'] as List? ?? const []) Map<String, dynamic>.from(x as Map)];
    final calculated = c['kcal'] is Map;
    final misses = [
      if (c['overKcal'] is num) l.dcMissOverKcal(formatKcal(c['overKcal'] as num)),
      if (c['underProtein'] is num) l.dcMissUnderProtein(formatNumber((c['underProtein'] as num).ceil())),
    ];
    final (status, tone) = !calculated
        ? (unmatched.isNotEmpty ? l.dcIdeaNeedsMatch(unmatched.join(l.dcAnd)) : l.dcIdeaConfirm, Tone.warning)
        : misses.isNotEmpty
            ? (l.dcMisses(misses.join(l.dcAnd)), Tone.warning)
            : c['unknownTarget'] == true
                ? (l.dcIdeaUnknownTarget, Tone.warning)
                : (l.dcIdeaCalculated, Tone.success);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(key: Key('day-card-$id-$i'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(c['name'] as String, style: context.sansStyle(16, weight: FontWeight.w600)),
          Text(l.dcIdeaLabel, style: context.caption),
          const SizedBox(height: 6),
          for (final p in c['parts'] as List? ?? const []) Text(['${(p as Map)['amount']} · ${p['name']}', if (p['match'] is String) '(${p['match']})'].join(' '), style: context.body),
          for (final u in unmatched) Text(l.dcIdeaUnmatchedFood(u), style: context.body.copyWith(color: context.c.secondary)),
          if (calculated) ...[
            const SizedBox(height: 4),
            Text('${kcalSaid(l, Map<String, dynamic>.from(c['kcal'] as Map))} · ${proteinSaid(l, Map<String, dynamic>.from(c['protein'] as Map))}', key: Key('day-values-$id-$i'),
                style: context.numStyle(15, weight: FontWeight.w500)),
          ],
          Padding(padding: const EdgeInsets.only(top: 4), child: StatusLine(Icons.info_outline, status, key: Key('day-idea-status-$id-$i'), tone: tone)),
          // What the person confirms before any total: which record a food is, or how much of it.
          for (final (k, x) in confirm.indexed) ..._confirmRow(id, i, c, k, x, reply),
          if (c['toward'] is String) Padding(padding: const EdgeInsets.only(top: 2), child: Text(c['toward'] as String, style: context.caption)),
          if (action != null) ...[
            const SizedBox(height: 10),
            action['id'] == 'reviewIdea'
                ? PrimaryButton(l.dcReviewMeal, key: Key('day-review-$id-$i'), icon: Icons.fact_check_outlined, onPressed: () => _act(action, reply, stale))
                : SecondaryButton(l.dcFindFood, key: Key('day-find-$id-$i'), icon: Icons.search, onPressed: () => _act(action, reply, stale)),
          ],
        ]),
      ),
    );
  }

  List<Widget> _confirmRow(String id, int i, Json c, int k, Json x, Json reply) {
    final l = context.l10n, idea = c['idea'] as int, label = x['label'] as String;
    void answer({int? option, Json? part}) => _convo.confirmIdea(id, idea, k, _records(), l, option: option, part: part);
    if (x['confirm'] == 'record') {
      return [
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.dcIdeaWhich(label), style: context.sansStyle(15, weight: FontWeight.w600))),
        for (final (o, opt) in (x['options'] as List).indexed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SecondaryButton(['${(opt as Map)['name']}', if (opt['match'] is String) '(${opt['match']})'].join(' '), key: Key('day-pick-$id-$i-$k-$o'), onPressed: () => answer(option: o)),
          ),
      ];
    }
    final food = Map<String, dynamic>.from(x['food'] as Map);
    return [
      Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.dcIdeaAmountNeeded(food['name'] as String), style: context.sansStyle(15, weight: FontWeight.w600))),
      if (x['asked'] is String)
        Text(l.dcIdeaPrepDiffers(['${food['name']}', if (food['match'] is String) '(${food['match']})'].join(' '), x['asked'] as String), key: Key('day-prep-$id-$i-$k'), style: context.caption),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SecondaryButton(l.dcChooseAmount, key: Key('day-amount-$id-$i-$k'), icon: Icons.tune, onPressed: () async {
          // The usual amount form, in its selection mode: the person picks a quantity in one of the record's own units.
          final item = FoodItem(food['item'] as Json), day = reply['dayKey'] as String;
          final d = await push<FoodDraft>(context, FoodFormScreen(draft: FoodDraft.of(item, dayKey: day, meal: mealAt(DateTime.now()), name: food['name'] as String), pick: true));
          if (d == null || !mounted) return;
          answer(part: {...MealComponent.ofDraft(d).j, if (food['match'] is String) 'match': food['match']});
        }),
      ),
    ];
  }

  static String _actionLabel(AppLocalizations l, Json a) => switch (a['id']) {
        'another' => l.dcAnotherIdea,
        'usual' => l.habitReview,
        'workout' => l.dcActionWorkout,
        'journal' => l.dcActionJournal,
        'goals' => l.dcActionGoals,
        'meals' => l.mealsLibraryTitle,
        'eatingOut' => l.eatHintEatingOutAction,
        'addFood' => l.habitOther,
        'training' => l.dcActionTraining,
        'ask' => l.dcActionChooseMeal,
        _ => l.dcActionReview,
      };

  /// Runs an allowlisted action against the records as they are now. A stale reply opens no review until recalculated;
  /// navigating starts, saves and logs nothing.
  Future<void> _act(Json a, Json reply, bool stale) async {
    final l = context.l10n, r = _records(), day = reply['dayKey'] as String;
    final meal = DayIntent.fromJson(reply['intent'])?.meal ?? r.mealNow;
    final shell = ref.read(shellProvider.notifier), eat = ref.read(eatDayRequestProvider.notifier);
    void home() => Navigator.of(context).popUntil((route) => route.isFirst);
    switch (a['id']) {
      case 'reviewIdea':
        // The idea's own foods and amounts, worked out again from them; a reply made before the day or goals changed is
        // recalculated first, so it is never reviewed as if it still fit.
        if (stale) return toast(context, l.dcStaleReview);
        final c = (reply['cards'] as List)[a['card'] as int] as Map;
        final parts = [for (final p in c['parts'] as List) Map<String, dynamic>.from(p as Map)];
        await push(context, MealReviewScreen(body: MealBody({'kind': MealBody.meal, 'name': c['name'], 'components': parts}), dayKey: day, meal: meal));
      case 'findFood':
        final c = (reply['cards'] as List)[a['card'] as int] as Map;
        await push(context, LogFoodScreen(dayKey: day, meal: meal, query: ((c['unmatched'] as List?)?.firstOrNull as String?) ?? ''));
      case 'usual':
        final u = ref.read(usualMealProvider(mealAt(DateTime.now())));
        if (stale || u == null) return toast(context, l.dcStaleReview);
        await reviewUsualMeal(context, u, day);
      case 'another':
        if (ref.read(dayIdeasAvailableProvider) && ref.read(dayCoachAvailableProvider)) {
          _send(l.dcAnotherIdeaText);
        } else {
          await push(context, LogFoodScreen(dayKey: day, meal: meal));
        }
      case 'ask':
        final intent = DayIntent.fromJson(a['intent']);
        final card = a['card'] is int ? (reply['cards'] as List)[a['card'] as int] as Map : null;
        if (intent != null) _builtIn(intent, card?['name'] as String? ?? _actionLabel(l, a));
      case 'review':
        final c = (reply['cards'] as List)[a['card'] as int] as Map;
        final item = r.item(c['id'] as String), portion = Portion.fromJson(c['portion']);
        if (stale || item == null || portion == null || CoachMath.values(item, portion) == null) return toast(context, l.dcStaleReview);
        if (item.kind == ItemKind.food) {
          await push(context, FoodFormScreen(draft: foodDraft(item, portion, day: day, meal: meal)!));
        } else {
          final saved = (ref.read(savedMealsProvider).value ?? const <Stored<SavedMeal>>[]).where((s) => s.value.id == item.id).firstOrNull?.value;
          // One food changed for this time: rebuilt from the saved meal as it is now, or not opened when it has changed.
          final parts = c['ingredient'] == null ? null : ingredientParts(item.body!, c['ingredient']);
          if (c['ingredient'] != null && parts == null) return toast(context, l.dcStaleReview);
          // A copy taken now: an edit arriving from another phone never changes what is being reviewed.
          await push(context, MealReviewScreen(
              body: MealBody(copyJson(item.body!.j)), saved: saved, dayKey: day, meal: meal, initialParts: parts,
              initialFactor: item.kind == ItemKind.meal ? portion.amount : null,
              initialAmount: item.kind == ItemKind.recipe ? portion.amount : null,
              initialMeasure: portion.unit == 'g' ? PortionMeasure.gram : PortionMeasure.serving));
        }
      case 'workout':
        final f = a['workoutId'] is String ? WorkoutFocus.session(a['workoutId'] as String) : WorkoutFocus.preview(a['planId'] as String, a['occasionId'] as String);
        home();
        shell.openWorkout(f);
      case 'journal':
        eat.show(day);
        home();
        shell.switchTab(2);
      case 'goals':
        // Goals are edited in Eat: Eat opens its own goal sheet, over today's journal.
        eat.show(r.today, goals: true);
        home();
        shell.switchTab(2);
      case 'meals':
        await openMealsLibrary(context, dayKey: day, meal: meal);
      case 'eatingOut':
        await openEatingOut(context, dayKey: day, meal: meal);
      case 'addFood':
        await push(context, LogFoodScreen(dayKey: day, meal: meal));
      case 'training':
        await openAskGoHard(context, const CoachContext(label: 'Your training'));
    }
  }
}
