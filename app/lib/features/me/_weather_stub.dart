// TEMPORARY stand-in for two symbols of `features/weather/weather.dart` (owned by the weather branch), so the
// Appearance "Today background" row builds before that branch is merged. The lead deletes this file at merge and
// points the import in me_screen.dart at '../weather/weather.dart'. Nothing else may import it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Stub: the weather module's summary ("Scenic" | "Weather · Montréal" | "Weather · Automatic" | "Plain").
/// Scenic is the contract's fresh-install default.
final todayBackgroundSummaryProvider = Provider<String>((_) => 'Scenic');

/// Stub: the weather module's Today background page.
class TodayBackgroundScreen extends ConsumerWidget {
  const TodayBackgroundScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(title: 'Today background', children: [
        Text('Today uses the scenic background.', style: context.body),
      ]);
}
