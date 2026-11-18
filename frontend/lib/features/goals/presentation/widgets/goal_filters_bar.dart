import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../domain/entities/goal_query.dart';
import '../../domain/entities/goal_type.dart';

/// Edits a draft of the filters; nothing is sent until "Apply".
class GoalFiltersBar extends StatefulWidget {
  const GoalFiltersBar({
    super.key,
    required this.filters,
    required this.sort,
    required this.onApply,
    required this.onSortChanged,
  });

  final GoalFilters filters;
  final GoalSort sort;
  final ValueChanged<GoalFilters> onApply;
  final ValueChanged<GoalSort> onSortChanged;

  @override
  State<GoalFiltersBar> createState() => _GoalFiltersBarState();
}

class _GoalFiltersBarState extends State<GoalFiltersBar> {
  late Currency? _currency = widget.filters.currency;
  late GoalType? _type = widget.filters.type;
  late final _min = TextEditingController(text: _amount(widget.filters.minTargetAmount));
  late final _max = TextEditingController(text: _amount(widget.filters.maxTargetAmount));
  late final _from = TextEditingController(text: widget.filters.yearFrom?.toString() ?? '');
  late final _to = TextEditingController(text: widget.filters.yearTo?.toString() ?? '');
  String? _error;

  static String _amount(int? scaled) => scaled == null ? '' : Scaled.formatCompact(scaled);

  @override
  void dispose() {
    for (final c in [_min, _max, _from, _to]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    final min = _min.text.isEmpty ? null : Scaled.tryParse(_min.text);
    final max = _max.text.isEmpty ? null : Scaled.tryParse(_max.text);
    final from = int.tryParse(_from.text);
    final to = int.tryParse(_to.text);

    final error = switch (true) {
      _ when (_min.text.isNotEmpty && min == null) || (_max.text.isNotEmpty && max == null) =>
        'Amounts must be numbers with at most 2 decimal places.',
      _ when min != null && max != null && min > max => 'Minimum amount is above the maximum.',
      _ when from != null && to != null && from > to => '“From” year is after the “to” year.',
      _ => null,
    };
    setState(() => _error = error);
    if (error != null) return;

    widget.onApply(
      GoalFilters(
        currency: _currency,
        type: _type,
        // Amounts are in each goal's own currency, so they only filter within one currency.
        minTargetAmount: _currency == null ? null : min,
        maxTargetAmount: _currency == null ? null : max,
        yearFrom: from,
        yearTo: to,
      ),
    );
  }

  void _clear() {
    setState(() {
      _currency = null;
      _type = null;
      _error = null;
      for (final c in [_min, _max, _from, _to]) {
        c.clear();
      }
    });
    widget.onApply(GoalFilters.none);
  }

  @override
  Widget build(BuildContext context) {
    final amountsEnabled = _currency != null;
    final digits = FilteringTextInputFormatter.digitsOnly;
    final decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

    Widget field(Widget child, [double width = 160]) => SizedBox(width: width, child: child);

    return Container(
      color: AppColors.layer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              field(
                DropdownButtonFormField<Currency?>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  dropdownColor: AppColors.layer,
                  items: [
                    const DropdownMenuItem(child: Text('All')),
                    for (final c in Currency.values)
                      DropdownMenuItem(value: c, child: Text(c.code)),
                  ],
                  onChanged: (c) => setState(() => _currency = c),
                ),
                120,
              ),
              field(
                DropdownButtonFormField<GoalType?>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Goal type'),
                  dropdownColor: AppColors.layer,
                  items: [
                    const DropdownMenuItem(child: Text('All types')),
                    for (final t in GoalType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (t) => setState(() => _type = t),
                ),
                170,
              ),
              field(
                TextField(
                  controller: _min,
                  enabled: amountsEnabled,
                  inputFormatters: [decimal],
                  decoration: InputDecoration(
                    labelText: 'Min target',
                    hintText: amountsEnabled ? null : 'Pick a currency',
                  ),
                ),
                140,
              ),
              field(
                TextField(
                  controller: _max,
                  enabled: amountsEnabled,
                  inputFormatters: [decimal],
                  decoration: const InputDecoration(labelText: 'Max target'),
                ),
                140,
              ),
              field(
                TextField(
                  controller: _from,
                  inputFormatters: [digits, LengthLimitingTextInputFormatter(4)],
                  decoration: const InputDecoration(labelText: 'Year from'),
                ),
                110,
              ),
              field(
                TextField(
                  controller: _to,
                  inputFormatters: [digits, LengthLimitingTextInputFormatter(4)],
                  decoration: const InputDecoration(labelText: 'Year to'),
                ),
                110,
              ),
              FilledButton(onPressed: _apply, child: const Text('Apply')),
              if (!widget.filters.isEmpty)
                TextButton(onPressed: _clear, child: const Text('Clear filters')),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Sort by', style: TextStyle(color: AppColors.text2)),
              const SizedBox(width: 12),
              DropdownButton<GoalSort>(
                value: widget.sort,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.layer,
                items: [
                  for (final s in GoalSort.values) DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (s) => s == null ? null : widget.onSortChanged(s),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
