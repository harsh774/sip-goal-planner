import '../../../../core/domain/currency.dart';
import '../../../../core/error/result.dart';
import '../entities/user.dart';

abstract interface class AuthRepository {
  /// The logged-in user, or `Success(null)` when there is no stored session.
  Future<Result<User?>> currentUser();

  Future<Result<User>> login({required String email, required String password});

  Future<Result<User>> register({required String email, required String password});

  Future<void> logout();

  Future<Result<User>> updateDefaultCurrency(Currency currency);
}
