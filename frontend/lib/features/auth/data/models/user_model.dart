import '../../../../core/domain/currency.dart';
import '../../domain/entities/user.dart';

abstract final class UserModel {
  static User fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String? ?? '',
    defaultCurrency: Currency.fromCode(json['default_currency'] as String),
  );
}
