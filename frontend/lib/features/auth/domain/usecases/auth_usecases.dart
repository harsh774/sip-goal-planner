import '../../../../core/domain/currency.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/new_account.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class Credentials {
  const Credentials(this.email, this.password);

  final String email;
  final String password;
}

class GetCurrentUser implements UseCase<User?, NoParams> {
  GetCurrentUser(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<User?>> call(NoParams _) => _repo.currentUser();
}

class Login implements UseCase<User, Credentials> {
  Login(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<User>> call(Credentials c) => _repo.login(email: c.email, password: c.password);
}

class Register implements UseCase<User, NewAccount> {
  Register(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<User>> call(NewAccount account) => _repo.register(account);
}

class Logout implements UseCase<void, NoParams> {
  Logout(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<void>> call(NoParams _) async {
    await _repo.logout();
    return const Success(null);
  }
}

class NameChange {
  const NameChange(this.firstName, this.lastName);

  final String firstName;
  final String lastName;
}

class PasswordChange {
  const PasswordChange(this.current, this.next);

  final String current;
  final String next;
}

class UpdateName implements UseCase<User, NameChange> {
  UpdateName(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<User>> call(NameChange c) =>
      _repo.updateName(firstName: c.firstName.trim(), lastName: c.lastName.trim());
}

class ChangePassword implements UseCase<void, PasswordChange> {
  ChangePassword(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<void>> call(PasswordChange c) =>
      _repo.changePassword(current: c.current, next: c.next);
}

class UpdateDefaultCurrency implements UseCase<User, Currency> {
  UpdateDefaultCurrency(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<User>> call(Currency currency) => _repo.updateDefaultCurrency(currency);
}
