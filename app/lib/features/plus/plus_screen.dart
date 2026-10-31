import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart' show dayKeyOf;
import '../../core/format.dart' show longDate;
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../coach/coach_bubble.dart';
import 'entitlement.dart';

/// Me › GoHard Plus (docs/PLUS_PREVIEW.md): an honest preview. What each tier includes today, this month's AI
/// allowance, and for the configured owner only the server-authorized test switch. There is no purchase, trial or
/// restore action anywhere, because no billing exists.
class PlusScreen extends ConsumerStatefulWidget {
  const PlusScreen({super.key});
  @override
  ConsumerState<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends ConsumerState<PlusScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(entitlementProvider.notifier).refresh();
  }

  Future<void> _manage(Future<bool> Function(EntitlementController c) action, {String? done}) async {
    setState(() => _busy = true);
    final ok = await action(ref.read(entitlementProvider.notifier));
    if (!mounted) return;
    setState(() => _busy = false);
    final l = context.l10n;
    if (!ok) {
      toast(context, l.plusOwnerFailed);
    } else if (done != null) {
      toast(context, done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(plusProvider);
    final l = context.l10n;
    final compare = e?.j['compare'] as Map?;
    Map? tier(String t) => compare?[t] as Map?;
    String limit(Object? n) => n is int ? l.plusUpTo(n) : l.plusNoLimit;
    String month(Object? n) => n is int ? l.plusPerMonth(n) : '—';
    final rows = <(String, String, String)>[
      (l.plusRowTracking, l.plusIncluded, l.plusIncluded),
      (l.plusRowReports, l.plusIncluded, l.plusIncluded),
      if (compare != null) ...[
        (l.plusRowPlans, limit(tier('free')?['savedPlans']), limit(tier('plus')?['savedPlans'])),
        (l.plusRowMeals, limit(tier('free')?['savedMeals']), limit(tier('plus')?['savedMeals'])),
        (l.plusRowAi, month(tier('free')?['monthlyAi']), month(tier('plus')?['monthlyAi'])),
      ],
      (l.plusRowTrends, l.plusNotIncluded, l.plusIncluded),
      (l.plusRowProgression, l.plusNotIncluded, l.plusIncluded),
    ];
    final allowance = e?.allowance;

    return AppPage(
      title: l.plusTitle,
      children: [
        CoachSpot(id: 'plus.intro', introduce: true, padding: EdgeInsets.zero, say: CoachSay(l.plusCoachIntro)),
        const SizedBox(height: 12),
        PanelTheme(
          child: Builder(builder: (context) => PanelSurface(
            child: Column(key: const Key('plus-preview'), crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(l.plusPreviewTitle, style: context.pageTitleStyle(24))),
              const SizedBox(height: 6),
              Text(l.plusNoPurchases, key: const Key('plus-no-purchases'), style: context.sansStyle(16, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(l.plusPreviewBody, style: context.sansStyle(14.5)),
              const SizedBox(height: 10),
              if (e == null)
                StatusLine(Icons.cloud_off, l.plusUnknown)
              else if (!e.isLegacy)
                StatusLine(e.isPlus ? Icons.star_outline : Icons.person_outline, e.isPlus ? l.plusCurrentPlus : l.plusCurrentFree,
                    key: const Key('plus-current'), tone: e.isPlus ? Tone.success : Tone.neutral),
            ]),
          )),
        ),
        if (e == null) ...[
          const SizedBox(height: 10),
          SecondaryButton(l.actionTryAgain, key: const Key('plus-retry'), onPressed: () => ref.read(entitlementProvider.notifier).refresh()),
        ],
        if (e != null && e.overrideActive) ...[
          const SizedBox(height: 12),
          StatusLine(Icons.science_outlined, l.plusOverrideActive, key: const Key('plus-override-active'), tone: Tone.warning),
        ],

        const SizedBox(height: 22),
        SectionHeader(l.plusCompareHeader),
        GroupCard(children: [for (final (label, free, plus) in rows) _CompareRow(label: label, free: free, plus: plus)]),

        if (allowance != null) ...[
          const SizedBox(height: 22),
          SectionHeader(l.plusAllowanceHeader),
          Panel(
            child: Column(key: const Key('plus-allowance'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.plusAllowanceUsed(allowance.used, allowance.limit), style: context.sansStyle(17, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              ProgressRail(allowance.limit == 0 ? 1 : allowance.used / allowance.limit, label: l.plusAllowanceRail),
              const SizedBox(height: 8),
              if (allowance.resetsAtUtc case final resets?) Text(l.plusAllowanceLeft(allowance.remaining, resetDate(resets)), style: context.sansStyle(15)),
              const SizedBox(height: 8),
              Text(l.plusAllowanceNote, style: context.caption),
            ]),
          ),
        ],

        // Only for the configured owner, and only because the server said so; the server checks again on every change.
        if (e != null && e.canManagePreview) ...[
          const SizedBox(height: 22),
          SectionHeader(l.plusOwnerHeader),
          Text(l.plusOwnerTier, style: context.label),
          const SizedBox(height: 8),
          Segmented<bool>(
            values: const [false, true], selected: e.isPlus, keyPrefix: 'plus-tier', label: (p) => p ? l.plusTierPlus : l.plusTierFree,
            onChanged: (p) => _busy || p == e.isPlus ? null : _manage((c) => c.setPreviewTier(p)),
          ),
          const SizedBox(height: 12),
          SecondaryButton(l.plusOwnerReset, key: const Key('plus-reset-allowance'),
              onPressed: _busy ? null : () => _manage((c) => c.resetAllowance(), done: l.plusOwnerResetDone)),
        ],
      ],
    );
  }
}

/// One comparison row: the benefit, then Free and Plus. Wraps for long words and large text; read as one sentence.
class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.free, required this.plus});
  final String label, free, plus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget cell(String tier, String value) => ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Overline(tier),
            Text(value, style: context.sansStyle(15, weight: FontWeight.w600)),
          ]),
        );
    return Semantics(
      container: true, label: l.plusRowSemantic(label, free, plus),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(label, style: context.sansStyle(15.5)),
            const SizedBox(height: 6),
            Wrap(spacing: 24, runSpacing: 6, children: [cell(l.plusTierFree, free), cell(l.plusTierPlus, plus)]),
          ]),
        ),
      ),
    );
  }
}

/// The reset instant (00:00 UTC on the 1st) as that calendar date in the reader's language.
String resetDate(DateTime resetsAtUtc) => longDate(dayKeyOf(resetsAtUtc.toUtc()));

/// The words for a used-up monthly allowance, with its reset date when the server gave one.
String aiAllowanceUsedText(AppLocalizations l, AiAllowance? a) =>
    [l.plusAiUsed, if (a?.resetsAtUtc case final r?) l.plusAiResets(resetDate(r))].join(' ');

/// "AI this month: 12 of 15 left · resets 1 December": near an AI composer, only once the account has said.
class AiAllowanceLine extends ConsumerWidget {
  const AiAllowanceLine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(plusProvider)?.allowance;
    final resets = a?.resetsAtUtc;
    if (a == null || resets == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(context.l10n.plusAiLeftLine(a.remaining, a.limit, resetDate(resets)), key: const Key('ai-allowance-line'), style: context.caption),
    );
  }
}

/// A creation limit, explained where the person asked for it. The page underneath (and its draft) stays exactly as it
/// was: this is a sheet over it, and View Plus opens the Plus page above both.
enum PlusLimit { plans, meals }

Future<void> showPlusLimit(BuildContext context, PlusLimit kind, {required CreateGate gate, required int existing}) {
  final l = context.l10n;
  final e = ProviderScope.containerOf(context, listen: false).read(plusProvider);
  final limit = (kind == PlusLimit.plans ? e?.savedPlans : e?.savedMeals) ?? 0;
  final known = gate == CreateGate.limit;
  return showGoSheet<void>(context,
      title: known ? (kind == PlusLimit.plans ? l.plusLimitPlansTitle : l.plusLimitMealsTitle) : l.plusTitle,
      builder: (sheet) => Column(key: const Key('plus-limit'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                known ? (kind == PlusLimit.plans ? l.plusLimitPlansBody(limit, existing) : l.plusLimitMealsBody(limit, existing)) : l.plusUnknownCreate,
                style: context.sansStyle(15.5)),
            const SizedBox(height: 18),
            if (known) ...[
              PrimaryButton(l.plusViewPlus, key: const Key('plus-limit-view'), onPressed: () => push(sheet, const PlusScreen())),
              const SizedBox(height: 8),
            ],
            SecondaryButton(l.builderBack, key: const Key('plus-limit-back'), onPressed: () => Navigator.pop(sheet)),
          ]));
}

/// A Plus-only view, explained when the person chose it. Unknown says so instead of selling anything.
Future<void> showPlusFeature(BuildContext context) {
  final l = context.l10n;
  final known = ProviderScope.containerOf(context, listen: false).read(plusProvider) != null;
  return showGoSheet<void>(context,
      title: l.plusFeatureTrendsTitle,
      builder: (sheet) => Column(key: const Key('plus-feature'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(known ? l.plusFeatureTrendsBody : l.plusUnknown, style: context.sansStyle(15.5)),
            const SizedBox(height: 18),
            if (known) ...[
              PrimaryButton(l.plusViewPlus, key: const Key('plus-feature-view'), onPressed: () => push(sheet, const PlusScreen())),
              const SizedBox(height: 8),
            ],
            SecondaryButton(l.builderBack, key: const Key('plus-feature-back'), onPressed: () => Navigator.pop(sheet)),
          ]));
}
