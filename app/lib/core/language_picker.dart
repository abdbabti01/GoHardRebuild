import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_prefs.dart';
import 'language.dart';
import 'theme.dart';
import 'widgets.dart';

/// What a language row shows: "System · English" or the chosen language's own name.
String languageValue(AppLocalizations l, AppLanguage choice, Locale resolved) => choice == AppLanguage.system
    ? '${l.languageSystem} · ${AppLanguage.values.firstWhere((a) => a.locale?.languageCode == resolved.languageCode).nativeName}'
    : choice.nativeName!;

/// The one language chooser: System, English, Français, العربية, each named in itself (no flags). Choosing applies at
/// once, on this phone only; nothing is signed out, reset, sent or asked for.
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) => showGoSheet<void>(context,
    title: context.l10n.languageTitle,
    builder: (sheet) => Consumer(builder: (sheet, ref, _) {
          final choice = ref.watch(devicePrefsProvider.select((p) => p.language));
          final resolved = resolveLocale(AppLanguage.system, ref.watch(deviceLocalesProvider));
          final l = sheet.l10n;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final a in AppLanguage.values)
              ChoiceTile<AppLanguage>(
                key: Key('language-${a.id}'),
                value: a, groupValue: choice,
                title: a.nativeName ?? l.languageSystem,
                subtitle: a == AppLanguage.system
                    ? l.languageSystemResolved(AppLanguage.values.firstWhere((x) => x.locale?.languageCode == resolved.languageCode).nativeName!)
                    : null,
                onChanged: ref.read(devicePrefsProvider.notifier).setLanguage,
              ),
            const SizedBox(height: 6),
            Text(l.languageFootnote, style: sheet.caption),
          ]);
        }));

/// The unobtrusive language control for the signed-out screen and setup: a quiet button naming the current choice.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(devicePrefsProvider.select((p) => p.language));
    final value = languageValue(context.l10n, choice, ref.watch(appLocaleProvider));
    return TextButton.icon(
      key: const Key('language-button'),
      onPressed: () => showLanguagePicker(context, ref),
      icon: const Icon(Icons.translate, size: 20),
      label: Text(value, semanticsLabel: '${context.l10n.languageTitle}: $value'),
    );
  }
}
