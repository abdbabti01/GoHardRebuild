import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/compatibility.dart';
import '../../core/device_prefs.dart' show Haptics;
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../coach/coach_bubble.dart';
import '../progress/progress_view.dart' show plural;
import '../progress/trend_screens.dart' show PointChart, timeOf;
import '../progress/trends.dart' show TrendRange;
import 'body_metrics.dart';
import 'body_prefs.dart';
import 'body_repository.dart';

/// Body progress (docs/BODY_PROGRESS.md): Me › Body progress, with a quiet way in from Train › Progress. Three
/// connected views over the account's own check-ins: the overview, Log measurements, Compare dates. Looking never
/// writes; only Save, Delete and a unit or field choice change anything.

/// "Oct 5, 2026"
String _dateYear(String day) => '${dayMonth(day)}, ${parseDayKey(day).year}';

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
    return AppPage(title: title, children: const [EmptyState('This could not be read', 'Your measurements on this phone could not be read just now. Nothing was changed; try again.')]);
  }
  if (!rows.hasValue) return const Scaffold(body: Center(child: CircularProgressIndicator()));
  return build(_Records(rows.value!));
}

/// "Saved on this phone · waiting to sync" or "Needs review", in the app's existing words; nothing for a synced one.
String? _syncWords(Stored<BodyMetric> r) => r.needsReview ? 'Needs review in Me › Sync status' : r.isPending ? 'Saved on this phone · waiting to sync' : null;

/// "Waist 35.5 in · Body fat 21.5 %", every value a check-in holds.
String _summary(BodyMetric m, BodyUnits units) => [for (final f in BodyField.values) if (has(m, f)) '${f.label} ${units.value(f, m.value(f.key))}'].join(' · ');

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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(known ? '${onDay.length} entries this day, in the order they were saved.' : '${onDay.length} entries this day. The order they were taken in is not known.', style: context.caption),
      const SizedBox(height: 10),
      GroupCard(children: [
        for (final (i, m) in onDay.indexed)
          GroupRow(
            key: Key('body-day-entry-${m.id}'), title: known && m.recordedAtUtc != null ? 'Saved at ${timeOf(m.recordedAtUtc!)}' : 'Entry ${i + 1}',
            subtitle: _summary(m, units),
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
  Widget build(BuildContext context) => _guard(context, ref, 'Body progress', (r) {
        final units = ref.watch(bodyUnitsProvider);
        final today = ref.watch(todayKeyProvider);
        final pending = r.all.where((x) => x.isPending).length;
        final caps = ref.watch(compatibilityProvider).capabilities;
        return AppPage(
          title: 'Body progress', subtitle: longDate(today),
          actions: const [CoachHelpEntry(id: 'me.body', label: 'Help with body progress')],
          children: [
            CoachSpot(
              id: 'me.body', introduce: true, padding: const EdgeInsets.only(bottom: 16),
              say: CoachSay('Track what matters to you. Every measurement is optional.',
                  guide: (label: 'How to measure', key: const Key('body-how'), onPressed: () => push(context, const HowToMeasureScreen()))),
            ),
            if (r.all.isEmpty)
              EmptyState('Nothing recorded yet', 'Log a weight or any one measurement when it helps you. Nothing here is required.',
                  action: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    PrimaryButton('Log measurements', key: const Key('body-log'), onPressed: () => push(context, const CheckInScreen())),
                    QuietLink('How to measure', key: const Key('body-how-empty'), onPressed: () => push(context, const HowToMeasureScreen())),
                  ]))
            else ...[
              _WeightPanel(checkIns: r.trusted, today: today, units: units),
              if (pending > 0) ...[
                const SizedBox(height: 10),
                StatusLine(Icons.phone_iphone, caps != null && !caps.contains(BodyRepository.capability)
                    ? '${plural(pending, 'change')} saved on this phone. Some wait for your account\'s server to support body measurements.'
                    : '${plural(pending, 'change')} saved on this phone · waiting to sync', key: const Key('body-pending')),
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
                child: QuietLink('All measurements', key: const Key('body-all'), onPressed: () => push(context, const BodyHistoryScreen())),
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
        return [
          const Overline('Latest weight'),
          if (latest == null) ...[
            Text('Not recorded', key: const Key('body-latest-weight'), style: context.pageTitleStyle(32)),
            Text('Your other measurements are below.', style: context.sansStyle(15, color: c.secondary)),
          ] else ...[
            Text(units.value(BodyField.weight, latest.value), key: const Key('body-latest-weight'), style: context.pageTitleStyle(44)),
            Text(latest.averaged ? 'Average of ${latest.count} entries on ${dayMonth(latest.dayKey)}' : 'Recorded ${dayMonth(latest.dayKey)}',
                key: const Key('body-latest-date'), style: context.sansStyle(15, color: c.secondary)),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 12),
          Wrap(spacing: 24, runSpacing: 8, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('7-day average', style: context.sansStyle(15, color: c.secondary)),
              Text(week == null ? 'Not available' : units.value(BodyField.weight, week.kg), key: const Key('body-average'), style: context.pageTitleStyle(26)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(week == null ? 'No weight in the last 7 days' : '${plural(week.days, 'recorded day')} of 7', key: const Key('body-average-days'), style: context.sansStyle(15, weight: FontWeight.w600)),
              Text('${dayMonth(addDays(today, -6))} – ${dayMonth(today)}', style: context.sansStyle(15, color: c.secondary)),
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
    final log = PrimaryButton('Log', key: const Key('body-log'), icon: Icons.add, onPressed: onLog);
    final compare = SecondaryButton('Compare dates', key: const Key('body-compare'), icon: Icons.date_range_outlined, onPressed: onCompare);
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
    final pts = seriesOf(checkIns, field, range, today);
    final means = dailyMeans(pts);
    final everRecorded = checkIns.any((m) => has(m, field));
    final rangeWords = range == TrendRange.all ? 'in all your history' : 'in the last ${range.label}';
    final severalADay = means.length < pts.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: SectionHeader('${field.label} over time')),
        if (seeAll != null && everRecorded) QuietLink('See all', key: Key('body-see-${field.name}'), onPressed: seeAll),
      ]),
      const SizedBox(height: 10),
      Segmented<TrendRange>(values: TrendRange.values, selected: range, keyPrefix: 'body-range', label: (r) => r.label, onChanged: onRange),
      const SizedBox(height: 12),
      Panel(
        key: Key('body-chart-${field.name}'),
        child: !everRecorded
            ? Text(field == BodyField.weight ? 'No weight recorded yet. Log one to see it over time.' : 'No ${field.label.toLowerCase()} recorded yet.', key: const Key('body-chart-none'), style: context.caption)
            : pts.isEmpty
                ? Text('No ${field.label.toLowerCase()} $rangeWords. Choose a longer range.', key: const Key('body-chart-empty'), style: context.caption)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(severalADay ? 'Points: each entry · line: daily average' : 'Each point is an entry you recorded', style: context.caption),
                    const SizedBox(height: 8),
                    PointChart<BodyPoint>(
                      points: pts, value: (p) => units.toDisplay(field, p.value), at: (p) => parseDayKey(p.dayKey), dayKey: (p) => p.dayKey,
                      line: severalADay ? [for (final (d, v) in means) (parseDayKey(d), units.toDisplay(field, v))] : null,
                      axisLabel: (v) => '${bodyNumber(v)} ${units.label(field)}',
                      onPoint: (p) => _openDay(context, checkIns, p.dayKey),
                      semanticsLabel: '${field.label} $rangeWords: ${plural(pts.length, 'entry', 'entries')}. ${pts.map((p) => '${dayMonth(p.dayKey)}, ${units.value(field, p.value)}').join('; ')}.',
                    ),
                    if (means.length == 1)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text('One day recorded $rangeWords. A change needs at least two.', key: const Key('body-one-point'), style: context.caption))
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('First to latest day in this range: ${units.change(field, means.first.$2, means.last.$2)}', key: const Key('body-range-change'), style: context.caption),
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
    final rows = [
      for (final f in BodyField.values)
        if (f != BodyField.weight)
          if (latestOf(checkIns, f) case final l?) (f, l),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Latest measurements'),
      const SizedBox(height: 10),
      if (rows.isEmpty)
        Text('No measurements other than weight yet. Log measurements to add waist, chest, arms or thighs.', key: const Key('body-latest-none'), style: context.caption)
      else
        GroupCard(children: [
          for (final (f, l) in rows)
            GroupRow(
              key: Key('body-latest-${f.name}'), title: f.label, value: units.value(f, l.value),
              subtitle: l.averaged ? 'Average of ${l.count} entries on ${dayMonth(l.dayKey)}' : dayMonth(l.dayKey),
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
  Widget build(BuildContext context) => _guard(context, ref, widget.field.label, (r) {
        final units = ref.watch(bodyUnitsProvider);
        final today = ref.watch(todayKeyProvider);
        final f = widget.field;
        final pts = seriesOf(r.trusted, f, _range, today);
        return AppPage(title: f.label, subtitle: f.dimension == BodyDimension.percent ? 'Body fat you entered, in %' : 'In ${units.label(f)}', children: [
          _ChartSection(field: f, checkIns: r.trusted, range: _range, today: today, units: units, onRange: (x) => setState(() => _range = x)),
          if (pts.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader('Entries in this range'),
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
  Widget build(BuildContext context, WidgetRef ref) => _guard(context, ref, 'All measurements', (r) {
        final units = ref.watch(bodyUnitsProvider);
        final perDay = <String, List<BodyMetric>>{};
        for (final x in r.all) {
          (perDay[x.value.dayKey] ??= []).add(x.value);
        }
        return AppPage(title: 'All measurements', subtitle: 'Every entry, newest first', children: [
          if (r.all.isEmpty)
            EmptyState('Nothing recorded yet', 'Your entries appear here once you log one.', action: PrimaryButton('Log measurements', onPressed: () => push(context, const CheckInScreen())))
          else
            GroupCard(children: [
              for (final x in r.all)
                GroupRow(
                  key: Key('body-history-${x.value.id}'),
                  title: _summary(x.value, units).isEmpty ? 'No measurement' : _summary(x.value, units),
                  subtitle: [
                    shortDate(x.value.dayKey),
                    if (perDay[x.value.dayKey]!.length > 1) orderKnown(perDay[x.value.dayKey]!) && x.value.recordedAtUtc != null ? 'saved ${timeOf(x.value.recordedAtUtc!)}' : 'one of ${perDay[x.value.dayKey]!.length} entries, order not known',
                    if (x.value.note != null) '“${x.value.note}”',
                    ?_syncWords(x),
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
  final _errors = <BodyField, String>{};
  String? _error;
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
      setState(() => _error = 'A field holds text that is not a number. Correct or clear it, then change the unit.');
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
      helpText: 'Date measured',
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
    if (_day.compareTo(ref.read(todayKeyProvider)) > 0) _error = 'Choose today or an earlier date.';
    if (_errors.isNotEmpty || _day.compareTo(ref.read(todayKeyProvider)) > 0) {
      setState(() => _error ??= 'Check the highlighted fields. Nothing was saved.');
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
        if (!supported) throw const BodyInputError('Correcting an entry needs an update to your account\'s server. Your changes are still here.');
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
      toast(context, 'Saved on this phone · it syncs to your account when it can');
      Navigator.pop(context);
    } on BodyInputError catch (e) {
      setState(() => _error = e.message);
    } on LocalSaveFailure {
      setState(() => _error = 'That could not be saved on this phone. Everything you typed is still here.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final m = _old!;
    if (!await confirm(context, title: 'Delete this entry?', body: 'The entry from ${longDate(m.dayKey)} will be removed from your measurements.', action: 'Delete', destructive: true)) return;
    try {
      await ref.read(bodyRepositoryProvider).delete(m);
      if (mounted) Navigator.pop(context);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = 'That could not be removed on this phone. Try again.');
    }
  }

  void _chooseFields() => showGoSheet<void>(context, title: 'Choose measurements', builder: (sheet) => Consumer(builder: (context, ref, _) {
        final prefs = ref.watch(bodyPrefsProvider);
        final shown = prefs.shown ?? BodyPrefs.defaultShown;
        final owner = ref.read(ownerProvider);
        void set(Set<BodyField> next, bool note) {
          if (owner != null) ref.read(bodyPrefsControllerProvider.notifier).update(owner, (p) => BodyPrefs(mass: p.mass, length: p.length, shown: next, note: note));
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Choose what this form shows. Hiding a field never removes anything you recorded.', style: context.caption),
          const SizedBox(height: 8),
          for (final f in BodyField.values)
            CheckboxListTile(
              key: Key('body-choose-${f.name}'), value: shown.contains(f), title: Text(f.label), contentPadding: EdgeInsets.zero,
              onChanged: (on) => set(on! ? {...shown, f} : ({...shown}..remove(f)), prefs.note),
            ),
          CheckboxListTile(key: const Key('body-choose-note'), value: prefs.note, title: const Text('Note'), contentPadding: EdgeInsets.zero, onChanged: (on) => set(shown, on!)),
        ]);
      }));

  Widget _field(BodyField f, {bool large = false}) => TextField(
        key: Key('body-field-${f.name}'), controller: _text[f],
        keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: large ? context.pageTitleStyle(30) : context.numStyle(20),
        onChanged: (_) => setState(() {
          _errors.remove(f);
          _error = null;
        }),
        decoration: InputDecoration(labelText: f.label, suffixText: _units.label(f), errorText: _errors[f], errorMaxLines: 3),
      );

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(bodyPrefsProvider);
    final shown = _shown(prefs);
    final lengths = [for (final f in BodyField.values) if (f.dimension == BodyDimension.length && shown.contains(f)) f];
    final wide = MediaQuery.sizeOf(context).width >= 360 && MediaQuery.textScalerOf(context).scale(10) <= 13;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _saving || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirm(context, title: 'Discard your changes?', body: 'What you typed has not been saved.', action: 'Discard', cancel: 'Keep editing');
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: AppPage(
        title: _old == null ? 'Log measurements' : 'Edit entry',
        subtitle: 'Every measurement is optional.',
        actions: [IconButton(tooltip: 'How to measure', icon: const Icon(Icons.help_outline), onPressed: () => push(context, const HowToMeasureScreen()))],
        bottom: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // iOS number pads have no return key: this closes the keyboard.
          if (keyboard) Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(key: const Key('body-done-typing'), onPressed: () => FocusScope.of(context).unfocus(), child: const Text('Done typing'))),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error, key: const Key('body-error'))),
          PrimaryButton(_old == null ? 'Save measurements' : 'Save changes', key: const Key('body-save'), busy: _saving, onPressed: _save),
        ]),
        children: [
          GroupCard(children: [
            GroupRow(key: const Key('body-date'), icon: Icons.event_outlined, title: longDate(_day), subtitle: 'Date measured', onTap: _pickDay),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _UnitChoice<LoadUnit>(label: 'Weight', keyPrefix: 'body-mass', values: LoadUnit.values, selected: _units.mass, name: (u) => u.name, onChanged: (u) => _switchUnits(BodyUnits(u, _units.length))),
            _UnitChoice<LengthUnit>(label: 'Length', keyPrefix: 'body-length', values: LengthUnit.values, selected: _units.length, name: (u) => u.label, onChanged: (u) => _switchUnits(BodyUnits(_units.mass, u))),
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
                  onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Note (optional)')),
            ),
          GroupCard(children: [
            GroupRow(key: const Key('body-choose'), icon: Icons.tune, title: 'Choose measurements', subtitle: 'Body fat, a note, or fewer fields', onTap: _chooseFields),
          ]),
          const SizedBox(height: 10),
          Text('Enter at least one measurement to save. Blank means not measured.', style: context.caption),
          if (_old != null) ...[
            const SizedBox(height: 20),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(key: const Key('body-delete'), onPressed: _delete, icon: Icon(Icons.delete_outline, color: context.c.error),
                  label: Text('Delete entry', style: TextStyle(color: context.c.error))),
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
    final picked = await showGoSheet<String>(context, title: from ? 'Compare from' : 'Compare to', builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Only days with a saved entry can be chosen.', style: context.caption),
          const SizedBox(height: 10),
          for (final m in [...eligible]..sort((a, b) => compareCheckIns(b, a)))
            ChoiceTile<String?>(
              key: Key('body-pick-${m.id}'), value: m.id, groupValue: current, title: _dateYear(m.dayKey),
              subtitle: [
                if (perDay[m.dayKey]!.length > 1)
                  orderKnown(perDay[m.dayKey]!) && m.recordedAtUtc != null ? 'Saved at ${timeOf(m.recordedAtUtc!)}' : 'One of ${perDay[m.dayKey]!.length} entries this day, order not known',
                _summary(m, units),
              ].join('\n'),
              onChanged: (id) => Navigator.pop(sheet, id),
            ),
        ]));
    if (picked != null) setState(() => from ? _fromId = picked : _toId = picked);
  }

  @override
  Widget build(BuildContext context) => _guard(context, ref, 'Compare dates', (r) {
        final units = ref.watch(bodyUnitsProvider);
        final eligible = r.trusted;
        final days = {for (final m in eligible) m.dayKey};
        BodyMetric? byId(String? id) => id == null ? null : eligible.where((m) => m.id == id).firstOrNull;
        final defaults = defaultPair(eligible);
        // A chosen entry that was deleted or is awaiting review falls back to the default, and the page says so.
        final lostFrom = _fromId != null && byId(_fromId) == null, lostTo = _toId != null && byId(_toId) == null;
        final from = byId(_fromId) ?? defaults.$1, to = byId(_toId) ?? defaults.$2;
        return AppPage(
          title: 'Compare dates', subtitle: 'Changes between your recorded entries.',
          actions: const [CoachHelpEntry(id: 'me.body.compare', label: 'Help with comparing')],
          children: [
            const CoachSpot(id: 'me.body.compare', padding: EdgeInsets.only(bottom: 16), say: CoachSay('Compare the same measurement on two dates. A dash means it was not recorded that day.')),
            if (days.length < 2)
              EmptyState('Two dates needed', days.isEmpty ? 'Comparing needs entries on two different days. You have none yet.' : 'Comparing needs entries on two different days. You have entries on ${dayMonth(days.single)} only.',
                  action: PrimaryButton('Log measurements', key: const Key('body-compare-log'), onPressed: () => push(context, const CheckInScreen())))
            else ...[
              if (lostFrom || lostTo)
                const Padding(padding: EdgeInsets.only(bottom: 10), child: StatusLine(Icons.info_outline, 'An entry you chose is no longer available, so the default is shown.', key: Key('body-compare-lost'))),
              _Pickers(
                from: from, to: to,
                onFrom: () => _choose(eligible, true), onTo: () => _choose(eligible, false),
              ),
              const SizedBox(height: 6),
              Align(alignment: AlignmentDirectional.centerEnd, child: Text('${units.mass.name} · ${units.length.label}', style: context.caption)),
              const SizedBox(height: 10),
              if (from == null || to == null)
                const StatusLine(Icons.touch_app_outlined, 'Those days have more than one entry and their order is not known. Choose the entries to compare.', key: Key('body-compare-choose'))
              else if (from.id == to.id)
                const StatusLine(Icons.info_outline, 'From and To are the same entry. Choose another one.')
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
    Widget pick(String label, BodyMetric? m, VoidCallback onTap, String key) => Expanded(
          child: GroupCard(children: [
            GroupRow(key: Key(key), icon: Icons.event_outlined, title: m == null ? 'Choose' : _dateYear(m.dayKey), subtitle: label, onTap: onTap),
          ]),
        );
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 360;
    final a = pick('From', from, onFrom, 'body-compare-from'), b = pick('To', to, onTo, 'body-compare-to');
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
    final rows = compareCheckInsRows(from, to);
    final weight = rows.where((x) => x.field == BodyField.weight).firstOrNull;
    final others = [for (final x in rows) if (x.field != BodyField.weight) x];
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 360;
    String cell(double? v, BodyField f) => v == null ? '—' : units.value(f, v);
    String said(double? v, BodyField f) => v == null ? 'not recorded' : units.value(f, v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (weight != null)
        PhotoPanel(
          key: const Key('body-compare-weight'),
          content: (context) => [
            const Overline('Weight'),
            const SizedBox(height: 6),
            Wrap(spacing: 24, runSpacing: 8, children: [
              for (final (day, v) in [(from.dayKey, weight.from), (to.dayKey, weight.to)])
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(dayMonth(day), style: context.sansStyle(15, color: context.c.secondary)),
                  Text(cell(v, BodyField.weight), style: context.pageTitleStyle(30)),
                  if (v == null) Text('Not recorded', style: context.caption),
                ]),
            ]),
            const SizedBox(height: 10),
            Text(weight.hasChange ? 'Change  ${units.change(BodyField.weight, weight.from!, weight.to!)}' : 'Change  —  needs a weight on both days',
                key: const Key('body-compare-weight-change'), style: context.sansStyle(17, weight: FontWeight.w600)),
          ],
        ),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 20),
        const SectionHeader('Measurements'),
        const SizedBox(height: 10),
        GroupCard(children: [
          if (!stacked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Expanded(flex: 4, child: SizedBox()),
                for (final h in [dayMonth(from.dayKey), dayMonth(to.dayKey), 'Change']) Expanded(flex: 3, child: Text(h, style: context.label)),
              ]),
            ),
          for (final x in others)
            MergeSemantics(
              key: Key('body-compare-${x.field.name}'),
              child: Semantics(
                label: '${x.field.label}: ${dayMonth(from.dayKey)} ${said(x.from, x.field)}, ${dayMonth(to.dayKey)} ${said(x.to, x.field)}, '
                    'change ${x.hasChange ? units.change(x.field, x.from!, x.to!) : 'not available'}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: stacked
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(x.field.label, style: context.sansStyle(16, weight: FontWeight.w600)),
                            Text('${dayMonth(from.dayKey)}: ${x.from == null ? '— Not recorded' : cell(x.from, x.field)}', style: context.body),
                            Text('${dayMonth(to.dayKey)}: ${x.to == null ? '— Not recorded' : cell(x.to, x.field)}', style: context.body),
                            Text('Change: ${x.hasChange ? units.change(x.field, x.from!, x.to!) : '—'}', style: context.body),
                          ])
                        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(flex: 4, child: Text(x.field.label, style: context.sansStyle(15.5, weight: FontWeight.w600))),
                            for (final v in [x.from, x.to])
                              Expanded(
                                flex: 3,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(cell(v, x.field), style: context.numStyle(15)),
                                  if (v == null) Text('Not recorded', style: context.caption),
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
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Body fat change is in percentage points.', style: context.caption)),
      ],
      const SizedBox(height: 12),
      Text('Recorded values only. A change is shown only where both entries have that measurement.', style: context.caption),
    ]);
  }
}

// ---------------------------------------------------------------------------- how to measure

/// Built-in guidance, nothing generated. The landmarks are from the CDC's NHANES procedures, cited on the page.
class HowToMeasureScreen extends StatelessWidget {
  const HowToMeasureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget part(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(title, style: context.sansStyle(17, weight: FontWeight.w600))),
            const SizedBox(height: 4),
            Text(body, style: context.body),
          ]),
        );
    return AppPage(title: 'How to measure', subtitle: 'Measure the same way each time, so entries compare.', children: [
      part('Any tape measurement', 'Use a flexible tape. Keep it level and snug, without pressing into the skin, and read it at the same place every time.'),
      part('Waist', 'Find the top of your hip bone at the side. Wrap the tape around your waist at that level, parallel to the floor, and read it at the end of a normal breath out.'),
      part('Upper arm', 'Find the midpoint between the bony tip of your shoulder and the point of your elbow, at the back of the arm. With the arm relaxed and hanging loosely, wrap the tape around the arm at that point. Tensing the muscle changes the reading. Measure the left and right arm separately.'),
      part('Chest and thighs', 'GoHard has no verified standard landmark for these. Choose one place, note it if that helps, and measure there each time with the same tape fit. Measure the left and right thigh separately.'),
      part('Weight and body fat', 'Optional. Enter body fat only if you have a value from a method you trust; GoHard does not estimate it.'),
      const SizedBox(height: 4),
      Text('Source: Centers for Disease Control and Prevention, National Center for Health Statistics. NHANES Anthropometry Procedures Manual, January 2017: '
          '3.4.6 Upper Arm Length, 3.4.7 Arm Circumference, 3.4.8 Abdominal (Waist) Circumference.', key: const Key('body-how-source'), style: context.caption),
      const SizedBox(height: 8),
      Text('This is measuring technique, not health advice. GoHard does not judge measurements.', style: context.caption),
    ]);
  }
}
