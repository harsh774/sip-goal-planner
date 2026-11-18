import 'dart:math' as math;

import '../entities/projection.dart';

/// SIP projection engine. Pure; mirrors backend/app/services/projection.py and
/// must pass the same shared vectors (shared/projection_vectors.json).
///
/// - Effective monthly rate: i = (1 + R)^(1/12) - 1.
/// - SIP paid at the start of each month; step-up once a year.
/// - Required SIP rounded up to a whole unit so the plan still reaches the target.
abstract final class ProjectionCalculator {
  static Projection project(ProjectionInput input) {
    final months = monthsBetween(input.asOf, input.targetDate);
    final i = effectiveMonthlyRate(input.annualReturn);
    final corpusFv = input.corpus * math.pow(1 + i, months);
    final gap = input.target - corpusFv;

    return Projection(
      asOf: input.asOf,
      months: months,
      monthlyRate: i,
      corpusFutureValue: corpusFv,
      gap: math.max(gap, 0),
      todayValue: input.target / math.pow(1 + input.inflation, months / 12),
      onTrack: gap <= 0,
      level: _plan(input, months, i, 0, gap),
      stepUp: _plan(input, months, i, input.annualStepUp, gap),
    );
  }

  /// Whole calendar months; a trailing partial month is dropped. Minimum 1.
  static int monthsBetween(DateTime start, DateTime end) {
    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) months -= 1;
    return math.max(months, 1);
  }

  static double effectiveMonthlyRate(double annualRate) =>
      math.pow(1 + annualRate, 1 / 12).toDouble() - 1;

  /// P0 = gap / Σ (1+s)^⌊m/12⌋ · (1+i)^(n−m). Covers zero return, zero step-up
  /// and partial final years without special cases.
  static double requiredFirstSip(double gap, int months, double i, double stepUp) {
    if (gap <= 0) return 0;
    var factor = 0.0;
    for (var m = 0; m < months; m++) {
      factor += math.pow(1 + stepUp, m ~/ 12) * math.pow(1 + i, months - m);
    }
    return gap / factor;
  }

  static Plan _plan(ProjectionInput input, int months, double i, double stepUp, double gap) {
    final firstSip = _wholeUnitsUp(requiredFirstSip(gap, months, i, stepUp));
    var balance = input.corpus;
    var invested = input.corpus;
    final rows = <ScheduleRow>[];

    for (var year = 0; year * 12 < months; year++) {
      final sip = firstSip == 0 ? 0.0 : _wholeUnitsUp(firstSip * math.pow(1 + stepUp, year));
      final monthsInYear = math.min(12, months - year * 12);
      for (var m = 0; m < monthsInYear; m++) {
        balance = (balance + sip) * (1 + i);
        invested += sip;
      }
      final endIndex = input.asOf.year * 12 + (input.asOf.month - 1) + year * 12 + monthsInYear;
      rows.add(
        ScheduleRow(
          year: year + 1,
          calendarYear: endIndex ~/ 12,
          months: monthsInYear,
          monthlySip: sip,
          investedToDate: invested,
          closingBalance: balance,
          goalPct: balance / input.target * 100,
        ),
      );
    }
    return Plan(annualStepUp: stepUp, firstYearSip: firstSip, rows: rows);
  }

  // Round to 6 places first so float noise (21000.000000000004) doesn't add a unit.
  static double _wholeUnitsUp(double value) =>
      (double.parse(value.toStringAsFixed(6))).ceilToDouble();
}
