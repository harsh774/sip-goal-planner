import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/disclaimer.dart';
import '../../../../shared/widgets/state_views.dart';
import '../bloc/auth_bloc.dart';

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.mode});

  final AuthMode mode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
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
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final bloc = context.read<AuthBloc>();
    if (_isRegister && _password.text != _confirm.text) {
      setState(() => _confirmError = 'Passwords don’t match.');
      return;
    }
    setState(() => _confirmError = null);
    final email = _email.text.trim();
    bloc.add(
      _isRegister
          ? AuthRegisterRequested(email, _password.text)
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
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const AppLogo(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= Breakpoints.compact;
          final card = _card(state, fieldErrors);
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: wide ? 48 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
                child: Column(
                  children: [
                    wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 448, child: card),
                              const SizedBox(width: 48),
                              const Expanded(child: _Benefits()),
                            ],
                          )
                        : card,
                    const Disclaimer(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(AuthState state, Map<String?, FieldIssue> fieldErrors) {
    final generalError = switch (state.failure) {
      null || ValidationFailure() => null,
      final failure => failure.message,
    };

    return Container(
      color: AppColors.layer,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isRegister ? 'Create your account' : 'Log in',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _isRegister ? 'Already have an account?' : 'New here?',
                  style: const TextStyle(color: AppColors.text2),
                ),
                TextButton(
                  onPressed: () => context.go(_isRegister ? Routes.login : Routes.register),
                  child: Text(_isRegister ? 'Log in' : 'Create an account'),
                ),
              ],
            ),
            if (generalError != null) ...[
              const SizedBox(height: 8),
              NoticeBanner(
                icon: Icons.error_outline,
                color: AppColors.danger,
                background: AppColors.dangerBg,
                title: _isRegister ? 'Couldn’t create your account.' : 'Couldn’t log you in.',
                body: generalError,
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Email',
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
                labelText: 'Password',
                helperText: _isRegister
                    ? 'At least 8 characters, including a letter and a number.'
                    : null,
                errorText: fieldErrors['password']?.message,
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
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
                  labelText: 'Confirm password',
                  errorText: _confirmError,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: state.submitting ? null : _submit,
              child: state.submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegister ? 'Create account' : 'Log in'),
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
    (
      Icons.flag_outlined,
      'Set a goal',
      'A home, a car, education, retirement — add as many as you like.',
    ),
    (
      Icons.calendar_month_outlined,
      'See your monthly SIP',
      'How much to invest each month, and how a yearly increase changes it.',
    ),
    (
      Icons.trending_down,
      'Know what it’s really worth',
      'See your goal in today’s money after price rise.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Plan for anything you’re saving towards', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 16),
        for (final (icon, title, body) in _items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.gold, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
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
