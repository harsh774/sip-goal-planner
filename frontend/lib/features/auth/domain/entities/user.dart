import 'package:equatable/equatable.dart';

import '../../../../core/domain/currency.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.defaultCurrency,
  });

  final String id;
  final String email;
  final String displayName;
  final Currency defaultCurrency;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'[\s._-]+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  List<Object?> get props => [id, email, displayName, defaultCurrency];
}
