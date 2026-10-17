import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../me/account_repository.dart';

/// Optional body measurements. Weight is stored in kilograms and shown in the chosen unit.
class BodyMetricsScreen extends ConsumerStatefulWidget {
  const BodyMetricsScreen({super.key});
  @override
  ConsumerState<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends ConsumerState<BodyMetricsScreen> {
  final _weight = TextEditingController(), _fat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    _fat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(loadUnitProvider);
    final metrics = [for (final r in ref.watch(metricsProvider).value ?? const <Stored<BodyMetric>>[]) if (!r.value.isDeleted) r.value]..sort((a, b) => b.dayKey.compareTo(a.dayKey));
    return AppPage(title: 'Body measurements', children: [
      Text('Optional. Add a measurement only when it helps you; nothing here is required for a plan.', style: context.caption),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: TextField(key: const Key('metric-weight'), controller: _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Weight', suffixText: unit.name))),
        const SizedBox(width: 10),
        Expanded(child: TextField(key: const Key('metric-fat'), controller: _fat, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Body fat', suffixText: '%'))),
      ]),
      const SizedBox(height: 12),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      PrimaryButton('Add today\'s measurement', key: const Key('metric-save'), onPressed: () async {
        final w = parseNonNegative(_weight.text), f = parseNonNegative(_fat.text);
        if ((_weight.text.trim().isNotEmpty && w == null) || (_fat.text.trim().isNotEmpty && f == null)) return setState(() => _error = 'Enter numbers of zero or more, or leave a field blank.');
        try {
          await ref.read(activityRepositoryProvider).addMetric(ref.read(todayKeyProvider), weightKg: w == null ? null : loadInputToKg(w, unit), bodyFatPercent: f);
          _weight.clear();
          _fat.clear();
          setState(() => _error = null);
        } on AuthFailure catch (e) {
          setState(() => _error = e.message);
        } on LocalSaveFailure {
          setState(() => _error = 'That could not be saved on this phone. Your entry is still here.');
        }
      }),
      const SizedBox(height: 22),
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Overline('History')),
      if (metrics.isEmpty)
        Text('No measurements recorded.', style: context.caption)
      else
        GroupCard(children: [
          for (final m in metrics)
            GroupRow(
              title: [if (m.weightKg != null) formatLoad(m.weightKg, unit), if (m.bodyFatPercent != null) '${formatNumber(m.bodyFatPercent!)} % body fat'].join(' · '),
              subtitle: longDate(m.dayKey),
              trailing: IconButton(tooltip: 'Remove measurement', icon: const Icon(Icons.close, size: 20), onPressed: () async {
                if (await confirm(context, title: 'Remove this measurement?', body: 'The measurement from ${longDate(m.dayKey)} will be removed.', action: 'Remove', destructive: true)) await ref.read(activityRepositoryProvider).deleteMetric(m);
              }),
            ),
        ]),
    ]);
  }
}
