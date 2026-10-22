import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/language.dart';
import '../../core/language_picker.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/session.dart' show SignOutReason;
import '../coach/coach_prefs.dart';
import '../me/account_repository.dart';
import 'account_security.dart';

/// Sign in or create an account. Typed values are kept through any failure.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController(), _password = TextEditingController(), _name = TextEditingController();
  bool _register = false, _busy = false, _showPassword = false;
  /// Worded at build time, so an error on screen follows a language change.
  String Function(AppLocalizations)? _error;

  /// Set when a password reset just finished here.
  bool _passwordReset = false;

  @override
  void initState() {
    super.initState();
    // After a password change the address that was signed in is filled in again.
    _email.text = ref.read(sessionsProvider).retainedEmail ?? '';
  }

  Future<void> _forgot() async {
    final email = await push<String>(context, ForgotPasswordScreen(email: _email.text.trim()));
    if (email == null || !mounted) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _register = false;
      _error = null;
      _passwordReset = true;
    });
  }

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
      setState(() => _error = (l) => l.authFillEveryField);
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
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final notice = switch (ref.watch(sessionsProvider).notice) {
      SignOutReason.expired => l.authNoticeExpired,
      SignOutReason.accountDeleted => l.authNoticeAccountDeleted,
      SignOutReason.passwordChanged => l.authNoticePasswordChanged,
      null => _passwordReset ? l.authNoticePasswordChanged : null,
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.inset, 28, context.inset, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // The badge and the wordmark in the serif, then the page title.
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const BrandBadge(),
              const SizedBox(width: 12),
              Flexible(child: Text(l.brandName, style: context.pageTitleStyle(34, color: context.c.accent))),
            ]),
            const SizedBox(height: 22),
            Heading(_register ? l.authCreateAccountTitle : l.authWelcomeBack, size: 40, serif: true),
            const SizedBox(height: 8),
            Text(_register ? l.authRegisterLead : l.authSignInLead,
                style: context.sansStyle(16, color: context.c.secondary)),
            const SizedBox(height: 20),
            PhotoPanel(
              photo: 'assets/images/workout-hero.webp',
              content: (context) => [
                const SizedBox(height: 6),
                Text(context.l10n.authTagline, style: context.pageTitleStyle(26)),
                const SizedBox(height: 6),
              ],
            ),
            const SizedBox(height: 22),
            if (notice != null) ...[Panel(padding: const EdgeInsets.all(14), child: StatusLine(Icons.info_outline, notice, tone: Tone.warning)), const SizedBox(height: 16)],
            if (_register) ...[
              TextField(key: const Key('auth-name'), controller: _name, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name], decoration: InputDecoration(labelText: l.authNameLabel)),
              const SizedBox(height: 12),
            ],
            TextField(key: const Key('auth-email'), controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autocorrect: false,
                autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: l.authEmailLabel)),
            const SizedBox(height: 12),
            TextField(key: const Key('auth-password'), controller: _password, obscureText: !_showPassword, autocorrect: false, enableSuggestions: false, onSubmitted: (_) => _submit(),
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l.authPasswordLabel, helperText: _register ? l.passwordRule : null, helperMaxLines: 3,
                  // The one visibility control: a labelled button that says what it will do.
                  suffixIcon: IconButton(
                    key: const Key('auth-show-password'), tooltip: _showPassword ? l.authHidePassword : l.authShowPassword,
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                )),
            // Recovery where it is needed: under the password, on sign-in only.
            if (!_register)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(key: const Key('auth-forgot'), onPressed: _busy ? null : _forgot, child: Text(l.authForgotPassword)),
              ),
            const SizedBox(height: 16),
            if (_error != null) ...[StatusLine(Icons.error_outline, _error!(l), tone: Tone.error), const SizedBox(height: 14)],
            PrimaryButton(_register ? l.authCreateAccountButton : l.authSignInButton, key: const Key('auth-submit'), onPressed: _submit, busy: _busy),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                key: const Key('auth-toggle'),
                onPressed: _busy ? null : () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
                child: Text(_register ? l.authToggleToSignIn : l.authToggleToRegister),
              ),
            ),
            // The language, without a step of its own: nothing is asked for or sent.
            const Center(child: LanguageButton()),
          ],
        ),
      ),
    );
  }
}
