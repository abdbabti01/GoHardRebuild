import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/compatibility.dart';
import '../../core/device_prefs.dart' show Haptics;
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../coach/coach_bubble.dart';
import '../progress/trend_screens.dart' show PointChart, timeOf;
import '../progress/trends.dart' show TrendRange;
import 'body_metrics.dart';
import 'body_prefs.dart';
import 'body_repository.dart';

/// Body progress (docs/BODY_PROGRESS.md): Me › Body progress, with a quiet way in from Train › Progress. Three
/// connected views over the account's own check-ins: the overview, Log measurements, Compare dates. Looking never
/// writes; only Save, Delete and a unit or field choice change anything.

/// "4 weeks", "12 weeks", "All".
String _rangeLabel(AppLocalizations l, TrendRange r) => l.bodyRangeLabel(r.name);

/// "in the last 4 weeks", "in all your history".
String _rangeWords(AppLocalizations l, TrendRange r) => l.bodyRangeWords(r.name);

String _inputText(AppLocalizations l, BodyInputError e) => switch (e.problem) {
      BodyInputProblem.nothingEntered => l.bodyErrorNothingEntered,
      BodyInputProblem.outOfRange => l.bodyErrorFieldOutOfRange(bodyFieldLabel(l, e.field!)),
      BodyInputProblem.noteTooLong => l.bodyErrorNoteTooLong,
      BodyInputProblem.measurementsNeedServer => l.bodyErrorMeasurementsNeedServer,
      BodyInputProblem.needsOneMeasurement => l.bodyErrorNeedsOneMeasurement,
      BodyInputProblem.correctionNeedsServer => l.bodyErrorCorrectionNeedsServer,
    };

/// What the page knows about this account's check-ins: every one not deleted (history shows them all) and the trusted
/// ones (not awaiting review) that feed latest values, averages, charts and comparisons.
class _Records {
  _Records(List<Stored<BodyMetric>> rows)
      : all = [for (final r in rows) if (!r.value.isDeleted) r]..sort((a, b) => compareCheckIns(b.value, a.value)),
        trusted = [for (final r in rows) if (!r.value.isDeleted && !r.needsReview && hasMeasurement(r.value)) r.value];
  final List<Stored<BodyMetric>> all;
  final List<BodyMetric> trusted;
}

/// Loading, unreadable and loaded are three different pages; only loaded draws anything from records.
Widget _guard(BuildContext context, WidgetRef ref, String title, Widget Function(_Records r) build) {
  final rows = ref.watch(metricsProvider);
  if (rows.hasError) {
    return AppPage(title: title, children: [EmptyState(context.l10n.bodyReadErrorTitle, context.l10n.bodyReadErrorBody)]);
  }
  if (!rows.hasValue) return const Scaffold(body: Center(child: CircularProgressIndicator()));
  return build(_Records(rows.value!));
}

/// "Saved on this phone · waiting to sync" or "Needs review", in the app's existing words; nothing for a synced one.
String? _syncWords(AppLocalizations l, Stored<BodyMetric> r) => r.needsReview ? l.bodySyncNeedsReview : r.isPending ? l.bodySyncWaiting : null;

/// "Waist 35.5 in · Body fat 21.5 %", every value a check-in holds.
String _summary(AppLocalizations l, BodyMetric m, BodyUnits units) =>
    [for (final f in BodyField.values) if (has(m, f)) l.bodyFieldValue(bodyFieldLabel(l, f), units.value(f, m.value(f.key)))].join(' · ');

/// Opens a check-in for correction, or, on a day with several, a list to choose from.
Future<void> _openDay(BuildContext context, List<BodyMetric> checkIns, String day) async {
  final onDay = [for (final m in checkIns) if (m.dayKey == day) m]..sort(compareCheckIns);
  if (onDay.length == 1) {
    await push(context, CheckInScreen(existing: onDay.single));
    return;
  }
  await showGoSheet<void>(context, title: longDate(day), builder: (sheet) => _DayList(onDay: onDay));
}

class _DayList extends ConsumerWidget {
  const _DayList({required this.onDay});
  final List<BodyMetric> onDay;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(bodyUnitsProvider);
    final known = orderKnown(onDay);
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(known ? l.bodyDayEntriesKnown(onDay.length) : l.bodyDayEntriesUnknown(onDay.length), style: context.caption),
      const SizedBox(height: 10),
      GroupCard(children: [
        for (final (i, m) in onDay.indexed)
          GroupRow(
            key: Key('body-day-entry-${m.id}'), title: known && m.recordedAtUtc != null ? l.bodySavedAt(timeOf(m.recordedAtUtc!)) : l.bodyEntryNumber(i + 1),
            subtitle: _summary(l, m, units),
            onTap: () {
              Navigator.pop(context);
              push(context, CheckInScreen(existing: m));
            },
          ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------- overview

class BodyProgressScreen extends ConsumerStatefulWidget {
  const BodyProgressScreen({super.key});
  @override
  ConsumerState<BodyProgressScreen> createState() => _BodyProgressScreenState();
}

class _BodyProgressScreenState extends ConsumerState<BodyProgressScreen> {
  // Kept while a history, chart or form is open over this page, so coming back shows the same range.
  TrendRange _range = TrendRange.weeks4;

  @override
  Widget build(BuildContext context) => _guard(context, ref, context.l10n.bodyTitle, (r) {
        final units = ref.watch(bodyUnitsProvider);
        final today = ref.watch(todayKeyProvider);
        final pending = r.all.where((x) => x.isPending).length;
        final caps = ref.watch(compatibilityProvider).capabilities;
        final l = context.l10n;
        return AppPage(
          title: l.bodyTitle, subtitle: longDate(today),
          actions: [CoachHelpEntry(id: 'me.body', label: l.bodyHelp)],
          children: [
            CoachSpot(
              id: 'me.body', introduce: true, padding: const EdgeInsets.only(bottom: 16),
              say: CoachSay(l.bodyCoachSay,
                  guide: (label: l.bodyHowToMeasure, key: const Key('body-how'), onPressed: () => push(context, const HowToMeasureScreen()))),
            ),
            if (r.all.isEmpty)
              EmptyState(l.bodyEmptyTitle, l.bodyEmptyBody,
                  action: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    PrimaryButton(l.bodyLogMeasurements, key: const Key('body-log'), onPressed: () => push(context, const CheckInScreen())),
                    QuietLink(l.bodyHowToMeasure, key: const Key('body-how-empty'), onPressed: () => push(context, const HowToMeasureScreen())),
                  ]))
            else ...[
              _WeightPanel(checkIns: r.trusted, today: today, units: units),
              if (pending > 0) ...[
                const SizedBox(height: 10),
                StatusLine(Icons.phone_iphone, caps != null && !caps.contains(BodyRepository.capability)
                    ? l.bodyPendingOldServer(pending)
                    : l.bodyPendingWaiting(pending), key: const Key('body-pending')),
              ],
              const SizedBox(height: 22),
              _ChartSection(field: BodyField.weight, checkIns: r.trusted, range: _range, today: today, units: units,
                  onRange: (x) => setState(() => _range = x), seeAll: () => push(context, MetricScreen(field: BodyField.weight, range: _range))),
              const SizedBox(height: 16),
              _Actions(onLog: () => push(context, const CheckInScreen()), onCompare: () => push(context, const CompareScreen())),
              const SizedBox(height: 24),
              _LatestList(checkIns: r.trusted, units: units, range: _range),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: QuietLink(l.bodyAllMeasurements, key: const Key('body-all'), onPressed: () => push(context, const BodyHistoryScreen())),
              ),
            ],
          ],
        );
      });
}

/// The pale accent panel: the latest weight with its real date, and the 7-day average with the days behind it.
class _WeightPanel extends StatelessWidget {
  const _WeightPanel({required this.checkIns, required this.today, required this.units});
  final List<BodyMetric> checkIns;
  final String today;
  final BodyUnits units;

  @override
  Widget build(BuildContext context) {
    final latest = latestOf(checkIns, BodyField.weight);
    final week = sevenDayWeight(checkIns, today);
    return PhotoPanel(
      key: const Key('body-weight-panel'),
      content: (context) {
        final c = context.c;
        final l = context.l10n;
        return [
          Overline(l.bodyLatestWeight),
          if (latest == null) ...[
            Text(l.bodyNotRecorded, key: const Key('body-latest-weight'), style: context.pageTitleStyle(32)),
            Text(l.bodyOtherBelow, style: context.sansStyle(15, color: c.secondary)),
          ] else ...[
            Text(units.value(BodyField.weight, latest.value), key: const Key('body-latest-weight'), style: context.pageTitleStyle(44)),
            Text(latest.averaged ? l.bodyAverageOfEntries(latest.count, dayMonth(latest.dayKey)) : l.bodyRecordedOn(dayMonth(latest.dayKey)),
                key: const Key('body-latest-date'), style: context.sansStyle(15, color: c.secondary)),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 12),
          Wrap(spacing: 24, runSpacing: 8, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(l.bodySevenDayAverage, style: context.sansStyle(15, color: c.secondary)),
              Text(week == null ? l.bodyNotAvailable : units.value(BodyField.weight, week.kg), key: const Key('body-average'), style: context.pageTitleStyle(26)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(week == null ? l.bodyNoWeightSevenDays : l.bodyRecordedDaysOfSeven(week.days), key: const Key('body-average-days'), style: context.sansStyle(15, weight: FontWeight.w600)),
              Text(l.bodyDateRange(dayMonth(addDays(today, -6)), dayMonth(today)), style: context.sansStyle(15, color: c.secondary)),
            ]),
          ]),
        ];
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onLog, required this.onCompare});
  final VoidCallback onLog, onCompare;
  @override
  Widget build(BuildContext context) {
    final log = PrimaryButton(context.l10n.bodyLog, key: const Key('body-log'), icon: Icons.add, onPressed: onLog);
    final compare = SecondaryButton(context.l10n.bodyCompareDates, key: const Key('body-compare'), icon: Icons.date_range_outlined, onPressed: onCompare);
    // Side by side while the words fit; one under the other at large text.
    if (MediaQuery.textScalerOf(context).scale(10) > 13) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [log, const SizedBox(height: 10), compare]);
    return Row(children: [Expanded(child: log), const SizedBox(width: 12), Expanded(child: compare)]);
  }
}

/// A metric over time: the range, the chart of every reading in it, and what the line means.
class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.field, required this.checkIns, required this.range, required this.today, required this.units, required this.onRange, this.seeAll});
  final BodyField field;
  final List<BodyMetric> checkIns;
  final TrendRange range;
  final String today;
  final BodyUnits units;
  final ValueChanged<TrendRange> onRange;
  final VoidCallback? seeAll;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pts = seriesOf(checkIns, field, range, today);
    final means = dailyMeans(pts);
    final everRecorded = checkIns.any((m) => has(m, field));
    final name = bodyFieldLabel(l, field);
    final rangeWords = _rangeWords(l, range);
    final severalADay = means.length < pts.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: SectionHeader(l.bodyOverTime(name))),
        if (seeAll != null && everRecorded) QuietLink(l.bodySeeAll, key: Key('body-see-${field.name}'), onPressed: seeAll),
      ]),
      const SizedBox(height: 10),
      Segmented<TrendRange>(values: TrendRange.values, selected: range, keyPrefix: 'body-range', label: (r) => _rangeLabel(l, r), onChanged: onRange),
      const SizedBox(height: 12),
      Panel(
        key: Key('body-chart-${field.name}'),
        child: !everRecorded
            ? Text(field == BodyField.weight ? l.bodyChartNoWeight : l.bodyChartNone(name.toLowerCase()), key: const Key('body-chart-none'), style: context.caption)
            : pts.isEmpty
                ? Text(l.bodyChartEmptyInRange(name.toLowerCase(), rangeWords), key: const Key('body-chart-empty'), style: context.caption)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(severalADay ? l.bodyChartLegendDaily : l.bodyChartLegendPoints, style: context.caption),
                    const SizedBox(height: 8),
                    // Time runs left to right in every language; only the words around the chart follow the page.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: PointChart<BodyPoint>(
                        points: pts, value: (p) => units.toDisplay(field, p.value), at: (p) => parseDayKey(p.dayKey), dayKey: (p) => p.dayKey,
                        line: severalADay ? [for (final (d, v) in means) (parseDayKey(d), units.toDisplay(field, v))] : null,
                        axisLabel: (v) => withUnit(localDecimal(bodyNumber(v)), units.label(field)),
                        onPoint: (p) => _openDay(context, checkIns, p.dayKey),
                        semanticsLabel: l.bodyChartSemantics(name, rangeWords, pts.length, pts.map((p) => l.bodyReading(dayMonth(p.dayKey), units.value(field, p.value))).join('; ')),
                      ),
                    ),
                    if (means.length == 1)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.bodyOneDayInRange(rangeWords), key: const Key('body-one-point'), style: context.caption))
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l.bodyRangeChange(units.change(field, means.first.$2, means.last.$2)), key: const Key('body-range-change'), style: context.caption),
                      ),
                  ]),
      ),
    ]);
  }
}

/// Every metric except weight (the panel has it), each with its own latest day.
class _LatestList extends StatelessWidget {
  const _LatestList({required this.checkIns, required this.units, required this.range});
  final List<BodyMetric> checkIns;
  final BodyUnits units;
  final TrendRange range;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = [
      for (final f in BodyField.values)
        if (f != BodyField.weight)
          if (latestOf(checkIns, f) case final l?) (f, l),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l.bodyLatestMeasurements),
      const SizedBox(height: 10),
      if (rows.isEmpty)
        Text(l.bodyLatestNone, key: const Key('body-latest-none'), style: context.caption)
      else
        GroupCard(children: [
          for (final (f, latest) in rows)
            GroupRow(
              key: Key('body-latest-${f.name}'), title: bodyFieldLabel(l, f), value: units.value(f, latest.value),
              subtitle: latest.averaged ? l.bodyAverageOfEntries(latest.count, dayMonth(latest.dayKey)) : dayMonth(latest.dayKey),
              onTap: () => push(context, MetricScreen(field: f, range: range)),
            ),
        ]),
    ]);
  }
}

// ---------------------------------------------------------------------------- one metric, all entries

/// One metric over time: its chart and every reading in the range, each opening its check-in.
class MetricScreen extends ConsumerStatefulWidget {
  const MetricScreen({super.key, required this.field, this.range = TrendRange.weeks4});
  final BodyField field;
  final TrendRange range;
  @override
  ConsumerState<MetricScreen> createState() => _MetricScreenState();
}

class _MetricScreenState extends ConsumerState<MetricScreen> {
  late TrendRange _range = widget.range;

  @override
  Widget build(BuildContext context) => _guard(context, ref, bodyFieldLabel(context.l10n, widget.field), (r) {
        final units = ref.watch(bodyUnitsProvider);
        final today = ref.watch(todayKeyProvider);
        final f = widget.field;
        final l = context.l10n;
        final pts = seriesOf(r.trusted, f, _range, today);
        return AppPage(title: bodyFieldLabel(l, f), subtitle: f.dimension == BodyDimension.percent ? l.bodyMetricFatSubtitle : l.bodyMetricUnitSubtitle(units.label(f)), children: [
          _ChartSection(field: f, checkIns: r.trusted, range: _range, today: today, units: units, onRange: (x) => setState(() => _range = x)),
          if (pts.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(l.bodyEntriesInRange),
            const SizedBox(height: 10),
            GroupCard(children: [
              for (final p in pts.reversed)
                GroupRow(key: Key('body-metric-row-${p.checkIn.id}'), title: shortDate(p.dayKey), value: units.value(f, p.value), onTap: () => push(context, CheckInScreen(existing: p.checkIn))),
            ]),
          ],
        ]);
      });
}

/// Every check-in, newest first, with all its values, body fat and note; each opens for correction or removal.
class BodyHistoryScreen extends ConsumerWidget {
  const BodyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _guard(context, ref, context.l10n.bodyAllMeasurements, (r) {
        final units = ref.watch(bodyUnitsProvider);
        final l = context.l10n;
        final perDay = <String, List<BodyMetric>>{};
        for (final x in r.all) {
          (perDay[x.value.dayKey] ??= []).add(x.value);
        }
        return AppPage(title: l.bodyAllMeasurements, subtitle: l.bodyHistorySubtitle, children: [
          if (r.all.isEmpty)
            EmptyState(l.bodyEmptyTitle, l.bodyHistoryEmptyBody, action: PrimaryButton(l.bodyLogMeasurements, onPressed: () => push(context, const CheckInScreen())))
          else
            GroupCard(children: [
              for (final x in r.all)
                GroupRow(
                  key: Key('body-history-${x.value.id}'),
                  title: _summary(l, x.value, units).isEmpty ? l.bodyNoMeasurement : _summary(l, x.value, units),
                  subtitle: [
                    shortDate(x.value.dayKey),
                    if (perDay[x.value.dayKey]!.length > 1)
                      orderKnown(perDay[x.value.dayKey]!) && x.value.recordedAtUtc != null ? l.bodySavedAtLower(timeOf(x.value.recordedAtUtc!)) : l.bodyOneOfEntriesLower(perDay[x.value.dayKey]!.length),
                    if (x.value.note != null) l.bodyQuotedNote(x.value.note!),
                    ?_syncWords(l, x),
                  ].join(' · '),
                  onTap: () => push(context, CheckInScreen(existing: x.value)),
                ),
            ]),
        ]);
      });
}

// ---------------------------------------------------------------------------- log / correct

/// Log measurements, or correct a saved check-in ([existing]). Every field is optional; at least one number is needed.
/// Save is explicit, Back with changes asks, and a rejected save keeps every character typed.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, this.existing});
  final BodyMetric? existing;
  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

/// Digits in any of the app's languages and one decimal mark; [readField] rejects anything else that gets through.
final _numberChars = FilteringTextInputFormatter.allow(RegExp('[0-9.,٠-٩۰-۹٫]'));

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  BodyMetric? get _old => widget.existing;
  // One ID per form: however often Save is pressed, one check-in and one command.
  late final String _id = _old?.id ?? SyncEngine.newId();
  late String _day = _old?.dayKey ?? ref.read(todayKeyProvider);
  late BodyUnits _units = ref.read(bodyUnitsProvider);
  final _text = {for (final f in BodyField.values) f: TextEditingController()};
  late final _anchors = <BodyField, FieldAnchor?>{
    for (final f in BodyField.values)
      f: _old?.value(f.key) == null ? null : FieldAnchor(_units.number(f, _old!.value(f.key)!), _old!.value(f.key)!),
  };
  late final _note = TextEditingController(text: _old?.note ?? '');
  final _errors = <BodyField, BodyFieldError>{};
  // Kept as words to be said, so a language change rewords the message instead of leaving it in the old language.
  String Function(AppLocalizations l)? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final f in BodyField.values) {
      _text[f]!.text = _anchors[f]?.text ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  /// The fields this form shows: the account's choice on this phone, plus every value the check-in already holds.
  Set<BodyField> _shown(BodyPrefs p) => {...p.shown ?? BodyPrefs.defaultShown, if (_old != null) ...BodyField.values.where((f) => has(_old!, f))};
  bool _noteShown(BodyPrefs p) => p.note || (_old?.note != null);

  bool get _dirty {
    if (_day != (_old?.dayKey ?? ref.read(todayKeyProvider)) || _note.text.trim() != (_old?.note ?? '')) return true;
    for (final f in BodyField.values) {
      final r = readField(f, _text[f]!.text, _anchors[f], _units, checkRange: false);
      if (r.error != null || r.value != _old?.value(f.key)) return true;
    }
    return false;
  }

  void _switchUnits(BodyUnits next) {
    final converted = convertFields({for (final f in BodyField.values) f: _text[f]!.text}, _anchors, _units, next);
    if (converted == null) {
      setState(() => _error = (l) => l.bodyConvertBlocked);
      return;
    }
    setState(() {
      for (final f in BodyField.values) {
        _anchors[f] = converted[f];
        _text[f]!.text = converted[f]?.text ?? '';
      }
      _units = next;
      _error = null;
      _errors.clear();
    });
    setBodyUnits(ref, next);
  }

  Future<void> _pickDay() async {
    final today = parseDayKey(ref.read(todayKeyProvider));
    final picked = await showDatePicker(
      context: context, initialDate: parseDayKey(_day), firstDate: DateTime.utc(2000), lastDate: today,
      helpText: context.l10n.bodyDateMeasured,
    );
    if (picked != null) setState(() => _day = dayKeyOf(picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    final prefs = ref.read(bodyPrefsProvider);
    final shown = _shown(prefs);
    final values = <BodyField, double?>{};
    _errors.clear();
    for (final f in shown) {
      final r = readField(f, _text[f]!.text, _anchors[f], _units);
      if (r.error != null) _errors[f] = r.error!;
      values[f] = r.value;
    }
    if (_day.compareTo(ref.read(todayKeyProvider)) > 0) _error = (l) => l.bodyFutureDate;
    if (_errors.isNotEmpty || _day.compareTo(ref.read(todayKeyProvider)) > 0) {
      setState(() => _error ??= (l) => l.bodyCheckFields);
      return;
    }
    final caps = ref.read(compatibilityProvider).capabilities;
    final supported = caps == null || caps.contains(BodyRepository.capability);
    final repo = ref.read(bodyRepositoryProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_old == null) {
        await repo.create(_id, _day, values, note: _noteShown(prefs) ? _note.text : null, nowUtc: ref.read(clockProvider).utcNow(), measurementsServer: supported);
      } else {
        if (!supported) throw const BodyInputError(BodyInputProblem.correctionNeedsServer);
        final changes = {for (final f in shown) if (values[f] != _old!.value(f.key)) f: values[f]};
        final noteChanged = _noteShown(prefs) && _note.text.trim() != (_old!.note ?? '');
        if (changes.isEmpty && !noteChanged && _day == _old!.dayKey) {
          if (mounted) Navigator.pop(context);
          return;
        }
        await repo.update(_old!, _day, changes, noteChanged: noteChanged, note: _note.text);
      }
      Haptics.confirm();
      if (!mounted) return;
      toast(context, context.l10n.bodySavedToast);
      Navigator.pop(context);
    } on BodyInputError catch (e) {
      setState(() => _error = (l) => _inputText(l, e));
    } on LocalSaveFailure {
      setState(() => _error = (l) => l.bodySaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final m = _old!;
    final l = context.l10n;
    if (!await confirm(context, title: l.bodyDeleteConfirmTitle, body: l.bodyDeleteConfirmBody(longDate(m.dayKey)), action: l.actionDelete, destructive: true)) return;
    try {
      await ref.read(bodyRepositoryProvider).delete(m);
      if (mounted) Navigator.pop(context);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = (l) => l.bodyDeleteFailed);
    }
  }

  void _chooseFields() => showGoSheet<void>(context, title: context.l10n.bodyChooseMeasurements, builder: (sheet) => Consumer(builder: (context, ref, _) {
        final prefs = ref.watch(bodyPrefsProvider);
        final shown = prefs.shown ?? BodyPrefs.defaultShown;
        final owner = ref.read(ownerProvider);
        final l = context.l10n;
        void set(Set<BodyField> next, bool note) {
          if (owner != null) ref.read(bodyPrefsControllerProvider.notifier).update(owner, (p) => BodyPrefs(mass: p.mass, length: p.length, shown: next, note: note));
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.bodyChooseExplanation, style: context.caption),
          const SizedBox(height: 8),
          for (final f in BodyField.values)
            CheckboxListTile(
              key: Key('body-choose-${f.name}'), value: shown.contains(f), title: Text(bodyFieldLabel(l, f)), contentPadding: EdgeInsets.zero,
              onChanged: (on) => set(on! ? {...shown, f} : ({...shown}..remove(f)), prefs.note),
            ),
          CheckboxListTile(key: const Key('body-choose-note'), value: prefs.note, title: Text(l.bodyNote), contentPadding: EdgeInsets.zero, onChanged: (on) => set(shown, on!)),
        ]);
      }));

  Widget _field(BodyField f, {bool large = false}) => TextField(
        key: Key('body-field-${f.name}'), controller: _text[f],
        keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next,
        inputFormatters: [_numberChars],
        style: large ? context.pageTitleStyle(30) : context.numStyle(20),
        onChanged: (_) => setState(() {
          _errors.remove(f);
          _error = null;
        }),
        decoration: InputDecoration(labelText: bodyFieldLabel(context.l10n, f), suffixText: _units.label(f),
            errorText: _errors[f] == null ? null : bodyFieldErrorText(context.l10n, f, _errors[f]!), errorMaxLines: 3),
      );

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(bodyPrefsProvider);
    final shown = _shown(prefs);
    final lengths = [for (final f in BodyField.values) if (f.dimension == BodyDimension.length && shown.contains(f)) f];
    final wide = MediaQuery.sizeOf(context).width >= 360 && MediaQuery.textScalerOf(context).scale(10) <= 13;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final l = context.l10n;
    return PopScope(
      canPop: _saving || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirm(context, title: l.bodyDiscardTitle, body: l.bodyDiscardBody, action: l.bodyDiscard, cancel: l.bodyKeepEditing);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: AppPage(
        title: _old == null ? l.bodyLogMeasurements : l.bodyEditEntry,
        subtitle: l.bodyEveryOptional,
        actions: [IconButton(tooltip: l.bodyHowToMeasure, icon: const Icon(Icons.help_outline), onPressed: () => push(context, const HowToMeasureScreen()))],
        bottom: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // iOS number pads have no return key: this closes the keyboard.
          if (keyboard) Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(key: const Key('body-done-typing'), onPressed: () => FocusScope.of(context).unfocus(), child: Text(l.bodyDoneTyping))),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!(l), tone: Tone.error, key: const Key('body-error'))),
          PrimaryButton(_old == null ? l.bodySaveMeasurements : l.bodySaveChanges, key: const Key('body-save'), busy: _saving, onPressed: _save),
        ]),
        children: [
          GroupCard(children: [
            GroupRow(key: const Key('body-date'), icon: Icons.event_outlined, title: longDate(_day), subtitle: l.bodyDateMeasured, onTap: _pickDay),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _UnitChoice<LoadUnit>(label: l.bodyUnitWeight, keyPrefix: 'body-mass', values: LoadUnit.values, selected: _units.mass, name: (u) => u.label, onChanged: (u) => _switchUnits(BodyUnits(u, _units.length))),
            _UnitChoice<LengthUnit>(label: l.bodyUnitLength, keyPrefix: 'body-length', values: LengthUnit.values, selected: _units.length, name: (u) => u.label, onChanged: (u) => _switchUnits(BodyUnits(_units.mass, u))),
          ]),
          const SizedBox(height: 16),
          if (shown.contains(BodyField.weight)) ...[
            PanelTheme(child: Builder(builder: (context) => PanelSurface(child: _field(BodyField.weight, large: true)))),
            const SizedBox(height: 14),
          ],
          if (wide)
            for (var i = 0; i < lengths.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _field(lengths[i])),
                  const SizedBox(width: 12),
                  Expanded(child: i + 1 < lengths.length ? _field(lengths[i + 1]) : const SizedBox()),
                ]),
              )
          else
            for (final f in lengths) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
          if (shown.contains(BodyField.bodyFat)) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(BodyField.bodyFat)),
          if (_noteShown(prefs))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(key: const Key('body-note'), controller: _note, maxLength: maxNoteLength, textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: l.bodyNoteOptional)),
            ),
          GroupCard(children: [
            GroupRow(key: const Key('body-choose'), icon: Icons.tune, title: l.bodyChooseMeasurements, subtitle: l.bodyChooseSubtitle, onTap: _chooseFields),
          ]),
          const SizedBox(height: 10),
          Text(l.bodyAtLeastOne, style: context.caption),
          if (_old != null) ...[
            const SizedBox(height: 20),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(key: const Key('body-delete'), onPressed: _delete, icon: Icon(Icons.delete_outline, color: context.c.error),
                  label: Text(l.bodyDeleteEntry, style: TextStyle(color: context.c.error))),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnitChoice<T> extends StatelessWidget {
  const _UnitChoice({required this.label, required this.keyPrefix, required this.values, required this.selected, required this.name, required this.onChanged});
  final String label, keyPrefix;
  final List<T> values;
  final T selected;
  final String Function(T) name;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final choice = Segmented<T>(values: values, selected: selected, keyPrefix: keyPrefix, label: name, onChanged: onChanged);
    // At large text the label goes above a full-width control (which stacks its segments itself).
    if (MediaQuery.textScalerOf(context).scale(10) > 13) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(label, style: context.sansStyle(15, weight: FontWeight.w600)), const SizedBox(height: 6), choice]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: context.sansStyle(15, weight: FontWeight.w600)),
      const SizedBox(width: 10),
      SizedBox(width: 132, child: choice),
    ]);
  }
}

// ---------------------------------------------------------------------------- compare

/// Compare two saved check-ins: real values side by side, To minus From only where both hold that exact metric.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});
  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  String? _fromId, _toId;

  Future<void> _choose(List<BodyMetric> eligible, bool from) async {
    final units = ref.read(bodyUnitsProvider);
    final current = from ? _fromId : _toId;
    final perDay = <String, List<BodyMetric>>{};
    for (final m in eligible) {
      (perDay[m.dayKey] ??= []).add(m);
    }
    final l = context.l10n;
    final picked = await showGoSheet<String>(context, title: from ? l.bodyCompareFrom : l.bodyCompareTo, builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.bodyCompareOnlySaved, style: context.caption),
          const SizedBox(height: 10),
          for (final m in [...eligible]..sort((a, b) => compareCheckIns(b, a)))
            ChoiceTile<String?>(
              key: Key('body-pick-${m.id}'), value: m.id, groupValue: current, title: dayMonthYear(m.dayKey),
              subtitle: [
                if (perDay[m.dayKey]!.length > 1)
                  orderKnown(perDay[m.dayKey]!) && m.recordedAtUtc != null ? l.bodySavedAt(timeOf(m.recordedAtUtc!)) : l.bodyOneOfEntriesDay(perDay[m.dayKey]!.length),
                _summary(l, m, units),
              ].join('\n'),
              onChanged: (id) => Navigator.pop(sheet, id),
            ),
        ]));
    if (picked != null) setState(() => from ? _fromId = picked : _toId = picked);
  }

  @override
  Widget build(BuildContext context) => _guard(context, ref, context.l10n.bodyCompareDates, (r) {
        final units = ref.watch(bodyUnitsProvider);
        final l = context.l10n;
        final eligible = r.trusted;
        final days = {for (final m in eligible) m.dayKey};
        BodyMetric? byId(String? id) => id == null ? null : eligible.where((m) => m.id == id).firstOrNull;
        final defaults = defaultPair(eligible);
        // A chosen entry that was deleted or is awaiting review falls back to the default, and the page says so.
        final lostFrom = _fromId != null && byId(_fromId) == null, lostTo = _toId != null && byId(_toId) == null;
        final from = byId(_fromId) ?? defaults.$1, to = byId(_toId) ?? defaults.$2;
        return AppPage(
          title: l.bodyCompareDates, subtitle: l.bodyCompareSubtitle,
          actions: [CoachHelpEntry(id: 'me.body.compare', label: l.bodyCompareHelp)],
          children: [
            CoachSpot(id: 'me.body.compare', padding: const EdgeInsets.only(bottom: 16), say: CoachSay(l.bodyCompareCoachSay)),
            if (days.length < 2)
              EmptyState(l.bodyTwoDatesTitle, days.isEmpty ? l.bodyTwoDatesNone : l.bodyTwoDatesOne(dayMonth(days.single)),
                  action: PrimaryButton(l.bodyLogMeasurements, key: const Key('body-compare-log'), onPressed: () => push(context, const CheckInScreen())))
            else ...[
              if (lostFrom || lostTo)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.info_outline, l.bodyCompareLost, key: const Key('body-compare-lost'))),
              _Pickers(
                from: from, to: to,
                onFrom: () => _choose(eligible, true), onTo: () => _choose(eligible, false),
              ),
              const SizedBox(height: 6),
              Align(alignment: AlignmentDirectional.centerEnd, child: Text('${units.mass.label} · ${units.length.label}', style: context.caption)),
              const SizedBox(height: 10),
              if (from == null || to == null)
                StatusLine(Icons.touch_app_outlined, l.bodyCompareChoose, key: const Key('body-compare-choose'))
              else if (from.id == to.id)
                StatusLine(Icons.info_outline, l.bodyCompareSame)
              else
                _Comparison(from: from, to: to, units: units),
            ],
          ],
        );
      });
}

class _Pickers extends StatelessWidget {
  const _Pickers({required this.from, required this.to, required this.onFrom, required this.onTo});
  final BodyMetric? from, to;
  final VoidCallback onFrom, onTo;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget pick(String label, BodyMetric? m, VoidCallback onTap, String key) => Expanded(
          child: GroupCard(children: [
            GroupRow(key: Key(key), icon: Icons.event_outlined, title: m == null ? l.bodyChoose : dayMonthYear(m.dayKey), subtitle: label, onTap: onTap),
          ]),
        );
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 360;
    final a = pick(l.bodyFrom, from, onFrom, 'body-compare-from'), b = pick(l.bodyTo, to, onTo, 'body-compare-to');
    if (stacked) return Column(children: [Row(children: [a]), const SizedBox(height: 10), Row(children: [b])]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [a, const SizedBox(width: 10), b]);
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.from, required this.to, required this.units});
  final BodyMetric from, to;
  final BodyUnits units;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = compareCheckInsRows(from, to);
    final weight = rows.where((x) => x.field == BodyField.weight).firstOrNull;
    final others = [for (final x in rows) if (x.field != BodyField.weight) x];
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 360;
    String cell(double? v, BodyField f) => v == null ? '—' : units.value(f, v);
    String said(double? v, BodyField f) => v == null ? l.bodyNotRecordedLower : units.value(f, v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (weight != null)
        PhotoPanel(
          key: const Key('body-compare-weight'),
          content: (context) => [
            Overline(bodyFieldLabel(l, BodyField.weight)),
            const SizedBox(height: 6),
            Wrap(spacing: 24, runSpacing: 8, children: [
              for (final (day, v) in [(from.dayKey, weight.from), (to.dayKey, weight.to)])
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(dayMonth(day), style: context.sansStyle(15, color: context.c.secondary)),
                  Text(cell(v, BodyField.weight), style: context.pageTitleStyle(30)),
                  if (v == null) Text(l.bodyNotRecorded, style: context.caption),
                ]),
            ]),
            const SizedBox(height: 10),
            Text(weight.hasChange ? l.bodyCompareWeightChange(units.change(BodyField.weight, weight.from!, weight.to!)) : l.bodyCompareWeightNoChange,
                key: const Key('body-compare-weight-change'), style: context.sansStyle(17, weight: FontWeight.w600)),
          ],
        ),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 20),
        SectionHeader(l.bodyMeasurements),
        const SizedBox(height: 10),
        GroupCard(children: [
          if (!stacked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Expanded(flex: 4, child: SizedBox()),
                for (final h in [dayMonth(from.dayKey), dayMonth(to.dayKey), l.bodyChange]) Expanded(flex: 3, child: Text(h, style: context.label)),
              ]),
            ),
          for (final x in others)
            MergeSemantics(
              key: Key('body-compare-${x.field.name}'),
              child: Semantics(
                label: l.bodyCompareRowSemantics(bodyFieldLabel(l, x.field), dayMonth(from.dayKey), said(x.from, x.field), dayMonth(to.dayKey), said(x.to, x.field),
                    x.hasChange ? units.change(x.field, x.from!, x.to!) : l.bodyNotAvailableLower),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: stacked
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(bodyFieldLabel(l, x.field), style: context.sansStyle(16, weight: FontWeight.w600)),
                            Text(l.bodyDatedValue(dayMonth(from.dayKey), x.from == null ? l.bodyDashNotRecorded : cell(x.from, x.field)), style: context.body),
                            Text(l.bodyDatedValue(dayMonth(to.dayKey), x.to == null ? l.bodyDashNotRecorded : cell(x.to, x.field)), style: context.body),
                            Text(l.bodyChangeValue(x.hasChange ? units.change(x.field, x.from!, x.to!) : '—'), style: context.body),
                          ])
                        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(flex: 4, child: Text(bodyFieldLabel(l, x.field), style: context.sansStyle(15.5, weight: FontWeight.w600))),
                            for (final v in [x.from, x.to])
                              Expanded(
                                flex: 3,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(cell(v, x.field), style: context.numStyle(15)),
                                  if (v == null) Text(l.bodyNotRecorded, style: context.caption),
                                ]),
                              ),
                            Expanded(flex: 3, child: Text(x.hasChange ? units.change(x.field, x.from!, x.to!) : '—', style: context.numStyle(15))),
                          ]),
                  ),
                ),
              ),
            ),
        ]),
        if (others.any((x) => x.field == BodyField.bodyFat && x.hasChange))
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.bodyFatPointsNote, style: context.caption)),
      ],
      const SizedBox(height: 12),
      Text(l.bodyRecordedOnly, style: context.caption),
    ]);
  }
}

// ---------------------------------------------------------------------------- how to measure

/// Built-in guidance, nothing generated. The landmarks are from the CDC's NHANES procedures, cited on the page.
class HowToMeasureScreen extends StatelessWidget {
  const HowToMeasureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget part(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(title, style: context.sansStyle(17, weight: FontWeight.w600))),
            const SizedBox(height: 4),
            Text(body, style: context.body),
          ]),
        );
    return AppPage(title: l.bodyHowToMeasure, subtitle: l.bodyHowSubtitle, children: [
      part(l.bodyHowTapeTitle, l.bodyHowTapeBody),
      part(l.bodyFieldWaist, l.bodyHowWaistBody),
      part(l.bodyHowArmTitle, l.bodyHowArmBody),
      part(l.bodyHowChestThighsTitle, l.bodyHowChestThighsBody),
      part(l.bodyHowWeightFatTitle, l.bodyHowWeightFatBody),
      const SizedBox(height: 4),
      Text(l.bodyHowSource, key: const Key('body-how-source'), style: context.caption),
      const SizedBox(height: 8),
      Text(l.bodyHowNotAdvice, style: context.caption),
    ]);
  }
}
