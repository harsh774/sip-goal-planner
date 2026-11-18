import 'package:characters/characters.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/domain/currency.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.defaultCurrency,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final Currency defaultCurrency;

  String get fullName => '$firstName $lastName'.trim();

  String get initials => [
    firstName,
    lastName,
  ].where((n) => n.isNotEmpty).map((n) => n.characters.first.toUpperCase()).join();

  @override
  List<Object?> get props => [id, email, firstName, lastName, defaultCurrency];
}
