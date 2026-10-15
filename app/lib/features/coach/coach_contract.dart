import 'package:flutter/widgets.dart';

import '../plans/plan_draft.dart';

/// What Ask GoHard is asked about (docs/COACH.md). Built by the screen that opens it.
///
/// [label] names the real split, workout or exercise for the person ("Upper / Lower", "Bench press · Upper A"); it
/// never contains an ID. [draft] is read when a question is sent and again when a suggestion is previewed or applied,
/// so a suggestion made for an earlier version of the draft is recognised as stale. [applyToDraft] is how an
/// accepted suggestion reaches the builder: through its own editor, saved like any other edit, never activated.
/// Without it no change is offered, only answers.
@immutable
class CoachContext {
  const CoachContext({required this.label, this.focus = CoachFocus.plan, this.templateId, this.workoutId, this.occurrenceKey, this.catalogKey, this.draft, this.applyToDraft});
  final String label;
  final CoachFocus focus;
  final String? templateId, workoutId, occurrenceKey, catalogKey;
  final PlanDraft Function()? draft;
  final Future<void> Function(PlanDraft next)? applyToDraft;
}

enum CoachFocus { plan, split, workout, exercise }

/// Opens Ask GoHard over [context]'s page. Closing it returns to exactly where the person was. Opening it sends
/// nothing: a model request is made only when the person presses Send (or a suggested question).
Future<void> openAskGoHard(BuildContext context, CoachContext coach) async {
  // Contract stub: replaced by the Ask GoHard screen (features/coach/ask_screen.dart).
}
