import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../domain/entities/projection.dart';

const _chartOfHowYourText = 'Chart of how your money grows each year against your goal of ';
const _todayNText = 'Today\n';
const _chartTableNoteText = 'The yearly table below has the same numbers.';
const _totalWorthText = 'Total worth';
const _youPutInText = 'You put in';
const _growthText = 'Growth';
const _monthlySipText = 'Monthly SIP';
const _goalReachedText = 'Goal reached';
const _growthGapBetweenTheText = 'Growth (gap between the two)';

/// The selected plan year by year: total worth (gold) over money put in (blue),
/// the gap between them being growth. The goal is a dashed line, the year the
/// plan first reaches it is marked, and the other plan shows as a faint line.
class GrowthChart extends StatelessWidget {
  const GrowthChart({
    super.key,
    required this.plan,
    required this.corpus,
    required this.target,
    required this.currency,
    required this.startYear,
    this.otherPlan,
    this.otherLabel,
  });

  final Plan plan;
  final Plan? otherPlan;
  final String? otherLabel;
  final double corpus;
  final double target;
  final Currency currency;
  final int startYear;

  double _x(ScheduleRow r) => (r.year - 1) + r.months / 12;

  List<FlSpot> _spots(Plan p, double Function(ScheduleRow) y) => [
    FlSpot(0, corpus),
    for (final r in p.rows) FlSpot(_x(r), y(r)),
  ];

  @override
  Widget build(BuildContext context) {
    final years = plan.rows.isEmpty ? 1.0 : _x(plan.rows.last);
    final peak = [target, plan.finalBalance, otherPlan?.finalBalance ?? 0].reduce(math.max);
    final maxY = peak * 1.12;
    final reached = plan.rows.where((r) => r.closingBalance >= target).firstOrNull;

    final worth = LineChartBarData(
      spots: _spots(plan, (r) => r.closingBalance),
      color: AppColors.gold,
      barWidth: 3,
      isCurved: true,
      preventCurveOverShooting: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (s, _) => reached != null && s.x == _x(reached),
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 6,
          color: AppColors.gold,
          strokeWidth: 3,
          strokeColor: AppColors.background,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: .topCenter,
          end: .bottomCenter,
          colors: [AppColors.gold.withValues(alpha: 0.35), AppColors.gold.withValues(alpha: 0.02)],
        ),
      ),
    );
    final invested = LineChartBarData(
      spots: _spots(plan, (r) => r.investedToDate),
      color: AppColors.seriesLevel,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: AppColors.seriesLevel.withValues(alpha: 0.25)),
    );
    final other = switch (otherPlan) {
      null => null,
      final o => LineChartBarData(
        spots: _spots(o, (r) => r.closingBalance),
        color: AppColors.text3,
        barWidth: 1.5,
        isCurved: true,
        preventCurveOverShooting: true,
        dashArray: [4, 4],
        dotData: const FlDotData(show: false),
      ),
    };

    return Semantics(
      label:
          '$_chartOfHowYourText${MoneyFormatter.short(target, currency)}. '
          '$_chartTableNoteText',
      child: SizedBox(
        height: 320,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: years,
            minY: 0,
            maxY: maxY,
            lineBarsData: [worth, invested, ?other],
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: target,
                  color: AppColors.text2,
                  strokeWidth: 1,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: .topLeft,
                    style: const TextStyle(fontSize: 11, color: AppColors.text2),
                    labelResolver: (_) => 'Goal ${MoneyFormatter.short(target, currency)}',
                  ),
                ),
              ],
              verticalLines: [
                if (reached != null)
                  VerticalLine(
                    x: _x(reached),
                    color: AppColors.gold.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: .topLeft,
                      style: const TextStyle(fontSize: 11, color: AppColors.gold),
                      labelResolver: (_) => 'Goal reached ${reached.calendarYear}',
                    ),
                  ),
              ],
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 5,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 64,
                  interval: maxY / 5,
                  getTitlesWidget: (v, meta) => v >= meta.max
                      ? const SizedBox.shrink()
                      : Text(MoneyFormatter.axis(v, currency), style: _axisStyle),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: years <= 10 ? 1 : (years / 8).ceilToDouble(),
                  getTitlesWidget: (v, meta) {
                    // The last label is the goal's own year; drop a whole-year tick crowding it.
                    final isEnd = v == meta.max;
                    if (!isEnd && meta.max - v < meta.appliedInterval * 0.6) {
                      return const SizedBox.shrink();
                    }
                    final year = isEnd && plan.rows.isNotEmpty
                        ? plan.rows.last.calendarYear
                        : startYear + v.round();
                    return Padding(
                      padding: const .only(top: 6),
                      child: Text('$year', style: _axisStyle),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.layer2,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: const .all(10),
                getTooltipItems: (spots) => [
                  for (final s in spots) s.barIndex == 0 ? _tooltip(s.spotIndex) : null,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineTooltipItem _tooltip(int index) {
    String money(double v) => MoneyFormatter.short(v, currency);
    if (index == 0) {
      return LineTooltipItem(
        _todayNText,
        const TextStyle(fontWeight: .w600, color: AppColors.text, fontSize: 12),
        children: [
          TextSpan(
            text: 'Already invested ${money(corpus)}',
            style: const TextStyle(fontWeight: .w400, color: AppColors.text2),
          ),
        ],
      );
    }
    final r = plan.rows[index - 1];
    TextSpan line(String label, String value, Color color) => TextSpan(
      text: '\n$label  $value',
      style: TextStyle(color: color, fontWeight: .w400, fontSize: 12),
    );
    return LineTooltipItem(
      '${r.calendarYear}',
      const TextStyle(fontWeight: .w600, color: AppColors.text, fontSize: 13),
      textAlign: .left,
      children: [
        line(_totalWorthText, money(r.closingBalance), AppColors.gold),
        line(_youPutInText, money(r.investedToDate), AppColors.seriesLevel),
        line(_growthText, money(r.growthToDate), AppColors.success),
        line(_monthlySipText, MoneyFormatter.full(r.monthlySip, currency), AppColors.text2),
        line(_goalReachedText, '${r.goalPct.clamp(0, 100).toStringAsFixed(0)}%', AppColors.text2),
      ],
    );
  }

  static const _axisStyle = TextStyle(fontSize: 11, color: AppColors.text2);
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.goalLabel, this.otherLabel});

  final String goalLabel;
  final String? otherLabel;

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text, {double height = 3}) => Row(
      mainAxisSize: .min,
      children: [
        Container(width: 16, height: height, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
      ],
    );
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        item(AppColors.gold, _totalWorthText),
        item(AppColors.seriesLevel, _youPutInText),
        item(AppColors.gold.withValues(alpha: 0.35), _growthGapBetweenTheText, height: 10),
        if (otherLabel != null) item(AppColors.text3, otherLabel!, height: 1.5),
        item(AppColors.text2, 'Your goal ($goalLabel)', height: 1),
      ],
    );
  }
}
