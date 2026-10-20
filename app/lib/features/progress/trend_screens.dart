import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_screen.dart' show setText;
import 'progress_view.dart';
import 'trends.dart';

/// Every exercise with recorded evidence, searchable (Progress › Strength trends › See all). Only exercises that were
/// actually recorded appear: the catalog's other movements have no history to show.
class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({super.key});
  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(trendIndexProvider).recent;
    final q = _query.trim().toLowerCase();
    final shown = [for (final t in all) if (q.isEmpty || t.name.toLowerCase().contains(q)) t];
    return AppPage(title: 'Exercise trends', subtitle: 'Exercises you have recorded, most recent first', children: [
      TextField(
        key: const Key('trends-search'),
        decoration: const InputDecoration(labelText: 'Search your exercises', prefixIcon: Icon(Icons.search)),
        onChanged: (v) => setState(() => _query = v),
      ),
      const SizedBox(height: 14),
      if (all.isEmpty)
        const EmptyState('Nothing recorded yet', 'An exercise appears here once a finished workout has recorded sets of it.')
      else if (shown.isEmpty)
        EmptyState('No match', 'None of your recorded exercises matches "${_query.trim()}".')
      else
        GroupCard(children: [
          for (final t in shown)
            GroupRow(
              key: Key('trend-row-${t.key}'), icon: Icons.show_chart, tone: Tone.neutral, title: t.name,
              subtitle: '${plural(t.sessions.length, 'session')} · latest ${dayMonth(t.sessions.last.workout.dayKey)}',
              onTap: () => push(context, ExerciseTrendScreen(exerciseKey: t.key)),
            ),
        ]),
    ]);
  }
}

/// One exercise's comparable results over time: the latest result, a range, the metric (and its rep count), the
/// chart, the change across the range, and the sessions behind every point. Choosing never changes a record.
class ExerciseTrendScreen extends ConsumerStatefulWidget {
  const ExerciseTrendScreen({super.key, required this.exerciseKey});
  final String exerciseKey;
  @override
  ConsumerState<ExerciseTrendScreen> createState() => _ExerciseTrendScreenState();
}

class _ExerciseTrendScreenState extends ConsumerState<ExerciseTrendScreen> {
  TrendRange _range = TrendRange.weeks4;
  int? _reps;

  void _open(String workoutId) => push(context, WorkoutDetailScreen(workoutId: workoutId));

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(workoutsProvider), sets = ref.watch(allSetsProvider);
    if (workouts.hasError || sets.hasError) {
      return const AppPage(title: 'Exercise trends', children: [EmptyState('This could not be read', 'Your records on this phone could not be read just now. Nothing was changed; try again.')]);
    }
    if (!workouts.hasValue || !sets.hasValue) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final t = ref.watch(trendIndexProvider).trends[widget.exerciseKey];
    if (t == null) {
      return const AppPage(title: 'Exercise trends', children: [EmptyState('No recorded sets', 'This exercise has no recorded sets in a finished workout any more.')]);
    }
    final unit = ref.watch(loadUnitProvider);
    final today = ref.watch(todayKeyProvider);
    final reps = t.metric == TrendMetric.load ? (_reps != null && t.repOptions.contains(_reps) ? _reps : t.defaultReps) : null;
    final pts = inRange(t.points(reps: reps), _range, today);
    final change = changeOf(pts);
    final latest = pts.lastOrNull;
    final catalog = ref.watch(exerciseChoicesProvider).where((c) => c.key == t.key).firstOrNull;
    final overline = [if (catalog != null && catalog.equipment.isNotEmpty) catalog.equipment, if (catalog != null) catalog.category].join(' · ');
    final days = {for (final p in pts) p.dayKey: pts.where((x) => x.dayKey == p.dayKey).length};
    String when(TrendPoint p) => '${shortDate(p.dayKey)}${(days[p.dayKey] ?? 0) > 1 ? ' · ${timeOf(p.startedAtUtc)}' : ''}';
    final label = metricLabel(t, reps);
    final rangeWords = _range == TrendRange.all ? 'in all your history' : 'in the last ${_range.label}';

    return AppPage(title: 'Exercise trends', children: [
      PhotoPanel(
        key: const Key('trend-hero'),
        photo: 'assets/images/workout-hero.webp',
        photoAlignment: const Alignment(1, 0.6),
        content: (context) => [
          if (overline.isNotEmpty) Overline(overline),
          Text(t.name, style: context.pageTitleStyle(30)),
          const SizedBox(height: 4),
          if (latest != null) ...[
            Text('Latest recorded', style: context.sansStyle(15, color: context.c.secondary)),
            Text(trendValue(t, latest, unit), key: const Key('trend-latest'), style: context.pageTitleStyle(36)),
            Text(when(latest), style: context.numStyle(15, weight: FontWeight.w500)),
          ] else
            Text(t.metric == TrendMetric.none ? 'No comparable measure' : 'No session $rangeWords', style: context.sansStyle(15, color: context.c.secondary)),
        ],
      ),
      const SizedBox(height: 16),
      Segmented<TrendRange>(values: TrendRange.values, selected: _range, keyPrefix: 'trend-range', label: (r) => r.label, onChanged: (r) => setState(() => _range = r)),
      if (t.metric == TrendMetric.load && t.repOptions.length > 1) ...[
        const SizedBox(height: 12),
        Text('Compare sets of', style: context.caption),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in t.repOptions)
            ChoiceChip(key: Key('trend-reps-$r'), label: Text('$r reps'), selected: r == reps, onSelected: (_) => setState(() => _reps = r)),
        ]),
      ],
      const SizedBox(height: 16),
      if (t.metric == TrendMetric.none)
        Panel(child: Text('These sets have no reps with a load, no reps alone and no recorded time, so there is nothing comparable to chart. Every recorded session is listed below.', style: context.caption))
      else
        Panel(
          key: const Key('trend-chart-card'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.start, spacing: 12, runSpacing: 8, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, key: const Key('trend-metric'), style: context.sansStyle(17, weight: FontWeight.w600)),
                Text('Recorded sessions only', style: context.caption),
              ]),
              if (change != null)
                Container(
                  key: const Key('trend-change'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: context.c.sunken, borderRadius: BorderRadius.circular(Radii.field)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(changeText(t, change, unit), style: context.numStyle(17)),
                    Text('first to latest, this range', style: context.sansStyle(12.5, color: context.c.secondary)),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),
            if (pts.isEmpty)
              Text(t.metric == TrendMetric.load ? 'No session with a set of $reps reps $rangeWords. Choose a longer range or another rep count.' : 'No session $rangeWords. Choose a longer range.',
                  key: const Key('trend-empty-range'), style: context.caption)
            else ...[
              TrendChart(
                points: pts, axisLabel: (v) => axisValue(t, v, unit), onPoint: (p) => _open(p.workoutId),
                semanticsLabel: '$label, $rangeWords: ${plural(pts.length, 'session')}. ${pts.map((p) => '${when(p)}, ${trendValue(t, p, unit)}').join('; ')}.',
              ),
              if (pts.length == 1)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('One comparable session so far. A change needs at least two.', key: const Key('trend-one-point'), style: context.caption)),
            ],
          ]),
        ),
      if (pts.isNotEmpty) ...[
        const SizedBox(height: 24),
        const SectionHeader('Sessions in this range'),
        const SizedBox(height: 10),
        GroupCard(children: [
          for (final p in pts.reversed)
            GroupRow(key: Key('trend-session-${p.workoutId}'), title: when(p), value: trendValue(t, p, unit), onTap: () => _open(p.workoutId)),
        ]),
        const SizedBox(height: 8),
        Text(t.metric == TrendMetric.load ? 'Each row is the heaviest set of $reps reps in that workout. Shown at the same rep count.' : 'Each row is that workout\'s best set by this measure.',
            style: context.caption),
      ],
      if (t.excluded > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(switch (t.metric) {
            TrendMetric.load => '${plural(t.excluded, 'recorded set')} without both reps and a load ${t.excluded == 1 ? 'is' : 'are'} not in this chart.',
            TrendMetric.reps => '${plural(t.excluded, 'recorded set')} with a load or without reps ${t.excluded == 1 ? 'is' : 'are'} not in this chart.',
            _ => '${plural(t.excluded, 'recorded set')} without a recorded time ${t.excluded == 1 ? 'is' : 'are'} not in this chart.',
          }, style: context.caption),
        ),
      const SizedBox(height: 14),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: QuietLink('All ${plural(t.sessions.length, 'session')} and sets', key: const Key('trend-all-sessions'), onPressed: () => push(context, _AllSessions(exerciseKey: t.key))),
      ),
    ]);
  }
}

/// "07:30", local time of a session start, to tell two sessions on one day apart.
String timeOf(String utc) {
  final d = DateTime.parse(utc).toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Every recorded session of the exercise with all of its sets, whatever the chart's metric uses.
class _AllSessions extends ConsumerWidget {
  const _AllSessions({required this.exerciseKey});
  final String exerciseKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trendIndexProvider).trends[exerciseKey];
    final unit = ref.watch(loadUnitProvider);
    return AppPage(title: t?.name ?? 'Sessions', subtitle: 'Every recorded session, newest first', children: [
      if (t == null) const EmptyState('No recorded sets', 'This exercise has no recorded sets any more.'),
      if (t != null)
        GroupCard(children: [
          for (final s in t.sessions.reversed)
            GroupRow(
              key: Key('all-session-${s.workout.id}'), title: '${shortDate(s.workout.dayKey)} · ${s.workout.title}',
              subtitle: s.sets.map((x) => setText(x, unit)).join(', '),
              onTap: () => push(context, WorkoutDetailScreen(workoutId: s.workout.id)),
            ),
        ]),
    ]);
  }
}

/// A small data-driven line chart of [points] at their real session times. Not a picture: it is drawn from the
/// values, announced as [semanticsLabel] (the list beside it is the full non-visual alternative), and a tap near a
/// point calls [onPoint] with it. [compact] drops the date axis for the overview.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points, required this.axisLabel, this.onPoint, this.semanticsLabel, this.height = 180, this.compact = false});
  final List<TrendPoint> points;
  final String Function(double) axisLabel;
  final void Function(TrendPoint)? onPoint;
  final String? semanticsLabel;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) => PointChart<TrendPoint>(
        points: points, value: (p) => p.value, at: (p) => DateTime.parse(p.startedAtUtc), dayKey: (p) => p.dayKey,
        axisLabel: axisLabel, onPoint: onPoint, semanticsLabel: semanticsLabel, height: height, compact: compact,
      );
}

/// The chart behind [TrendChart], for any recorded points: each point at [at] with its [value], the line through them
/// in order, or through [line] when given (Body progress joins daily means and marks every reading).
class PointChart<T> extends StatelessWidget {
  const PointChart({super.key, required this.points, required this.value, required this.at, required this.dayKey, required this.axisLabel,
      this.line, this.onPoint, this.semanticsLabel, this.height = 180, this.compact = false});
  final List<T> points;
  final double Function(T) value;
  final DateTime Function(T) at;
  final String Function(T) dayKey;
  final List<(DateTime, double)>? line;
  final String Function(double) axisLabel;
  final void Function(T)? onPoint;
  final String? semanticsLabel;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = context.numStyle(12.5, color: context.c.secondary, weight: FontWeight.w400);
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final h = height + (compact ? 0 : 6 * scale.scale(1));
    final chart = LayoutBuilder(builder: (context, box) {
      final layout = _ChartLayout([for (final p in points) (at(p), value(p), dayKey(p))], line, Size(box.maxWidth, h), axisLabel, style, scale, compact);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onPoint == null
            ? null
            : (d) {
                final i = layout.nearest(d.localPosition);
                if (i != null) onPoint!(points[i]);
              },
        child: CustomPaint(size: Size(box.maxWidth, h), painter: _ChartPainter(layout, context.c.accent, context.c.surface, context.c.divider)),
      );
    });
    return Semantics(label: semanticsLabel, container: true, child: ExcludeSemantics(child: SizedBox(key: const Key('trend-chart'), height: h, child: chart)));
  }
}

class _ChartLayout {
  _ChartLayout(List<(DateTime, double, String)> points, List<(DateTime, double)>? line, this.size, String Function(double) label, TextStyle style, TextScaler scale, bool compact) {
    final values = points.map((p) => p.$2);
    var lo = values.isEmpty ? 0.0 : values.reduce(math.min), hi = values.isEmpty ? 1.0 : values.reduce(math.max);
    // One level: a flat line in the middle, never an invented slope.
    this.lo = hi == lo ? lo - 1 : lo;
    this.hi = hi == lo ? hi + 1 : hi;
    TextPainter text(String s) => TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, textScaler: scale)..layout();
    yLabels = [text(label(hi)), text(label(lo))];
    xLabels = compact || points.isEmpty ? const [] : [text(dayMonth(points.first.$3)), if (points.length > 1) text(dayMonth(points.last.$3))];
    final left = yLabels.map((t) => t.width).reduce(math.max) + 10;
    final bottom = xLabels.isEmpty ? 6.0 : xLabels.first.height + 10;
    plot = Rect.fromLTRB(left, yLabels.first.height / 2 + 4, size.width - 10, size.height - bottom);
    final times = points.map((p) => p.$1.millisecondsSinceEpoch).toList();
    final t0 = times.isEmpty ? 0 : times.first, t1 = times.isEmpty ? 1 : times.last;
    Offset place(int t, double v) => Offset(t1 == t0 ? plot.center.dx : plot.left + plot.width * (t - t0) / (t1 - t0), plot.bottom - plot.height * (v - this.lo) / (this.hi - this.lo));
    offsets = [for (final (i, p) in points.indexed) place(times[i], p.$2)];
    path = line == null ? offsets : [for (final (t, v) in line) place(t.millisecondsSinceEpoch, v)];
  }
  final Size size;
  late final double lo, hi;
  late final List<TextPainter> yLabels, xLabels;
  late final Rect plot;
  late final List<Offset> offsets, path;

  int? nearest(Offset at) {
    int? best;
    for (final (i, o) in offsets.indexed) {
      if ((o - at).distance <= 28 && (best == null || (o - at).distance < (offsets[best] - at).distance)) best = i;
    }
    return best;
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.l, this.accent, this.surface, this.grid);
  final _ChartLayout l;
  final Color accent, surface, grid;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final (i, y) in [l.plot.top, l.plot.bottom].indexed) {
      canvas.drawLine(Offset(l.plot.left, y), Offset(l.plot.right, y), line);
      final t = l.yLabels[i];
      t.paint(canvas, Offset(l.plot.left - 10 - t.width, y - t.height / 2));
    }
    for (final (i, t) in l.xLabels.indexed) {
      final x = i == 0 ? l.offsets.first.dx : l.offsets.last.dx;
      t.paint(canvas, Offset((x - t.width / 2).clamp(0, size.width - t.width), l.plot.bottom + 6));
    }
    if (l.path.length > 1) {
      canvas.drawPath(
          Path()..addPolygon(l.path, false),
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round);
    }
    for (final o in l.offsets) {
      canvas.drawCircle(o, 5.5, Paint()..color = accent);
      canvas.drawCircle(o, 2.5, Paint()..color = surface);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true; // a handful of points: cheaper than comparing labels, units and colours
}
