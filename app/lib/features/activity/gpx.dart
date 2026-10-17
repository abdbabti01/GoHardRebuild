import '../../data/models.dart';
import 'track_math.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// GPX 1.1 of a saved activity (docs/RUN_WALK.md › History and export): the accepted fixes as recorded, a `<time>` on
/// every point, `<ele>` only where altitude was measured, and one `<trkseg>` per segment so gaps and pauses are not
/// joined. Nothing is smoothed, snapped or invented.
String toGpx(Run run, Iterable<TrackEntry> entries) {
  final a = TrackAnalysis();
  final segments = <int, List<TrackEntry>>{};
  for (final e in entries) {
    a.add(e);
    if (e.type == EntryType.fix && identical(a.lastAccepted, e)) (segments[a.segmentIndex] ??= []).add(e);
  }
  String time(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
  final name = _esc(run.title ?? (run.isWalk ? 'Walk' : 'Run'));
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="GoHard" xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('  <metadata><name>$name</name><time>${_esc(run.startedAtUtc)}</time></metadata>')
    ..writeln('  <trk><name>$name</name><type>${run.isWalk ? 'walking' : 'running'}</type>');
  for (final seg in segments.values) {
    b.writeln('    <trkseg>');
    for (final p in seg) {
      b.write('      <trkpt lat="${p.lat!.toStringAsFixed(7)}" lon="${p.lon!.toStringAsFixed(7)}">');
      if (p.alt != null) b.write('<ele>${p.alt!.toStringAsFixed(1)}</ele>');
      b.writeln('<time>${time(p.t)}</time></trkpt>');
    }
    b.writeln('    </trkseg>');
  }
  b
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}
