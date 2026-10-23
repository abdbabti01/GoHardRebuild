import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/clock.dart' show dayKeyOf;
import '../../core/format.dart' show longDate, ltr;
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../me/account_repository.dart';

/// Password reset, password change and email verification (docs/AUTHENTICATION_EMAIL.md). Codes are typed or pasted
/// into one field; nothing here needs a link, a website or a particular mail app.

/// What the server says about these features: a server from before them, or one without a sender, is said up front.
const securityCapability = 'account.security', emailCapability = 'account.email';

/// Null when emailed codes can be asked for (or nothing is known yet: the request will say).
String? emailCodesBlocked(AppLocalizations l, Compatibility c) => c.capabilities == null
    ? null
    : !c.supports(securityCapability)
        ? l.accountErrorNotSupported
        : !c.supports(emailCapability)
            ? l.accountEmailUnavailable
            : null;

/// The one password rule, as the server applies it to every new password: 15 to 256 characters, any characters.
const passwordMin = 15, passwordMax = 256;
AuthError? checkNewPassword(String password, String confirmation) {
  final length = password.runes.length;
  if (length < passwordMin) return AuthError.weakPassword;
  if (length > passwordMax) return AuthError.passwordTooLong;
  if (password != confirmation) return AuthError.passwordMismatch;
  return null;
}

/// Digits from any script a keyboard or a pasted message may give (Arabic-Indic, Eastern Arabic, full-width) become
/// ASCII; everything else (spaces, dashes, words around a pasted code) is dropped. Leading zeros are kept.
String normalizeCode(String raw) {
  final out = StringBuffer();
  for (final r in raw.runes) {
    final d = switch (r) {
      >= 0x30 && <= 0x39 => r - 0x30,
      >= 0x660 && <= 0x669 => r - 0x660,
      >= 0x6F0 && <= 0x6F9 => r - 0x6F0,
      >= 0xFF10 && <= 0xFF19 => r - 0xFF10,
      _ => -1,
    };
    if (d >= 0) out.writeCharCode(0x30 + d);
  }
  return out.toString();
}

class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = normalizeCode(newValue.text);
    final text = digits.length > 8 ? digits.substring(0, 8) : digits;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// One accessible field for an 8-digit code: paste and one-time-code autofill, numbers keyboard, always left to right.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.onSubmitted});
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextField(
      key: const Key('code-field'), controller: controller, autofocus: true,
      keyboardType: TextInputType.number, textInputAction: TextInputAction.done, autocorrect: false, enableSuggestions: false,
      autofillHints: const [AutofillHints.oneTimeCode], inputFormatters: [_CodeFormatter()],
      textDirection: TextDirection.ltr, textAlign: TextAlign.center,
      style: context.sansStyle(26, weight: FontWeight.w600).copyWith(letterSpacing: 6, fontFeatures: const [FontFeature.tabularFigures()]),
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(labelText: l.codeFieldLabel, helperText: l.codeFieldHelper, helperMaxLines: 3),
    );
  }
}

/// A new password with its confirmation, show/hide, and the rule beside it.
class NewPasswordFields extends StatefulWidget {
  const NewPasswordFields({super.key, required this.password, required this.confirmation, this.onSubmitted});
  final TextEditingController password, confirmation;
  final VoidCallback? onSubmitted;
  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget eye() => IconButton(
          tooltip: _show ? l.authHidePassword : l.authShowPassword,
          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _show = !_show),
        );
    return AutofillGroup(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const Key('new-password'), controller: widget.password, obscureText: !_show, autocorrect: false, enableSuggestions: false,
          textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(labelText: l.newPasswordLabel, helperText: l.passwordRule, helperMaxLines: 3, suffixIcon: eye()),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('new-password-confirm'), controller: widget.confirmation, obscureText: !_show, autocorrect: false, enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword], onSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(labelText: l.newPasswordConfirmLabel),
        ),
      ]),
    );
  }
}

/// Counts down a resend cooldown, one rebuild a second while it runs.
mixin _Cooldown<T extends StatefulWidget> on State<T> {
  DateTime? _until;
  Timer? _tick;

  int get cooldownLeft => _until == null ? 0 : (_until!.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 3600);

  void startCooldown(int seconds) {
    _until = DateTime.now().add(Duration(seconds: seconds));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (cooldownLeft == 0) t.cancel();
    });
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

enum _ResetStep { email, code, password }

/// Forgot password: email → code → new password → back to sign-in with the address filled in. Pops with the address
/// when the password was changed. The reset authorization lives only in this screen's memory: after the app is closed,
/// a fresh code is asked for.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> with _Cooldown {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController(), _password = TextEditingController(), _confirmation = TextEditingController();
  var _step = _ResetStep.email;
  bool _busy = false, _uncertain = false;
  String? _resetToken;
  AuthFailure? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AuthRepository auth) action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(authRepositoryProvider));
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _uncertain = e.code == AuthError.uncertainReset;
        if (e.code == AuthError.cooldown) startCooldown(e.seconds ?? 60);
        // The authorization is gone or spent: only a fresh code helps.
        if (e.code == AuthError.resetExpired) _step = _ResetStep.email;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run((auth) async {
        if (_email.text.trim().isEmpty) throw const AuthFailure.of(AuthError.invalidEmail);
        final cooldown = await auth.requestReset(_email.text);
        if (!mounted) return;
        startCooldown(cooldown);
        _code.clear();
        setState(() => _step = _ResetStep.code);
      });

  Future<void> _verify() => _run((auth) async {
        if (_code.text.length != 8) throw const AuthFailure.of(AuthError.codeIncomplete);
        final token = await auth.verifyReset(_email.text, _code.text);
        if (!mounted) return;
        setState(() {
          _resetToken = token;
          _step = _ResetStep.password;
        });
      });

  Future<void> _complete() => _run((auth) async {
        if (checkNewPassword(_password.text, _confirmation.text) case final problem?) throw AuthFailure.of(problem);
        await auth.completeReset(_resetToken!, _password.text);
        if (mounted) Navigator.pop(context, _email.text.trim());
      });

  /// Back goes one step back (the code step returns to the address; a spent code cannot be re-entered, so the password
  /// step does too), and leaves from the first step.
  bool get _canLeave => _step == _ResetStep.email;
  void _back() => setState(() {
        _step = _ResetStep.email;
        _error = null;
        _uncertain = false;
        _resetToken = null;
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final blocked = emailCodesBlocked(l, ref.watch(compatibilityProvider));
    final error = _error == null ? null : Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!.text(l), tone: Tone.error));
    final (title, lead, Widget bottom, List<Widget> fields) = switch (_step) {
      _ResetStep.email => (
          l.resetTitle, l.resetEmailLead,
          Column(mainAxisSize: MainAxisSize.min, children: [
            ?error,
            PrimaryButton(l.resetSendCode, key: const Key('reset-send'), busy: _busy, onPressed: blocked != null || cooldownLeft > 0 ? null : _send),
          ]),
          [
            TextField(key: const Key('reset-email'), controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false,
                autofillHints: const [AutofillHints.email], textInputAction: TextInputAction.send, onSubmitted: (_) => blocked == null ? _send() : null,
                decoration: InputDecoration(labelText: l.authEmailLabel)),
            if (blocked != null) Padding(padding: const EdgeInsets.only(top: 14), child: StatusLine(Icons.mail_lock_outlined, blocked, tone: Tone.warning)),
            if (cooldownLeft > 0) Padding(padding: const EdgeInsets.only(top: 14), child: StatusLine(Icons.schedule, l.codeResendIn(cooldownLeft))),
          ],
        ),
      _ResetStep.code => (
          l.resetCodeTitle, l.resetCodeLead(ltr(_email.text.trim())),
          Column(mainAxisSize: MainAxisSize.min, children: [
            ?error,
            PrimaryButton(l.actionContinue, key: const Key('reset-verify'), busy: _busy, onPressed: _verify),
            TextButton(key: const Key('reset-resend'), onPressed: _busy || cooldownLeft > 0 ? null : _send,
                child: Text(cooldownLeft > 0 ? l.codeResendIn(cooldownLeft) : l.codeResend)),
            TextButton(key: const Key('reset-change-email'), onPressed: _busy ? null : _back, child: Text(l.resetUseAnotherEmail)),
          ]),
          [
            CodeField(controller: _code, onSubmitted: _verify),
            const SizedBox(height: 14),
            StatusLine(Icons.mark_email_unread_outlined, l.codeDeliveryNote),
          ],
        ),
      _ResetStep.password => (
          l.resetPasswordTitle, l.resetPasswordLead,
          Column(mainAxisSize: MainAxisSize.min, children: [
            ?error,
            if (_uncertain)
              TextButton(key: const Key('reset-go-sign-in'), onPressed: () => Navigator.pop(context, _email.text.trim()), child: Text(l.resetGoToSignIn)),
            PrimaryButton(l.resetSetPassword, key: const Key('reset-complete'), busy: _busy, onPressed: _uncertain ? null : _complete),
          ]),
          [NewPasswordFields(password: _password, confirmation: _confirmation, onSubmitted: _complete)],
        ),
    };
    return PopScope(
      canPop: _canLeave && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: AppPage(title: title, subtitle: lead, bottom: bottom, children: fields),
    );
  }
}

/// Signed in: current password, new password and its confirmation. Needs a connection; signs every device out.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController(), _password = TextEditingController(), _confirmation = TextEditingController();
  bool _busy = false, _showCurrent = false;
  AuthFailure? _error;

  @override
  void dispose() {
    for (final c in [_current, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    final problem = _current.text.isEmpty ? AuthError.wrongPassword : checkNewPassword(_password.text, _confirmation.text);
    if (problem != null) return setState(() => _error = AuthFailure.of(problem));
    if (!await confirm(context, title: l.changePasswordConfirmTitle, body: l.changePasswordConfirmBody, action: l.changePasswordButton) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the session ends here; the app returns to sign-in with this address filled in.
      await ref.read(authRepositoryProvider).changePassword(_current.text, _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final offline = ref.watch(connectionProvider) == false;
    return AppPage(
      title: l.changePasswordTitle,
      subtitle: l.changePasswordLead,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!.text(l), tone: Tone.error)),
        if (offline) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.cloud_off, l.changePasswordOffline)),
        PrimaryButton(l.changePasswordButton, key: const Key('change-password-submit'), busy: _busy, onPressed: offline ? null : _submit),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.actionCancel)),
      ]),
      children: [
        StatusLine(Icons.devices_outlined, l.changePasswordSignsOut, tone: Tone.warning),
        const SizedBox(height: 16),
        AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              key: const Key('current-password'), controller: _current, obscureText: !_showCurrent, autocorrect: false, enableSuggestions: false,
              textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: l.currentPasswordLabel,
                suffixIcon: IconButton(
                  tooltip: _showCurrent ? l.authHidePassword : l.authShowPassword,
                  icon: Icon(_showCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showCurrent = !_showCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            NewPasswordFields(password: _password, confirmation: _confirmation, onSubmitted: _submit),
          ]),
        ),
      ],
    );
  }
}

/// Signed in: send a code to the account's address and enter it. Proves the address only; nothing else changes.
///
/// [gate]: the new account's step before anything else (docs/AUTHENTICATION_EMAIL.md › Required verification). It is
/// the app's home then, so there is no Later and no Back: the ways out are verifying, Check again (verified elsewhere)
/// and signing out to use another account. Registration already sent the first code; opening it sends nothing.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.alreadySent = false, this.gate = false});

  /// Right after registration the first code was sent by the server.
  final bool alreadySent;
  final bool gate;
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> with _Cooldown {
  final _code = TextEditingController();
  late bool _sent = widget.alreadySent || widget.gate;
  bool _busy = false;
  AuthFailure? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AuthRepository auth) action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(authRepositoryProvider));
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        if (e.code == AuthError.cooldown) startCooldown(e.seconds ?? 60);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run((auth) async {
        final cooldown = await auth.requestVerification();
        if (!mounted) return;
        if (cooldown > 0) startCooldown(cooldown);
        setState(() => _sent = true);
      });

  Future<void> _confirm() => _run((auth) async {
        if (_code.text.length != 8) throw const AuthFailure.of(AuthError.codeIncomplete);
        await auth.confirmVerification(_code.text);
        if (!mounted) return;
        toast(context, context.l10n.verifyDone);
        // As the gate the app moves on by itself (setup, or Today); elsewhere this page closes.
        if (!widget.gate) Navigator.pop(context);
      });

  Future<void> _checkAgain() => _run((auth) async {
        await auth.checkAccess();
        if (mounted && !(ref.read(accountAccessProvider).value?.required ?? false)) toast(context, context.l10n.verifyDone);
      });

  Future<void> _signOut() async {
    final l = context.l10n;
    if (!await confirm(context, title: l.verifyGateSignOutTitle, body: l.verifyGateSignOutBody, action: l.meSignOut)) return;
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final email = ref.watch(sessionProvider)?.email ?? '';
    final access = ref.watch(accountAccessProvider).value;
    final verified = ref.watch(profileProvider).value?.emailVerified == true || (access?.verified ?? false);
    final blocked = emailCodesBlocked(l, ref.watch(compatibilityProvider));
    final due = access?.dueAt;
    final gate = widget.gate;
    return PopScope(
      canPop: !gate,
      child: AppPage(
        title: gate ? l.verifyGateTitle : l.verifyTitle,
        subtitle: gate ? l.verifyGateLead(ltr(email)) : l.verifyLead(ltr(email)),
        // The compact mark of the sign-in screen: the same account flow, one step on.
        above: gate
            ? Row(key: const Key('verify-gate'), children: [
                const BrandBadge(width: 32),
                const SizedBox(width: 10),
                Flexible(child: Text(l.brandName, style: context.pageTitleStyle(24, color: context.c.accent))),
              ])
            : null,
        bottom: verified && !gate
            ? PrimaryButton(l.actionDone, onPressed: () => Navigator.pop(context))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!.text(l), tone: Tone.error)),
                if (_sent) ...[
                  PrimaryButton(l.verifyConfirm, key: const Key('verify-confirm'), busy: _busy, onPressed: _confirm),
                  TextButton(key: const Key('verify-resend'), onPressed: _busy || cooldownLeft > 0 || blocked != null ? null : _send,
                      child: Text(cooldownLeft > 0 ? l.codeResendIn(cooldownLeft) : l.codeResend)),
                ] else
                  PrimaryButton(l.verifySend, key: const Key('verify-send'), busy: _busy, onPressed: blocked != null ? null : _send),
                if (gate) ...[
                  // Verified on another phone, or a confirmation whose answer never came back: ask, without a code.
                  TextButton(key: const Key('verify-check-again'), onPressed: _busy ? null : _checkAgain, child: Text(l.verifyCheckAgain)),
                  TextButton(key: const Key('verify-sign-out'), onPressed: _busy ? null : _signOut, child: Text(l.verifyGateSignOut)),
                ] else
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(l.verifyLater)),
              ]),
        children: [
          if (verified && !gate)
            StatusLine(Icons.verified_outlined, l.verifyVerified, tone: Tone.success)
          else ...[
            if (blocked != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: StatusLine(Icons.mail_lock_outlined, blocked, tone: Tone.warning)),
            if (_sent) ...[
              CodeField(controller: _code, onSubmitted: _confirm),
              const SizedBox(height: 14),
              StatusLine(Icons.mark_email_unread_outlined, l.codeDeliveryNote),
            ],
            const SizedBox(height: 14),
            Text(
                gate
                    ? l.verifyGateWhy
                    : access?.required ?? false
                        ? l.verifyPausedWhy
                        : due != null
                            ? l.verifyGraceWhy(longDate(dayKeyOf(due)))
                            : l.verifyScope,
                style: context.caption),
          ],
        ],
      ),
    );
  }
}
