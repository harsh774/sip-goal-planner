import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../../projection/domain/engine/projection_calculator.dart';
import 'goal_card.dart' show CardGrid;

const _whyASipPlanText = 'Why a SIP plan matters';
const _smallRegularAmountsAddText =
    'Small, regular amounts add up. Examples at 12% a year, for illustration only.';
const _start5YearsEarlierText = 'Start 5 years earlier';
const _compoundingDoesTheWorkText = 'Compounding does the work';
const _planForRisingPricesText = 'Plan for rising prices';
const _aboutGoalText = 'About Goal';
const _plannerText = 'Planner';
const _setAGoalText = 'Set a goal';
const _nameItChooseAText = 'Name it, choose a target amount, a date and a currency.';
const _seeTheMonthlySipText = 'See the monthly SIP';
const _weWorkOutWhatText = 'We work out what to invest each month, flat or rising every year.';
const _understandThePlanText = 'Understand the plan';
const _yearByYearGrowthText =
    'Year-by-year growth, the effect of inflation, and every step of the maths.';
const _goalplannerTurnsTheThingsText =
    'GoalPlanner turns the things you’re saving for into a clear monthly SIP. Each goal keeps its own currency and assumptions, so you can plan a home in India and a degree abroad side by side. It is a planning tool, not investment advice: returns are assumptions, and real markets go up and down.';

/// Worked examples of why a SIP plan matters, each with an illustration.
/// Numbers come from the same engine as the plans, at 12% a year.
class SipImpactSection extends StatelessWidget {
  const SipImpactSection({super.key, required this.currency});

  final Currency currency;

  static const _rate = 0.12;
  static const _inflation = 0.06;

  double get _monthly => switch (currency) {
    Currency.inr => 10000,
    Currency.jpy => 50000,
    _ => 500,
  };

  /// Value after [years] of a SIP paid at the start of each month.
  static double futureValue(double monthly, int years, double rate) {
    final i = ProjectionCalculator.effectiveMonthlyRate(rate);
    final n = years * 12;
    return monthly * (math.pow(1 + i, n) - 1) / i * (1 + i);
  }

  @override
  Widget build(BuildContext context) {
    String money(double v) => MoneyFormatter.short(v, currency);
    final m = MoneyFormatter.full(_monthly, currency);
    final early = futureValue(_monthly, 20, _rate);
    final late = futureValue(_monthly, 15, _rate);
    final putIn = _monthly * 12 * 20;
    final goal = _monthly * 1000;
    final goalToday = goal / math.pow(1 + _inflation, 20);

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Text(_whyASipPlanText, style: TextStyle(fontSize: 22, fontWeight: .w600)),
        const Text(_smallRegularAmountsAddText, style: TextStyle(color: AppColors.text2)),
        const SizedBox(height: 16),
        CardGrid(
          maxColumns: 3,
          children: [
            _InsightCard(
              painter: _TwoCurvesPainter(),
              stat: '${money(early - late)} more',
              title: _start5YearsEarlierText,
              body:
                  '$m a month for 20 years grows to ${money(early)}. Starting 5 years later '
                  'gives ${money(late)}.',
            ),
            _InsightCard(
              painter: _StackPainter(putIn / early),
              stat: '${(early / putIn).toStringAsFixed(1)}× your money',
              title: _compoundingDoesTheWorkText,
              body:
                  'Put in ${money(putIn)} over 20 years and returns add '
                  '${money(early - putIn)} on top.',
            ),
            _InsightCard(
              painter: _InflationPainter(),
              stat: '${money(goal)} → ${money(goalToday)}',
              title: _planForRisingPricesText,
              body:
                  'At 6% inflation, ${money(goal)} in 20 years buys what '
                  '${money(goalToday)} buys today. Every plan here shows both.',
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.painter,
    required this.stat,
    required this.title,
    required this.body,
  });

  final CustomPainter painter;
  final String stat;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.layer,
        borderRadius: .circular(12),
        border: .all(color: AppColors.border),
      ),
      clipBehavior: .antiAlias,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: .topLeft,
                end: .bottomRight,
                colors: [AppColors.goldTint, AppColors.layer2],
              ),
            ),
            child: ExcludeSemantics(child: CustomPaint(painter: painter)),
          ),
          Padding(
            padding: const .all(20),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  stat,
                  style: const TextStyle(fontSize: 20, color: AppColors.gold, fontWeight: .w600),
                ),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontWeight: .w600, fontSize: 16)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(color: AppColors.text2, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two growth curves: started early (gold) and started late (blue).
class _TwoCurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.height * 0.15;
    Path curve(double startFrac) {
      final path = Path();
      for (var k = 0; k <= 40; k++) {
        final t = k / 40;
        final x = size.width * (0.08 + 0.84 * t);
        final grown = t < startFrac
            ? 0.0
            : (math.exp(3.2 * (t - startFrac)) - 1) / (math.exp(3.2) - 1);
        final y = size.height - pad - grown * (size.height - pad * 2);
        k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      return path;
    }

    final early = curve(0);
    canvas.drawPath(
      Path.from(early)
        ..lineTo(size.width * 0.92, size.height - pad)
        ..lineTo(size.width * 0.08, size.height - pad)
        ..close(),
      Paint()..color = AppColors.gold.withValues(alpha: 0.18),
    );
    canvas.drawPath(early, _stroke(AppColors.gold, 3));
    canvas.drawPath(curve(0.25), _stroke(AppColors.seriesLevel, 2.5));
    canvas.drawCircle(Offset(size.width * 0.92, pad), 5, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(_TwoCurvesPainter old) => false;
}

/// Rising bars split into money put in (blue) and growth (gold).
class _StackPainter extends CustomPainter {
  _StackPainter(this.investedShare);

  final double investedShare;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 7;
    final pad = size.height * 0.15;
    final slot = size.width * 0.8 / bars;
    for (var b = 0; b < bars; b++) {
      final t = (b + 1) / bars;
      final total = (size.height - pad * 2) * math.pow(t, 1.8);
      final invested = total * (1 - (1 - investedShare) * t);
      final x = size.width * 0.1 + b * slot + slot * 0.2;
      final w = slot * 0.6;
      final bottom = size.height - pad;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottom - total, w, total),
          const Radius.circular(3),
        ),
        Paint()..color = AppColors.gold,
      );
      canvas.drawRect(
        Rect.fromLTWH(x, bottom - invested, w, invested),
        Paint()..color = AppColors.seriesLevel,
      );
    }
  }

  @override
  bool shouldRepaint(_StackPainter old) => old.investedShare != investedShare;
}

/// A stack of coins shrinking over time, with a falling arrow.
class _InflationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.height * 0.15;
    const stacks = 5;
    final slot = size.width * 0.7 / stacks;
    for (var s = 0; s < stacks; s++) {
      final coins = 6 - s;
      final cx = size.width * 0.12 + s * slot + slot / 2;
      for (var c = 0; c < coins; c++) {
        final cy = size.height - pad - c * 9.0;
        final rect = Rect.fromCenter(center: Offset(cx, cy), width: slot * 0.6, height: 10);
        canvas.drawOval(
          rect,
          Paint()..color = Color.lerp(AppColors.gold, AppColors.goldHover, c / 6) ?? AppColors.gold,
        );
        canvas.drawOval(rect, _stroke(AppColors.goldTint, 1));
      }
    }
    final from = Offset(size.width * 0.18, pad);
    final to = Offset(size.width * 0.88, size.height * 0.55);
    canvas.drawLine(from, to, _stroke(AppColors.danger, 2.5));
    final dir = (to - from).direction;
    canvas.drawPath(
      Path()
        ..moveTo(to.dx + 8 * math.cos(dir), to.dy + 8 * math.sin(dir))
        ..lineTo(to.dx + 9 * math.cos(dir + 2.4), to.dy + 9 * math.sin(dir + 2.4))
        ..lineTo(to.dx + 9 * math.cos(dir - 2.4), to.dy + 9 * math.sin(dir - 2.4))
        ..close(),
      Paint()..color = AppColors.danger,
    );
  }

  @override
  bool shouldRepaint(_InflationPainter old) => false;
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class AboutGoalPlanner extends StatelessWidget {
  const AboutGoalPlanner({super.key});

  static const _points = [
    (Icons.flag_outlined, _setAGoalText, _nameItChooseAText),
    (Icons.calculate_outlined, _seeTheMonthlySipText, _weWorkOutWhatText),
    (Icons.insights_outlined, _understandThePlanText, _yearByYearGrowthText),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.layer,
        borderRadius: .circular(12),
        border: .all(color: AppColors.border),
      ),
      padding: const .all(24),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text.rich(
            TextSpan(
              text: _aboutGoalText,
              children: [
                TextSpan(
                  text: _plannerText,
                  style: TextStyle(color: AppColors.gold),
                ),
              ],
            ),
            style: TextStyle(fontSize: 22, fontWeight: .w600),
          ),
          const SizedBox(height: 8),
          const Text(
            _goalplannerTurnsTheThingsText,
            style: TextStyle(color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              for (final (icon, title, body) in _points)
                SizedBox(
                  width: 300,
                  child: Row(
                    crossAxisAlignment: .start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.goldTint,
                        child: Icon(icon, size: 18, color: AppColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: .w600)),
                            Text(body, style: const TextStyle(color: AppColors.text2, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
