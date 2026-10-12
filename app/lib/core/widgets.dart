import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Shared Calm Momentum building blocks. Spacing and quiet separators come before containers; no card inside a card.

/// The main action: a filled accent pill, at least 52 px high.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.busy = false, this.expand = true, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy, expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.c.secondary, semanticsLabel: 'Working'))
        : Text(label, textAlign: TextAlign.center);
    final button = icon == null || busy
        ? FilledButton(onPressed: busy ? null : onPressed, child: child)
        : FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 22), label: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, required this.onPressed, this.expand = true, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, textAlign: TextAlign.center);
    final button = icon == null ? OutlinedButton(onPressed: onPressed, child: child) : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
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
          tween: Tween(end: v), duration: context.motion(Motion.large), curve: Curves.easeOutCubic,
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
            onTap: () => onChanged(value),
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
/// segments stack, so no label is ever shrunk or cut.
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
          borderRadius: BorderRadius.circular(99),
          onTap: () {
            if (!on) HapticFeedback.selectionClick();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: context.motion(Motion.quick), curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: Targets.minimum),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: on ? context.c.accent : context.c.sunken, borderRadius: BorderRadius.circular(99)),
            // Fill, weight and a strong luminance step mark the choice, so it also reads in grayscale.
            child: Text(label(v), textAlign: TextAlign.center, style: context.sansStyle(15, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? context.c.onAccent : context.c.text)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: context.c.sunken, borderRadius: BorderRadius.circular(stacked ? Radii.panel : 99)),
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

/// The training pass: a landscape card in a deep shade of the accent with a second layer behind its top edge.
/// It shows a plan's name, calendar position and completed workouts. It is not a payment card.
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
    const soft = Color(0xE6FFFFFF);
    final percent = progress == null ? null : '${(progress!.clamp(0.0, 1.0) * 100).round()}%';
    final card = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.hero),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.passTop, c.passBottom]),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('GoHard', style: context.sansStyle(14, color: soft, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(title, style: context.titleStyle(21, color: GoColors.onPass)),
                ]),
              ),
              if (week != null) Padding(padding: const EdgeInsets.only(left: 12, top: 1), child: Text(week!, style: context.sansStyle(14.5, color: GoColors.onPass, weight: FontWeight.w600))),
            ]),
            const SizedBox(height: 16),
            Text(count, style: context.titleStyle(40, color: GoColors.onPass)),
            Text(caption, style: context.sansStyle(15, color: soft)),
            if (progress != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: ExcludeSemantics(child: ProgressRail(progress!, label: caption, color: c.passFill, track: const Color(0x59000000), height: 10))),
                const SizedBox(width: 14),
                Text(percent!, style: context.sansStyle(16, color: GoColors.onPass, weight: FontWeight.w700)),
              ]),
            ],
          ]),
        ),
        if (onTap != null) Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: onTap))),
      ]),
    );
    return Semantics(
      container: true, button: onTap != null,
      label: '$title. ${week == null ? '' : '$week. '}$count ${caption.toLowerCase()}${percent == null ? '' : ', $percent'}.',
      child: ExcludeSemantics(
        child: Stack(children: [
          // The layer behind: a controlled hint of depth, nothing more.
          Positioned(top: 0, left: 16, right: 16, height: 40, child: DecoratedBox(decoration: BoxDecoration(color: Color.lerp(c.passTop, c.page, 0.45), borderRadius: BorderRadius.circular(Radii.hero)))),
          Padding(padding: const EdgeInsets.only(top: 9), child: card),
        ]),
      ),
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

/// A specific confirmation. Returns true only when the named action was chosen.
Future<bool> confirm(BuildContext context, {required String title, required String body, required String action, String cancel = 'Cancel'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// A short confirmation. It is brief and can be swiped away, because while it shows it covers the bottom of the page.
void toast(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2200), dismissDirection: DismissDirection.horizontal));

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
