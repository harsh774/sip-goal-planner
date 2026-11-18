import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/scaled.dart';
import '../../../../core/format/money_formatter.dart';
import '../../../projection/domain/engine/projection_calculator.dart';
import '../../../projection/domain/usecases/plan_goals.dart';
import 'goal_type_icon.dart';

const _investEveryMonthText = 'Invest every month';
const _seeFullPlanText = 'See full plan →';
const _sameAmountEveryMonthText = 'Same amount every month';
const _nothingMoreNeededText = 'Nothing more needed';

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.plan, required this.onOpen, this.compact = false});

  final GoalPlan plan;
  final VoidCallback onOpen;

  /// The "Reaching soon" row: headline numbers only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final goal = plan.goal;
    final c = goal.currency;
    final monthsLeft = ProjectionCalculator.monthsBetween(DateTime.now(), goal.targetDate);
    final stepLine = goal.annualStepUpBp == 0
        ? _sameAmountEveryMonthText
        : 'or start at ${MoneyFormatter.full(plan.stepUpFirstSip, c)}, rising '
              '${Scaled.formatCompact(goal.annualStepUpBp)}% a year';

    return Material(
      color: AppColors.layer,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: .all(compact ? 20 : 24),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Icon(goal.type.icon, color: AppColors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: .w600),
                        ),
                        Text(
                          '${MoneyFormatter.short(Scaled.toDouble(goal.targetAmount), c)} by '
                          '${DateFormats.monthYear.format(goal.targetDate)}',
                          style: const TextStyle(color: AppColors.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 20),
              const Text(
                _investEveryMonthText,
                style: TextStyle(fontSize: 12, color: AppColors.text2),
              ),
              Text(
                plan.projection.onTrack
                    ? _nothingMoreNeededText
                    : MoneyFormatter.full(plan.levelSip, c),
                style: TextStyle(fontSize: compact ? 24 : 28, fontWeight: .w300),
              ),
              if (!compact)
                Text(stepLine, style: const TextStyle(color: AppColors.text2, fontSize: 13)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (plan.progressPct / 100).clamp(0, 1),
                backgroundColor: AppColors.border,
                color: AppColors.gold,
                minHeight: 4,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved ${plan.progressPct.toStringAsFixed(plan.progressPct < 10 ? 1 : 0)}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.text2),
                    ),
                  ),
                  Text(
                    '${DateFormats.duration(monthsLeft)} left',
                    style: const TextStyle(fontSize: 12, color: AppColors.text2),
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: .centerRight,
                  child: Text(_seeFullPlanText, style: TextStyle(color: AppColors.gold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays cards out in 1–3 columns depending on width.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.maxColumns = 2});

  final List<Widget> children;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 340).floor().clamp(1, maxColumns);
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}
