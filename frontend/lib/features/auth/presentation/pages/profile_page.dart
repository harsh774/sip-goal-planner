import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/profile_cubit.dart';

const _nameUpdatedText = 'Name updated.';
const _passwordChangedText = 'Password changed.';
const _myGoalsText = 'My goals';
const _profileText = 'Profile';
const _yourDetailsText = 'Your details';
const _firstNameText = 'First name';
const _lastNameOptionalText = 'Last name (optional)';
const _emailText = 'Email';
const _emailCantBeChangedText = 'Email can’t be changed.';
const _saveDetailsText = 'Save details';
const _changePasswordText = 'Change password';
const _currentPasswordText = 'Current password';
const _newPasswordText = 'New password';
const _atLeast8CharactersText = 'At least 8 characters, including a letter and a number.';
const _confirmNewPasswordText = 'Confirm new password';
const _couldntSaveText = 'Couldn’t save.';
const _showPasswordsText = 'Show passwords';
const _hidePasswordsText = 'Hide passwords';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileCubit>(),
      child: BlocListener<ProfileCubit, ProfileState>(
        listenWhen: (a, b) => a.nameStatus != b.nameStatus || a.passwordStatus != b.passwordStatus,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if ((state.nameStatus, state.updatedUser) case (SaveStatus.saved, final user?)) {
            context.read<AuthBloc>().add(AuthUserUpdated(user));
            messenger.showSnackBar(const SnackBar(content: Text(_nameUpdatedText)));
          }
          if (state.passwordStatus == SaveStatus.saved) {
            messenger.showSnackBar(const SnackBar(content: Text(_passwordChangedText)));
          }
        },
        child: const AppShell(child: _ProfileView()),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Align(
          alignment: .centerLeft,
          child: TextButton.icon(
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.goals),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text(_myGoalsText),
          ),
        ),
        const SizedBox(height: 8),
        const Text(_profileText, style: TextStyle(fontSize: 32)),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 800
              ? const Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(child: _NameForm()),
                    SizedBox(width: 24),
                    Expanded(child: _PasswordForm()),
                  ],
                )
              : const Column(children: [_NameForm(), SizedBox(height: 24), _PasswordForm()]),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.layer,
    padding: const .all(24),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: .w600)),
        const SizedBox(height: 24),
        ...children,
      ],
    ),
  );
}

class _NameForm extends StatefulWidget {
  const _NameForm();

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final _user = context.read<AuthBloc>().state.user;
  late final _first = TextEditingController(text: _user?.firstName);
  late final _last = TextEditingController(text: _user?.lastName);

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileCubit>().state;
    final errors = state.nameErrors;
    final general = state.nameFailure is ValidationFailure ? null : state.nameFailure?.message;

    return _Section(
      title: _yourDetailsText,
      children: [
        if (general != null) ...[_error(general), const SizedBox(height: 16)],
        TextField(
          controller: _first,
          textCapitalization: .words,
          decoration: InputDecoration(
            labelText: _firstNameText,
            errorText: errors['first_name']?.message,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _last,
          textCapitalization: .words,
          decoration: InputDecoration(
            labelText: _lastNameOptionalText,
            errorText: errors['last_name']?.message,
          ),
        ),
        const SizedBox(height: 24),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: _emailText,
            helperText: _emailCantBeChangedText,
          ),
          child: Text(_user?.email ?? '', style: const TextStyle(color: AppColors.text2)),
        ),
        const SizedBox(height: 32),
        Align(
          alignment: .centerRight,
          child: GoldButton(
            loading: state.nameStatus == SaveStatus.saving,
            onPressed: () => context.read<ProfileCubit>().saveName(_first.text, _last.text),
            child: const Text(_saveDetailsText),
          ),
        ),
      ],
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileCubit>().state;
    final errors = state.passwordErrors;
    final general = state.passwordFailure is ValidationFailure
        ? null
        : state.passwordFailure?.message;

    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => a.passwordStatus != b.passwordStatus,
      listener: (_, state) {
        if (state.passwordStatus == SaveStatus.saved) {
          for (final c in [_current, _next, _confirm]) {
            c.clear();
          }
        }
      },
      child: _Section(
        title: _changePasswordText,
        children: [
          if (general != null) ...[_error(general), const SizedBox(height: 16)],
          TextField(
            controller: _current,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: _currentPasswordText,
              errorText: errors['current_password']?.message,
              suffixIcon: IconButton(
                tooltip: _obscure ? _showPasswordsText : _hidePasswordsText,
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _next,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: _newPasswordText,
              helperText: _atLeast8CharactersText,
              errorText: errors['new_password']?.message,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: _confirmNewPasswordText,
              errorText: errors['confirm_password']?.message,
            ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: .centerRight,
            child: GoldButton(
              loading: state.passwordStatus == SaveStatus.saving,
              onPressed: () => context.read<ProfileCubit>().changePassword(
                _current.text,
                _next.text,
                _confirm.text,
              ),
              child: const Text(_changePasswordText),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _error(String message) => NoticeBanner(
  icon: Icons.error_outline,
  color: AppColors.danger,
  background: AppColors.dangerBg,
  title: _couldntSaveText,
  body: message,
);
