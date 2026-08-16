import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';

/// Two sign-in surfaces on one screen.
///
/// Staff use email and password; guardians have no password at all — per the
/// spec they authenticate with a one-time code sent to the number the academy
/// already has on file.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _rememberMe = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Prefill whatever they signed in with last time, if they asked us to.
    final auth = ref.read(authNotifierProvider);
    _rememberMe = auth.rememberMe;
    if (auth.savedIdentifier != null) _identifier.text = auth.savedIdentifier!;
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final isGuardian = auth.method == SignInMethod.guardianOtp;

    ref.listen(authNotifierProvider, (previous, next) {
      final error = next.error;
      if (error != null && error != previous?.error) {
        context.showSnack(error.message, isError: true);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Najath',
                      style: context.text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SegmentedButton<SignInMethod>(
                      segments: const [
                        ButtonSegment(
                          value: SignInMethod.staffPassword,
                          label: Text('Staff'),
                        ),
                        ButtonSegment(
                          value: SignInMethod.guardianOtp,
                          label: Text('Guardian'),
                        ),
                      ],
                      selected: {auth.method},
                      onSelectionChanged: auth.isBusy
                          ? null
                          : (selection) {
                              notifier.setMethod(selection.first);
                              _password.clear();
                              _code.clear();
                            },
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _identifier,
                      enabled: !auth.otpRequested,
                      keyboardType: isGuardian ? TextInputType.phone : TextInputType.emailAddress,
                      autofillHints: [
                        if (isGuardian) AutofillHints.telephoneNumber else AutofillHints.email,
                      ],
                      decoration: InputDecoration(
                        labelText: isGuardian ? 'Phone number' : 'Email',
                        prefixIcon: Icon(
                          isGuardian ? Icons.phone_outlined : Icons.mail_outline,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return isGuardian ? 'Enter your phone number' : 'Enter your email';
                        }
                        if (!isGuardian && !value.contains('@')) {
                          return 'That does not look like an email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!isGuardian)
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'Enter your password' : null,
                      )
                    else if (auth.otpRequested)
                      TextFormField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(
                          labelText: 'Six-digit code',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (value) => (value == null || value.trim().length < 4)
                            ? 'Enter the code we sent you'
                            : null,
                      ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _rememberMe,
                      onChanged: (value) => setState(() => _rememberMe = value ?? false),
                      title: const Text('Remember me'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: auth.isBusy ? null : _submit,
                      child: auth.isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_buttonLabel(isGuardian, auth.otpRequested)),
                    ),
                    if (isGuardian && auth.otpRequested) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: auth.isBusy ? null : () => notifier.requestOtp(_identifier.text),
                        child: const Text('Send the code again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buttonLabel(bool isGuardian, bool otpRequested) {
    if (!isGuardian) return 'Sign in';
    return otpRequested ? 'Verify code' : 'Send code';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = ref.read(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);

    if (auth.method == SignInMethod.staffPassword) {
      await notifier.signInWithEmail(
        email: _identifier.text,
        password: _password.text,
        rememberMe: _rememberMe,
      );
      return;
    }

    if (!auth.otpRequested) {
      await notifier.requestOtp(_identifier.text);
      return;
    }

    await notifier.verifyOtp(
      phoneNumber: _identifier.text,
      code: _code.text,
      rememberMe: _rememberMe,
    );
  }
}
