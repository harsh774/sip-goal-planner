import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/format/money_formatter.dart';
import '../../domain/entities/goal_query.dart';

class SummaryStrip extends StatelessWidget {
  const SummaryStrip({
    super.key,
    required this.summary,
    required this.filtered,
    required this.onCurrencyChanged,
  });

  final GoalsSummary summary;

  /// Totals cover only the goals matching the current filters.
  final bool filtered;
  final ValueChanged<Currency> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final c = summary.currency;
    return Container(
      color: AppColors.layer,
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 48,
        runSpacing: 24,
        children: [
          _Stat(label: filtered ? 'Matching goals' : 'Goals', value: '${summary.count}'),
          _Stat(
            label: 'Total monthly SIP needed',
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
          _Stat(label: 'All goals added up', value: MoneyFormatter.short(summary.totalTarget, c)),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
        if (note != null) Text(note!, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
      ],
    );
  }
}
