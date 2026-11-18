import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../entities/goal.dart';
import '../entities/goal_type.dart';

/// Raw form input, as the user typed it.
class GoalFormInput {
  const GoalFormInput({
    required this.name,
    required this.type,
    required this.currency,
    required this.targetAmount,
    required this.targetDate,
    required this.currentCorpus,
    required this.expectedReturn,
    required this.annualStepUp,
    required this.inflation,
  });

  final String name;
  final GoalType? type;
  final Currency currency;
  final String targetAmount;
  final DateTime? targetDate;
  final String currentCorpus;
  final String expectedReturn;
  final String annualStepUp;
  final String inflation;
}

class GoalValidation {
  const GoalValidation(this.draft, this.errors);

  /// Non-null only when [errors] is empty.
  final GoalDraft? draft;

  /// Keyed by API field name, so server errors land on the same fields.
  final Map<String, String> errors;

  bool get isValid => draft != null;
}

/// Mirrors the API's rules (docs/LLD.md §5) so most mistakes are caught before a request.
abstract final class GoalFormValidator {
  static const maxAmount = 1000000000000 * 100;

  static GoalValidation validate(GoalFormInput input, {required DateTime today}) {
    final errors = <String, String>{};

    final name = input.name.trim();
    if (name.isEmpty) errors['name'] = 'Name is required.';
    if (name.length > 100) errors['name'] = 'Use at most 100 characters.';
    if (input.type == null) errors['goal_type'] = 'Choose a goal type.';

    final target = _money(input.targetAmount, input.currency, 'target_amount', errors);
    if (target != null && target <= 0) {
      errors['target_amount'] = 'Target amount must be greater than 0.';
    }
    final corpus = input.currentCorpus.trim().isEmpty
        ? 0
        : _money(input.currentCorpus, input.currency, 'current_corpus', errors);
    if (corpus != null && corpus < 0) {
      errors['current_corpus'] = 'Amount already invested cannot be negative.';
    }

    final date = input.targetDate;
    final day = DateTime(today.year, today.month, today.day);
    if (date == null) {
      errors['target_date'] = 'Choose a target date.';
    } else if (!date.isAfter(day)) {
      errors['target_date'] = 'Target date must be in the future.';
    } else if (date.year > today.year + 100) {
      errors['target_date'] = 'Target date must be within 100 years.';
    }

    final ret = _rate(input.expectedReturn, 30, 'Expected return', 'expected_return_pct', errors);
    final step = _rate(input.annualStepUp, 25, 'Yearly increase', 'annual_step_up_pct', errors);
    final infl = _rate(input.inflation, 12, 'Inflation', 'inflation_pct', errors);

    if (errors.isNotEmpty) return GoalValidation(null, errors);
    return GoalValidation(
      GoalDraft(
        name: name,
        type: input.type!,
        currency: input.currency,
        targetAmount: target!,
        targetDate: date!,
        currentCorpus: corpus!,
        expectedReturnBp: ret!,
        annualStepUpBp: step!,
        inflationBp: infl!,
      ),
      const {},
    );
  }

  static int? _money(String raw, Currency currency, String field, Map<String, String> errors) {
    final value = Scaled.tryParse(raw.replaceAll(',', ''));
    if (raw.trim().isEmpty) {
      errors[field] = 'Enter an amount.';
      return null;
    }
    if (value == null) {
      errors[field] = 'Enter a number with at most 2 decimal places.';
      return null;
    }
    if (currency.decimals == 0 && value % 100 != 0) {
      errors[field] = '${currency.code} amounts can’t have decimals.';
      return null;
    }
    if (value > maxAmount) {
      errors[field] = 'That amount is too large.';
      return null;
    }
    return value;
  }

  static int? _rate(
    String raw,
    int maxPct,
    String label,
    String field,
    Map<String, String> errors,
  ) {
    final value = Scaled.tryParse(raw.trim().isEmpty ? '0' : raw);
    if (value == null || value < 0 || value > maxPct * 100) {
      errors[field] = '$label must be between 0% and $maxPct%.';
      return null;
    }
    return value;
  }
}
