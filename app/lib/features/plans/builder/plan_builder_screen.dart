import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';

/// Train › Plan › Create plan: choose "Start from a template" or "Build my own", then the four-step builder.
/// (Contract stub: implemented by the builder owner. Keys and behaviour: docs/TRAINING_PLANS.md and the task brief.)
class CreatePlanScreen extends ConsumerWidget {
  const CreatePlanScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const Scaffold(body: Center(child: Text('Create plan')));
}

/// Opens the builder on an existing plan: edit it from an effective date, or duplicate it into a new draft.
Future<void> openPlanEditor(BuildContext context, WidgetRef ref, Plan plan, {bool duplicate = false}) async {}

/// "Edit this workout only": the exercise editor for one pending occurrence of a fixed-weekday plan, saved with
/// `PlanRepository.editOccasion`. Returns when the user saves or leaves.
Future<void> openOccurrenceEditor(BuildContext context, WidgetRef ref, Plan plan, Occasion occasion) async {}
