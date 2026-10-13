import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'device_prefs.dart';
import 'theme.dart';

/// Shared Calm Momentum building blocks: one button, card, list, sheet and form system for every screen.
/// Spacing and quiet separators come before containers; no card inside a card.

/// Scales its child to [Motion.pressScale] while pressed. With Reduce Motion nothing scales; the tint still shows.
class _PressScale extends StatelessWidget {
  const _PressScale({required this.down, required this.child});
  final bool down;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      AnimatedScale(scale: down && !context.reduceMotion ? Motion.pressScale : 1, duration: context.motion(Motion.press), curve: Motion.curve, child: child);
}

/// Gives a Material button the same press scale, driven by the button's own pressed state.
class _ScaledButton extends StatefulWidget {
  const _ScaledButton(this.builder);
  final Widget Function(WidgetStatesController states) builder;
  @override
  State<_ScaledButton> createState() => _ScaledButtonState();
}

class _ScaledButtonState extends State<_ScaledButton> {
  final _states = WidgetStatesController();
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_changed);
  }

  void _changed() {
    final down = _states.value.contains(WidgetState.pressed);
    if (down == _down || !mounted) return;
    // A button disabled in the middle of a press reports it while the tree is building.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
    } else {
      setState(() => _down = down);
    }
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PressScale(down: _down, child: widget.builder(_states));
}

/// The main action: a filled accent rounded rectangle, at least 52 px high. One per screen or card.
/// [busy] shows a spinner and ignores taps; a null [onPressed] is the disabled state. [destructive] fills it with the
/// error colour for an action that erases something (the label still has to say what it does).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.busy = false, this.expand = true, this.icon, this.destructive = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy, expand, destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.c.secondary, semanticsLabel: 'Working'))
        : Text(label, textAlign: TextAlign.center);
    final style = destructive ? FilledButton.styleFrom(backgroundColor: context.c.error, foregroundColor: context.c.page) : null;
    final button = _ScaledButton((states) => icon == null || busy
        ? FilledButton(onPressed: busy ? null : onPressed, style: style, statesController: states, child: child)
        : FilledButton.icon(onPressed: onPressed, style: style, statesController: states, icon: Icon(icon, size: 22), label: child));
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The quieter action beside or below a [PrimaryButton]: the same shape and height, outlined.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, required this.onPressed, this.expand = true, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, textAlign: TextAlign.center);
    final button = _ScaledButton((states) => icon == null
        ? OutlinedButton(onPressed: onPressed, statesController: states, child: child)
        : OutlinedButton.icon(onPressed: onPressed, statesController: states, icon: Icon(icon, size: 20), label: child));
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Wraps a card, row or custom control with the system's press feedback: a quiet tint and a light scale (no scale
/// under Reduce Motion), a target of at least 48 px, button semantics, and focus/keyboard activation.
///
///     Pressable(onTap: openRun, semanticLabel: 'Open run', child: Panel(child: ...))
///
/// A null [onTap] is the disabled state. [semanticLabel] replaces what the child would announce; leave it out when
/// the child's own text is the right label. [haptic] adds a selection tick (silent when Haptics is Off).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child, this.semanticLabel, this.selected, this.haptic = false,
      this.borderRadius = const BorderRadius.all(Radius.circular(Radii.panel))});
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;

  /// Announced as selected / not selected when set (a choice among several).
  final bool? selected;
  final bool haptic;

  /// The shape of the press tint; match the child's corners.
  final BorderRadius borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _tap() {
    if (widget.haptic) Haptics.selection();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final labelled = widget.semanticLabel != null;
    return Semantics(
      container: true, button: true, enabled: enabled, selected: widget.selected, label: widget.semanticLabel,
      excludeSemantics: labelled, onTap: labelled && enabled ? _tap : null,
      child: _PressScale(
        down: _down,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? _tap : null,
            onHighlightChanged: (down) => setState(() => _down = down),
            borderRadius: widget.borderRadius,
            child: ConstrainedBox(constraints: const BoxConstraints(minWidth: Targets.minimum, minHeight: Targets.minimum), child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Small capitals above a group of rows or inside a card ("PERSONAL", "WORKOUT"). It is drawn in the secondary
/// text colour, which keeps 4.5:1 on every surface, and is announced in its normal case.
///
///     const Overline('Preferences')
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      semanticsLabel: text, style: context.sansStyle(12.5, color: color ?? context.c.secondary, weight: FontWeight.w600, spacing: 1.1));
}

/// The top of each of the four tabs, the same everywhere: an optional quiet line (the date, "Your profile"), the
/// large title, and the small GH mark at the top trailing edge. [trailing] is an optional control placed before
/// the mark; [below] is an optional line under the title (Today's greeting). It has no padding of its own: put it
/// first in the tab's list, inside the page inset.
///
///     TabHeader(title: 'Today', overline: longDate(today), below: Text('Good evening, Alex'))
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.overline, this.trailing, this.below});
  final String title;
  final String? overline;
  final Widget? trailing, below;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (overline != null) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(overline!, style: context.sansStyle(15, color: context.c.secondary))),
              Heading(title),
            ]),
          ),
          if (trailing != null) Padding(padding: const EdgeInsets.only(left: 8), child: trailing),
          const Padding(padding: EdgeInsets.only(left: 12, top: 6), child: GhMark()),
        ]),
        if (below != null) Padding(padding: const EdgeInsets.only(top: 10), child: below),
      ]);
}

/// The small rounded tinted square that holds an icon: beside a row title, at the head of a card. [tone] picks the
/// tint (accent by default, neutral for quiet rows, a status tone for a status). It is decoration unless
/// [semanticLabel] is given; a status must also be said in words next to it.
///
///     const IconTile(Icons.directions_run)                         // 40 px, accent tint
///     const IconTile(Icons.rule, tone: Tone.warning, size: 36)
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40, this.tone = Tone.accent, this.semanticLabel});
  final IconData icon;
  final double size;
  final Tone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (fill, ink) = switch (tone) {
      Tone.accent => (c.accentSoft, c.accent),
      Tone.neutral => (c.sunken, c.text),
      _ => (Color.alphaBlend(_toneColor(context, tone).withValues(alpha: 0.14), c.surface), _toneColor(context, tone)),
    };
    final tile = Container(
      width: size, height: size,
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.55, color: ink, semanticLabel: semanticLabel),
    );
    return semanticLabel == null ? ExcludeSemantics(child: tile) : tile;
  }
}

/// Quiet label above a group ("Recorded sets").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text, style: context.label.copyWith(color: color));
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.size = 34, this.color, this.header = true});
  final String text;
  final double size;
  final Color? color;
  final bool header;
  @override
  Widget build(BuildContext context) => Semantics(header: header, child: Text(text, style: context.titleStyle(size, color: color)));
}

/// A section title with an optional value or action at the trailing edge. They wrap rather than squeeze.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.detail, this.trailing});
  final String title;
  final String? detail;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
          Heading(title, size: 20),
          if (detail != null) Text(detail!, style: context.sansStyle(14.5, color: context.c.secondary)),
        ]),
        ?trailing,
      ]);
}

enum Tone { neutral, accent, success, warning, error }

Color _toneColor(BuildContext context, Tone tone) => switch (tone) {
      Tone.accent => context.c.accent,
      Tone.success => context.c.success,
      Tone.warning => context.c.warning,
      Tone.error => context.c.error,
      Tone.neutral => context.c.secondary,
    };

/// Status with an icon AND text; colour alone never carries meaning.
class StatusLine extends StatelessWidget {
  const StatusLine(this.icon, this.text, {super.key, this.tone = Tone.neutral, this.onColor});
  final IconData icon;
  final String text;
  final Tone tone;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final color = onColor ?? _toneColor(context, tone);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: context.sansStyle(14, color: color))),
    ]);
  }
}

/// A named state ("Completed", "In progress"): always a word, with an icon, on a quiet tint.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.icon, this.tone = Tone.neutral});
  final String label;
  final IconData? icon;
  final Tone tone;
  @override
  Widget build(BuildContext context) {
    final color = tone == Tone.neutral ? context.c.text : _toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: tone == Tone.accent ? context.c.accentSoft : context.c.sunken, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)],
        Flexible(child: Text(label, style: context.sansStyle(13, color: color, weight: FontWeight.w600))),
      ]),
    );
  }
}

/// A labelled progress rail. The words beside it carry the value; this announces it once for a screen reader.
/// It appears at its value and moves only when the value really changes: a rebuild, a theme change or the tab
/// coming back never replays it from zero.
class ProgressRail extends StatelessWidget {
  const ProgressRail(this.value, {super.key, required this.label, this.color, this.track, this.height = 8});
  final double value;
  final String label;
  final Color? color, track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: label, value: '${(v * 100).round()} percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: v), duration: context.motion(Motion.progress), curve: Motion.curve,
          builder: (context, shown, _) => LinearProgressIndicator(value: shown, minHeight: height, color: color ?? context.c.accent, backgroundColor: track ?? context.c.sunken),
        ),
      ),
    );
  }
}

class Rule extends StatelessWidget {
  const Rule({super.key});
  @override
  Widget build(BuildContext context) => Divider(color: context.c.divider, height: 1);
}

/// A flat tappable row with a quiet separator below it.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.title, this.subtitle, this.icon, this.trailing, this.onTap, this.divider = true});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(children: [
        InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.navigation),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                if (icon != null) ...[Icon(icon, size: 24, color: context.c.text), const SizedBox(width: 14)],
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: context.sansStyle(16, weight: FontWeight.w500)),
                  if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: context.caption)),
                ])),
                if (trailing != null) Padding(padding: const EdgeInsets.only(left: 10), child: trailing) else if (onTap != null) Icon(Icons.chevron_right, size: 22, color: context.c.secondary),
              ]),
            ),
          ),
        ),
        if (divider) const Rule(),
      ]);
}

/// A bordered group of [GroupRow]s with thin inset separators between them (Me's "Personal", a meal's foods).
/// Give it rows, not other cards.
///
///     GroupCard(children: [GroupRow(...), GroupRow(...)])
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: context.c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel), side: BorderSide(color: context.c.divider)),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(color: context.c.divider, height: 1, indent: 16, endIndent: 16),
            child,
          ],
        ]),
      );
}

/// One row of a [GroupCard]: an [IconTile], a title, an optional second line, an optional value at the trailing
/// edge ("Blue · System") and a chevron when it opens something. With large text or a long value, the value moves
/// under the title instead of being cut, and at very large text the decorative tile gives its width to the words.
/// [trailing] replaces the chevron (a switch); [destructive] marks a row that erases something. Only give
/// [onTap] a real destination.
///
///     GroupRow(icon: Icons.palette_outlined, title: 'Appearance', value: 'Blue · System', onTap: openAppearance)
class GroupRow extends StatelessWidget {
  const GroupRow({super.key, required this.title, this.subtitle, this.icon, this.tone = Tone.accent, this.value, this.trailing, this.onTap, this.destructive = false});
  final String title;
  final String? subtitle, value;
  final IconData? icon;
  final Tone tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final roomy = MediaQuery.textScalerOf(context).scale(10) <= 15;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: roomy ? 16 : 12, vertical: 12),
        child: Row(children: [
          if (icon != null && roomy) ...[IconTile(icon!, tone: destructive ? Tone.error : tone), const SizedBox(width: 14)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              // The value shares the title's line while both fit, and drops under it when they do not.
              Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 2, children: [
                Text(title, style: context.sansStyle(16, weight: FontWeight.w600, color: destructive ? context.c.error : null)),
                if (value != null) Text(value!, style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w500)),
              ]),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 1), child: Text(subtitle!, style: context.caption)),
            ]),
          ),
          if (trailing != null) Padding(padding: const EdgeInsets.only(left: 10), child: trailing) else if (onTap != null) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right, size: 22, color: context.c.secondary)),
        ]),
      ),
    );
    return onTap == null ? row : Semantics(button: true, child: InkWell(onTap: onTap, child: row));
  }
}

/// A selectable choice with radio semantics. Selection shows as a tint, a heavier border and a filled mark.
class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({super.key, required this.value, required this.groupValue, required this.onChanged, required this.title, this.subtitle});
  final T value, groupValue;
  final ValueChanged<T> onChanged;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        inMutuallyExclusiveGroup: true, checked: selected, button: true,
        child: Material(
          color: selected ? context.c.accentSoft : context.c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field), side: BorderSide(color: selected ? context.c.accent : context.c.outline, width: selected ? 2 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (!selected) Haptics.selection();
              onChanged(value);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.primary),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 22, color: selected ? context.c.accent : context.c.outline),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: context.sansStyle(16, weight: selected ? FontWeight.w600 : FontWeight.w400)),
                    if (subtitle != null) Text(subtitle!, style: context.caption),
                  ])),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented choice: a recessed track with the chosen segment filled in the accent. With large text the
/// segments stack, so no label is ever shrunk or cut. Choosing another segment gives a selection tick.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.values, required this.selected, required this.label, required this.onChanged, this.keyPrefix});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  /// Each segment gets `Key('$keyPrefix-${value.name or value}')`.
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13.5;
    Widget segment(T v) {
      final on = v == selected;
      final name = v is Enum ? v.name : '$v';
      return Semantics(
        selected: on, button: true, inMutuallyExclusiveGroup: true,
        child: InkWell(
          key: keyPrefix == null ? null : Key('$keyPrefix-$name'),
          borderRadius: BorderRadius.circular(Radii.field - 2),
          onTap: () {
            if (!on) Haptics.selection();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: context.motion(Motion.quick), curve: Motion.curve,
            constraints: const BoxConstraints(minHeight: Targets.minimum),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: on ? context.c.accent : context.c.sunken, borderRadius: BorderRadius.circular(Radii.field - 2)),
            // Fill, weight and a strong luminance step mark the choice, so it also reads in grayscale.
            child: Text(label(v), textAlign: TextAlign.center, style: context.sansStyle(15, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? context.c.onAccent : context.c.text)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: context.c.sunken, borderRadius: BorderRadius.circular(Radii.field + 1)),
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final v in values) segment(v)])
          : Row(children: [for (final v in values) Expanded(child: segment(v))]),
    );
  }
}

/// A raised card on the page.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity, padding: padding,
      decoration: BoxDecoration(color: color ?? context.c.surface, borderRadius: BorderRadius.circular(Radii.panel), border: Border.all(color: context.c.divider)),
      child: child);
}

/// The training pass: a plan's name, calendar position and completed workouts on one calm card, in the same
/// surface and border as every other card (no gradient, shadow or stacked layer). It is not a payment card.
class PassCard extends StatelessWidget {
  const PassCard({super.key, required this.title, this.week, required this.count, required this.caption, required this.progress, this.onTap});
  final String title, count, caption;

  /// Calendar position ("Week 3 of 8"); separate from completion.
  final String? week;

  /// Null when there is nothing to measure yet.
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final percent = progress == null ? null : '${(progress!.clamp(0.0, 1.0) * 100).round()}%';
    final card = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Overline('Training plan'),
        const SizedBox(height: 4),
        Text(title, style: context.titleStyle(24)),
        if (week != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(week!, style: context.sansStyle(15, color: c.secondary, weight: FontWeight.w500))),
        const SizedBox(height: 14),
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
          Text(count, style: context.titleStyle(34)),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(caption, style: context.sansStyle(15, color: c.secondary))),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ProgressRail(progress!, label: caption)),
            const SizedBox(width: 12),
            Text(percent!, style: context.numStyle(15)),
          ]),
        ],
      ]),
    );
    return Semantics(
      container: true, button: onTap != null, onTap: onTap,
      label: '$title. ${week == null ? '' : '$week. '}$count ${caption.toLowerCase()}${percent == null ? '' : ', $percent'}.',
      child: ExcludeSemantics(child: onTap == null ? card : Pressable(onTap: onTap, child: card)),
    );
  }
}

/// Secondary page: back, large title, one scroll view that respects keyboard and safe areas.
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.title, required this.children, this.actions, this.bottom, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;

  /// Pinned primary action area; it rides above the keyboard.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(context.inset, 0, context.inset, 28);
    final content = [
      Heading(title, size: 30),
      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle!, style: context.sansStyle(16, color: context.c.secondary))),
      const SizedBox(height: 18),
      ...children,
    ];
    return Scaffold(
      appBar: AppBar(actions: actions),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            // A page with a pinned action is a form: it is short, and every field stays built while the keyboard
            // shrinks the page, so the field just tapped can never be dropped from under the user. Other pages
            // can be long histories and are laid out lazily.
            child: bottom != null
                ? SingleChildScrollView(
                    padding: padding, keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content))
                : ListView(padding: padding, keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: content),
          ),
          if (bottom != null) Padding(padding: EdgeInsets.fromLTRB(context.inset, 8, context.inset, 12), child: bottom),
        ]),
      ),
    );
  }
}

/// A specific confirmation. Returns true only when the named action was chosen. [destructive] fills the action
/// with the error colour, for something that cannot be undone.
Future<bool> confirm(BuildContext context, {required String title, required String body, required String action, String cancel = 'Cancel', bool destructive = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
          FilledButton(
              style: destructive ? FilledButton.styleFrom(backgroundColor: context.c.error, foregroundColor: context.c.page) : null,
              onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// A short confirmation. It is brief and can be swiped away, because while it shows it covers the bottom of the page.
void toast(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2200), dismissDirection: DismissDirection.horizontal));

/// The one way to open a modal bottom sheet: the system's shape and drag handle, [Motion.sheet] in with an ease-out
/// and [Motion.quick] out (no travel under Reduce Motion), above the keyboard and the home indicator, and scrolling
/// when its content is taller than the screen. [builder] returns the content only; padding, the optional [title]
/// and scrolling are provided. Close it with `Navigator.pop(context, result)`.
///
///     final unit = await showGoSheet<String>(context, title: 'Units', builder: (context) => Column(children: [...]));
Future<T?> showGoSheet<T>(BuildContext context, {required WidgetBuilder builder, String? title, bool isDismissible = true}) => showModalBottomSheet<T>(
      context: context, isScrollControlled: true, useSafeArea: true, isDismissible: isDismissible,
      sheetAnimationStyle: context.reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Motion.sheet, reverseDuration: Motion.quick, curve: Motion.curve, reverseCurve: Motion.exit),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (title != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Heading(title, size: 22)),
              builder(context),
            ]),
          ),
        ),
      ),
    );

/// Opens a page with the platform's own transition (interactive back on iOS). With Reduce Motion it simply appears.
Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MediaQuery.disableAnimationsOf(context)
    ? PageRouteBuilder(pageBuilder: (_, _, _) => page, transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero)
    : MaterialPageRoute(builder: (_) => page));

/// An honest starting state: what is true, and one useful next step.
class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.body, {super.key, this.action});
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Heading(title, size: 22, header: false),
          const SizedBox(height: 8),
          Text(body, style: context.sansStyle(16, color: context.c.secondary)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// The GH mark takes the foreground colour of the surface it sits on.
class GhMark extends StatelessWidget {
  const GhMark({super.key, this.height = 22});
  final double height;
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/evening-gh-mark.png', height: height, color: context.c.text, semanticLabel: 'GoHard');
}
