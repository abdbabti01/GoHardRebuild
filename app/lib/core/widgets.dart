import 'package:flutter/material.dart';

import 'theme.dart';

/// Shared Evening Club building blocks. Flat typography and quiet separators; no card inside a card.

/// The main action: warm ivory in dark mode, charcoal in light mode, pill shaped, at least 48 px high.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.busy = false, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final bool busy, expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.ec.secondary, semanticsLabel: 'Working'))
          : Text(label, textAlign: TextAlign.center),
    );
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
    final button = icon == null ? OutlinedButton(onPressed: onPressed, child: child) : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Small tracked label above a section ("YOUR TRAINING").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: context.label.copyWith(color: color));
}

class Serif extends StatelessWidget {
  const Serif(this.text, {super.key, this.size = 36, this.color, this.header = true});
  final String text;
  final double size;
  final Color? color;
  final bool header;
  @override
  Widget build(BuildContext context) => Semantics(header: header, child: Text(text, style: context.serifStyle(size, color: color)));
}

enum Tone { neutral, warning, error }

/// Status with an icon AND text; colour alone never carries meaning.
class StatusLine extends StatelessWidget {
  const StatusLine(this.icon, this.text, {super.key, this.tone = Tone.neutral, this.onColor});
  final IconData icon;
  final String text;
  final Tone tone;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final color = onColor ?? switch (tone) { Tone.warning => context.ec.warning, Tone.error => context.ec.error, Tone.neutral => context.ec.secondary };
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 17, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: context.sansStyle(13, color: color))),
    ]);
  }
}

class Rule extends StatelessWidget {
  const Rule({super.key});
  @override
  Widget build(BuildContext context) => Divider(color: context.ec.divider, height: 1);
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
                if (icon != null) ...[Icon(icon, size: 22, color: context.ec.secondary), const SizedBox(width: 14)],
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: context.sansStyle(16)),
                  if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: context.caption)),
                ])),
                if (trailing != null) Padding(padding: const EdgeInsets.only(left: 10), child: trailing) else if (onTap != null) Icon(Icons.chevron_right, size: 20, color: context.ec.secondary),
              ]),
            ),
          ),
        ),
        if (divider) const Rule(),
      ]);
}

/// A selectable choice with radio semantics and the selected surface.
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
          color: selected ? context.ec.selected : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field), side: BorderSide(color: selected ? context.ec.text : context.ec.divider)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.primary),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: selected ? context.ec.text : context.ec.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: context.sansStyle(15, weight: selected ? FontWeight.w600 : FontWeight.w400)),
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

/// A grouped review panel on the input surface.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color ?? context.ec.input, borderRadius: BorderRadius.circular(Radii.panel)), child: child);
}

/// Secondary page: back, serif heading, one scroll view that respects keyboard and safe areas.
class EveningPage extends StatelessWidget {
  const EveningPage({super.key, required this.title, required this.children, this.actions, this.bottom});
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  /// Pinned primary action area; it rides above the keyboard.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: actions),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 28),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [Serif(title), const SizedBox(height: 18), ...children],
              ),
            ),
            if (bottom != null) Padding(padding: EdgeInsets.fromLTRB(context.inset, 8, context.inset, 12), child: bottom),
          ]),
        ),
      );
}

/// A specific confirmation. Returns true only when the named action was chosen.
Future<bool> confirm(BuildContext context, {required String title, required String body, required String action, String cancel = 'Cancel'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// An honest starting state: what is true, and one useful next step.
class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.body, {super.key, this.action});
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Serif(title, size: 25, header: false),
          const SizedBox(height: 8),
          Text(body, style: context.sansStyle(15, color: context.ec.secondary)),
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
      Image.asset('assets/images/evening-gh-mark.png', height: height, color: context.ec.text, semanticLabel: 'GoHard');
}
