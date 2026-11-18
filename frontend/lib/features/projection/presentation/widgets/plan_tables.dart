import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../domain/entities/projection.dart';

const _yearText = 'Year';
const _monthlySipText = 'Monthly SIP';
const _putInSoFarText = 'Put in so far';
const _growthSoFarText = 'Growth so far';
const _totalWorthText = 'Total worth';
const _goalReachedText = 'Goal reached';
const _measureText = 'Measure';
const _sameEveryMonthText = 'Same every month';
const _monthlySipInYearText = 'Monthly SIP in year 1';
const _monthlySipInFinalText = 'Monthly SIP in final year';
const _totalYouPutInText = 'Total you put in';
const _growthFromReturnsText = 'Growth from returns';

class YearlyTable extends StatelessWidget {
  const YearlyTable({super.key, required this.plan, required this.currency});

  final Plan plan;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    String money(double v) => MoneyFormatter.full(v, currency);
    return _Scrollable(
      child: DataTable(
        headingTextStyle: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: .w600),
        columns: const [
          DataColumn(label: Text(_yearText)),
          DataColumn(label: Text(_monthlySipText), numeric: true),
          DataColumn(label: Text(_putInSoFarText), numeric: true),
          DataColumn(label: Text(_growthSoFarText), numeric: true),
          DataColumn(label: Text(_totalWorthText), numeric: true),
          DataColumn(label: Text(_goalReachedText), numeric: true),
        ],
        rows: [
          for (final r in plan.rows)
            DataRow(
              cells: [
                DataCell(Text('${r.calendarYear}')),
                DataCell(Text(money(r.monthlySip))),
                DataCell(Text(money(r.investedToDate))),
                DataCell(Text(money(r.growthToDate))),
                DataCell(Text(money(r.closingBalance))),
                DataCell(Text('${r.goalPct.clamp(0, 100).toStringAsFixed(0)}%')),
              ],
            ),
        ],
      ),
    );
  }
}

class ComparisonTable extends StatelessWidget {
  const ComparisonTable({
    super.key,
    required this.projection,
    required this.currency,
    required this.stepUpPct,
  });

  final Projection projection;
  final Currency currency;
  final String stepUpPct;

  @override
  Widget build(BuildContext context) {
    final l = projection.level;
    final s = projection.stepUp;
    String money(double v) => MoneyFormatter.full(v, currency);
    DataRow row(String label, double a, double b) =>
        DataRow(cells: [DataCell(Text(label)), DataCell(Text(money(a))), DataCell(Text(money(b)))]);

    return _Scrollable(
      child: DataTable(
        headingTextStyle: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: .w600),
        columns: [
          const DataColumn(label: Text(_measureText)),
          const DataColumn(label: Text(_sameEveryMonthText), numeric: true),
          DataColumn(label: Text('Increase $stepUpPct% yearly'), numeric: true),
        ],
        rows: [
          row(_monthlySipInYearText, l.firstYearSip, s.firstYearSip),
          row(_monthlySipInFinalText, l.finalYearSip, s.finalYearSip),
          row(_totalYouPutInText, l.totalInvested, s.totalInvested),
          row(_growthFromReturnsText, l.growth, s.growth),
        ],
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: .horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: c.maxWidth),
        child: child,
      ),
    ),
  );
}
