import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../../../shared/widgets/elevated_card.dart';
import '../../domain/entities/goal_query.dart';

const _totalMonthlySipNeededText = 'Total monthly SIP needed';
const _allGoalsAddedUpText = 'All goals added up';
const _goalsText = 'Goals';
const _acrossAllGoalsText = 'Across all your goals';

class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.summary, required this.onCurrencyChanged});

  /// Always every goal; list filters don't change it.
  final GoalsSummary summary;
  final ValueChanged<Currency> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final c = summary.currency;
    return ElevatedCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_outlined, size: 18, color: AppColors.gold),
              SizedBox(width: 8),
              Text(_acrossAllGoalsText, style: TextStyle(color: AppColors.gold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 48,
            runSpacing: 24,
            children: [
              _Stat(label: _goalsText, value: '${summary.count}'),
              _Stat(
                label: _totalMonthlySipNeededText,
                value: MoneyFormatter.full(summary.totalMonthlySip, c),
                trailing: DropdownButton<Currency>(
                  value: c,
                  underline: const SizedBox.shrink(),
                  dropdownColor: AppColors.layer,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  items: [
                    for (final option in Currency.values)
                      DropdownMenuItem(value: option, child: Text(option.code)),
                  ],
                  onChanged: (value) => value == null ? null : onCurrencyChanged(value),
                ),
                note: summary.converted
                    ? 'Approximate, at rates from ${DateFormats.dayMonthYear.format(summary.ratesAsOf)}'
                    : null,
              ),
              _Stat(
                label: _allGoalsAddedUpText,
                value: MoneyFormatter.short(summary.totalTarget, c),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.trailing, this.note});

  final String label;
  final String value;
  final Widget? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: .min,
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: .w300)),
            if (trailing case final t?) ...[const SizedBox(width: 12), t],
          ],
        ),
        if (note case final n?)
          Text(n, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
      ],
    );
  }
}
