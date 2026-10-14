// TEMPORARY stand-in for `ScenicBackdrop` from `features/weather/weather.dart` (owned by the weather branch), so the
// Train header builds before that branch is merged. The lead deletes this file at merge and points the import in
// train_screen.dart at '../weather/weather.dart'. Nothing else may import it.
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Stub: fills its parent with a quiet recessed-to-page gradient where the dusk scene will be. Decoration only.
class ScenicBackdrop extends StatelessWidget {
  const ScenicBackdrop({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [context.c.sunken, context.c.page])),
          child: const SizedBox.expand(),
        ),
      );
}
