import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../../../shared/widgets/world_network_background.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/new_account.dart';
import '../bloc/auth_bloc.dart';

const _firstNameText = 'First name';
const _lastNameOptionalText = 'Last name (optional)';
const _emailText = 'Email';
const _passwordText = 'Password';
const _confirmPasswordText = 'Confirm password';
const _planForAnythingYoureText = 'Plan for anything you’re saving towards';
const _passwordsDontMatchText = 'Passwords don’t match.';
const _createYourAccountText = 'Create your account';
const _logInText = 'Log in';
const _alreadyHaveAnAccountText = 'Already have an account?';
const _newHereText = 'New here?';
const _createAnAccountText = 'Create an account';
const _couldntCreateYourAccountText = 'Couldn’t create your account.';
const _couldntLogYouInText = 'Couldn’t log you in.';
const _atLeast8CharactersText = 'At least 8 characters, including a letter and a number.';
const _showPasswordText = 'Show password';
const _hidePasswordText = 'Hide password';
const _createAccountText = 'Create account';
const _setAGoalText = 'Set a goal';
const _aHomeACarText = 'A home, a car, education, retirement — add as many as you like.';
const _seeYourMonthlySipText = 'See your monthly SIP';
const _howMuchToInvestText = 'How much to invest each month, and how a yearly increase changes it.';
const _knowWhatItsReallyText = 'Know what it’s really worth';
const _seeYourGoalInText = 'See your goal in today’s money after price rise.';

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.mode});

  final AuthMode mode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _confirmError;

  bool get _isRegister => widget.mode == AuthMode.register;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthFailureCleared());
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final bloc = context.read<AuthBloc>();
    if (_isRegister && _password.text != _confirm.text) {
      setState(() => _confirmError = _passwordsDontMatchText);
      return;
    }
    setState(() => _confirmError = null);
    final email = _email.text.trim();
    bloc.add(
      _isRegister
          ? AuthRegisterRequested(
              NewAccount(
                firstName: _firstName.text.trim(),
                lastName: _lastName.text.trim(),
                email: email,
                password: _password.text,
              ),
            )
          : AuthLoginRequested(email, _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final fieldErrors = switch (state.failure) {
      ValidationFailure(:final fieldErrors) => fieldErrors,
      _ => const <String?, FieldIssue>{},
    };

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: AppColors.header,
          alignment: .centerLeft,
          padding: const .symmetric(horizontal: 16),
          child: const AppLogo(),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: WorldNetworkBackground()),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= Breakpoints.compact;
              final card = _card(state, fieldErrors);
              return FooterScrollView(
                padding: .fromLTRB(16, wide ? 48 : 24, 16, 32),
                child: wide
                    ? Row(
                        crossAxisAlignment: .start,
                        children: [
                          SizedBox(width: 448, child: card),
                          const SizedBox(width: 48),
                          const Expanded(child: _Benefits()),
                        ],
                      )
                    : card,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card(AuthState state, Map<String?, FieldIssue> fieldErrors) {
    final generalError = switch (state.failure) {
      null || ValidationFailure() => null,
      final failure => failure.message,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.layer.withValues(alpha: 0.92),
        borderRadius: .circular(16),
        border: .all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 32, offset: Offset(0, 12))],
      ),
      padding: const .symmetric(horizontal: 24, vertical: 32),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Text(
              _isRegister ? _createYourAccountText : _logInText,
              style: const TextStyle(fontSize: 28, fontWeight: .w400),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _isRegister ? _alreadyHaveAnAccountText : _newHereText,
                  style: const TextStyle(color: AppColors.text2),
                ),
                TextButton(
                  onPressed: () => context.go(_isRegister ? Routes.login : Routes.register),
                  child: Text(_isRegister ? _logInText : _createAnAccountText),
                ),
              ],
            ),
            if (generalError != null) ...[
              const SizedBox(height: 8),
              NoticeBanner(
                icon: Icons.error_outline,
                color: AppColors.danger,
                background: AppColors.dangerBg,
                title: _isRegister ? _couldntCreateYourAccountText : _couldntLogYouInText,
                body: generalError,
              ),
            ],
            if (_isRegister) ...[
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      autofillHints: const [AutofillHints.givenName],
                      textCapitalization: .words,
                      textInputAction: .next,
                      decoration: InputDecoration(
                        labelText: _firstNameText,
                        errorText: fieldErrors['first_name']?.message,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _lastName,
                      autofillHints: const [AutofillHints.familyName],
                      textCapitalization: .words,
                      textInputAction: .next,
                      decoration: InputDecoration(
                        labelText: _lastNameOptionalText,
                        errorText: fieldErrors['last_name']?.message,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: .emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: .next,
              decoration: InputDecoration(
                labelText: _emailText,
                errorText: fieldErrors['email']?.message,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: [_isRegister ? AutofillHints.newPassword : AutofillHints.password],
              textInputAction: _isRegister ? TextInputAction.next : TextInputAction.done,
              onSubmitted: _isRegister ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: _passwordText,
                helperText: _isRegister ? _atLeast8CharactersText : null,
                errorText: fieldErrors['password']?.message,
                suffixIcon: IconButton(
                  tooltip: _obscure ? _showPasswordText : _hidePasswordText,
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_isRegister) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: _confirmPasswordText,
                  errorText: _confirmError,
                ),
              ),
            ],
            const SizedBox(height: 32),
            GoldButton(
              onPressed: _submit,
              loading: state.submitting,
              child: Text(_isRegister ? _createAccountText : _logInText),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  static const _items = [
    (Icons.flag_outlined, _setAGoalText, _aHomeACarText),
    (Icons.calendar_month_outlined, _seeYourMonthlySipText, _howMuchToInvestText),
    (Icons.trending_down, _knowWhatItsReallyText, _seeYourGoalInText),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        const Text(_planForAnythingYoureText, style: TextStyle(fontSize: 20)),
        const SizedBox(height: 16),
        for (final (icon, title, body) in _items)
          Container(
            padding: const .symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Icon(icon, color: AppColors.gold, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: .w600, fontSize: 16)),
                      Text(body, style: const TextStyle(color: AppColors.text2, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
