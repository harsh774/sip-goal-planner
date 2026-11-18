import '../../../../core/domain/currency.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/remote_call.dart';
import '../../domain/entities/new_account.dart';
import '../../domain/entities/user.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<User> register(NewAccount a) => remoteObject(
    () => _api.post(
      Endpoints.register,
      body: {
        'first_name': a.firstName,
        'last_name': a.lastName.isEmpty ? null : a.lastName,
        'email': a.email,
        'password': a.password,
      },
    ),
    UserModel.fromJson,
  );

  /// Returns the access token.
  Future<String> login(String email, String password) => remoteObject(
    () => _api.postForm(Endpoints.login, {'username': email, 'password': password}),
    (json) => json['access_token'] as String,
  );

  Future<User> me() => remoteObject(() => _api.get(Endpoints.me), UserModel.fromJson);

  Future<User> updateName({required String firstName, required String lastName}) => remoteObject(
    () => _api.patch(
      Endpoints.me,
      body: {'first_name': firstName, 'last_name': lastName.isEmpty ? null : lastName},
    ),
    UserModel.fromJson,
  );

  Future<void> changePassword({required String current, required String next}) => remoteVoid(
    () => _api.post(Endpoints.password, body: {'current_password': current, 'new_password': next}),
  );

  Future<User> updateDefaultCurrency(Currency currency) => remoteObject(
    () => _api.patch(Endpoints.me, body: {'default_currency': currency.code}),
    UserModel.fromJson,
  );
}
