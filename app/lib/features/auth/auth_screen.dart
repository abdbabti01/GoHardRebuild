import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../coach/coach_prefs.dart';
import '../me/account_repository.dart';

/// Sign in or create an account. Typed values are kept through any failure.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController(), _password = TextEditingController(), _name = TextEditingController();
  bool _register = false, _busy = false, _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_email.text.trim().isEmpty || _password.text.isEmpty || (_register && _name.text.trim().isEmpty)) {
      setState(() => _error = 'Fill in every field to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      final coach = ref.read(coachPrefsProvider.notifier);
      await (_register ? auth.register(_email.text, _password.text, _name.text, onCreated: coach.startSetup) : auth.signIn(_email.text, _password.text));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(sessionsProvider).notice;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.inset, 28, context.inset, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // The wordmark in the serif, then the page title.
            Center(child: Text('GoHard', style: context.pageTitleStyle(34, color: context.c.accent))),
            const SizedBox(height: 22),
            Heading(_register ? 'Create account' : 'Welcome back', size: 40, serif: true),
            const SizedBox(height: 8),
            Text(_register ? 'Know what to do next, and keep a record of what you actually did.' : 'Sign in to pick up where you left off.',
                style: context.sansStyle(16, color: context.c.secondary)),
            const SizedBox(height: 20),
            PhotoPanel(
              photo: 'assets/images/workout-hero.webp',
              content: (context) => [
                const SizedBox(height: 6),
                Text('Plan it.\nRecord it.\nKeep going.', style: context.pageTitleStyle(26)),
                const SizedBox(height: 6),
              ],
            ),
            const SizedBox(height: 22),
            if (notice != null) ...[Panel(padding: const EdgeInsets.all(14), child: StatusLine(Icons.info_outline, notice, tone: Tone.warning)), const SizedBox(height: 16)],
            if (_register) ...[
              TextField(key: const Key('auth-name'), controller: _name, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Your name')),
              const SizedBox(height: 12),
            ],
            TextField(key: const Key('auth-email'), controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autocorrect: false,
                autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(key: const Key('auth-password'), controller: _password, obscureText: !_showPassword, autocorrect: false, enableSuggestions: false, onSubmitted: (_) => _submit(),
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password', helperText: _register ? 'At least 8 characters' : null,
                  // The one visibility control: a labelled button that says what it will do.
                  suffixIcon: IconButton(
                    key: const Key('auth-show-password'), tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                )),
            const SizedBox(height: 16),
            if (_error != null) ...[StatusLine(Icons.error_outline, _error!, tone: Tone.error), const SizedBox(height: 14)],
            PrimaryButton(_register ? 'Create account' : 'Sign in', key: const Key('auth-submit'), onPressed: _submit, busy: _busy),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                key: const Key('auth-toggle'),
                onPressed: _busy ? null : () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
                child: Text(_register ? 'I already have an account · Sign in' : 'New to GoHard? Create account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
