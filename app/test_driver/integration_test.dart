import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves native screenshots taken during the journey into docs/evidence/screenshots.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        File('../docs/evidence/screenshots/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
        return true;
      },
    );
