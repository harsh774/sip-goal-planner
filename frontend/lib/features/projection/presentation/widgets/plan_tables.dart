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
const _keyYearsNoteText = 'Showing key years:';
const _showKeyYearsText = 'Show key years only';

/// Year-by-year rows. Long plans start collapsed to key years (the first
/// three, every fifth, and the last) with a button to show every year.
class YearlyTable extends StatefulWidget {
  const YearlyTable({super.key, required this.plan, required this.currency});

  final Plan plan;
  final Currency currency;

  static const collapseAbove = 8;

  /// Indexes shown while collapsed.
  static List<int> keyRows(int count) => [
    for (var i = 0; i < count; i++)
      if (i < 3 || (i + 1) % 5 == 0 || i == count - 1) i,
  ];

  @override
  State<YearlyTable> createState() => _YearlyTableState();
}

class _YearlyTableState extends State<YearlyTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    String money(double v) => MoneyFormatter.full(v, widget.currency);
    final rows = widget.plan.rows;
    final collapsible = rows.length > YearlyTable.collapseAbove;
    final shown = collapsible && !_expanded
        ? YearlyTable.keyRows(rows.length)
        : [for (var i = 0; i < rows.length; i++) i];
    final reachedAt = rows.indexWhere((r) => r.goalPct >= 100);

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _Scrollable(
          child: DataTable(
            headingTextStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.text2,
              fontWeight: .w600,
            ),
            columns: const [
              DataColumn(label: Text(_yearText)),
              DataColumn(label: Text(_monthlySipText), numeric: true),
              DataColumn(label: Text(_putInSoFarText), numeric: true),
              DataColumn(label: Text(_growthSoFarText), numeric: true),
              DataColumn(label: Text(_totalWorthText), numeric: true),
              DataColumn(label: Text(_goalReachedText), numeric: true),
            ],
            rows: [
              for (final i in shown)
                DataRow(
                  color: i == reachedAt
                      ? WidgetStatePropertyAll(AppColors.gold.withValues(alpha: 0.1))
                      : null,
                  cells: [
                    DataCell(Text('${rows[i].calendarYear}')),
                    DataCell(Text(money(rows[i].monthlySip))),
                    DataCell(Text(money(rows[i].investedToDate))),
                    DataCell(Text(money(rows[i].growthToDate))),
                    DataCell(Text(money(rows[i].closingBalance))),
                    DataCell(Text('${rows[i].goalPct.clamp(0, 100).toStringAsFixed(0)}%')),
                  ],
                ),
            ],
          ),
        ),
        if (collapsible) ...[
          const SizedBox(height: 12),
          if (!_expanded)
            Text(
              '$_keyYearsNoteText ${shown.length} of ${rows.length} years.',
              textAlign: .center,
              style: const TextStyle(fontSize: 12, color: AppColors.text3),
            ),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.unfold_less : Icons.unfold_more, size: 18),
              label: Text(_expanded ? _showKeyYearsText : 'Show all ${rows.length} years'),
            ),
          ),
        ],
      ],
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
