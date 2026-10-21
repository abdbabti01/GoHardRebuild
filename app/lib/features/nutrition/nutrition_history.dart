import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/go_icon.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../coach/coach_bubble.dart';
import '../coach/coach_prefs.dart';
import 'intake_history.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'water.dart';

/// "2,230 kcal", "140.5 g", "1,250 mL": from the exact stored sum, rounded only here.
String intakeAmount(IntakeMetric m, double v, VolumeUnit unit) => switch (m) {
      IntakeMetric.calories => currentL10n.eatKcalValue(formatKcal(v)),
      IntakeMetric.water => unit.format(v),
      _ => currentL10n.eatGramsValue(_grams(v)),
    };

String _grams(double v) => formatGrouped((v * 10).round() / 10);

/// What one day holds for the metric, in words; the same words on the chart's day panel and in the list.
String intakeDayText(IntakeDay d, IntakeMetric m, VolumeUnit unit) {
  final l = currentL10n;
  final sync = d.review ? ' · ${l.eatNeedsReview}' : d.pending ? ' · ${l.eatSyncPendingShort}' : '';
  final foods = l.trendsFoodCount(d.foods);
  return switch (d.state) {
    DayState.future => l.trendsFuture,
    DayState.notLogged => m == IntakeMetric.water ? l.waterNoneLogged : l.trendsNoFoodLogged,
    DayState.unknown => '${l.trendsDayUnknown(intakeMetricLabel(l, m), foods)}$sync',
    DayState.partial => '${l.trendsDayPartial(intakeAmount(m, d.value!, unit), d.unknownFoods, foods, intakeMetricNoun(l, m))}$sync',
    DayState.recorded when d.isZero => '${l.trendsDayZero(intakeAmount(m, 0, unit))}$sync',
    DayState.recorded => '${intakeAmount(m, d.value!, unit)}${m == IntakeMetric.water ? '' : ' · $foods'}$sync',
  };
}

/// "Oct 12 – 18, 2026", "Sep 28 – Oct 4, 2026", "Dec 29, 2025 – Jan 4, 2026", "October 2026"; in French and
/// Arabic each end is a localized date ("12 oct. – 18 oct. 2026").
String periodLabel(Period p) {
  final a = parseDayKey(p.start), b = parseDayKey(p.end);
  if (p.kind == PeriodKind.month) return monthYear(a.year, a.month);
  if (currentLocale.languageCode != 'en') return '${a.year != b.year ? dayMonthYear(p.start) : dayMonth(p.start)} – ${dayMonthYear(p.end)}';
  if (a.year != b.year) return '${dayMonth(p.start)}, ${a.year} – ${dayMonth(p.end)}, ${b.year}';
  return '${dayMonth(p.start)} – ${a.month == b.month ? '${b.day}' : dayMonth(p.end)}, ${b.year}';
}

/// The view the person left History & trends in, for this account, so coming back from a day keeps it.
class TrendsView {
  const TrendsView(this.kind, this.metric, this.anchor, this.selected);
  final PeriodKind kind;
  final IntakeMetric metric;
  final String anchor, selected;
}

class TrendsViewController extends Notifier<TrendsView?> {
  @override
  TrendsView? build() {
    ref.watch(ownerProvider); // another account starts afresh
    return null;
  }

  void keep(TrendsView v) => state = v;
}

final trendsViewProvider = NotifierProvider<TrendsViewController, TrendsView?>(TrendsViewController.new);

/// Eat › History & trends (docs/FOOD_DATA.md › History & trends): Week or Month, one bar per day for the chosen
/// metric, known totals and averages, the chosen day with View day, and every day of the period. View day returns the
/// day's key: Eat then shows that day's journal, dated, with Back to today. Opening this screen from that day again
/// keeps the period, metric and day. Nothing is compared with a goal: past days' goals were not kept.
class NutritionHistoryScreen extends ConsumerStatefulWidget {
  const NutritionHistoryScreen({super.key, required this.selected});

  /// The day Eat shows.
  final String selected;
  @override
  ConsumerState<NutritionHistoryScreen> createState() => _NutritionHistoryScreenState();
}

class _NutritionHistoryScreenState extends ConsumerState<NutritionHistoryScreen> {
  late PeriodKind _kind;
  late IntakeMetric _metric;
  late String _anchor, _selected;

  @override
  void initState() {
    super.initState();
    final kept = ref.read(trendsViewProvider);
    _kind = kept?.kind ?? PeriodKind.week;
    _metric = kept?.metric ?? IntakeMetric.calories;
    // Back from the day it opened: the same view. Otherwise the period of the day Eat shows.
    final back = kept != null && kept.selected == widget.selected;
    _anchor = back ? kept.anchor : widget.selected;
    _selected = widget.selected;
  }

  void _set({PeriodKind? kind, IntakeMetric? metric, String? anchor, String? selected}) {
    setState(() {
      _kind = kind ?? _kind;
      _metric = metric ?? _metric;
      _anchor = anchor ?? _anchor;
      _selected = selected ?? _selected;
    });
    ref.read(trendsViewProvider.notifier).keep(TrendsView(_kind, _metric, _anchor, _selected));
  }

  void _open(String day) {
    ref.read(trendsViewProvider.notifier).keep(TrendsView(_kind, _metric, _anchor, day));
    Navigator.of(context).pop(day);
  }

  /// Moves to another period, choosing its last elapsed day.
  void _shift(Period p, int by, String today) {
    final next = p.shift(by);
    _set(anchor: next.start, selected: next.end.compareTo(today) > 0 ? today : next.end);
  }

  void _select(String day) => _set(selected: day, anchor: day);

  static void _help(BuildContext context) => showCoachHelpSheet(context, title: context.l10n.eatHistoryTrends, say: CoachSay(context.l10n.trendsHelpBody));

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayKeyProvider);
    final display = ref.watch(nutritionDisplayProvider);
    final unit = ref.watch(volumeUnitProvider);
    final foodDays = ref.watch(foodDaysProvider);
    final waterDays = display.water ? ref.watch(waterDaysProvider) : const AsyncData<WaterDays>({});
    final coachOn = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final metrics = [
      IntakeMetric.calories, IntakeMetric.protein,
      if (display.carbs) IntakeMetric.carbs,
      if (display.fat) IntakeMetric.fat,
      if (display.water) IntakeMetric.water,
    ];
    // A metric hidden since it was chosen gives way to calories; the choice comes back if it is shown again.
    final metric = metrics.contains(_metric) ? _metric : IntakeMetric.calories;
    final anchor = _anchor.compareTo(today) > 0 ? today : _anchor;
    final selected = _selected.compareTo(today) > 0 ? today : _selected;
    final period = Period.containing(_kind, anchor);
    final source = metric == IntakeMetric.water ? waterDays : foodDays;
    final food = foodDays.value ?? const {}, water = waterDays.value ?? const {};
    final summary = IntakeSummary.build(period, metric, today: today, food: food, water: water);
    final earliest = [...food.keys, ...water.keys, addDays(today, -365)].reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final c = context.c;
    final l = context.l10n;

    final heading = Heading(l.eatHistoryTrends, size: 36, serif: true);
    final coach = TabCoach(key: const Key('trends-coach'), id: 'eat.trends', avatarLabel: l.trendsHelpLabel,
        say: CoachSay(l.trendsCoachSay), onAvatarTap: () => _help(context));
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 28), children: [
          if (coachOn) ...[
            // Beside the title as on Run / Walk; under it with large text, so the bubble never covers the title.
            if (MediaQuery.textScalerOf(context).scale(10) <= 13)
              Stack(children: [heading, Padding(padding: const EdgeInsets.only(top: 14), child: coach)])
            else ...[heading, coach],
          ] else
            heading,
          const SizedBox(height: 14),
          Segmented<PeriodKind>(
            keyPrefix: 'trends-kind', values: PeriodKind.values, selected: _kind, label: (k) => k == PeriodKind.week ? l.trendsWeek : l.trendsMonth,
            onChanged: (k) => _set(kind: k, anchor: selected),
          ),
          const SizedBox(height: 10),
          _PeriodBar(
            summary: summary,
            onPrevious: period.start.compareTo(earliest) <= 0 ? null : () => _shift(period, -1, today),
            onNext: summary.current ? null : () => _shift(period, 1, today),
            onPick: () async {
              final d = await showDatePicker(context: context, initialDate: parseDayKey(selected), firstDate: parseDayKey(earliest), lastDate: parseDayKey(today),
                  currentDate: parseDayKey(today), helpText: l.trendsChooseDay);
              if (d != null) _select(dayKeyOf(d));
            },
            onToday: summary.current ? null : () => _select(today),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in metrics)
              ChoiceChip(key: Key('trends-metric-${m.name}'), label: Text(intakeMetricLabel(l, m)), selected: m == metric, onSelected: (_) => _set(metric: m)),
          ]),
          const SizedBox(height: 16),
          if (source.hasError)
            Panel(child: StatusLine(Icons.error_outline, metric == IntakeMetric.water ? l.trendsWaterReadError : l.trendsFoodReadError, tone: Tone.error))
          else if (!source.hasValue)
            Panel(child: StatusLine(Icons.hourglass_empty, l.trendsReading))
          else ...[
            _Totals(summary: summary, unit: unit),
            const SizedBox(height: 16),
            Panel(
              key: const Key('trends-chart-card'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.trendsByDay(intakeMetricLabel(l, metric)), style: context.pageTitleStyle(22)),
                Text(metric == IntakeMetric.water ? unit.short : metric == IntakeMetric.calories ? l.eatUnitKcal : l.eatUnitGram, style: context.caption),
                const SizedBox(height: 8),
                IntakeChart(summary: summary, selected: selected, unit: unit, onSelect: (d) => _set(selected: d)),
                const SizedBox(height: 10),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _Key('–', metric == IntakeMetric.water ? l.waterNoneLogged : l.trendsLegendNotLogged),
                  if (metric != IntakeMetric.water) ...[_Key('?', l.trendsLegendNotEntered), _Key('★', l.trendsLegendPartial)],
                  _Key('○', l.trendsLegendZero),
                ]),
              ]),
            ),
            if (period.contains(selected)) ...[
              const SizedBox(height: 12),
              _DayPanel(
                day: summary.days.firstWhere((d) => d.dayKey == selected), metric: metric, unit: unit,
                onPrevious: selected.compareTo(earliest) <= 0 ? null : () => _select(addDays(selected, -1)),
                onNext: selected.compareTo(today) >= 0 ? null : () => _select(addDays(selected, 1)),
                onView: () => _open(selected),
              ),
            ],
          ],
          const SizedBox(height: 24),
          SectionHeader(l.trendsDaysInPeriod,
              trailing: QuietLink(l.trendsCalendar, key: const Key('trends-calendar'), said: l.trendsCalendarSaid, onPressed: () async {
                final day = await push<String>(context, NutritionDaysScreen(selected: selected));
                if (day != null) _open(day);
              })),
          const SizedBox(height: 10),
          if (foodDays.hasError || waterDays.hasError)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusLine(Icons.error_outline, foodDays.hasError ? l.trendsFoodErrorWaterShown : l.trendsWaterErrorFoodShown, tone: Tone.error)),
          if (!foodDays.hasValue && !foodDays.hasError)
            StatusLine(Icons.hourglass_empty, l.trendsReading)
          else
            GroupCard(children: [
              for (final d in summary.elapsed.reversed)
                Semantics(
                  selected: d.dayKey == selected,
                  child: ColoredBox(
                    color: d.dayKey == selected ? c.accentSoft : Colors.transparent,
                    child: GroupRow(
                      key: Key('trends-day-${d.dayKey}'), title: d.dayKey == today ? l.eatTodayCaption : shortDate(d.dayKey),
                      value: d.hasValue ? intakeAmount(metric, d.value!, unit) : '—',
                      subtitle: [
                        intakeDayText(d, metric, unit),
                        if (metric != IntakeMetric.water && d.waterEntries > 0 && display.water) l.eatWaterValue(unit.format(waterTotal([for (final w in water[d.dayKey]!) w.value]))),
                        if (metric == IntakeMetric.water && d.foods > 0) l.trendsFoodsLogged(l.trendsFoodCount(d.foods)),
                      ].join(' · '),
                      onTap: () => _open(d.dayKey),
                    ),
                  ),
                ),
            ]),
          const SizedBox(height: 8),
          Text(l.trendsFootnote, style: context.caption),
        ]),
      ),
    );
  }
}

/// The period, its arrows (no wholly future period), a calendar to choose any day, and the way back to this period.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.summary, required this.onPrevious, required this.onNext, required this.onPick, required this.onToday});
  final IntakeSummary summary;
  final VoidCallback? onPrevious, onNext, onToday;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = summary.period;
    final week = p.kind == PeriodKind.week;
    final today = summary.today;
    final l = context.l10n;
    final sameMonth = p.start.substring(0, 7) == today.substring(0, 7) && currentLocale.languageCode == 'en';
    final through = p.start == today ? dayMonth(today) : '${dayMonth(p.start)} – ${sameMonth ? parseDayKey(today).day : dayMonth(today)}';
    final sub = summary.current ? (week ? l.trendsWeekSoFar(through) : l.trendsMonthToDate(through)) : null;
    return Container(
      decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.field + 1), border: Border.all(color: context.c.divider)),
      child: Column(children: [
        Row(children: [
          IconButton(key: const Key('trends-previous'), tooltip: week ? l.trendsPreviousWeek : l.trendsPreviousMonth, icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
          Expanded(
            child: Semantics(
              button: true, label: sub == null ? l.trendsPeriodSaid(periodLabel(p)) : l.trendsPeriodSaidSub(periodLabel(p), sub), excludeSemantics: true,
              child: InkWell(
                key: const Key('trends-period'),
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: context.c.secondary),
                      Text(periodLabel(p), key: const Key('trends-period-label'), textAlign: TextAlign.center, style: context.sansStyle(16.5, weight: FontWeight.w600)),
                    ]),
                    if (sub != null) Text(sub, key: const Key('trends-so-far'), textAlign: TextAlign.center, style: context.caption),
                  ]),
                ),
              ),
            ),
          ),
          IconButton(key: const Key('trends-next'), tooltip: week ? l.trendsNextWeek : l.trendsNextMonth, icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ]),
        if (onToday != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextButton.icon(key: const Key('trends-current'), onPressed: onToday, icon: const Icon(Icons.today, size: 18), label: Text(week ? l.trendsThisWeek : l.trendsThisMonth)),
          ),
      ]),
    );
  }
}

/// The period's known total, how many days it covers, and the daily average over those days only.
class _Totals extends StatelessWidget {
  const _Totals({required this.summary, required this.unit});
  final IntakeSummary summary;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = summary, m = s.metric;
    final water = m == IntakeMetric.water;
    final elapsed = s.elapsed.length;
    final label = intakeMetricLabel(l, m), noun = intakeMetricNoun(l, m);
    final partial = s.partialDays > 0;
    return PhotoPanel(
      key: const Key('trends-totals'),
      content: (context) => [
        Overline(partial ? l.trendsKnownLogged(label) : l.trendsLogged(label)),
        const SizedBox(height: 4),
        Text(s.total == null ? (water ? l.waterNoneLogged : l.trendsNoValues(noun)) : intakeAmount(m, s.total!, unit), key: const Key('trends-total'), style: context.pageTitleStyle(s.total == null ? 26 : 38)),
        Text(
            water
                ? (s.current ? l.trendsCoverageWaterSoFar(s.known.length, elapsed) : l.trendsCoverageWater(s.known.length, elapsed))
                : (s.current ? l.trendsCoverageSoFar(s.known.length, elapsed, noun) : l.trendsCoverage(s.known.length, elapsed, noun)),
            key: const Key('trends-coverage'), style: context.sansStyle(15.5)),
        if (!water && s.loggedDays != s.known.length)
          Text([l.trendsDaysWithFood(s.loggedDays), if (s.unknownDays > 0) l.trendsDaysWithoutValue(s.unknownDays, noun)].join(' · '), key: const Key('trends-logged'), style: context.caption),
        if (s.average != null) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: context.c.text.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Wrap(spacing: 20, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(partial ? l.trendsAverageKnown : l.trendsAverage, style: context.sansStyle(15)),
              Text(intakeAmount(m, s.average!, unit), key: const Key('trends-average'), style: context.pageTitleStyle(28)),
            ]),
            Text(water ? l.trendsAcrossWater(s.known.length) : l.trendsAcross(s.known.length, noun), key: const Key('trends-average-days'),
                style: context.sansStyle(14.5, color: context.c.secondary)),
          ]),
          if (partial)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.trendsPartialNote(s.partialDays, noun), key: const Key('trends-partial-note'), style: context.caption),
            ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.mark, this.text);
  final String mark, text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: Text(mark, style: context.sansStyle(14, weight: FontWeight.w700, color: context.c.secondary))),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: context.caption)),
      ]);
}

/// The chosen day: its date, value and coverage, a step either side, and View day.
class _DayPanel extends StatelessWidget {
  const _DayPanel({required this.day, required this.metric, required this.unit, required this.onPrevious, required this.onNext, required this.onView});
  final IntakeDay day;
  final IntakeMetric metric;
  final VolumeUnit unit;
  final VoidCallback? onPrevious, onNext;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) => Panel(
        key: const Key('trends-selected'),
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 8, 8).resolve(Directionality.of(context)),
        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(key: const Key('trends-day-previous'), tooltip: context.l10n.eatPreviousDay, icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 150),
              child: Semantics(
                liveRegion: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(longDate(day.dayKey), key: const Key('trends-selected-date'), style: context.sansStyle(16.5, weight: FontWeight.w700)),
                  Text(intakeDayText(day, metric, unit), key: const Key('trends-selected-value'), style: context.sansStyle(14.5, color: context.c.secondary)),
                ]),
              ),
            ),
            IconButton(key: const Key('trends-day-next'), tooltip: context.l10n.eatNextDay, icon: const Icon(Icons.chevron_right), onPressed: onNext),
          ]),
          QuietLink(context.l10n.trendsViewDay, key: const Key('trends-view-day'), said: context.l10n.trendsViewDaySaid(longDate(day.dayKey)), onPressed: onView),
        ]),
      );
}

/// One bar per date position from the zero baseline, drawn from the summary's values. A partial sum is lighter, outlined
/// and starred; a recorded zero is a ring on the baseline; a day with food but no value is "?"; nothing logged is a
/// dash; future days are left empty. Tapping or sliding chooses the nearest elapsed day. The list of days below is the
/// full non-visual alternative.
class IntakeChart extends StatelessWidget {
  const IntakeChart({super.key, required this.summary, required this.selected, required this.unit, required this.onSelect, this.height = 200});
  final IntakeSummary summary;
  final String selected;
  final VolumeUnit unit;
  final ValueChanged<String> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = context.numStyle(12, color: context.c.secondary, weight: FontWeight.w400);
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final m = summary.metric;
    String axis(double v) => m == IntakeMetric.water ? unit.number(v) : m == IntakeMetric.calories ? formatKcal(v) : _grams(v);
    final known = summary.known;
    // Time runs left to right in every language: the plot is laid out left to right, labels stay under their bars.
    return Semantics(
      container: true,
      label: context.l10n.trendsChartSaid(intakeMetricLabel(context.l10n, m), periodLabel(summary.period), known.length, summary.elapsed.length),
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
          key: const Key('trends-chart'),
          height: height + 16 * scale.scale(1),
          child: LayoutBuilder(builder: (context, box) {
            final l = _BarLayout(summary, Size(box.maxWidth, height + 16 * scale.scale(1)), axis, style, scale);
            void pick(Offset at) {
              final d = l.dayAt(at.dx);
              if (d != null && d != selected) onSelect(d);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => pick(d.localPosition),
              onHorizontalDragStart: (d) => pick(d.localPosition),
              onHorizontalDragUpdate: (d) => pick(d.localPosition),
              child: CustomPaint(size: l.size, painter: _BarPainter(l, selected, context.c)),
            );
          }),
          ),
        ),
      ),
    );
  }
}

class _BarLayout {
  _BarLayout(this.s, this.size, String Function(double) label, this.style, this.scale) {
    final max = s.maxValue;
    // A round top (1, 2, 2.5 or 5 × a power of ten) and three or four lines from zero.
    final raw = max <= 0 ? 1.0 : max / 3;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    step = [1, 2, 2.5, 5, 10].map((k) => k * mag).firstWhere((v) => v >= raw);
    top = math.max(step, step * (max / step).ceil());
    yLabels = [for (var v = 0.0; v <= top + step / 2; v += step) (v, text(label(v)))];
    final week = s.period.kind == PeriodKind.week;
    final left = yLabels.map((t) => t.$2.width).reduce(math.max) + 8;
    // Weekday names shorten to one letter when three would touch (narrow screens, large text).
    final letters = text('Wed').width > (size.width - 4 - left) / s.days.length - 4 ? 1 : 3;
    xLabels = [
      for (final (i, d) in s.days.indexed)
        if (week || _labelled(i, s.days.length))
          (i, text(week ? '${_weekday(weekdayOf(d.dayKey), letters)}\n${parseDayKey(d.dayKey).day}' : '${parseDayKey(d.dayKey).day}')),
    ];
    final bottom = (week ? text('M\n1').height : text('1').height) + 8;
    plot = Rect.fromLTRB(left, 14, size.width - 4, size.height - bottom);
    slot = plot.width / s.days.length;
  }

  final IntakeSummary s;
  final Size size;
  final TextStyle style;
  final TextScaler scale;
  late final double step, top, slot;
  late final List<(double, TextPainter)> yLabels;
  late final List<(int, TextPainter)> xLabels;
  late final Rect plot;

  TextPainter text(String t, [TextStyle? st]) => TextPainter(text: TextSpan(text: t, style: st ?? style), textAlign: TextAlign.center, textDirection: TextDirection.ltr, textScaler: scale)..layout();

  /// A weekday under its bar: "Mon" or "M" in English (as before), the locale's short or narrow form otherwise
  /// (Arabic has no short form, so its one-letter form is used).
  static String _weekday(int iso, int letters) => switch (currentLocale.languageCode) {
        'en' => weekdayShort(iso).substring(0, letters),
        'fr' when letters == 3 => weekdayShort(iso),
        _ => weekdayNarrow(iso),
      };

  /// Month labels: the 1st, every fifth day, and the last day when it is not crowded.
  static bool _labelled(int i, int n) => i == 0 || (i + 1) % 5 == 0 && n - (i + 1) >= 3 || i == n - 1;

  double x(int i) => plot.left + slot * (i + 0.5);
  double y(double v) => plot.bottom - plot.height * v / top;

  /// The elapsed day nearest to [dx]; never a future one.
  String? dayAt(double dx) {
    final elapsed = s.elapsed.length;
    if (elapsed == 0) return null;
    final i = ((dx - plot.left) / slot).floor().clamp(0, elapsed - 1);
    return s.days[i].dayKey;
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.l, this.selected, this.c);
  final _BarLayout l;
  final String selected;
  final GoColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = c.divider
      ..strokeWidth = 1;
    for (final (v, t) in l.yLabels) {
      final y = l.y(v);
      canvas.drawLine(Offset(l.plot.left, y), Offset(l.plot.right, y), grid..color = v == 0 ? c.secondary.withValues(alpha: 0.6) : c.divider);
      t.paint(canvas, Offset(l.plot.left - 8 - t.width, y - t.height / 2));
    }
    final barW = math.min(28.0, math.max(3.0, l.slot * (l.s.period.kind == PeriodKind.week ? 0.55 : 0.62)));
    for (final (i, d) in l.s.days.indexed) {
      final x = l.x(i);
      final on = d.dayKey == selected;
      if (on) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, l.plot.center.dy), width: math.max(barW + 8, l.slot * 0.9), height: l.plot.height + 10), const Radius.circular(8)),
            Paint()..color = c.accentSoft);
      }
      final base = l.plot.bottom;
      void mark(String s, {Color? color}) {
        final t = l.text(s, l.style.copyWith(color: color ?? c.secondary, fontWeight: FontWeight.w700));
        t.paint(canvas, Offset(x - t.width / 2, base - t.height - 2));
      }

      switch (d.state) {
        case DayState.future:
          break;
        case DayState.notLogged:
          canvas.drawLine(Offset(x - math.min(barW, 10) / 2, base - 5), Offset(x + math.min(barW, 10) / 2, base - 5), Paint()
            ..color = c.secondary
            ..strokeWidth = 2);
        case DayState.unknown:
          mark('?');
        case DayState.partial || DayState.recorded when d.isZero:
          canvas.drawCircle(Offset(x, base - 5), math.min(4.5, barW / 2 + 1), Paint()
            ..color = c.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
        case DayState.partial:
          final r = RRect.fromRectAndCorners(Rect.fromLTRB(x - barW / 2, l.y(d.value!), x + barW / 2, base), topLeft: const Radius.circular(4), topRight: const Radius.circular(4));
          canvas.drawRRect(r, Paint()..color = c.accent.withValues(alpha: 0.35));
          canvas.drawRRect(r, Paint()
            ..color = c.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
          final t = l.text('★', l.style.copyWith(color: c.text, fontSize: l.slot < 14 ? 9 : 12));
          t.paint(canvas, Offset(x - t.width / 2, l.y(d.value!) - t.height - 1));
        case DayState.recorded:
          canvas.drawRRect(
              RRect.fromRectAndCorners(Rect.fromLTRB(x - barW / 2, l.y(d.value!), x + barW / 2, base), topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
              Paint()..color = c.accent);
      }
    }
    for (final (i, t) in l.xLabels) {
      final d = l.s.days[i];
      final future = d.state == DayState.future;
      final p = d.dayKey == selected || future ? l.text(t.text!.toPlainText(), l.style.copyWith(color: future ? c.secondary.withValues(alpha: 0.5) : c.text, fontWeight: d.dayKey == selected ? FontWeight.w700 : null)) : t;
      p.paint(canvas, Offset((l.x(i) - p.width / 2).clamp(0, size.width - p.width), l.plot.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true; // at most 31 bars: cheaper than comparing summaries and colours
}

/// The calendar and every day with entries, newest first (the History of before): choosing a day returns its key.
class NutritionDaysScreen extends ConsumerWidget {
  const NutritionDaysScreen({super.key, required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayKeyProvider);
    final showWater = ref.watch(nutritionDisplayProvider).water;
    final food = ref.watch(foodDaysProvider);
    final water = showWater ? ref.watch(waterDaysProvider) : const AsyncData<WaterDays>({});
    final unit = ref.watch(volumeUnitProvider);
    final loaded = food.hasValue && (water.hasValue || water.hasError);
    final f = food.value ?? const {}, w = water.value ?? const {};
    final days = {...f.keys, ...w.keys}.toList()..sort((a, b) => b.compareTo(a));
    final first = days.isEmpty || days.last.compareTo(addDays(today, -365)) > 0 ? addDays(today, -365) : days.last;
    void open(String day) => Navigator.of(context).pop(day);

    final l = context.l10n;
    String summary(String day) {
      final d = intakeDay(day, IntakeMetric.calories, today: today, food: f, water: w);
      return [
        if (d.foods > 0) l.trendsFoodCount(d.foods),
        if (d.foods > 0) !d.hasValue ? l.trendsCaloriesUnknownLower : d.state == DayState.partial ? l.eatKcalKnown(formatKcal(d.value!)) : l.eatKcalValue(formatKcal(d.value!)),
        if (d.waterEntries > 0) l.eatWaterValue(unit.format(waterTotal([for (final r in w[day]!) r.value]))),
      ].join(' · ');
    }

    final c = context.c;
    return AppPage(
      title: l.trendsCalendar,
      subtitle: l.trendsCalendarSubtitle,
      children: [
        Text(l.trendsCalendarCaption, style: context.caption),
        // Material's month grid in the app's language: its first weekday and, in Arabic, right-to-left order follow
        // the locale; each date stays in its own cell, and a tap returns that day's key.
        CalendarDatePicker(
          key: const Key('history-calendar'),
          initialDate: parseDayKey(selected), firstDate: parseDayKey(first), lastDate: parseDayKey(today), currentDate: parseDayKey(today),
          onDateChanged: (d) => open(dayKeyOf(d)),
        ),
        const SizedBox(height: 8),
        Text(l.trendsDaysWithEntries, style: context.label),
        const SizedBox(height: 8),
        if (food.hasError) StatusLine(Icons.error_outline, l.trendsFoodReadError, tone: Tone.error),
        if (!loaded && !food.hasError)
          StatusLine(Icons.hourglass_empty, l.trendsReading)
        else if (loaded && days.isEmpty)
          EmptyState(l.foodRecentEmptyTitle, l.trendsNothingYetBody)
        else
          // One list item per day, so a long history is laid out only as it scrolls into view.
          for (final (i, day) in days.indexed)
            Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: c.divider),
                borderRadius: BorderRadius.vertical(top: Radius.circular(i == 0 ? Radii.panel : 0), bottom: Radius.circular(i == days.length - 1 ? Radii.panel : 0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: GroupRow(
                key: Key('history-day-$day'), leading: const GoIcon(GoGlyph.history),
                title: day == today ? l.eatTodayCaption : longDate(day), subtitle: summary(day),
                onTap: () => open(day),
              ),
            ),
      ],
    );
  }
}
