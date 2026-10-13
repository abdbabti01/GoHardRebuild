import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../me/account_repository.dart';

/// Sign in or create an account. Typed values are kept through any failure.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController(), _password = TextEditingController(), _name = TextEditingController();
  bool _register = false, _busy = false;
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
      await (_register ? auth.register(_email.text, _password.text, _name.text) : auth.signIn(_email.text, _password.text));
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
            // The mark sits where every tab has it: small, at the top trailing edge.
            const Align(alignment: Alignment.centerRight, child: GhMark()),
            const SizedBox(height: 32),
            Heading(_register ? 'Create your account' : 'Welcome back'),
            const SizedBox(height: 8),
            Text('Know what to do next, and keep a record of what you actually did.', style: context.sansStyle(16, color: context.c.secondary)),
            const SizedBox(height: 24),
            if (notice != null) ...[Panel(padding: const EdgeInsets.all(14), child: StatusLine(Icons.info_outline, notice, tone: Tone.warning)), const SizedBox(height: 16)],
            if (_register) ...[
              TextField(key: const Key('auth-name'), controller: _name, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Your name')),
              const SizedBox(height: 12),
            ],
            TextField(key: const Key('auth-email'), controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autocorrect: false,
                autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(key: const Key('auth-password'), controller: _password, obscureText: true, onSubmitted: (_) => _submit(),
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                decoration: InputDecoration(labelText: 'Password', helperText: _register ? 'At least 8 characters' : null)),
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
                child: Text(_register ? 'I already have an account' : 'Create an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
