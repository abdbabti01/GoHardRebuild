import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/appearance.dart';
import '../core/compatibility.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
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
      _check();
    }
  }

  /// Start and resume only: first whether this build is still accepted, then the account. A check that gets no
  /// answer changes nothing, so being offline works exactly as before.
  Future<void> _check() async {
    if (AppConfig.problem != null) return;
    await ref.read(compatibilityProvider.notifier).check();
    _refresh();
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
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).appBarTheme.systemOverlayStyle!,
          child: CompatibilityGate(child: child!)),
      home: AppConfig.problem != null
          ? _ConfigProblem(AppConfig.problem!)
          : owner == null
              ? const AuthScreen()
              // Keyed by owner: switching accounts rebuilds the whole shell with none of the previous owner's state.
              : HomeShell(key: ValueKey(owner)),
    );
  }
}

/// Draws the update notice over the app while this build is confirmed too old, rather than replacing the app:
/// whatever was open underneath, with everything typed into it, is still there the moment a check passes.
class CompatibilityGate extends ConsumerWidget {
  const CompatibilityGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(compatibilityProvider).blocked
      ? Stack(children: [ExcludeFocus(child: ExcludeSemantics(child: child)), const Positioned.fill(child: UpdateRequiredScreen())])
      : child;
}

/// This build is older than the account's server accepts. Nothing is sent while this shows, and nothing is lost:
/// what was saved on the phone waits in the outbox for an updated app, or for a check that passes.
class UpdateRequiredScreen extends ConsumerStatefulWidget {
  const UpdateRequiredScreen({super.key});
  @override
  ConsumerState<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends ConsumerState<UpdateRequiredScreen> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.inset),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Heading('Update GoHard to continue', size: 30),
            const SizedBox(height: 12),
            Text('This version of the app is too old for your account\'s server, so it has stopped syncing.', style: context.body),
            const SizedBox(height: 12),
            StatusLine(Icons.phone_iphone, pending == 0
                ? 'Everything you saved on this phone is still here.'
                : 'Everything you saved on this phone is still here, including $pending change${pending == 1 ? '' : 's'} waiting to sync. They will sync after you update.'),
            const SizedBox(height: 22),
            SecondaryButton('Check again', key: const Key('compat-recheck'), onPressed: _checking
                ? null
                : () async {
                    setState(() => _checking = true);
                    await ref.read(compatibilityProvider.notifier).check();
                    if (mounted) setState(() => _checking = false);
                    // Passed: this screen is gone and the waiting changes can go.
                    if (!ref.read(compatibilityProvider).blocked) ref.read(syncProvider).kick();
                  }),
          ]),
        ),
      ),
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
