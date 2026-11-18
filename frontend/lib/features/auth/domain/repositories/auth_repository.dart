import '../../../../core/domain/currency.dart';
import '../../../../core/error/result.dart';
import '../entities/new_account.dart';
import '../entities/user.dart';

abstract interface class AuthRepository {
  /// The logged-in user, or `Success(null)` when there is no stored session.
  Future<Result<User?>> currentUser();

  Future<Result<User>> login({required String email, required String password});

  Future<Result<User>> register(NewAccount account);

  Future<void> logout();

  Future<Result<User>> updateDefaultCurrency(Currency currency);

  Future<Result<User>> updateName({required String firstName, required String lastName});

  Future<Result<void>> changePassword({required String current, required String next});
}
