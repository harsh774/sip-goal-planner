import 'package:equatable/equatable.dart';

import '../../../../core/domain/rounding.dart';

class ProjectionInput extends Equatable {
  const ProjectionInput({
    required this.target,
    required this.corpus,
    required this.annualReturn,
    required this.annualStepUp,
    required this.inflation,
    required this.asOf,
    required this.targetDate,
  });

  final double target;
  final double corpus;

  /// Rates as fractions: 12% -> 0.12.
  final double annualReturn;
  final double annualStepUp;
  final double inflation;
  final DateTime asOf;
  final DateTime targetDate;

  @override
  List<Object?> get props => [
    target,
    corpus,
    annualReturn,
    annualStepUp,
    inflation,
    asOf,
    targetDate,
  ];
}

class ScheduleRow extends Equatable {
  const ScheduleRow({
    required this.year,
    required this.calendarYear,
    required this.months,
    required this.monthlySip,
    required this.investedToDate,
    required this.closingBalance,
    required this.goalPct,
  });

  final int year;
  final int calendarYear;
  final int months;
  final double monthlySip;
  final double investedToDate;
  final double closingBalance;
  final double goalPct;

  double get growthToDate => roundMoney(closingBalance - investedToDate);

  @override
  List<Object?> get props => [
    year,
    calendarYear,
    months,
    monthlySip,
    investedToDate,
    closingBalance,
    goalPct,
  ];
}

class Plan extends Equatable {
  const Plan({required this.annualStepUp, required this.firstYearSip, required this.rows});

  final double annualStepUp;
  final double firstYearSip;
  final List<ScheduleRow> rows;

  double get finalYearSip => rows.isEmpty ? firstYearSip : rows.last.monthlySip;
  double get totalInvested => rows.last.investedToDate;
  double get finalBalance => rows.last.closingBalance;
  double get growth => roundMoney(finalBalance - totalInvested);

  @override
  List<Object?> get props => [annualStepUp, firstYearSip, rows];
}

class Projection extends Equatable {
  const Projection({
    required this.asOf,
    required this.months,
    required this.monthlyRate,
    required this.corpusFutureValue,
    required this.gap,
    required this.todayValue,
    required this.onTrack,
    required this.level,
    required this.stepUp,
  });

  final DateTime asOf;
  final int months;
  final double monthlyRate;
  final double corpusFutureValue;
  final double gap;
  final double todayValue;
  final bool onTrack;
  final Plan level;
  final Plan stepUp;

  @override
  List<Object?> get props => [
    asOf,
    months,
    monthlyRate,
    corpusFutureValue,
    gap,
    todayValue,
    onTrack,
    level,
    stepUp,
  ];
}
