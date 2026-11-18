import '../../../../core/domain/currency.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
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

class Register implements UseCase<User, Credentials> {
  Register(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<User>> call(Credentials c) => _repo.register(email: c.email, password: c.password);
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

class UpdateDefaultCurrency implements UseCase<User, Currency> {
  UpdateDefaultCurrency(this._repo);

  final AuthRepository _repo;

  @override
  Future<Result<User>> call(Currency currency) => _repo.updateDefaultCurrency(currency);
}
