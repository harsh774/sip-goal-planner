import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/core/error/failure.dart';
import 'package:sip_goal_planner/core/error/result.dart';
import 'package:sip_goal_planner/features/auth/data/models/user_model.dart';
import 'package:sip_goal_planner/features/auth/domain/entities/user.dart';
import 'package:sip_goal_planner/features/auth/domain/usecases/auth_usecases.dart';
import 'package:sip_goal_planner/features/auth/presentation/bloc/profile_cubit.dart';

class _MockUpdateName extends Mock implements UpdateName {}

class _MockChangePassword extends Mock implements ChangePassword {}

const _user = User(
  id: '1',
  email: 'priya@example.com',
  firstName: 'Priya',
  lastName: '',
  defaultCurrency: Currency.inr,
);

void main() {
  late _MockUpdateName updateName;
  late _MockChangePassword changePassword;

  setUpAll(() {
    registerFallbackValue(const NameChange('', ''));
    registerFallbackValue(const PasswordChange('', ''));
  });

  setUp(() {
    updateName = _MockUpdateName();
    changePassword = _MockChangePassword();
  });

  ProfileCubit build() => ProfileCubit(updateName: updateName, changePassword: changePassword);

  blocTest<ProfileCubit, ProfileState>(
    'saving a name returns the updated user',
    setUp: () => when(() => updateName(any())).thenAnswer((_) async => const Success(_user)),
    build: build,
    act: (c) => c.saveName('Priya', ''),
    expect: () => const [
      ProfileState(nameStatus: SaveStatus.saving),
      ProfileState(nameStatus: SaveStatus.saved, updatedUser: _user),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'mismatched new passwords never reach the server',
    build: build,
    act: (c) => c.changePassword('secret123', 'fresh123', 'fresh124'),
    verify: (c) {
      expect(c.state.passwordErrors.keys, ['confirm_password']);
      verifyNever(() => changePassword(any()));
    },
  );

  blocTest<ProfileCubit, ProfileState>(
    'a wrong current password shows on that field',
    setUp: () => when(() => changePassword(any())).thenAnswer(
      (_) async => const Err(
        ValidationFailure({
          'current_password': FieldIssue('password_incorrect', 'Current password is incorrect.'),
        }),
      ),
    ),
    build: build,
    act: (c) => c.changePassword('nope1234', 'fresh123', 'fresh123'),
    verify: (c) {
      expect(c.state.passwordStatus, SaveStatus.idle);
      expect(c.state.passwordErrors['current_password']?.code, 'password_incorrect');
    },
  );

  test('a missing last name reads as empty and is left out of initials', () {
    final user = UserModel.fromJson({
      'id': '1',
      'email': 'solo@example.com',
      'first_name': 'Madonna',
      'last_name': null,
      'default_currency': 'INR',
    });
    expect((user.lastName, user.fullName, user.initials), ('', 'Madonna', 'M'));
  });
}
