import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../domain/entities/projection.dart';

/// Corpus by year for both plans, with the goal as a dashed line.
class GrowthChart extends StatelessWidget {
  const GrowthChart({
    super.key,
    required this.projection,
    required this.corpus,
    required this.target,
    required this.currency,
  });

  final Projection projection;
  final double corpus;
  final double target;
  final Currency currency;

  List<FlSpot> _spots(Plan plan) => [
    FlSpot(0, corpus),
    for (final row in plan.rows) FlSpot((row.year - 1) + row.months / 12, row.closingBalance),
  ];

  LineChartBarData _line(Plan plan, Color color) => LineChartBarData(
    spots: _spots(plan),
    color: color,
    barWidth: 2.5,
    isCurved: false,
    dotData: const FlDotData(show: false),
  );

  @override
  Widget build(BuildContext context) {
    final years = projection.months / 12;
    final maxY =
        [target, projection.level.finalBalance, projection.stepUp.finalBalance].reduce(math.max) *
        1.08;

    return Semantics(
      label:
          'Chart of how your money grows each year for both plans, against your goal of '
          '${MoneyFormatter.short(target, currency)}. The yearly table below has the same numbers.',
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: years,
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              _line(projection.level, AppColors.seriesLevel),
              _line(projection.stepUp, AppColors.seriesStepUp),
            ],
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: target,
                  color: AppColors.text2,
                  strokeWidth: 1,
                  dashArray: [6, 4],
                ),
              ],
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
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
                  getTitlesWidget: (v, meta) => v == meta.max
                      ? const SizedBox.shrink()
                      : Text(MoneyFormatter.axis(v, currency), style: _axisStyle),
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: const Text('Years from now', style: _axisStyle),
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: years <= 12 ? 1 : (years / 8).ceilToDouble(),
                  getTitlesWidget: (v, meta) => Text('${v.round()}', style: _axisStyle),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.layer2,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.barIndex == 0 ? 'Same every month' : 'Step-up'}: '
                      '${MoneyFormatter.short(s.y, currency)}',
                      TextStyle(
                        color: s.barIndex == 0 ? AppColors.seriesLevel : AppColors.seriesStepUp,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _axisStyle = TextStyle(fontSize: 11, color: AppColors.text2);
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.stepUpPct, required this.goalLabel});

  final String stepUpPct;
  final String goalLabel;

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text, {bool dashed = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: dashed ? 1 : 3, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
      ],
    );
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        item(AppColors.seriesLevel, 'Same every month'),
        item(AppColors.seriesStepUp, 'Step-up $stepUpPct%'),
        item(AppColors.text2, 'Your goal ($goalLabel)', dashed: true),
      ],
    );
  }
}
