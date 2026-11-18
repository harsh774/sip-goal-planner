import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/auth_usecases.dart';

const _passwordsDontMatchText = 'Passwords don’t match.';

enum SaveStatus { idle, saving, saved }

class ProfileState extends Equatable {
  const ProfileState({
    this.nameStatus = SaveStatus.idle,
    this.nameFailure,
    this.passwordStatus = SaveStatus.idle,
    this.passwordFailure,
    this.updatedUser,
  });

  final SaveStatus nameStatus;
  final Failure? nameFailure;
  final SaveStatus passwordStatus;
  final Failure? passwordFailure;
  final User? updatedUser;

  Map<String?, FieldIssue> get nameErrors => _fields(nameFailure);
  Map<String?, FieldIssue> get passwordErrors => _fields(passwordFailure);

  static Map<String?, FieldIssue> _fields(Failure? f) =>
      f is ValidationFailure ? f.fieldErrors : const {};

  @override
  List<Object?> get props => [
    nameStatus,
    nameFailure,
    passwordStatus,
    passwordFailure,
    updatedUser,
  ];
}

/// The two independent forms on the profile page: name, and password.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required UpdateName updateName, required ChangePassword changePassword})
    : _updateName = updateName,
      _changePassword = changePassword,
      super(const ProfileState());

  final UpdateName _updateName;
  final ChangePassword _changePassword;

  Future<void> saveName(String firstName, String lastName) async {
    emit(_copy(nameStatus: SaveStatus.saving, nameFailure: null));
    final result = await _updateName(NameChange(firstName, lastName));
    emit(switch (result) {
      Success(value: final user) => _copy(nameStatus: SaveStatus.saved, updatedUser: user),
      Err(:final failure) => _copy(nameStatus: SaveStatus.idle, nameFailure: failure),
    });
  }

  Future<void> changePassword(String current, String next, String confirm) async {
    if (next != confirm) {
      emit(
        _copy(
          passwordFailure: const ValidationFailure({
            'confirm_password': FieldIssue('password_mismatch', _passwordsDontMatchText),
          }),
        ),
      );
      return;
    }
    emit(_copy(passwordStatus: SaveStatus.saving, passwordFailure: null));
    final result = await _changePassword(PasswordChange(current, next));
    emit(switch (result) {
      Success() => _copy(passwordStatus: SaveStatus.saved),
      Err(:final failure) => _copy(passwordStatus: SaveStatus.idle, passwordFailure: failure),
    });
  }

  ProfileState _copy({
    SaveStatus? nameStatus,
    Object? nameFailure = _keep,
    SaveStatus? passwordStatus,
    Object? passwordFailure = _keep,
    User? updatedUser,
  }) => ProfileState(
    nameStatus: nameStatus ?? state.nameStatus,
    nameFailure: identical(nameFailure, _keep) ? state.nameFailure : nameFailure as Failure?,
    passwordStatus: passwordStatus ?? state.passwordStatus,
    passwordFailure: identical(passwordFailure, _keep)
        ? state.passwordFailure
        : passwordFailure as Failure?,
    updatedUser: updatedUser ?? state.updatedUser,
  );

  static const _keep = Object();
}
