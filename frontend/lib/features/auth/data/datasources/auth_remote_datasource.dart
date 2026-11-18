import '../../../../core/domain/currency.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../domain/entities/new_account.dart';
import '../../domain/entities/user.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<User> register(NewAccount a) async {
    final json = await _api.post(
      Endpoints.register,
      body: {
        'first_name': a.firstName,
        'last_name': a.lastName,
        'email': a.email,
        'password': a.password,
      },
    );
    return UserModel.fromJson(json! as Map<String, dynamic>);
  }

  /// Returns the access token.
  Future<String> login(String email, String password) async {
    final json = await _api.postForm(Endpoints.login, {'username': email, 'password': password});
    return (json! as Map<String, dynamic>)['access_token'] as String;
  }

  Future<User> me() async {
    final json = await _api.get(Endpoints.me);
    return UserModel.fromJson(json! as Map<String, dynamic>);
  }

  Future<User> updateDefaultCurrency(Currency currency) async {
    final json = await _api.patch(Endpoints.me, body: {'default_currency': currency.code});
    return UserModel.fromJson(json! as Map<String, dynamic>);
  }
}
