import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import 'nutrient_coverage.dart';

/// Energy per gram used to weigh protein, carbs and fat against each other: the general Atwater factors (4, 4 and 9
/// kcal/g), the same convention as the target estimator's `macrosFor`. Used only for the share of each macro, never to
/// replace a recorded calorie total.
const macroKcalPerGram = {Nutrient.protein: 4, Nutrient.carbs: 4, Nutrient.fat: 9};
const macroOrder = [Nutrient.protein, Nutrient.carbs, Nutrient.fat];

/// What protein, carbs and fat make up, by the energy each contributes (docs/NUTRITION_RINGS.md › Macro composition).
/// Pure. A split exists only when every value behind it is known and their energy is above zero; otherwise there are
/// grams to show and no percentages, never the known part presented as a whole.
class MacroComposition {
  const MacroComposition(this.grams, {this.partial = const {}});

  /// A day's recorded foods, from the same coverage the rest of Eat reads. A macro no food has a value for is null;
  /// one some foods lack is [partial] (its grams are the known sum).
  factory MacroComposition.recorded(Map<Nutrient, NutrientTotal> t) => MacroComposition(
        {for (final n in macroOrder) n: t[n]!.hasAnyKnown ? t[n]!.knownTotal : null},
        partial: {for (final n in macroOrder) if (!t[n]!.isComplete) n},
      );

  final Map<Nutrient, double?> grams;
  final Set<Nutrient> partial;

  bool get complete => partial.isEmpty && macroOrder.every((n) => grams[n] != null);

  /// The energy the known grams stand for (kcal). Only a whole when [complete].
  double get kcal => macroOrder.fold(0.0, (s, n) => s + (grams[n] ?? 0) * macroKcalPerGram[n]!);

  /// Whole percentages of [kcal] that add up to 100 (largest remainder); null without a complete, non-zero split.
  Map<Nutrient, int>? get percents {
    final total = kcal;
    if (!complete || total <= 0) return null;
    final exact = {for (final n in macroOrder) n: grams[n]! * macroKcalPerGram[n]! * 100 / total};
    final out = {for (final n in macroOrder) n: exact[n]!.floor()};
    // Largest remainder first; a tie goes to the earlier macro (protein, carbs, fat), so the result never depends on sorting.
    double rest(Nutrient n) => exact[n]! - out[n]!;
    final byRemainder = [...macroOrder]..sort((a, b) {
        final d = rest(b).compareTo(rest(a));
        return d != 0 ? d : macroOrder.indexOf(a) - macroOrder.indexOf(b);
      });
    for (final n in byRemainder.take(100 - out.values.fold(0, (s, v) => s + v))) {
      out[n] = out[n]! + 1;
    }
    return out;
  }

  /// The share of the ring each macro takes (0–1), for drawing; empty without a split.
  Map<Nutrient, double> get fractions {
    final total = kcal;
    return percents == null ? const {} : {for (final n in macroOrder) n: grams[n]! * macroKcalPerGram[n]! / total};
  }
}

/// Fixed identity colours, the same in every theme and language: blue, orange, teal (never the goal green, gold or red,
/// so no macro reads as good or bad). Checked as a set for colour-vision separation and for 3:1 on the pale panels and
/// on Dark's page (theme_test). Always beside the macro's name: colour is never the only way to tell them apart.
Color macroColor(Nutrient n) => switch (n) {
      Nutrient.protein => const Color(0xFF2A78D6),
      Nutrient.carbs => const Color(0xFFC94F1D),
      _ => const Color(0xFF13866A),
    };

String macroName(AppLocalizations l, Nutrient n) => switch (n) {
      Nutrient.protein => l.eatProtein,
      Nutrient.carbs => l.eatCarbs,
      _ => l.eatFat,
    };

/// A composition donut with its legend (name, grams, percentage). Presentation only: it is handed a [MacroComposition]
/// and changes nothing. Without a split the ring is a plain track and the legend keeps the grams that are known. Read
/// out once, as one description; the drawing and the legend are not announced separately.
class MacroDonut extends StatelessWidget {
  const MacroDonut(this.m, {super.key, required this.title, required this.keyPrefix, required this.amount, this.notes = const []});
  final MacroComposition m;
  final String title, keyPrefix;

  /// The grams of a macro as shown ("120 g", "about 120 g").
  final String Function(Nutrient n, double grams) amount;

  /// Short lines under the legend (what the percentages are of, why the totals differ, why there is no split).
  final List<String> notes;

  static const size = 96.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.c;
    final pct = m.percents;
    String grams(Nutrient n) => m.grams[n] == null ? '—' : m.partial.contains(n) ? '${amount(n, m.grams[n]!)} · ${l.eatKnown}' : amount(n, m.grams[n]!);
    String said(Nutrient n) => [
          m.grams[n] == null ? l.eatNutrientUnknownSaid(macroName(l, n)) : l.eatSaidGrams(macroName(l, n), formatGrouped(m.grams[n]!)),
          if (m.grams[n] != null && m.partial.contains(n)) l.eatKnown,
          if (pct != null) formatPercent(pct[n]! / 100),
        ].join(l.eatListSeparator);
    final legend = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      for (final n in macroOrder)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.textScalerOf(context).scale(4)),
              child: DecoratedBox(decoration: BoxDecoration(color: macroColor(n), borderRadius: BorderRadius.circular(3)), child: const SizedBox.square(dimension: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 10, runSpacing: 0, children: [
                Text(macroName(l, n), style: context.sansStyle(15)),
                Wrap(spacing: 10, children: [
                  Text(grams(n), key: Key('$keyPrefix-macro-${n.name}'), style: context.numStyle(15, color: c.text, weight: FontWeight.w500)),
                  if (pct != null) Text(formatPercent(pct[n]! / 100), key: Key('$keyPrefix-macro-${n.name}-percent'), style: context.numStyle(15, color: c.secondary, weight: FontWeight.w500)),
                ]),
              ]),
            ),
          ]),
        ),
    ]);
    final ring = SizedBox.square(dimension: size, child: CustomPaint(key: Key('$keyPrefix-macro-donut'), painter: _DonutPainter(m.fractions, c.sunken)));
    return Semantics(
      container: true,
      label: [title, for (final n in macroOrder) said(n), ...notes].join('. '),
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: context.sansStyle(15, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= size + 16 + MediaQuery.textScalerOf(context).scale(190)
                ? Row(children: [ring, const SizedBox(width: 16), Expanded(child: legend)])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ring, const SizedBox(height: 10), legend]),
          ),
          for (final note in notes) Padding(padding: const EdgeInsets.only(top: 6), child: Text(note, style: context.caption)),
        ]),
      ),
    );
  }
}

/// The donut: a recessed track, and each macro's share as a segment from the top, clockwise, with a 2 px gap between
/// segments and flat ends (a share is drawn exactly, never lengthened by a round cap).
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.fractions, this.track);
  final Map<Nutrient, double> fractions;
  final Color track;
  static const stroke = 14.0, gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    final shown = [for (final n in macroOrder) if ((fractions[n] ?? 0) > 0) n];
    final gapAngle = shown.length > 1 ? gap / (rect.width / 2) : 0.0;
    var start = -math.pi / 2;
    for (final n in shown) {
      final sweep = 2 * math.pi * fractions[n]!;
      if (sweep > gapAngle) canvas.drawArc(rect, start + gapAngle / 2, sweep - gapAngle, false, paint..color = macroColor(n));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.track != track || old.fractions.toString() != fractions.toString();
}
