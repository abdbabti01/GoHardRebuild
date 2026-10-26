import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/session.dart' show SessionManager;
import '../../data/sync.dart';
import '../coach/coach_avatar.dart';
import '../coach/coach_bubble.dart';
import '../coach/coach_client.dart' show AskFailure, AskProblem;
import '../coach/coach_prefs.dart';
import 'eating_out.dart';
import 'food_form.dart';
import 'food_repository.dart';
import 'food_search.dart' show normalizeSearch;
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'restaurants.dart';
import 'saved_meals.dart';
import 'saved_meals_screens.dart';

/// Eating out (docs/EATING_OUT.md), opened for [dayKey] and [meal] from Eat or Add food. Pops `true` when an order was
/// logged. Nothing here records food: Review and log opens the saved-meal review, whose Log is the only action that
/// writes the journal, and Save as meal opens the ordinary saved-meal editor.
Future<bool?> openEatingOut(BuildContext context, {required String dayKey, required String meal}) => push<bool>(context, EatingOutScreen(dayKey: dayKey, meal: meal));

class EatingOutScreen extends ConsumerStatefulWidget {
  const EatingOutScreen({super.key, required this.dayKey, required this.meal});
  final String dayKey, meal;
  @override
  ConsumerState<EatingOutScreen> createState() => _EatingOutScreenState();
}

enum _Tab { choose, order }

class _EatingOutScreenState extends ConsumerState<EatingOutScreen> {
  late final EatOutStore _store = ref.read(eatOutStoreProvider);
  late final SessionManager _sessions = ref.read(sessionsProvider);
  final _question = TextEditingController();
  final _askFocus = FocusNode();
  EatOutDraft _d = const EatOutDraft();
  bool _loaded = false;

  /// Every change to the chain, the order or the preferences raises it; an answer made for an earlier one is not applied.
  int _rev = 0;
  _Tab _tab = _Tab.choose;

  // The conversation's state on screen. The question stays in the field until an answer is applied.
  bool _sending = false;
  AskProblem? _problem;
  bool _stale = false, _mismatch = false;
  String? _pendingId;
  Interpretation? _last;

  /// What an applied answer or a chosen suggestion replaced: Undo restores exactly this.
  EatOutDraft? _undo;

  @override
  void initState() {
    super.initState();
    _store.load().then((d) {
      if (!mounted) return;
      setState(() {
        _d = d;
        _loaded = true;
      });
    });
    // Once per visit, where the server keeps a catalog: a newer menu is taken; the order on screen is not touched.
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshRestaurantCatalog(ref).ignore());
  }

  @override
  void dispose() {
    _question.dispose();
    _askFocus.dispose();
    super.dispose();
  }

  String get _revision => '$_rev|${Localizations.localeOf(context).languageCode}';

  void _change(EatOutDraft d, {bool undoable = false}) => setState(() {
        if (undoable) _undo = _d;
        _d = d;
        _rev++;
        _store.keep(d);
      });

  void _restore() {
    final u = _undo;
    if (u == null) return;
    _change(u);
    setState(() => _undo = null);
  }

  // ---------------------------------------------------------------- asking

  Future<void> _send(RestaurantCatalog catalog, RestaurantChain chain, {bool retry = false}) async {
    final q = _question.text.trim();
    final session = _sessions.current;
    if (_sending || q.isEmpty || session == null) return;
    final requestId = retry && _pendingId != null ? _pendingId! : SyncEngine.newId();
    final sentRev = _revision;
    final request = interpretRequest(requestId: requestId, catalog: catalog, chainId: chain.id, question: q, draft: _d, revision: sentRev,
        languageCode: Localizations.localeOf(context).languageCode);
    setState(() {
      _sending = true;
      _problem = null;
      _stale = false;
      _mismatch = false;
      _pendingId = requestId;
    });
    Json? body;
    AskProblem? problem;
    var mismatch = false;
    try {
      body = await ref.read(eatingOutClientProvider).interpret(request);
    } on AskFailure catch (e) {
      problem = e.problem;
    } on CatalogMismatch {
      mismatch = true;
    }
    // Dropped when the screen closed, another account signed in, or another question was sent since.
    if (!mounted || _pendingId != requestId || _sessions.current?.ownerId != session.ownerId) return;
    // A failure keeps the question and its request ID, so Retry asks the same question once more.
    final read = body == null ? null : Interpretation.read(body, request, chain);
    if (read == null) {
      setState(() {
        _sending = false;
        _problem = mismatch ? null : problem ?? AskProblem.unavailable;
        _mismatch = mismatch;
      });
      return;
    }
    // The order, preferences, chain or language changed while it was read: newer edits are never replaced, and the
    // next Send is a new request about what is on screen then.
    if (sentRev != _revision || body!['orderRevision'] != sentRev) {
      setState(() {
        _sending = false;
        _stale = true;
        _pendingId = null;
      });
      return;
    }
    setState(() {
      _sending = false;
      _last = read;
      _pendingId = null;
    });
    if (read.kind != 'constraints') return; // a question back, or another restaurant: said, nothing changed
    final history = [..._d.history, {'role': 'user', 'text': q}, {'role': 'assistant', 'text': _summaryForHistory(read.preferences)}];
    _change(_d.copyWith(preferences: read.preferences, history: history.skip(history.length > 6 ? history.length - 6 : 0).toList()), undoable: true);
    _question.clear();
    setState(() => _tab = _Tab.choose);
  }

  /// What the next request is told was understood: IDs and numbers only, the same words in every language.
  static String _summaryForHistory(OrderPreferences p) => [
        if (p.maxCalories != null) 'max ${p.maxCalories} kcal',
        if (p.minCalories != null) 'min ${p.minCalories} kcal',
        if (p.minProtein != null) 'min ${p.minProtein} g protein',
        if (p.keep.isNotEmpty) 'keep ${p.keep.entries.map((e) => '${e.value} x ${e.key}').join(', ')}',
        if (p.exclude.isNotEmpty) 'exclude ${p.exclude.join(', ')}',
        if (p.prefer.isNotEmpty) 'prefer ${p.prefer.join(', ')}',
        if (p.priority != null) 'priority ${p.priority!.name}',
      ].join('; ');

  Future<void> _updateMenu() async {
    final took = await refreshRestaurantCatalog(ref);
    if (mounted) setState(() => _mismatch = !took);
  }

  // ---------------------------------------------------------------- order → the app's ordinary foods

  MealBody _body(RestaurantCatalog catalog, RestaurantChain chain) => MealBody({
        'kind': MealBody.meal, 'name': context.l10n.eatOutOrderName(chain.name),
        'components': [for (final c in orderComponents(catalog, chain, _d.order)) c.j],
      });

  Future<void> _review(RestaurantCatalog catalog, RestaurantChain chain) async {
    final logged = await push<bool>(context, MealReviewScreen(body: _body(catalog, chain), dayKey: widget.dayKey, meal: widget.meal));
    if (logged != true || !mounted) return;
    _change(_d.copyWith(order: const RestaurantOrder([])));
    Navigator.pop(context, true);
  }

  void _saveAsMeal(RestaurantCatalog catalog, RestaurantChain chain) => push(context, MealEditorScreen(dayKey: widget.dayKey, start: _body(catalog, chain)));

  void _ownEstimate(RestaurantChain chain) =>
      push(context, FoodFormScreen(draft: FoodDraft(dayKey: widget.dayKey, meal: meals.contains(widget.meal) ? widget.meal : meals.first, name: '${chain.name} ')));

  Future<void> _menu(RestaurantChain chain) => showGoSheet<void>(context, title: context.l10n.eatOutMenuTitle(chain.name), builder: (_) => _MenuSheet(
        chain: chain, order: () => _d.order, onAdd: (id) => _change(_d.copyWith(order: _d.order.withQuantity(id, _d.order.quantityOf(id) + 1)))));

  Future<void> _targets() async {
    final p = await showGoSheet<OrderPreferences>(context, title: context.l10n.eatOutTargetsTitle, builder: (_) => _TargetsSheet(_d.preferences));
    if (p != null && mounted) _change(_d.copyWith(preferences: p));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = ref.watch(restaurantCatalogProvider).value;
    if (catalog == null || !_loaded) return AppPage(title: l.eatOutTitle, children: const [SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))]);
    final chain = _d.chainId == null ? null : catalog.chain(_d.chainId!);
    if (chain == null || !chain.available) {
      return AppPage(
        title: l.eatOutTitle, subtitle: l.eatOutForContext(mealLabel(l, widget.meal), longDate(widget.dayKey)),
        children: [
          _CoachLine(say: CoachSay(l.eatOutCoachIntro), onAvatar: () {}),
          const SizedBox(height: 14),
          Heading(l.eatOutChooseChain, size: 20),
          const SizedBox(height: 10),
          GroupCard(children: [for (final c in catalog.chains) _ChainRow(c, catalog, onTap: () => _choose(c))]),
          const SizedBox(height: 14),
          Text(l.eatOutCoverageNote, style: context.caption),
        ],
      );
    }

    final aiDeclared = ref.watch(compatibilityProvider).supports(RestaurantCatalog.interpretCapability);
    final split = _d.order.against(chain);
    final order = split.kept;
    final orderTotals = order.totals(chain);
    final source = chain.sources.first;
    return AppPage(
      title: l.eatOutTitle,
      subtitle: l.eatOutChainContext(chain.name, mealLabel(l, widget.meal), longDate(widget.dayKey)),
      actions: [IconButton(key: const Key('eatout-change-chain'), tooltip: l.eatOutChangeChain, icon: const Icon(Icons.storefront_outlined), onPressed: () => _change(_d.copyWith(chainId: () => null)))],
      bottom: _tab == _Tab.order && !order.isEmpty
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              PrimaryButton(l.eatOutReview, key: const Key('eatout-review'), icon: Icons.fact_check_outlined, onPressed: split.missing.isEmpty ? () => _review(catalog, chain) : null),
              TextButton(key: const Key('eatout-save-meal'), onPressed: split.missing.isEmpty ? () => _saveAsMeal(catalog, chain) : null, child: Text(l.mealsSaveAsMeal)),
            ])
          : null,
      children: [
        _CoachLine(say: CoachSay(_coachWords(l, chain)), attentive: _sending, onAvatar: () => _askFocus.requestFocus()),
        const SizedBox(height: 12),
        _AskBox(
          controller: _question, focus: _askFocus, sending: _sending, enabled: aiDeclared,
          onSend: () => _send(catalog, chain),
        ),
        if (!aiDeclared) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.info_outline, l.eatOutAskUnavailable, key: const Key('eatout-ask-off'))),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusLine(Icons.error_outline, _problemText(l, _problem!), key: const Key('eatout-problem'), tone: Tone.warning),
              if (_problem != AskProblem.limit && _problem != AskProblem.invalid)
                TextButton(key: const Key('eatout-retry'), onPressed: () => _send(catalog, chain, retry: true), child: Text(l.coachAskRetry)),
            ]),
          ),
        if (_stale) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.update, l.eatOutStale, key: const Key('eatout-stale'), tone: Tone.warning)),
        if (_mismatch)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusLine(Icons.menu_book_outlined, l.eatOutMenuChanged, key: const Key('eatout-mismatch'), tone: Tone.warning),
              TextButton(key: const Key('eatout-update-menu'), onPressed: _updateMenu, child: Text(l.eatOutUpdateMenu)),
            ]),
          ),
        if (_last?.chainId case final id? when catalog.chain(id) != null)
          if (catalog.chain(id)! case final other)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: other.available
                ? Align(alignment: AlignmentDirectional.centerStart, child: TextButton(key: const Key('eatout-switch-chain'), onPressed: () => _choose(other), child: Text(l.eatOutSwitchTo(other.name))))
                : StatusLine(Icons.info_outline, l.eatOutChainNotYet(other.name)),
          ),
        const SizedBox(height: 18),
        _Targets(
          chain: chain, preferences: _d.preferences, onEdit: _targets, onUndo: _undo == null ? null : _restore,
          onChanged: (p) => _change(_d.copyWith(preferences: p)),
        ),
        const SizedBox(height: 16),
        Segmented<_Tab>(
          keyPrefix: 'eatout-tab', values: _Tab.values, selected: _tab,
          label: (t) => t == _Tab.choose ? l.eatOutHelpChoose : l.eatOutYourOrder(order.count), onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: 14),
        if (_tab == _Tab.choose)
          ..._suggestions(l, chain, order)
        else ...[
          if (split.missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusLine(Icons.warning_amber_outlined, l.eatOutNoLongerListed(split.missing.length), key: const Key('eatout-missing'), tone: Tone.warning),
                TextButton(onPressed: () => _change(_d.copyWith(order: order)), child: Text(l.eatOutRemoveThem)),
              ]),
            ),
          if (order.isEmpty)
            EmptyState(l.eatOutOrderEmptyTitle, l.eatOutOrderEmptyBody, key: const Key('eatout-order-empty'))
          else
            GroupCard(children: [
              for (final line in order.lines)
                _LineRow(chain: chain, line: line, onQuantity: (q) => _change(_d.copyWith(order: _d.order.withQuantity(line.itemId, q)))),
            ]),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(key: const Key('eatout-add'), onPressed: () => _menu(chain), icon: const Icon(Icons.add), label: Text(l.eatOutAddFromMenu)),
          ),
          if (!order.isEmpty) ...[
            const SizedBox(height: 8),
            _Totals(orderTotals, order: order, chain: chain, preferences: _d.preferences, key: const Key('eatout-totals')),
          ],
        ],
        const SizedBox(height: 22),
        Text(l.eatOutSourceLine(ltr('${source['title']}'), '${source['published'] ?? l.eatOutNotStated}', longDate('${source['checked']}')), style: context.caption),
        const SizedBox(height: 6),
        Text(l.eatOutCustomNote, style: context.caption),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(key: const Key('eatout-own-estimate'), onPressed: () => _ownEstimate(chain), child: Text(l.eatOutOwnEstimate)),
        ),
      ],
    );
  }

  void _choose(RestaurantChain c) {
    if (!c.available) {
      showGoSheet<void>(context, title: context.l10n.eatOutChainNotYet(c.name), builder: (_) => Text(context.l10n.eatOutChainBlocked, style: context.sansStyle(16)));
      return;
    }
    // Another chain's items cannot be in this order: its preferences and order start empty (Undo brings them back).
    _change(c.id == _d.chainId ? _d : EatOutDraft(chainId: c.id, history: _d.history), undoable: c.id != _d.chainId && !_d.order.isEmpty);
    setState(() {
      _last = null;
      _stale = false;
      _tab = _Tab.choose;
    });
  }

  String _coachWords(AppLocalizations l, RestaurantChain chain) {
    if (_sending) return l.eatOutCoachReading;
    final i = _last;
    if (i == null) return _d.order.isEmpty ? l.eatOutCoachChain(chain.name) : l.eatOutCoachImprove;
    if (i.kind == 'unsupported') return l.eatOutCoachUnsupported;
    if (i.problem == 'contradiction') return l.eatOutCoachContradiction;
    if (i.kind == 'clarify') return i.clarification == null ? l.eatOutCoachClarify : l.eatOutCoachAsks(i.clarification!);
    final unknown = i.unknownItems.isEmpty ? '' : ' ${l.eatOutCoachUnknown(i.unknownItems.join(', '))}';
    return '${l.eatOutCoachUnderstood}$unknown';
  }

  String _problemText(AppLocalizations l, AskProblem p) => switch (p) {
        AskProblem.limit => l.eatOutProblemLimit,
        AskProblem.busy => l.eatOutProblemBusy,
        AskProblem.unreached => l.eatOutProblemUnreached,
        AskProblem.invalid => l.eatOutAskInvalid,
        _ => l.eatOutProblemUnavailable,
      };

  List<Widget> _suggestions(AppLocalizations l, RestaurantChain chain, RestaurantOrder current) {
    final p = _d.preferences;
    if (p.maxCalories == null && p.minCalories == null && p.minProtein == null && p.keep.isEmpty && p.prefer.isEmpty) {
      return [EmptyState(l.eatOutNoTargetsTitle, l.eatOutNoTargetsBody, key: const Key('eatout-no-targets'), action: SecondaryButton(l.eatOutSetTargets, key: const Key('eatout-set-targets'), onPressed: _targets))];
    }
    final result = OrderPlanner.suggest(chain, p);
    if (result.impossible) return [StatusLine(Icons.block, p.contradictory ? l.eatOutContradiction : l.eatOutNothingPossible, key: const Key('eatout-impossible'), tone: Tone.warning)];
    final shown = result.fits.isNotEmpty ? result.fits : result.nearest;
    return [
      Text(l.eatOutSortedBy(_priorityText(l, result.sortedBy)), style: context.caption, key: const Key('eatout-sorted-by')),
      const SizedBox(height: 8),
      if (result.fits.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.info_outline, l.eatOutNoneFits, key: const Key('eatout-none-fits'), tone: Tone.warning)),
      for (final (n, s) in shown.indexed) ...[
        _SuggestionCard(s, index: n, chain: chain, preferences: p, current: current.isEmpty ? null : current,
            onUse: () {
              _change(_d.copyWith(order: s.order), undoable: true);
              setState(() => _tab = _Tab.order);
            }),
        const SizedBox(height: 12),
      ],
    ];
  }
}

String _priorityText(AppLocalizations l, OrderPriority p) => switch (p) {
      OrderPriority.protein => l.eatOutPriorityProtein,
      OrderPriority.calories => l.eatOutPriorityCalories,
      OrderPriority.closest => l.eatOutPriorityClosest,
    };

String _kindText(AppLocalizations l, String kind) => switch (kind) {
      'sandwich' => l.eatOutKindSandwich,
      'wrap' => l.eatOutKindWrap,
      'salad' => l.eatOutKindSalad,
      'bowl' => l.eatOutKindBowl,
      'breakfast' => l.eatOutKindBreakfast,
      'pizza' => l.eatOutKindPizza,
      'chicken' => l.eatOutKindChicken,
      'side' => l.eatOutKindSide,
      'dessert' => l.eatOutKindDessert,
      'drink' => l.eatOutKindDrink,
      _ => kind,
    };

String _g(double v) => formatNumber((v * 10).roundToDouble() / 10);

/// What an order misses of the chosen targets, in words: "120 kcal over your limit".
String _missText(AppLocalizations l, Miss m) => switch (m.kind) {
      MissKind.overCalories => l.eatOutMissOver(formatKcal(m.amount)),
      MissKind.underCalories => l.eatOutMissUnder(formatKcal(m.amount)),
      MissKind.underProtein => l.eatOutMissProtein(_g(m.amount)),
    };

/// The guide: the animated bust with its bubble where the coach is shown on tabs, otherwise its small avatar beside the
/// words. Either way it is the way to ask, and showing it sends nothing.
class _CoachLine extends ConsumerWidget {
  const _CoachLine({required this.say, required this.onAvatar, this.attentive = false});
  final CoachSay say;
  final VoidCallback onAvatar;
  final bool attentive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onTabs = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));
    final label = context.l10n.eatOutAskLabel(guide.displayName(context.l10n));
    if (onTabs) return TabCoach(key: const Key('eatout-coach'), id: 'eatout', say: say, attentive: attentive, avatarLabel: label, onAvatarTap: onAvatar);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CoachHelpButton(key: const Key('eatout-coach-small'), semanticLabel: label, onPressed: onAvatar),
      const SizedBox(width: 10),
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 10), child: Text(say.text, style: context.sansStyle(15)))),
    ]);
  }
}

class _AskBox extends StatelessWidget {
  const _AskBox({required this.controller, required this.focus, required this.sending, required this.enabled, required this.onSend});
  final TextEditingController controller;
  final FocusNode focus;
  final bool sending, enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Send is part of the field, on its line: brought into view with the caret, it stays above the keyboard.
    return TextField(
      key: const Key('eatout-ask'), controller: controller, focusNode: focus, enabled: enabled, minLines: 1, maxLines: 4, maxLength: 600,
      textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.newline,
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
      decoration: InputDecoration(
        hintText: l.eatOutAskHint, counterText: '',
        suffixIcon: sending
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)))
            : IconButton(key: const Key('eatout-send'), tooltip: l.coachAskSend, color: context.c.accent, onPressed: enabled ? onSend : null, icon: const Icon(Icons.send_rounded)),
      ),
    );
  }
}

class _ChainRow extends StatelessWidget {
  const _ChainRow(this.chain, this.catalog, {required this.onTap});
  final RestaurantChain chain;
  final RestaurantCatalog catalog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GroupRow(
      key: Key('eatout-chain-${chain.id}'), icon: chain.available ? Icons.storefront_outlined : Icons.do_not_disturb_on_outlined, tone: chain.available ? Tone.accent : Tone.neutral,
      title: l.eatOutChainCanada(chain.name),
      subtitle: chain.available ? l.eatOutChainOptions(chain.items.length, longDate(catalog.checked)) : l.eatOutChainUnavailable,
      onTap: onTap,
    );
  }
}

/// The chosen preferences, always visible and each removable, so a misunderstanding is corrected before anything is
/// used. Editing them changes the suggestions only.
class _Targets extends StatelessWidget {
  const _Targets({required this.chain, required this.preferences, required this.onEdit, required this.onChanged, this.onUndo});
  final RestaurantChain chain;
  final OrderPreferences preferences;
  final VoidCallback onEdit;
  final VoidCallback? onUndo;
  final ValueChanged<OrderPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = preferences;
    String name(String id) => ltr(chain.item(id)?.displayName ?? id);
    final chips = <(String, Key, OrderPreferences)>[
      if (p.maxCalories != null) (l.eatOutChipMax(formatKcal(p.maxCalories!.toDouble())), const Key('eatout-chip-max'), p.copyWith(maxCalories: () => null)),
      if (p.minCalories != null) (l.eatOutChipMin(formatKcal(p.minCalories!.toDouble())), const Key('eatout-chip-min'), p.copyWith(minCalories: () => null)),
      if (p.minProtein != null) (l.eatOutChipProtein(formatNumber(p.minProtein!)), const Key('eatout-chip-protein'), p.copyWith(minProtein: () => null)),
      for (final e in p.keep.entries) (l.eatOutChipKeep(name(e.key), e.value), Key('eatout-chip-keep-${e.key}'), p.copyWith(keep: {...p.keep}..remove(e.key))),
      for (final id in p.exclude) (l.eatOutChipExclude(name(id)), Key('eatout-chip-exclude-$id'), p.copyWith(exclude: {...p.exclude}..remove(id))),
      for (final k in p.prefer) (l.eatOutChipPrefer(_kindText(l, k)), Key('eatout-chip-prefer-$k'), p.copyWith(prefer: {...p.prefer}..remove(k))),
      for (final k in p.avoid) (l.eatOutChipAvoid(_kindText(l, k)), Key('eatout-chip-avoid-$k'), p.copyWith(avoid: {...p.avoid}..remove(k))),
      if (p.priority != null) (l.eatOutSortedBy(_priorityText(l, p.priority!)), const Key('eatout-chip-priority'), p.copyWith(priority: () => null)),
    ];
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The actions move under the heading when long words or large text leave no room beside it.
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Semantics(header: true, child: Text(l.eatOutYourTargets, style: context.titleStyle(18))),
          Wrap(children: [
            if (onUndo != null) TextButton(key: const Key('eatout-undo'), onPressed: onUndo, child: Text(l.coachAskUndo)),
            TextButton(key: const Key('eatout-edit-targets'), onPressed: onEdit, child: Text(l.actionEdit)),
          ]),
        ]),
        if (chips.isEmpty)
          Text(l.eatOutNoTargetsYet, style: context.caption)
        else
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final (label, key, without) in chips) _TargetChip(label, key: key, removeLabel: l.eatOutRemoveTarget(label), onRemove: () => onChanged(without)),
          ]),
        if (p.contradictory) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, l.eatOutContradiction, tone: Tone.error)),
      ]),
    );
  }
}

/// One chosen target with its remove button. Its words wrap rather than being cut, at any text size or language.
class _TargetChip extends StatelessWidget {
  const _TargetChip(this.label, {super.key, required this.removeLabel, required this.onRemove});
  final String label, removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: context.c.sunken, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.c.divider)),
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label, style: context.sansStyle(14.5, weight: FontWeight.w500))),
          IconButton(tooltip: removeLabel, onPressed: onRemove, icon: const Icon(Icons.close, size: 18), visualDensity: VisualDensity.compact),
        ]),
      );
}

/// One suggested order: its items and counts, calories and protein first, carbs and fat after, whether it fits the
/// chosen targets (or what it misses), and, beside an order already started, the difference from it.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard(this.s, {required this.index, required this.chain, required this.preferences, required this.onUse, this.current});
  final Suggestion s;
  final int index;
  final RestaurantChain chain;
  final OrderPreferences preferences;
  final RestaurantOrder? current;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = s.order.totals(chain);
    final carbs = t[Nutrient.carbs]!, fat = t[Nutrient.fat]!;
    final before = current;
    final kept = [for (final id in preferences.keep.keys) if (chain.item(id) case final i?) ltr(i.displayName)];
    return Panel(
      key: Key('eatout-suggestion-$index'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final line in s.order.lines)
          if (chain.item(line.itemId) case final i?)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l.eatOutLine(line.quantity, ltr(i.displayName)), style: context.sansStyle(16, weight: FontWeight.w600)),
            ),
        const SizedBox(height: 6),
        Wrap(spacing: 22, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.end, children: [
          Text(l.eatKcalValue(formatKcal(s.calories)), style: context.titleStyle(24)),
          Text(l.eatOutProteinValue(_g(s.protein)), style: context.titleStyle(20)),
          if (carbs.isComplete) Text('${l.eatCarbs} ${l.eatGramsValue(_g(carbs.knownTotal))}', style: context.caption),
          if (fat.isComplete) Text('${l.eatFat} ${l.eatGramsValue(_g(fat.knownTotal))}', style: context.caption),
        ]),
        const SizedBox(height: 6),
        if (s.fits)
          StatusLine(Icons.check_circle_outline, [l.eatOutFits, if (kept.isNotEmpty) l.eatOutKeeps(kept.join(', '))].join(' '), tone: Tone.success)
        else
          StatusLine(Icons.info_outline, l.eatOutMisses(s.misses.map((m) => _missText(l, m)).join(' · ')), tone: Tone.warning),
        if (before != null) ...[
          const SizedBox(height: 6),
          Text(
            l.eatOutVersusOrder(_signed(s.calories - before.total(chain, Nutrient.calories)!, formatKcal), _signed(s.protein - before.total(chain, Nutrient.protein)!, _g)),
            key: Key('eatout-compare-$index'), style: context.sansStyle(14, color: context.c.secondary),
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(key: Key('eatout-use-$index'), onPressed: onUse, child: Text(before == null ? l.eatOutUseOrder : l.eatOutUseInstead)),
        ),
      ]),
    );
  }

  static String _signed(double v, String Function(double) f) => v == 0 ? '±0' : v > 0 ? '+${f(v)}' : '−${f(-v)}';
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.chain, required this.line, required this.onQuantity});
  final RestaurantChain chain;
  final OrderLine line;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final i = chain.item(line.itemId)!;
    final kcal = i.nutrient('calories');
    final build = chain.buildNote(i.build);
    return Padding(
      key: Key('eatout-line-${i.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 6, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.displayName, style: context.sansStyle(16, weight: FontWeight.w600)),
            Text([ltr(i.portion), if (kcal != null) l.eatOutEach(formatKcal(kcal))].join(' · '), style: context.caption),
            if (build != null) Text(ltr(build), style: context.caption),
          ]),
        ),
        IconButton(key: Key('eatout-less-${i.id}'), tooltip: l.eatOutLess(i.displayName), onPressed: () => onQuantity(line.quantity - 1), icon: Icon(line.quantity == 1 ? Icons.delete_outline : Icons.remove)),
        Semantics(label: l.eatOutCountSaid(line.quantity), child: ExcludeSemantics(child: Text('${line.quantity}', style: context.numStyle(17)))),
        IconButton(key: Key('eatout-more-${i.id}'), tooltip: l.eatOutMore(i.displayName), onPressed: line.quantity >= 20 ? null : () => onQuantity(line.quantity + 1), icon: const Icon(Icons.add)),
      ]),
    );
  }
}

/// The order's values, computed from the catalog: calories and protein first, carbs, fat and sodium when every item
/// states them ("… known" otherwise), and how the order stands against the chosen targets.
class _Totals extends ConsumerWidget {
  const _Totals(this.totals, {super.key, required this.order, required this.chain, required this.preferences});
  final Map<Nutrient, NutrientTotal> totals;
  final RestaurantOrder order;
  final RestaurantChain chain;
  final OrderPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    String g(NutrientTotal t) => !t.hasAnyKnown ? '—' : t.isComplete ? l.eatGramsValue(_g(t.knownTotal)) : '${l.eatGramsValue(_g(t.knownTotal))} · ${l.eatKnown}';
    final kcal = totals[Nutrient.calories]!, protein = totals[Nutrient.protein]!;
    final sodium = [for (final line in order.lines) chain.item(line.itemId)?.extra('sodiumMg') == null ? null : chain.item(line.itemId)!.extra('sodiumMg')! * line.quantity];
    final misses = kcal.isComplete && protein.isComplete
        ? [
            if (preferences.maxCalories != null && kcal.knownTotal > preferences.maxCalories!) Miss(MissKind.overCalories, kcal.knownTotal - preferences.maxCalories!),
            if (preferences.minCalories != null && kcal.knownTotal < preferences.minCalories!) Miss(MissKind.underCalories, preferences.minCalories! - kcal.knownTotal),
            if (preferences.minProtein != null && protein.knownTotal < preferences.minProtein!) Miss(MissKind.underProtein, preferences.minProtein! - protein.knownTotal),
          ]
        : const <Miss>[];
    final hasTargets = preferences.maxCalories != null || preferences.minCalories != null || preferences.minProtein != null;
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(l.eatOutOrderTotal, style: context.titleStyle(18))),
        const SizedBox(height: 6),
        Wrap(spacing: 22, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.end, children: [
          Text(kcalText(l, kcal), style: context.titleStyle(24)),
          Text(protein.hasAnyKnown ? l.eatOutProteinValue(_g(protein.knownTotal)) : '—', style: context.titleStyle(20)),
          Text('${l.eatCarbs} ${g(totals[Nutrient.carbs]!)}', style: context.caption),
          Text('${l.eatFat} ${g(totals[Nutrient.fat]!)}', style: context.caption),
          if (!sodium.contains(null)) Text(l.eatOutSodium(formatNumber(sodium.fold(0.0, (a, b) => a + b!))), style: context.caption),
        ]),
        if (hasTargets) ...[
          const SizedBox(height: 8),
          if (misses.isEmpty)
            StatusLine(Icons.check_circle_outline, l.eatOutFits, tone: Tone.success)
          else
            StatusLine(Icons.info_outline, l.eatOutMisses(misses.map((m) => _missText(l, m)).join(' · ')), tone: Tone.warning),
        ],
      ]),
    );
  }
}

/// The chain's verified items to browse and add, grouped as the source groups them. Adding changes the order only.
class _MenuSheet extends StatefulWidget {
  const _MenuSheet({required this.chain, required this.order, required this.onAdd});
  final RestaurantChain chain;
  final RestaurantOrder Function() order;
  final ValueChanged<String> onAdd;
  @override
  State<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<_MenuSheet> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = normalizeSearch(_filter.text);
    final items = [for (final i in widget.chain.items) if (q.isEmpty || normalizeSearch('${i.displayName} ${i.section}').contains(q)) i];
    final sections = [for (final s in {for (final i in items) i.section}) s];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(key: const Key('eatout-menu-filter'), controller: _filter, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: l.eatOutMenuFilter, prefixIcon: const Icon(Icons.search))),
      const SizedBox(height: 10),
      if (items.isEmpty) StatusLine(Icons.search_off, l.mealsNoMatch(_filter.text.trim())),
      for (final s in sections) ...[
        Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(s, style: context.label)),
        GroupCard(children: [
          for (final i in items.where((i) => i.section == s))
            GroupRow(
              key: Key('eatout-menu-${i.id}'), title: i.displayName,
              subtitle: [ltr(i.portion), if (i.nutrient('calories') != null) l.eatKcalValue(formatKcal(i.nutrient('calories')!)), if (i.nutrient('protein') != null) l.eatOutProteinValue(_g(i.nutrient('protein')!))].join(' · '),
              value: widget.order().quantityOf(i.id) == 0 ? null : l.eatOutInOrder(widget.order().quantityOf(i.id)),
              trailing: IconButton(key: Key('eatout-menu-add-${i.id}'), tooltip: l.eatOutAddItem(i.displayName), icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => widget.onAdd(i.id))),
            ),
        ]),
      ],
    ]);
  }
}

/// Calorie limits, a protein minimum and how fitting orders are sorted. Every field may stay blank; nothing is suggested.
class _TargetsSheet extends StatefulWidget {
  const _TargetsSheet(this.start);
  final OrderPreferences start;
  @override
  State<_TargetsSheet> createState() => _TargetsSheetState();
}

class _TargetsSheetState extends State<_TargetsSheet> {
  late final _max = TextEditingController(text: widget.start.maxCalories?.toString() ?? '');
  late final _min = TextEditingController(text: widget.start.minCalories?.toString() ?? '');
  late final _protein = TextEditingController(text: widget.start.minProtein?.toString() ?? '');
  late OrderPriority? _priority = widget.start.priority;
  String? _error;

  @override
  void dispose() {
    _max.dispose();
    _min.dispose();
    _protein.dispose();
    super.dispose();
  }

  int? _int(TextEditingController c, int lo, int hi) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final v = parseNonNegative(raw);
    if (v == null || v != v.roundToDouble() || v < lo || v > hi) throw FormatException(raw);
    return v.toInt();
  }

  void _done() {
    try {
      final p = widget.start.copyWith(maxCalories: () => _int(_max, 100, 4000), minCalories: () => _int(_min, 0, 4000), minProtein: () => _int(_protein, 1, 300), priority: () => _priority);
      if (p.minCalories != null && p.maxCalories != null && p.minCalories! > p.maxCalories!) return setState(() => _error = context.l10n.eatOutContradiction);
      Navigator.pop(context, p);
    } on FormatException {
      setState(() => _error = context.l10n.eatOutTargetsInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    InputDecoration d(String label, String suffix) => InputDecoration(labelText: label, suffixText: suffix);
    const number = TextInputType.number;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.eatOutTargetsNote, style: context.caption),
      const SizedBox(height: 12),
      TextField(key: const Key('eatout-target-max'), controller: _max, keyboardType: number, decoration: d(l.eatOutTargetMax, l.eatUnitKcal)),
      const SizedBox(height: 10),
      TextField(key: const Key('eatout-target-min'), controller: _min, keyboardType: number, decoration: d(l.eatOutTargetMin, l.eatUnitKcal)),
      const SizedBox(height: 10),
      TextField(key: const Key('eatout-target-protein'), controller: _protein, keyboardType: number, decoration: d(l.eatOutTargetProtein, l.eatUnitGram)),
      const SizedBox(height: 14),
      Text(l.eatOutSortLabel, style: context.label),
      const SizedBox(height: 6),
      for (final p in [null, ...OrderPriority.values])
        ChoiceTile<OrderPriority?>(value: p, groupValue: _priority, onChanged: (v) => setState(() => _priority = v), title: p == null ? l.eatOutSortAutomatic : _priorityText(l, p)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 10),
      PrimaryButton(l.eatOutApplyTargets, key: const Key('eatout-targets-apply'), onPressed: _done),
    ]);
  }
}
