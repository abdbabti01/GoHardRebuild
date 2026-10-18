import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/ask_screen.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_companion.dart';
import 'package:gohard_rebuild/features/coach/coach_contract.dart';
import 'package:gohard_rebuild/features/coach/coach_proposal.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';

import 'support.dart';
import 'ui_support.dart';

/// Ask GoHard over a real on-disk store and a scripted `/coach/ask`. Every answer here is a fixture: no model and no
/// network are involved, so this checks the phone's side of docs/COACH.md only.

/// The scripted server: records every question; answers with the next reply, or a plain answer.
class _Coach implements Transport {
  final asks = <Json>[];
  final replies = <ApiResponse Function(Json request)>[];
  Completer<void>? hold;
  bool offline = false;

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer, Map<String, String>? headers}) async {
    if (path != '/coach/ask') return const ApiResponse(404, null);
    final request = jsonDecode(jsonEncode(data)) as Json;
    asks.add(request);
    if (offline) throw const TransportFailure('connectionError');
    if (hold != null) await hold!.future;
    final reply = replies.isEmpty ? null : replies.removeAt(0);
    return reply?.call(request) ?? _answer(request, 'Answer ${asks.length}');
  }
}

ApiResponse _answer(Json request, String text, {Json? proposal, List<String> sources = const []}) => ApiResponse(200, {
      'requestId': request['requestId'], 'kind': 'ai', 'answer': text, 'sources': sources, 'proposal': proposal,
      'draftRevision': (request['context'] as Json)['draftRevision'],
    });

Json _swap({String workoutId = 'w-upper', String key = 'e1', String catalogKey = 'dumbbell-bench-press', String op = 'replaceExercise', String scope = 'draft'}) => {
      'summary': 'Replace Bench press with Dumbbell bench press in Upper A', 'scope': scope,
      'operations': [
        {'op': op, 'workoutId': workoutId, 'occurrenceKey': key, 'catalogKey': catalogKey},
        {'op': 'setPrescription', 'workoutId': workoutId, 'occurrenceKey': key, 'targetSets': 4, 'targetRepsMin': 6, 'targetRepsMax': 10, 'targetDurationSeconds': null, 'restSeconds': 120},
      ],
    };

Json _ex(String key, String catalogKey, String name, int sets, int lo, int hi, int rest, {double? kg}) => {
      'occurrenceKey': key, 'catalogKey': catalogKey, 'name': name, 'isTimed': false, 'targetSets': sets, 'targetRepsMin': lo, 'targetRepsMax': hi,
      'targetDurationSeconds': null, 'restSeconds': rest, 'targetLoadKg': ?kg,
    };

PlanDraft _draft() => PlanDraft({
      'version': 1, 'mode': 'new', 'planId': 'plan-1', 'path': 'template', 'step': 2,
      'preferences': {'days': [1, 4], 'equipment': 'full_gym', 'timeBudgetMinutes': null, 'experience': null},
      'templateId': 'upper-lower', 'title': 'Upper / Lower', 'startDate': '2026-10-19', 'durationWeeks': 8, 'timeBudgetMinutes': null, 'effectiveDate': null,
      'workouts': [
        {'id': 'w-upper', 'name': 'Upper A', 'notes': null, 'exercises': [
          _ex('e1', 'bench-press', 'Bench press', 3, 8, 12, 90, kg: 60),
          _ex('e2', 'barbell-row', 'Barbell row', 3, 8, 12, 90),
          _ex('e3', 'triceps-pushdown', 'Triceps pushdown', 3, 10, 15, 60),
        ]},
        {'id': 'w-lower', 'name': 'Lower A', 'notes': null, 'exercises': [_ex('e1', 'back-squat', 'Back squat', 4, 5, 8, 150)]},
      ],
      'schedule': {'mode': 'fixed', 'pattern': [{'weekday': 1, 'workoutId': 'w-upper'}, {'weekday': 4, 'workoutId': 'w-lower'}], 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0},
    });

CatalogExercise _c(String key, String name, {bool custom = false}) =>
    CatalogExercise({'key': key, 'name': name, 'category': 'Strength', 'equipment': 'Barbell', 'isTimed': false, 'isCustom': custom});
final _catalog = [
  _c('back-squat', 'Back squat'), _c('barbell-row', 'Barbell row'), _c('bench-press', 'Bench press'), _c('dumbbell-bench-press', 'Dumbbell bench press'),
  _c('push-up', 'Push-up'), _c('triceps-pushdown', 'Triceps pushdown'),
];

final _guide = AskGuide({
  'version': 1,
  'sources': [{'id': 'acsm-2009', 'title': 'Progression models in resistance training', 'publisher': 'ACSM', 'url': 'https://example.test'}],
  'splits': [
    {'templateId': 'upper-lower', 'name': 'Upper / Lower', 'summary': 'Alternates upper-body and lower-body days.', 'benefits': ['Each half twice a week'], 'limitations': ['Long upper days'], 'sources': ['acsm-2009']},
    {'templateId': 'push-pull-legs', 'name': 'Push / Pull / Legs', 'summary': 'Groups muscles by movement.', 'sources': []},
  ],
  'exercises': [
    {'catalogKey': 'bench-press', 'muscles': ['Chest', 'Triceps'], 'equipment': 'Barbell and bench', 'role': 'main', 'cues': ['Feet planted'], 'alternatives': ['dumbbell-bench-press', 'push-up'], 'sources': ['unknown-id']},
  ],
  'terms': [{'id': 'sets-reps', 'term': '3 × 8–12', 'text': 'Three sets of eight to twelve repetitions.'}],
});

/// One install: the database file, the signed-in owner, the scripted server and the builder's draft.
class _Install {
  _Install() : store = TestStore();
  final TestStore store;
  final sessions = SessionManager(MemorySecretStore());
  final appearance = AppearanceStore(MemorySecretStore());
  final coach = _Coach();
  PlanDraft draft = _draft();
  int applies = 0;
  final _opened = <AppDb>[];

  /// What the builder hands Ask GoHard: its draft, and its own editor for an accepted suggestion.
  CoachContext context({CoachFocus focus = CoachFocus.exercise, bool canApply = true, String catalogKey = 'bench-press'}) => CoachContext(
        label: focus == CoachFocus.exercise ? 'Bench press · Upper A' : 'Upper / Lower', focus: focus, templateId: 'upper-lower',
        workoutId: focus == CoachFocus.exercise ? 'w-upper' : null, occurrenceKey: focus == CoachFocus.exercise ? 'e1' : null,
        catalogKey: focus == CoachFocus.exercise ? catalogKey : null,
        draft: () => draft.copy(),
        applyToDraft: !canApply
            ? null
            : (next) async {
                applies++;
                draft.j
                  ..clear()
                  ..addAll(copyJson(next.j));
              },
      );

  List<Override> open() {
    final db = store.open();
    _opened.add(db);
    return [
      sessionsProvider.overrideWithValue(sessions),
      dbProvider.overrideWithValue(db),
      appearanceStoreProvider.overrideWithValue(appearance),
      transportProvider.overrideWithValue(coach),
      syncProvider.overrideWith((ref) {
        final engine = SyncEngine(db, Api(FakeServer(), sessions), sessions)..isBlocked = () => true;
        ref.onDispose(engine.dispose);
        return engine;
      }),
      todayKeyProvider.overrideWith(() => FixedDay('2026-10-15')),
      profileProvider.overrideWith((ref) => Stream.value(Profile({...authFor('one')['profile'] as Json, 'loadUnit': 'kg'}))),
      catalogProvider.overrideWith((ref) => Stream.value(_catalog)),
      customExercisesProvider.overrideWith((ref) => Stream.value([CustomExercise({'id': 'mine', 'name': 'My curl', 'category': 'Arms', 'equipment': 'Dumbbells', 'isTimed': false})])),
      askGuideProvider.overrideWith((ref) async => _guide),
    ];
  }

  Future<void> close() async {
    for (final d in _opened) {
      await d.close();
    }
    _opened.clear();
  }

  SyncEngine _sync() => SyncEngine(_opened.last, Api(FakeServer(), sessions), sessions)..isBlocked = () => true;
  Future<Json?> chat(String owner) async {
    final r = await _sync().get(owner, Kinds.coachChat, 'current');
    return r == null ? null : jsonDecode(r.body) as Json;
  }

  Future<List<Cmd>> commands() => _sync().commands('one');
}

/// The builder stands in as a long scrolled page with the Ask GoHard button at its end.
class _Host extends StatefulWidget {
  const _Host(this.coach);
  final CoachContext Function() coach;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          key: const Key('host-list'),
          child: Column(children: [
            const SizedBox(height: 1500),
            TextButton(key: const Key('open'), onPressed: () => openAskGoHard(context, widget.coach()), child: const Text('Ask GoHard')),
          ]),
        ),
      );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Future<void> _launch(WidgetTester tester, _Install install, {CoachContext Function()? coach, Size size = const Size(390, 1000), double textScale = 1}) async {
  await pumpApp(tester, install.open(), home: _Host(coach ?? install.context), size: size, textScale: textScale);
  await _open(tester);
}

Future<void> _open(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  expect(f, findsOneWidget);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _key(WidgetTester tester, String key) => _tap(tester, find.byKey(Key(key)));
Finder _prefixed(String p) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(p));

Future<void> _ask(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const Key('ask-input')), q);
  await tester.pump();
  await tester.tap(find.byKey(const Key('ask-send')));
  await _settle(tester);
}

String _input(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('ask-input'))).controller!.text;
List<Json> _upper(PlanDraft d) => [for (final e in d.workout('w-upper')!.exercises) e.j];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late _Install install;
  setUp(() async {
    install = _Install();
    await install.sessions.signIn(authFor('one'));
  });
  tearDown(() async {
    await install.close();
    install.store.dispose();
  });

  testWidgets('opening sends nothing; Send asks once with the draft and its revision, duplicate taps included; follow-ups carry at most 6 turns', (tester) async {
    await _launch(tester, install);
    expect(install.coach.asks, isEmpty, reason: 'opening asks nothing');
    expect(find.text('Ask GoHard'), findsOneWidget);
    expect(find.text('About: Bench press · Upper A'), findsOneWidget);
    expect(find.text('AI training assistant'), findsOneWidget);
    expect(find.byKey(const Key('ask-suggest-1')), findsOneWidget);
    expect(find.text('Can I replace it with a dumbbell exercise?'), findsOneWidget, reason: 'suggestions for the exercise in focus');

    install.coach.hold = Completer();
    await tester.enterText(find.byKey(const Key('ask-input')), 'Is bench press enough for chest?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ask-send')));
    await tester.tap(find.byKey(const Key('ask-send')));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(install.coach.asks, hasLength(1), reason: 'one question in flight; repeated taps are ignored');
    expect(find.byKey(const Key('ask-sending')), findsOneWidget);
    expect(find.bySemanticsLabel('You asked: Is bench press enough for chest?'), findsOneWidget, reason: 'the question stays on screen while waiting');
    expect(tester.widget<IconButton>(find.byKey(const Key('ask-send'))).onPressed, isNull);

    final sent = install.coach.asks.single;
    final context = sent['context'] as Json;
    expect((sent['question'], (sent['history'] as List).length, (sent['requestId'] as String).isNotEmpty), ('Is bench press enough for chest?', 0, true));
    expect((context['label'], context['focus'], context['templateId'], context['workoutId'], context['occurrenceKey'], context['catalogKey']),
        ('Bench press · Upper A', 'exercise', 'upper-lower', 'w-upper', 'e1', 'bench-press'));
    expect(context['draftRevision'], draftRevision(install.draft));
    expect(jsonEncode((context['draft'] as Json)['workouts']), jsonEncode(install.draft.planBody['workouts']));
    expect((context['draft'] as Json).keys.toSet(), {'title', 'durationWeeks', 'timeBudgetMinutes', 'schedule', 'workouts'});

    install.coach.hold!.complete();
    install.coach.hold = null;
    await _settle(tester);
    expect(find.text('Answer 1'), findsOneWidget);
    expect(_prefixed('ask-ai-').evaluate().where((e) => (e.widget.key! as ValueKey<String>).value != 'ask-ai-assistant'), hasLength(1), reason: 'the answer is marked AI-generated');
    final answer = find.ancestor(of: _prefixed('ask-ai-').evaluate().map((e) => find.byWidget(e.widget)).firstWhere((f) => (f.evaluate().single.widget.key! as ValueKey<String>).value != 'ask-ai-assistant'), matching: find.byType(Row)).first;
    expect(find.descendant(of: answer, matching: find.byType(CoachAvatar)), findsOneWidget, reason: 'answered by the selected guide, face and name, not a generic AI icon');
    expect(find.descendant(of: answer, matching: find.text('Leon')), findsOneWidget);
    expect(find.descendant(of: answer, matching: find.byIcon(Icons.auto_awesome_outlined)), findsNothing);
    expect(find.text('AI-generated'), findsOneWidget);

    await _ask(tester, 'And for triceps?');
    expect((install.coach.asks[1]['history'] as List).map((h) => '${(h as Json)['role']}: ${h['text']}'),
        ['user: Is bench press enough for chest?', 'assistant: Answer 1']);
    await _ask(tester, 'Third');
    await _ask(tester, 'Fourth');
    final history = install.coach.asks[3]['history'] as List;
    expect((history.length, (history.first as Json)['text']), (6, 'Is bench press enough for chest?'));
    await _ask(tester, 'Fifth');
    expect(((install.coach.asks[4]['history'] as List).first as Json)['text'], 'And for triceps?', reason: 'only the last 6 turns');
    expect(find.text('Answer 5'), findsOneWidget);
  });

  testWidgets('503, a timeout-free failure and 429 are honest states: the question is kept, Retry reuses the requestId, nothing says Offline', (tester) async {
    await _launch(tester, install);
    install.coach.replies.add((_) => const ApiResponse(503, {'code': 'COACH_UNAVAILABLE', 'detail': 'anthropic: invalid x-api-key GOHARD_Coach__AnthropicApiKey'}));
    await _ask(tester, 'Why this order?');
    expect(find.textContaining('isn\'t available right now'), findsOneWidget);
    expect(find.bySemanticsLabel('You asked: Why this order?'), findsOneWidget);
    expect(find.byKey(const Key('ask-guide-link')), findsOneWidget, reason: 'the built-in guide is offered');
    for (final hidden in ['Offline', 'offline', 'api-key', 'Anthropic', 'GOHARD_']) {
      expect(find.textContaining(hidden), findsNothing, reason: hidden);
    }

    await _key(tester, 'ask-retry');
    expect(install.coach.asks[1]['requestId'], install.coach.asks[0]['requestId'], reason: 'a retry is the same question');
    expect(find.text('Answer 2'), findsOneWidget);
    expect(find.byKey(const Key('ask-problem')), findsNothing);

    install.coach.replies.add((_) => const ApiResponse(429, {'code': 'COACH_LIMIT'}));
    await _ask(tester, 'One more?');
    expect(find.textContaining('You\'ve asked a lot today'), findsOneWidget);

    // The provider's own rate limit or overload: busy, not the person's daily limit; the question and Retry stay.
    install.coach.replies.add((_) => const ApiResponse(503, {'code': 'COACH_BUSY', 'retryAfterSeconds': 30}));
    await _key(tester, 'ask-retry');
    expect(find.text('Ask GoHard is busy right now. Try again in a moment.'), findsOneWidget);
    expect(find.textContaining('You\'ve asked a lot today'), findsNothing);
    expect(find.textContaining('isn\'t available'), findsNothing);
    expect(find.bySemanticsLabel('You asked: One more?'), findsOneWidget);
    expect(find.byKey(const Key('ask-retry')), findsOneWidget);
    expect(find.textContaining('ffline'), findsNothing);
    await _key(tester, 'ask-retry');
    expect(install.coach.asks.last['requestId'], install.coach.asks[install.coach.asks.length - 2]['requestId'], reason: 'Retry after busy is the same question');
    expect(find.byKey(const Key('ask-problem')), findsNothing, reason: 'the retried question was answered');

    install.coach.replies.add((_) => const ApiResponse(429, {'code': 'COACH_LIMIT'}));
    await _ask(tester, 'Last one?');
    install.coach.offline = true;
    await _key(tester, 'ask-retry');
    expect(find.textContaining('couldn\'t be reached'), findsOneWidget);
    expect(find.textContaining('Offline'), findsNothing);
    expect(find.textContaining('offline'), findsNothing);
  });

  testWidgets('Cancel drops a late answer and puts the question back; an answer for a previous owner is dropped', (tester) async {
    await _launch(tester, install);
    install.coach.hold = Completer();
    await tester.enterText(find.byKey(const Key('ask-input')), 'Slow question');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ask-send')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ask-cancel')));
    await tester.pump();
    expect(_input(tester), 'Slow question');
    install.coach.hold!.complete();
    install.coach.hold = null;
    await _settle(tester);
    expect(find.text('Answer 1'), findsNothing, reason: 'cancelled: its late answer is not shown');

    install.coach.hold = Completer();
    await tester.tap(find.byKey(const Key('ask-send')));
    await tester.pump();
    expect(install.coach.asks, hasLength(2));
    await tester.runAsync(() => install.sessions.signIn(authFor('two')));
    await tester.pump();
    install.coach.hold!.complete();
    install.coach.hold = null;
    await _settle(tester);
    expect(find.text('Answer 2'), findsNothing);
    final one = await tester.runAsync(() => install.chat('one')), two = await tester.runAsync(() => install.chat('two'));
    expect((one!['messages'] as List), isEmpty, reason: 'the answer belongs to no one now');
    expect(((two?['messages'] as List?) ?? const []), isEmpty);
    expect(find.bySemanticsLabel('You asked: Slow question'), findsNothing, reason: 'the next owner sees none of it');
  });

  testWidgets('the companion is attentive only while a question is really waiting: an answer, a failure or Cancel ends it', (tester) async {
    bool attentive() => tester.widget<CoachCompanion>(find.byKey(const Key('ask-companion'))).attentive;
    // While waiting, the progress line animates (so no pumpAndSettle here); the companion itself reaches its pose and stops.
    Future<void> send(String q) async {
      await tester.enterText(find.byKey(const Key('ask-input')), q);
      await tester.pump();
      await tester.tap(find.byKey(const Key('ask-send')));
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await _launch(tester, install);
    expect(attentive(), isFalse, reason: 'opening sends nothing, so nothing is pending');

    install.coach.hold = Completer();
    await send('First');
    expect(attentive(), isTrue);
    expect(tester.state<CoachCompanionState>(find.byKey(const Key('ask-companion'))).ticking, isFalse, reason: 'holds the pose without frames');
    install.coach.hold!.complete();
    install.coach.hold = null;
    await _settle(tester);
    expect(find.text('Answer 1'), findsOneWidget);
    expect(attentive(), isFalse, reason: 'answered');

    install.coach.replies.add((_) => const ApiResponse(503, null));
    await _ask(tester, 'Second');
    expect(attentive(), isFalse, reason: 'failed: no pose pretends to wait');

    await _key(tester, 'ask-edit');
    install.coach.hold = Completer();
    await send('Third');
    expect(attentive(), isTrue);
    await tester.tap(find.byKey(const Key('ask-cancel')));
    await tester.pump();
    expect(attentive(), isFalse, reason: 'cancelled');
    install.coach.hold!.complete();
    install.coach.hold = null;
    await _settle(tester);
  });

  testWidgets('the conversation and unsent text survive closing, a restart and a theme change, and no other account sees them; Close returns to the same place', (tester) async {
    await _launch(tester, install);
    final hostScroll = tester.state<ScrollableState>(find.descendant(of: find.byKey(const Key('host-list'), skipOffstage: false), matching: find.byType(Scrollable, skipOffstage: false), skipOffstage: false)).position.pixels;
    await _ask(tester, 'Why bench first?');
    await tester.enterText(find.byKey(const Key('ask-input')), 'half typed');
    await _settle(tester);
    await _key(tester, 'ask-close');
    expect(find.byKey(const Key('open')), findsOneWidget, reason: 'back on the builder');
    expect(tester.state<ScrollableState>(find.descendant(of: find.byKey(const Key('host-list'), skipOffstage: false), matching: find.byType(Scrollable, skipOffstage: false), skipOffstage: false)).position.pixels, hostScroll);
    expect(jsonEncode(install.draft.j), jsonEncode(_draft().j));

    await _open(tester);
    expect((find.text('Answer 1').evaluate().length, _input(tester)), (1, 'half typed'));

    install.appearance
      ..accent = Accent.pink
      ..mode = ThemeMode.dark;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(install.close);
    await _launch(tester, install);
    expect((find.text('Answer 1').evaluate().length, _input(tester)), (1, 'half typed'), reason: 'after a restart');

    await tester.runAsync(() => install.sessions.signIn(authFor('two')));
    await tester.pumpWidget(const SizedBox());
    await _launch(tester, install);
    expect((find.text('Answer 1').evaluate().length, _input(tester)), (0, ''), reason: 'another account sees none of it');
    expect(find.byKey(const Key('ask-suggest-0')), findsOneWidget);

    await tester.runAsync(() => install.sessions.signIn(authFor('one')));
    await tester.pumpWidget(const SizedBox());
    await _launch(tester, install);
    expect(find.text('Answer 1'), findsOneWidget, reason: 'and it is there again for its owner');
  });

  testWidgets('Quick guide works with no connection and sends nothing; it is labelled built in; unknown source IDs are not shown', (tester) async {
    install.coach.offline = true;
    await _launch(tester, install);
    await _key(tester, 'ask-quick-guide');
    expect(find.text('Quick guide · built-in reviewed content'), findsOneWidget);
    expect(find.text('Upper / Lower'), findsOneWidget);
    expect(find.text('• Dumbbell bench press'), findsOneWidget);
    expect(find.text('• Feet planted'), findsOneWidget);
    expect(find.text('Progression models in resistance training · ACSM'), findsOneWidget);
    expect(find.textContaining('unknown-id'), findsNothing);
    expect(find.text('Three sets of eight to twelve repetitions.'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);

    await tester.enterText(find.byKey(const Key('ask-input')), 'What does 3 x 8-12 mean?');
    await tester.pump();
    await _key(tester, 'ask-quick-guide');
    expect(find.text('Three sets of eight to twelve repetitions.'), findsOneWidget);
    expect(install.coach.asks, isEmpty, reason: 'the built-in guide sends nothing');

    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);
    expect(_input(tester), 'What does 3 x 8-12 mean?');
  });

  testWidgets('a custom exercise in focus claims nothing: "Added by you"', (tester) async {
    await _launch(tester, install, coach: () => install.context(catalogKey: 'custom:mine'));
    await _key(tester, 'ask-quick-guide');
    expect(find.textContaining('Added by you'), findsOneWidget);
    expect(find.text('My curl'), findsOneWidget);
  });

  test('a proposal naming an unknown workout, exercise, catalog key or another account\'s exercise, or an unknown operation or scope, is not applicable', () {
    final d = _draft();
    final mine = [..._catalog, _c('custom:mine', 'My curl', custom: true)];
    expect(checkProposal(_swap(), d, mine)!.notApplicable, isEmpty);
    expect(checkProposal(_swap(workoutId: 'w-gone'), d, mine)!.canApply, isFalse);
    expect(checkProposal(_swap(key: 'e9'), d, mine)!.canApply, isFalse);
    expect(checkProposal(_swap(catalogKey: 'made-up'), d, mine)!.notApplicable, hasLength(1));
    expect(checkProposal(_swap(catalogKey: 'custom:someone-else'), d, mine)!.notApplicable, hasLength(1));
    expect(checkProposal(_swap(catalogKey: 'custom:mine'), d, mine)!.notApplicable, isEmpty);
    expect(checkProposal(_swap(op: 'deleteWorkout'), d, mine), isNull);
    expect(checkProposal(_swap(scope: 'plan'), d, mine), isNull);
    final tooMany = {..._swap(), 'operations': [for (var i = 0; i < 9; i++) (_swap()['operations'] as List).last]};
    expect(checkProposal(tooMany, d, mine), isNull);
    final outOfRange = {..._swap(), 'operations': [{'op': 'setPrescription', 'workoutId': 'w-upper', 'occurrenceKey': 'e2', 'targetSets': 50}]};
    expect(checkProposal(outOfRange, d, mine)!.canApply, isFalse);
    final weight = {..._swap(), 'operations': [{'op': 'setPrescription', 'workoutId': 'w-upper', 'occurrenceKey': 'e1', 'targetSets': 5}]};
    expect(Prescription(checkProposal(weight, d, mine)!.next.workout('w-upper')!.exercises.first.j).targetLoadKg, 60, reason: 'a prescription change keeps the weight target');
    expect(jsonEncode(d.j), jsonEncode(_draft().j), reason: 'checking changes nothing');
  });

  testWidgets('an unusable proposal gets no Preview; outside the builder a proposal is text only', (tester) async {
    install.coach.replies.add((r) => _answer(r, 'Try dumbbells.', proposal: _swap(catalogKey: 'custom:someone-else')));
    await _launch(tester, install);
    await _ask(tester, 'Can I replace it with a dumbbell exercise?');
    expect(_prefixed('ask-invalid-'), findsOneWidget);
    expect(_prefixed('ask-preview-'), findsNothing);
    await tester.pumpWidget(const SizedBox());

    install.coach.replies.add((r) => _answer(r, 'Try dumbbells.', proposal: _swap()));
    await _launch(tester, install, coach: () => install.context(canApply: false));
    await _ask(tester, 'Again?');
    expect(_prefixed('ask-preview-'), findsNothing);
    expect(_prefixed('ask-text-only-'), findsNWidgets(2));
  });

  testWidgets('Preview and Keep current change nothing; Apply changes exactly what was previewed, activates nothing; Undo restores only what it changed', (tester) async {
    install.coach.replies.add((r) => _answer(r, 'Dumbbells are easier on the shoulders.', proposal: _swap(), sources: ['acsm-2009']));
    await _launch(tester, install);
    await _ask(tester, 'Can I replace it with a dumbbell exercise?');
    await _tap(tester, _prefixed('ask-more-'));
    expect(find.text('Progression models in resistance training · ACSM'), findsOneWidget);
    final before = jsonEncode(install.draft.j);

    await _tap(tester, _prefixed('ask-preview-'));
    expect(find.text('Draft only'), findsOneWidget);
    final preview = tester.widget<Text>(find.byKey(const Key('ask-change-0'))).data!;
    expect(preview, contains('Bench press → Dumbbell bench press'));
    expect(preview, contains('3 × 8–12 · 90 s rest → 4 × 6–10 · 120 s rest'));
    expect(preview, contains('Weight target 60 kg is cleared'));
    expect(find.byKey(const Key('ask-change-1')), findsNothing, reason: 'one exercise changes');
    await _key(tester, 'ask-keep');
    expect((jsonEncode(install.draft.j), install.applies), (before, 0), reason: 'preview and dismiss change nothing');

    await _tap(tester, _prefixed('ask-preview-'));
    await _key(tester, 'ask-apply');
    expect(install.applies, 1);
    final upper = _upper(install.draft), was = _upper(_draft());
    expect((upper[0]['catalogKey'], upper[0]['name'], upper[0]['targetSets'], upper[0]['targetRepsMin'], upper[0]['targetRepsMax'], upper[0]['restSeconds'], upper[0].containsKey('targetLoadKg')),
        ('dumbbell-bench-press', 'Dumbbell bench press', 4, 6, 10, 120, false));
    expect(upper[0]['occurrenceKey'], isNot('e1'), reason: 'a replacement is a new exercise with its own history');
    expect(jsonEncode(upper.skip(1).toList()), jsonEncode(was.skip(1).toList()));
    expect(jsonEncode(install.draft.workout('w-lower')!.j), jsonEncode(_draft().workout('w-lower')!.j));
    expect(jsonEncode(install.draft.j['schedule']), jsonEncode(_draft().j['schedule']));
    expect(await tester.runAsync(install.commands), isEmpty, reason: 'nothing is created or activated');
    expect(_prefixed('ask-applied-'), findsOneWidget);

    install.draft.setPrescription('w-upper', 'e2', sets: 5, repsMin: 5, repsMax: 5, restSeconds: 180); // a later edit elsewhere
    await _tap(tester, _prefixed('ask-undo-'));
    expect(_prefixed('ask-undone-'), findsOneWidget);
    expect(jsonEncode(_upper(install.draft)[0]), jsonEncode(was[0]), reason: 'the replaced exercise is back as it was, weight target included');
    expect(_upper(install.draft)[1]['targetSets'], 5, reason: 'the later edit is kept');
  });

  testWidgets('Undo is refused after the same exercise was edited', (tester) async {
    install.coach.replies.add((r) => _answer(r, 'Swap it.', proposal: _swap()));
    await _launch(tester, install);
    await _ask(tester, 'Swap?');
    await _tap(tester, _prefixed('ask-preview-'));
    await _key(tester, 'ask-apply');
    final key = _upper(install.draft)[0]['occurrenceKey'] as String;
    install.draft.setPrescription('w-upper', key, sets: 2, repsMin: 6, repsMax: 10, restSeconds: 120);
    final edited = jsonEncode(install.draft.j);
    await _tap(tester, _prefixed('ask-undo-'));
    expect(find.textContaining('Undo is no longer safe: Dumbbell bench press was changed'), findsOneWidget);
    expect((jsonEncode(install.draft.j), install.applies), (edited, 1));
  });

  testWidgets('a suggestion made for an earlier draft is flagged; rebuilding lists what no longer applies and newer edits survive Apply', (tester) async {
    install.coach.replies.add((r) => _answer(r, 'More rows, fewer presses.', proposal: {
          'summary': 'Swap the press and add a set of rows', 'scope': 'draft',
          'operations': [
            {'op': 'replaceExercise', 'workoutId': 'w-upper', 'occurrenceKey': 'e1', 'catalogKey': 'push-up'},
            {'op': 'setPrescription', 'workoutId': 'w-upper', 'occurrenceKey': 'e2', 'targetSets': 4},
          ],
        }));
    await _launch(tester, install);
    await _ask(tester, 'More back work?');
    await _key(tester, 'ask-close');

    install.draft
      ..removeExercise('w-upper', 'e1')
      ..setPrescription('w-upper', 'e2', sets: 3, repsMin: 10, repsMax: 15, restSeconds: 45);
    final edited = _upper(install.draft);
    await _open(tester);
    expect(_prefixed('ask-stale-'), findsOneWidget);
    expect(find.text('Based on an earlier version of your draft'), findsOneWidget);

    await _tap(tester, _prefixed('ask-preview-'));
    expect(find.byKey(const Key('ask-draft-changed')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('ask-apply')), matching: find.byType(FilledButton))).onPressed, isNull);
    await _key(tester, 'ask-rebuild');
    expect(find.byKey(const Key('ask-not-applicable-0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('ask-change-0'))).data, contains('3 × 10–15 · 45 s rest → 4 × 10–15 · 45 s rest'));

    install.draft.setPrescription('w-upper', 'e3', sets: 2, repsMin: 10, repsMax: 15, restSeconds: 60); // changed while the preview is open
    await _key(tester, 'ask-apply');
    expect((install.applies, find.byKey(const Key('ask-draft-changed')).evaluate().length), (0, 1), reason: 'never applied over a newer edit');
    await _key(tester, 'ask-rebuild');
    await _key(tester, 'ask-apply');
    final upper = _upper(install.draft);
    expect(install.applies, 1);
    expect(upper.map((e) => e['catalogKey']), ['barbell-row', 'triceps-pushdown'], reason: 'the removed press stays removed');
    expect((upper[0]['targetSets'], upper[0]['targetRepsMin'], upper[0]['restSeconds'], upper[1]['targetSets']), (4, 10, 45, 2));
    expect(edited, hasLength(2));
  });

  testWidgets('large text at 320 px with the keyboard open keeps the composer, Send and Close on screen', (tester) async {
    await _launch(tester, install, size: const Size(320, 568), textScale: 2);
    await tester.tap(find.byKey(const Key('ask-input')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byKey(const Key('ask-input')), 'A long question that wraps over more than one line on a narrow phone');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final visible = const Rect.fromLTWH(0, 0, 320, 568 - 260);
    for (final key in ['ask-close', 'ask-input', 'ask-send']) {
      final r = tester.getRect(find.byKey(Key(key)));
      expect(visible.contains(r.topLeft) && visible.contains(r.bottomRight - const Offset(0.1, 0.1)), isTrue, reason: '$key at $r');
    }
    expect(find.byType(CoachFigure), findsNothing, reason: 'no full figure with large text');
  });

  for (final accent in Accent.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${accent.name} ${mode.name}: an answer with a suggestion meets contrast, target and label guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        install.appearance
          ..accent = accent
          ..mode = mode;
        install.coach.replies.add((r) => _answer(r, 'Dumbbells work too.', proposal: _swap(), sources: ['acsm-2009']));
        await _launch(tester, install, size: const Size(390, 1400));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await _ask(tester, 'Dumbbells?');
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await _tap(tester, _prefixed('ask-preview-'));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }
  }
}
