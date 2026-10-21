import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/catalog_names.dart';
import '../../core/language.dart';
import '../../core/search_fold.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../plans/builder/workout_editor.dart' show rxText;
import '../plans/plan_draft.dart';
import 'coach_avatar.dart';
import 'coach_companion.dart';
import 'coach_client.dart';
import 'coach_contract.dart';
import 'coach_prefs.dart';
import 'coach_rig.dart' show RigFrame;
import 'coach_proposal.dart';
import 'guide.dart' show loadCoachGuide;

// ------------------------------------------------------------------ reviewed content (Quick guide, sources)

/// The bundled reviewed content (`assets/data/coach-guide.json`, or its French or Arabic translation, docs/COACH.md),
/// read defensively: a missing or unreadable file is no guide, so no Quick guide and no sources. Needs no account, no
/// AI and no connection.
final askGuideProvider = FutureProvider<AskGuide?>((ref) async {
  try {
    return await loadCoachGuide(ref.watch(appLocaleProvider), (t) => AskGuide(jsonDecode(t) as Json));
  } on Object {
    return null;
  }
});

List<Json> _maps(Object? v) => [for (final x in v is List ? v : const []) if (x is Map) Map<String, dynamic>.from(x)];
List<String> _strings(Object? v) => [for (final x in v is List ? v : const []) if (x is String && x.trim().isNotEmpty) x];
String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
String _norm(String s) => foldForSearch(s).replaceAll('×', 'x').replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

class AskGuide {
  AskGuide(Json j)
      : sources = {for (final s in _maps(j['sources'])) ?_str(s['id']): s},
        splits = {for (final s in _maps(j['splits'])) ?_str(s['templateId']): s},
        exercises = {for (final e in _maps(j['exercises'])) ?_str(e['catalogKey']): e},
        terms = [for (final t in _maps(j['terms'])) if (_str(t['term']) != null && _str(t['text']) != null) t];
  final Map<String, Json> sources, splits, exercises;
  final List<Json> terms;

  /// "Title · Publisher" for each listed source ID. An ID the file does not list is never shown.
  List<String> cite(Iterable<String> ids) => [
        for (final id in ids)
          if (sources[id] case final s?) [_str(s['title']), _str(s['publisher'])].nonNulls.join(' · '),
      ];
}

typedef GuideEntry = ({String title, String? summary, List<(String, List<String>)> lists, List<String> sources});

/// Reviewed entries for what is being asked about: the focused split or exercise, and any split or term named in
/// [text] ("3 × 8–12", "Upper / Lower"). A custom exercise has no entry: it says "Added by you" and claims nothing.
List<GuideEntry> quickGuide(AskGuide g, CoachContext c, String text, Map<String, String> names, AppLocalizations l) {
  final t = _norm(text);
  final out = <GuideEntry>[];
  void split(Json s) {
    final title = _str(s['name']) ?? l.coachGuideThisSplit;
    if (out.any((e) => e.title == title)) return;
    out.add((
      title: title, summary: [_str(s['summary']), _str(s['organisation']), _str(s['days'])].nonNulls.join('\n\n'),
      lists: [(l.coachGuideBenefits, _strings(s['benefits'])), (l.coachGuideLimitations, _strings(s['limitations']))], sources: g.cite(_strings(s['sources'])),
    ));
  }

  if (g.splits[c.templateId] case final s?) split(s);
  for (final s in g.splits.values) {
    final n = _norm(_str(s['name']) ?? '');
    if (n.length > 3 && t.contains(n)) split(s);
  }
  final key = c.catalogKey;
  if (key != null && key.startsWith('custom:')) {
    out.add((title: names[key] ?? c.label, summary: l.coachGuideCustomNoInfo, lists: const [], sources: const []));
  } else if (g.exercises[key] case final e?) {
    out.add((
      title: names[key] ?? c.label,
      summary: [
        if (_strings(e['muscles']).isNotEmpty) l.coachGuideMusclesLine(_strings(e['muscles']).join(l.coachListSeparator)),
        if (_str(e['equipment']) case final q?) l.coachGuideEquipmentLine(q),
        if (e['role'] == 'main') l.coachGuideRoleMain else if (e['role'] == 'accessory') l.coachGuideRoleAccessory,
      ].join('\n'),
      lists: [
        (l.coachGuideTechniqueCues, _strings(e['cues'])), (l.coachGuideBenefits, _strings(e['benefits'])), (l.coachGuideLimitations, _strings(e['limitations'])),
        (l.coachGuideAlternatives, [for (final a in _strings(e['alternatives'])) names[a] ?? a]),
      ],
      sources: g.cite(_strings(e['sources'])),
    ));
  }
  for (final term in g.terms) {
    final n = _norm(term['term'] as String);
    if (n.isNotEmpty && t.contains(n)) out.add((title: term['term'] as String, summary: term['text'] as String, lists: const [], sources: g.cite(_strings(term['sources']))));
  }
  return out;
}

// ------------------------------------------------------------------ the screen

/// Ask GoHard: questions about the plan answered by the server's model, grounded in the draft and the reviewed
/// guide. A pushed page over the builder, so closing it returns to the same step, draft and scroll position.
/// Nothing is sent until Send or a suggested question; every answer is marked as AI-generated; nothing here is
/// simulated. A suggested change is previewed and applied only through [CoachContext.applyToDraft].
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, required this.coach});
  final CoachContext coach;
  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _arrivedKey = GlobalKey();
  final _expanded = <String>{};

  /// The answer that arrived while this screen was open: announced once and scrolled to once, never followed.
  String? _arrived;

  CoachContext get coach => widget.coach;
  AskConversation get _convo => ref.read(askConversationProvider.notifier);

  @override
  void initState() {
    super.initState();
    ref.listenManual<AskState>(askConversationProvider, (prev, next) {
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

  List<String> _suggestions(AppLocalizations l) => switch (coach.focus) {
        CoachFocus.exercise => [l.coachAskSuggestWhyIncluded, l.coachAskSuggestDumbbell, l.coachAskSuggestAlternatives, l.coachAskSuggestSetsReps],
        CoachFocus.workout => [l.coachAskSuggestShorten, l.coachAskSuggestSetsReps],
        _ => [l.coachAskSuggestWhySplit, l.coachAskSuggestCompareSplits, l.coachAskSuggestSetsReps],
      };

  void _send(String question, {bool retry = false}) {
    _convo.send(question, coach, retry: retry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _clear() async {
    final l = context.l10n;
    if (await confirm(context, title: l.coachAskClearTitle, body: l.coachAskClearBody, action: l.coachAskClearAction)) {
      _convo.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(askConversationProvider);
    final guide = ref.watch(askGuideProvider).value;
    final l = context.l10n;
    final locale = Localizations.localeOf(context);
    final catalogNames = ref.watch(exerciseNamesProvider);
    final guideName = ref.watch(coachPrefsProvider.select((p) => p.guide)).displayName(l);
    final choices = ref.watch(exerciseChoicesProvider);
    final names = {for (final c in choices) if (c.key != null) c.key!: catalogNames.nameOf(c.key!, c.name, locale)};
    final draft = coach.draft?.call();
    final revision = draft == null ? null : draftRevision(draft);
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final roomy = !large && MediaQuery.sizeOf(context).height >= 640;
    final asked = [for (final m in s.messages) if (m['role'] == 'user') m['text'] as String].lastOrNull ?? '';

    List<GuideEntry> entries() => guide == null ? const [] : quickGuide(guide, coach, '${_text.text} ${s.pending?['question'] ?? ''} $asked', names, l);
    Widget guideButton({Key key = const Key('ask-quick-guide'), String? label}) => ValueListenableBuilder(
          valueListenable: _text,
          builder: (context, _, _) {
            final found = entries();
            return found.isEmpty
                ? const SizedBox.shrink()
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(key: key, icon: const Icon(Icons.menu_book_outlined), label: Text(label ?? l.coachQuickGuideBuiltIn), onPressed: () => _showGuide(found)));
          },
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(key: const Key('ask-close'), tooltip: l.actionClose, icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context)),
        actions: [
          if (!s.isEmpty)
            IconButton(key: const Key('ask-clear'), tooltip: l.coachAskClearTooltip, icon: const Icon(Icons.delete_sweep_outlined), onPressed: s.sending ? null : _clear),
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
                  // Attentive only while a question is really waiting; an answer, an error, Cancel or a timeout ends it.
                  ClipOval(
                    child: ColoredBox(
                      color: context.c.sunken,
                      child: CoachCompanion(key: const Key('ask-companion'), guide: ref.watch(coachPrefsProvider.select((p) => p.guide)), size: const Size.square(48), frame: RigFrame.inline, attentive: s.sending),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Heading(l.coachAskTitle, size: 30, serif: true),
                      Wrap(children: [
                        Text(guideName, style: context.sansStyle(14, weight: FontWeight.w600)),
                        Text(' · ', style: context.caption),
                        Text(l.coachAskAiAssistant, key: const Key('ask-ai-assistant'), style: context.caption),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(l.coachAskAbout(coach.label), key: const Key('ask-context'), style: context.sansStyle(15, weight: FontWeight.w600)),
                if (s.isEmpty) ...[
                  if (roomy) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CoachFigure(height: 120))),
                  const SizedBox(height: 12),
                  Text(l.coachAskIntro,
                      style: context.sansStyle(15, color: context.c.secondary)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final (i, q) in _suggestions(l).indexed)
                      ActionChip(
                          key: Key('ask-suggest-$i'), label: Text(q), materialTapTargetSize: MaterialTapTargetSize.padded,
                          shape: StadiumBorder(side: BorderSide(color: context.c.outline)),
                          onPressed: s.sending || !s.loaded ? null : () => _send(q)),
                  ]),
                ],
                const SizedBox(height: 4),
                guideButton(),
                for (final m in s.messages)
                  if (m['role'] == 'user') _question(m['text'] as String) else _answer(m, revision, guide, draft, choices, guideName),
                if (s.pending != null) ..._pending(s, guideButton(key: const Key('ask-guide-link'), label: l.coachAskOpenQuickGuide)),
              ],
            ),
          ),
          _composer(s, large),
        ]),
      ),
    );
  }

  Widget _composer(AskState s, bool large) => Container(
        decoration: BoxDecoration(color: context.c.page, border: Border(top: BorderSide(color: context.c.divider))),
        padding: EdgeInsets.fromLTRB(context.inset, 8, context.inset, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              key: const Key('ask-input'), controller: _text, minLines: 1, maxLines: large ? 2 : 4, maxLength: 600,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => currentLength < 500 ? null : Text('$currentLength / $maxLength'),
              textInputAction: TextInputAction.send, textCapitalization: TextCapitalization.sentences,
              onSubmitted: (v) => _send(v),
              decoration: InputDecoration(hintText: context.l10n.coachAskInputHint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(26))),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: _text,
            builder: (context, v, _) => IconButton.filled(
                key: const Key('ask-send'), tooltip: context.l10n.coachAskSend, iconSize: 24, constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
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
          // The person's own words: a quiet bubble, so the answers in the pale tint stand out.
          decoration: BoxDecoration(color: context.c.surface, border: Border.all(color: context.c.outline), borderRadius: BorderRadius.circular(Radii.panel)),
          child: Semantics(label: context.l10n.coachAskYouAsked(text), excludeSemantics: true, child: Text(text, style: context.body)),
        ),
      );

  List<Widget> _pending(AskState s, Widget guideLink) {
    final p = s.pending!;
    final problem = s.problem;
    final l = context.l10n;
    return [
      _question(p['question'] as String),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: s.sending
            ? Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                Text(l.coachAskWaiting, key: const Key('ask-sending'), style: context.sansStyle(15, color: context.c.secondary)),
                TextButton(key: const Key('ask-cancel'), onPressed: _convo.cancel, child: Text(l.actionCancel)),
              ])
            : Semantics(
                liveRegion: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StatusLine(Icons.info_outline, _problemText(l, problem ?? AskProblem.unavailable), key: const Key('ask-problem'), tone: Tone.warning),
                  Wrap(spacing: 8, children: [
                    if (problem != AskProblem.invalid)
                      TextButton(key: const Key('ask-retry'), onPressed: () => _send(p['question'] as String, retry: true), child: Text(l.coachAskRetry)),
                    TextButton(key: const Key('ask-edit'), onPressed: _convo.edit, child: Text(l.coachAskEditQuestion)),
                  ]),
                  guideLink,
                ]),
              ),
      ),
    ];
  }

  static String _problemText(AppLocalizations l, AskProblem p) => switch (p) {
        AskProblem.limit => l.coachAskProblemLimit,
        AskProblem.busy => l.coachAskProblemBusy,
        AskProblem.unreached => l.coachAskProblemUnreached,
        AskProblem.invalid => l.coachAskProblemInvalid,
        AskProblem.interrupted => l.coachAskProblemInterrupted,
        AskProblem.unavailable => l.coachAskProblemUnavailable,
      };

  Widget _answer(Json m, String? revision, AskGuide? guide, PlanDraft? draft, List<CatalogExercise> choices, String guideName) {
    final l = context.l10n;
    final id = m['id'] as String;
    final stale = revision != null && m['draftRevision'] != null && m['draftRevision'] != revision;
    final cites = guide?.cite(_strings(m['sources'])) ?? const <String>[];
    final open = _expanded.contains(id);
    final arrived = id == _arrived;
    return Padding(
      key: arrived ? _arrivedKey : null,
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        container: true, liveRegion: arrived,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Who answers: the selected guide, the same face as the header and every way into this conversation.
          Row(children: [
            const CoachAvatar(size: 26),
            const SizedBox(width: 8),
            Text(guideName, style: context.sansStyle(14, weight: FontWeight.w600)),
            Text(' · ', style: context.caption),
            Text(l.coachAskAiGenerated, key: Key('ask-ai-$id'), style: context.caption),
          ]),
          if (stale)
            Padding(padding: const EdgeInsets.only(top: 4), child: StatusLine(Icons.history, l.coachAskStale, key: Key('ask-stale-$id'), tone: Tone.warning)),
          const SizedBox(height: 6),
          // The answer in the pale panel tint with its dark ink, the same in Light and Dark.
          Container(
            margin: const EdgeInsetsDirectional.only(end: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: context.c.tint, borderRadius: BorderRadius.circular(Radii.panel)),
            child: Text(m['text'] as String, key: Key('ask-answer-$id'), style: context.body.copyWith(color: GoColors.panelOf(context.c).text)),
          ),
          if (cites.isNotEmpty)
            TextButton(
                key: Key('ask-more-$id'),
                onPressed: () => setState(() => open ? _expanded.remove(id) : _expanded.add(id)),
                child: Text(open ? l.coachAskLess : l.coachAskMore)),
          if (open) ...[
            SectionLabel(l.coachAskSourcesHeading),
            for (final c in cites) Padding(padding: const EdgeInsets.only(top: 4), child: Text(c, style: context.caption)),
          ],
          if (m['proposal'] is Map) _proposal(m, stale, draft, choices),
        ]),
      ),
    );
  }

  Widget _proposal(Json m, bool stale, PlanDraft? draft, List<CatalogExercise> choices) {
    final id = m['id'] as String;
    final p = m['proposal'] as Map;
    final applied = m['applied'] as Map?;
    final l = context.l10n;
    final Widget content;
    if (applied != null && applied['undone'] != true) {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StatusLine(Icons.check_circle_outline, l.coachAskApplied, key: Key('ask-applied-$id'), tone: Tone.success),
        if (_str(applied['undoRefused']) case final why?) Padding(padding: const EdgeInsets.only(top: 6), child: Text(why, key: Key('ask-undo-refused-$id'), style: context.caption)),
        const SizedBox(height: 10),
        SecondaryButton(l.coachAskUndo, key: Key('ask-undo-$id'), onPressed: coach.applyToDraft == null || draft == null ? null : () => _undo(m)),
      ]);
    } else if (applied != null) {
      content = StatusLine(Icons.undo, l.coachAskUndone, key: Key('ask-undone-$id'));
    } else if (coach.applyToDraft == null || draft == null) {
      content = Text(l.coachAskTextOnly, key: Key('ask-text-only-$id'), style: context.caption);
    } else {
      final check = checkProposal(p, draft, choices);
      final usable = check != null && (stale || (check.canApply && check.notApplicable.isEmpty));
      content = usable
          ? SecondaryButton(l.coachAskPreview, key: Key('ask-preview-$id'), onPressed: () => _preview(m, choices))
          : StatusLine(Icons.block, l.coachAskCantApply, key: Key('ask-invalid-$id'));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Overline(l.coachAskSuggestedChange),
          const SizedBox(height: 4),
          Text(_str(p['summary']) ?? l.coachAskChangeFallback, style: context.sansStyle(16, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          content,
        ]),
      ),
    );
  }

  /// Preview against the current draft. Opening or dismissing it changes nothing. Apply checks again that the draft
  /// has not moved on since this preview, so a newer edit is never overwritten.
  Future<void> _preview(Json m, List<CatalogExercise> choices) async {
    final unit = ref.read(loadUnitProvider);
    final answeredOn = m['draftRevision'];
    ProposalCheck? check = checkProposal(m['proposal'], coach.draft!(), choices);
    var changed = answeredOn != null && answeredOn != check?.builtOn;
    var busy = false;
    final l = context.l10n;
    await showGoSheet<void>(context, title: l.coachAskSuggestedChange, builder: (context) => StatefulBuilder(builder: (context, setSheet) {
      void rebuild() => setSheet(() {
            check = checkProposal(m['proposal'], coach.draft!(), choices);
            changed = false;
          });
      Future<void> apply() async {
        if (draftRevision(coach.draft!()) != check!.builtOn) return setSheet(() => changed = true);
        setSheet(() => busy = true);
        await coach.applyToDraft!(check!.next);
        _convo.markApplied(m['id'] as String, changes: check!.changes);
        if (context.mounted) Navigator.pop(context);
      }

      final c = check;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_str((m['proposal'] as Map)['summary']) ?? l.coachAskChangeFallback, style: context.sansStyle(16, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        StatusPill(l.coachAskDraftOnly, key: Key('ask-scope'), icon: Icons.edit_note, tone: Tone.accent),
        const SizedBox(height: 6),
        Text(l.coachAskDraftOnlyBody, style: context.caption),
        if (changed || c == null) ...[
          const SizedBox(height: 14),
          StatusLine(Icons.update, l.coachAskDraftChanged, key: const Key('ask-draft-changed'), tone: Tone.warning),
          const SizedBox(height: 10),
          SecondaryButton(l.coachAskRecheck, key: const Key('ask-rebuild'), onPressed: rebuild),
        ] else ...[
          ..._changeRows(l, c, unit),
          if (c.notApplicable.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionLabel(l.coachAskNotApplicableHeading),
            for (final (i, why) in c.notApplicable.indexed) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_skipText(l, why), key: Key('ask-not-applicable-$i'))),
          ],
          if (!c.canApply) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l.coachAskNothingApplies, style: context.caption)),
        ],
        const SizedBox(height: 18),
        PrimaryButton(l.coachAskApply, key: const Key('ask-apply'), busy: busy, onPressed: changed || c == null || !c.canApply ? null : apply),
        const SizedBox(height: 8),
        SecondaryButton(l.coachAskKeep, key: const Key('ask-keep'), onPressed: () => Navigator.pop(context)),
      ]);
    }));
  }

  /// Before → after per exercise, grouped by workout: names, sets, reps, time, rest and any weight target.
  /// A left-out operation in words; an exercise named by an unchanged catalog name is shown in this language.
  String _skipText(AppLocalizations l, ProposalSkip k) {
    final x = _exerciseName(k.catalogKey, k.exercise ?? ''), w = k.workout ?? '';
    return switch (k.reason) {
      SkipReason.workoutGone => l.coachSkipWorkoutGone(k.op),
      SkipReason.exerciseGone => l.coachSkipExerciseGone(k.op, w),
      SkipReason.replaceUnavailable => l.coachSkipReplaceUnavailable(x),
      SkipReason.replaceSame => l.coachSkipReplaceSame(x),
      SkipReason.valuesOutside => l.coachSkipValuesOutside(x),
      SkipReason.addUnavailable => l.coachSkipAddUnavailable(w),
      SkipReason.addOutside => l.coachSkipAddOutside(x, w),
      SkipReason.addFull => l.coachSkipAddFull(x, w),
    };
  }

  String _exerciseName(Object? catalogKey, String stored) =>
      ref.read(exerciseNamesProvider).name(catalogKey as String?, stored, Localizations.localeOf(context));

  List<Widget> _changeRows(AppLocalizations l, ProposalCheck check, LoadUnit unit) {
    final out = <Widget>[];
    String? workout;
    for (final (i, c) in check.changes.indexed) {
      if (c['workoutName'] != workout) {
        workout = c['workoutName'] as String;
        out.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 2), child: Overline(workout)));
      }
      final b = c['before'] as Json?, a = c['after'] as Json?;
      final lines = <String>[];
      String name(Json e) => _exerciseName(e['catalogKey'], e['name'] as String);
      if (b == null) {
        lines.add(l.coachAskChangeAdded(name(a!), rxText(Prescription(a))));
      } else if (a == null) {
        lines.add(l.coachAskChangeRemoved(name(b), rxText(Prescription(b))));
      } else {
        lines.add(b['catalogKey'] == a['catalogKey'] ? name(a) : l.coachAskChangeArrow(name(b), name(a)));
        final rb = rxText(Prescription(b)), ra = rxText(Prescription(a));
        lines.add(rb == ra ? ra : l.coachAskChangeArrow(rb, ra));
        final wb = Prescription(b).targetLoadKg, wa = Prescription(a).targetLoadKg;
        if (wb != null && wa == null) {
          lines.add(l.coachAskWeightCleared(formatLoad(wb, unit), name(b)));
        } else if (wa != null) {
          lines.add(l.coachAskWeightKept(formatLoad(wa, unit)));
        }
      }
      out.add(Padding(padding: const EdgeInsets.only(top: 6), child: Text(lines.join('\n'), key: Key('ask-change-$i'), style: context.body)));
    }
    return out;
  }

  Future<void> _undo(Json m) async {
    final changes = [for (final c in (m['applied'] as Map)['changes'] as List) Map<String, dynamic>.from(c as Map)];
    final r = undoProposal(coach.draft!(), changes);
    // Stored as said, in the language of the moment, like the conversation's other words.
    if (r.next == null) return _convo.markApplied(m['id'] as String, undoRefused: context.l10n.coachUndoRefused(_exerciseName(r.refused!['catalogKey'], r.refused!['name'] as String)));
    await coach.applyToDraft!(r.next!);
    _convo.markApplied(m['id'] as String, undone: true);
  }

  void _showGuide(List<GuideEntry> entries) => showGoSheet<void>(context, title: context.l10n.coachQuickGuide, builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.coachQuickGuideReviewed, key: const Key('ask-guide-label'), style: context.label),
        for (final e in entries) ...[
          const SizedBox(height: 18),
          Heading(e.title, size: 20),
          if (e.summary case final s? when s.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s, style: context.body)),
          for (final (label, items) in e.lists)
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              SectionLabel(label),
              for (final item in items) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $item', style: context.body)),
            ],
          if (e.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            SectionLabel(context.l10n.coachGuideSources),
            for (final src in e.sources) Text(src, style: context.caption),
          ],
        ],
      ]));
}
