import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves native screenshots taken during the journey.
///
/// They go into the fresh folder `scripts\test-android.ps1` names in GOHARD_SHOT_DIR, never straight into
/// docs/evidence/screenshots: that folder is tracked by git, and a `git status` running at the same moment (an
/// editor's source-control view runs one whenever a file changes) maps each changed file into memory while it
/// hashes it. Windows then refuses to overwrite that file (error 1224), which failed a journey whose steps had all
/// passed. The script copies the captures into the evidence folder once the journey has passed.
Future<void> main() {
  final dir = Platform.environment['GOHARD_SHOT_DIR'];
  if (dir == null || dir.isEmpty) throw StateError('GOHARD_SHOT_DIR is not set. Run the journeys with scripts\\test-android.ps1.');
  return integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      File('$dir/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes, flush: true);
      return true;
    },
  );
}
