import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show ownerProvider;
import '../../core/go_icon.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart' show parsePositiveInt;
import '../../core/widgets.dart';
import 'move_prefs.dart';
import 'steps.dart';

/// Steps' one set of controls (docs/RUN_WALK.md › Steps › Where it is): the sheet opened from Today's Steps tile, Me ›
/// Activity & tracking › Steps and Run / Walk Ready, all backed by the same preferences and source. Opening any of them
/// asks for nothing; only Enable (or Allow) asks the phone.

/// Motion access for counting during a run or walk, read when shown and again after any change.
final stepAccessProvider = FutureProvider.autoDispose<StepAccess>((ref) {
  ref.watch(stepsEnabledProvider);
  return ref.watch(stepSourceProvider).access();
});

/// Turns steps on for this account, then asks the phone (motion; on Android also Health Connect's step read for the
/// daily total). Run / Walk works whatever the answers; the screens say what was not allowed. Never called by opening
/// a screen.
Future<void> enableSteps(WidgetRef ref) async {
  final owner = ref.read(ownerProvider);
  if (owner == null) return;
  final src = ref.read(stepSourceProvider);
  ref.read(movePrefsProvider.notifier).setSteps(owner, true);
  await src.request();
  await src.dailyRequest();
  ref.invalidate(stepAccessProvider);
  ref.invalidate(dailyStepsProvider);
}

/// The fix for the access state, as one action: ask (not asked yet) or the phone's settings (refused).
({String label, Future<void> Function() run})? stepsFix(WidgetRef ref, StepAccess access) => switch (access) {
      StepAccess.notAllowed => (label: ref.read(appL10nProvider).stepsAllow, run: () async {
          await ref.read(stepSourceProvider).request();
          ref.invalidate(stepAccessProvider);
        }),
      StepAccess.blocked => (label: ref.read(appL10nProvider).stepsSettings, run: () => ref.read(stepSourceProvider).openSettings()),
      _ => null,
    };

Future<void> showStepsSheet(BuildContext context) => showGoSheet<void>(appContext(context), title: context.l10n.stepsTitle, builder: (_) => const _StepsSheet());

/// A supplied glyph that points along the reading direction (back, chevron): mirrored in Arabic. [GoIcon] itself
/// never mirrors.
Widget directionalGlyph(BuildContext context, GoIcon icon) => context.isRtl ? Transform.flip(flipX: true, child: icon) : icon;

class _StepsSheet extends ConsumerStatefulWidget {
  const _StepsSheet();
  @override
  ConsumerState<_StepsSheet> createState() => _StepsSheetState();
}

class _StepsSheetState extends ConsumerState<_StepsSheet> {
  late final TextEditingController _goal;

  @override
  void initState() {
    super.initState();
    _goal = TextEditingController(text: ref.read(stepGoalProvider)?.toString() ?? '');
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(stepsEnabledProvider);
    final owner = ref.watch(ownerProvider);
    final src = ref.watch(stepSourceProvider);
    final access = on ? ref.watch(stepAccessProvider).value : null;
    final fix = access == null ? null : stepsFix(ref, access);
    final l = context.l10n;
    Widget toggle(String key, String title, String subtitle, bool value, ValueChanged<bool>? changed) => SwitchListTile(
        key: Key(key), contentPadding: EdgeInsets.zero, value: value, onChanged: changed,
        title: Text(title, style: context.sansStyle(16, weight: FontWeight.w600)), subtitle: Text(subtitle, style: context.caption));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      toggle('track-steps', l.stepsCount, l.stepsCountSubtitle,
          on, owner == null ? null : (v) => v ? enableSteps(ref) : ref.read(movePrefsProvider.notifier).setSteps(owner, false)),
      if (on && access != null && access != StepAccess.allowed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
              child: StatusLine(Icons.info_outline, switch (access) {
                StepAccess.notAllowed => l.stepsMotionNotAllowed,
                StepAccess.blocked => l.stepsMotionBlocked,
                _ => l.stepsNoCounter,
              }, tone: Tone.warning),
            ),
            if (fix != null) TextButton(key: const Key('steps-fix'), onPressed: fix.run, child: Text(fix.label)),
          ]),
        ),
      if (on)
        TextField(
          key: const Key('steps-goal'), controller: _goal, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.stepsGoalLabel, helperText: l.stepsGoalHelper),
          onChanged: (t) => ref.read(movePrefsProvider.notifier).setStepGoal(owner!, parsePositiveInt(t, grouping: true)),
        ),
      toggle('steps-on-today', l.stepsOnToday, l.stepsOnTodaySubtitle, ref.watch(stepsOnTodayProvider),
          owner == null ? null : (v) => ref.read(movePrefsProvider.notifier).setStepsOnToday(owner, v)),
      const SizedBox(height: 4),
      Text(l.stepsFooter(src.dailySource), style: context.caption),
    ]);
  }
}

/// One row of Ready's setup group (and the Steps row): the supplied glyph, the label, the real state, an optional
/// action and a chevron. The whole row opens its editor; "Off" is a state, never a disabled row.
class SetupRow extends StatelessWidget {
  const SetupRow({super.key, required this.glyph, required this.label, required this.value, required this.onTap, this.action, this.divider = false});
  final GoGlyph glyph;
  final String label, value;
  final VoidCallback onTap;
  final Widget? action;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    // Large text or a narrow phone: the state (and its action) go under the label, so no word breaks letter by letter.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 340;
    final valueText = Text(value, textAlign: stacked ? TextAlign.start : TextAlign.end, maxLines: stacked ? 3 : 2, overflow: TextOverflow.ellipsis,
        style: context.sansStyle(14.5, color: context.c.secondary));
    return Pressable(
        onTap: onTap,
        semanticLabel: '$label, $value',
        child: Container(
          constraints: const BoxConstraints(minHeight: Targets.minimum),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: stacked ? 8 : 4),
          decoration: divider ? BoxDecoration(border: Border(top: BorderSide(color: context.c.divider))) : null,
          child: stacked
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    GoIcon(glyph, size: 24, color: context.c.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label, style: context.sansStyle(16, weight: FontWeight.w600))),
                    directionalGlyph(context, GoIcon(GoGlyph.chevronRight, size: 20, color: context.c.secondary)),
                  ]),
                  if (value.isNotEmpty || action != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 36, top: 4),
                      child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [if (value.isNotEmpty) valueText, ?action]),
                    ),
                ])
              : Row(children: [
            GoIcon(glyph, size: 24, color: context.c.accent),
            const SizedBox(width: 14),
            // The label keeps its line; the state gives way (wraps, then ellipsis) when space is short.
            Expanded(child: Text(label, style: context.sansStyle(16, weight: FontWeight.w600))),
            const SizedBox(width: 8),
            ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4), child: valueText),
            if (action != null) ...[const SizedBox(width: 8), action!],
            const SizedBox(width: 4),
            directionalGlyph(context, GoIcon(GoGlyph.chevronRight, size: 20, color: context.c.secondary)),
          ]),
        ),
      );
  }
}

/// A rounded group of [SetupRow]s with an overline ("Your setup").
class SetupGroup extends StatelessWidget {
  const SetupGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.tile), border: Border.all(color: context.c.divider)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (title != null) Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: Overline(title!)),
          ...children,
        ]),
      );
}

/// Ready's Steps row: off with Enable, on, or what is needed. Enable is the direct action; the row opens the sheet.
class StepsSetupRow extends ConsumerWidget {
  const StepsSetupRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(stepsEnabledProvider);
    final access = on ? ref.watch(stepAccessProvider).value : null;
    final fix = access == null ? null : stepsFix(ref, access);
    final l = context.l10n;
    final (String label, String value) = !on
        ? (l.stepsOff, '')
        : switch (access) {
            null => (l.stepsTitle, l.stepsChecking),
            StepAccess.allowed => (l.stepsOn, ref.read(stepSourceProvider).simulated ? l.stepsSimulated : l.stepsCounted),
            StepAccess.notAllowed => (l.stepsTitle, l.stepsMotionNeeded),
            StepAccess.blocked => (l.stepsTitle, l.stepsMotionOff),
            StepAccess.unavailable => (l.stepsTitle, l.stepsNotOnPhone),
          };
    Widget pill(String text, Key key, VoidCallback onPressed) => FilledButton.tonal(
        key: key, onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16), visualDensity: VisualDensity.compact),
        child: Text(text));
    return SetupGroup(children: [
      SetupRow(
        key: const Key('runwalk-steps-row'), glyph: GoGlyph.steps, label: label, value: value, onTap: () => showStepsSheet(context),
        action: !on ? pill(l.stepsEnable, const Key('runwalk-steps-enable'), () => enableSteps(ref)) : fix == null ? null : pill(fix.label, const Key('runwalk-steps-fix'), fix.run),
      ),
    ]);
  }
}
