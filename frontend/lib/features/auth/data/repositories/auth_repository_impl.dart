import '../../../../core/domain/currency.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/guard.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  @override
  Future<Result<User?>> currentUser() async {
    if (await _tokens.read() == null) return const Success(null);
    final result = await guard(_remote.me);
    // An invalid stored token is "logged out", not an error.
    if (result case Err(failure: AuthFailure())) {
      await _tokens.clear();
      return const Success(null);
    }
    return result;
  }

  @override
  Future<Result<User>> login({required String email, required String password}) => guard(() async {
    await _tokens.write(await _remote.login(email, password));
    return _remote.me();
  });

  @override
  Future<Result<User>> register({required String email, required String password}) async {
    final registered = await guard(() => _remote.register(email, password));
    if (registered case Err(:final failure)) return Err(failure);
    return login(email: email, password: password);
  }

  @override
  Future<void> logout() => _tokens.clear();

  @override
  Future<Result<User>> updateDefaultCurrency(Currency currency) =>
      guard(() => _remote.updateDefaultCurrency(currency));
}
