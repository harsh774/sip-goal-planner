import '../../../../core/domain/currency.dart';
import '../../domain/entities/user.dart';

abstract final class UserModel {
  static User fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String,
    defaultCurrency: Currency.fromCode(json['default_currency'] as String),
  );
}
