import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/appearance.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../features/auth/auth_screen.dart';
import '../features/me/reminders.dart';
import '../features/shell/home_shell.dart';
import 'providers.dart';

class GoHardApp extends ConsumerStatefulWidget {
  const GoHardApp({super.key});
  @override
  ConsumerState<GoHardApp> createState() => _GoHardAppState();
}

class _GoHardAppState extends ConsumerState<GoHardApp> with WidgetsBindingObserver {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  /// On resume the shared date is re-read (midnight may have passed) and the account is contacted again.
  /// Neither resets navigation, an open form or a workout.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dateServiceProvider).refresh();
      ref.invalidate(reminderSyncProvider); // the phone's zone may have changed: re-time future reminders, never the plan's dates
      _refresh();
    }
  }

  void _refresh() {
    if (mounted && ref.read(ownerProvider) != null) unawaited(refreshFromAccount(ref));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderSyncProvider); // keeps scheduled reminders equal to the accepted plan; removes them when signed out
    final owner = ref.watch(ownerProvider);
    final appearance = ref.watch(appearanceProvider);
    ref.listen(profileProvider, (_, next) => ref.read(appearanceProvider.notifier).adoptAccountAppearance(next.value?.appearance));
    final accent = appearance.accent;
    return MaterialApp(
      title: 'GoHard',
      debugShowCheckedModeBanner: false,
      // System mode follows the phone as it changes; the accent stays. Increased Contrast gets its own variants.
      theme: goTheme(accent, Brightness.light),
      darkTheme: goTheme(accent, Brightness.dark),
      highContrastTheme: goTheme(accent, Brightness.light, highContrast: true),
      highContrastDarkTheme: goTheme(accent, Brightness.dark, highContrast: true),
      themeMode: appearance.mode,
      // A short cross-fade between looks, without movement. Navigation, drafts and timers are untouched by it.
      themeAnimationDuration: Motion.quick,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(value: Theme.of(context).appBarTheme.systemOverlayStyle!, child: child!),
      home: AppConfig.problem != null
          ? _ConfigProblem(AppConfig.problem!)
          : owner == null
              ? const AuthScreen()
              // Keyed by owner: switching accounts rebuilds the whole shell with none of the previous owner's state.
              : HomeShell(key: ValueKey(owner)),
    );
  }
}

class _ConfigProblem extends StatelessWidget {
  const _ConfigProblem(this.problem);
  final String problem;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(context.inset),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Heading('Not configured', size: 30),
              const SizedBox(height: 12),
              Text(problem, style: context.body),
              const SizedBox(height: 12),
              Text('This build has no default server on purpose. Start it with the development script so it knows which API to use.', style: context.caption),
            ]),
          ),
        ),
      );
}
