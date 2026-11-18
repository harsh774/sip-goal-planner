import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../../../shared/widgets/disclaimer.dart';
import '../../domain/entities/projection.dart';

const _livePreviewText = 'Live preview';
const _fillInTheHighlightedText = 'Fill in the highlighted fields to see your plan.';
const _monthlySipNeededText = 'Monthly SIP needed';
const _nothingMoreNeededText = 'Nothing more needed';
const _goalInTodaysMoneyText = 'Goal in today’s money';
const _totalYouPutInText = 'Total you put in';

class PlanPreviewPanel extends StatelessWidget {
  const PlanPreviewPanel({
    super.key,
    required this.projection,
    required this.currency,
    required this.target,
    required this.targetDate,
    required this.stepUpPct,
  });

  /// Null while the form is invalid.
  final Projection? projection;
  final Currency currency;
  final double? target;
  final DateTime? targetDate;
  final String stepUpPct;

  @override
  Widget build(BuildContext context) {
    final p = projection;
    return Container(
      color: AppColors.layer,
      padding: const .all(24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: .start,
          children: [
            const Text(_livePreviewText, style: TextStyle(fontSize: 12, color: AppColors.text2)),
            const SizedBox(height: 16),
            if (p == null)
              const Text(_fillInTheHighlightedText, style: TextStyle(color: AppColors.text2))
            else ...[
              const Text(_monthlySipNeededText, style: TextStyle(color: AppColors.text2)),
              Text(
                p.onTrack
                    ? _nothingMoreNeededText
                    : MoneyFormatter.full(p.level.firstYearSip, currency),
                style: const TextStyle(fontSize: 36, fontWeight: .w300),
              ),
              Text(
                'to reach ${MoneyFormatter.short(target!, currency)} by '
                '${DateFormats.monthYear.format(targetDate!)}',
                style: const TextStyle(color: AppColors.text2),
              ),
              const Divider(height: 32),
              _Line(
                'With $stepUpPct% yearly step-up',
                MoneyFormatter.full(p.stepUp.firstYearSip, currency),
              ),
              _Line(_goalInTodaysMoneyText, MoneyFormatter.short(p.todayValue, currency)),
              _Line(_totalYouPutInText, MoneyFormatter.short(p.level.totalInvested, currency)),
            ],
            const SizedBox(height: 16),
            const Text(
              'Illustrative estimate. ${Compliance.marketRisk}',
              style: TextStyle(fontSize: 12, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.text2)),
        ),
        Text(value, style: const TextStyle(fontWeight: .w600)),
      ],
    ),
  );
}
