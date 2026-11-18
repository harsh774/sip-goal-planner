import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../domain/entities/projection.dart';

class YearlyTable extends StatelessWidget {
  const YearlyTable({super.key, required this.plan, required this.currency});

  final Plan plan;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    String money(double v) => MoneyFormatter.full(v, currency);
    return _Scrollable(
      child: DataTable(
        headingTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.text2,
          fontWeight: FontWeight.w600,
        ),
        columns: const [
          DataColumn(label: Text('Year')),
          DataColumn(label: Text('Monthly SIP'), numeric: true),
          DataColumn(label: Text('Put in so far'), numeric: true),
          DataColumn(label: Text('Growth so far'), numeric: true),
          DataColumn(label: Text('Total worth'), numeric: true),
          DataColumn(label: Text('Goal reached'), numeric: true),
        ],
        rows: [
          for (final r in plan.rows)
            DataRow(
              cells: [
                DataCell(
                  Text('${r.year} · ${r.calendarYear}${r.months < 12 ? ' (${r.months} mo)' : ''}'),
                ),
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
        headingTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.text2,
          fontWeight: FontWeight.w600,
        ),
        columns: [
          const DataColumn(label: Text('Measure')),
          const DataColumn(label: Text('Same every month'), numeric: true),
          DataColumn(label: Text('Increase $stepUpPct% yearly'), numeric: true),
        ],
        rows: [
          row('Monthly SIP in year 1', l.firstYearSip, s.firstYearSip),
          row('Monthly SIP in final year', l.finalYearSip, s.finalYearSip),
          row('Total you put in', l.totalInvested, s.totalInvested),
          row('Growth from returns', l.growth, s.growth),
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
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: c.maxWidth),
        child: child,
      ),
    ),
  );
}
