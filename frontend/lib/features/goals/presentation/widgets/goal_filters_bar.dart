import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../domain/entities/goal_query.dart';
import '../../domain/entities/goal_type.dart';
import 'goal_type_icon.dart';

const _allGoalsText = 'All goals';
const _clearFiltersText = 'Clear filters';
const _anyAmountText = 'Any amount';
const _applyText = 'Apply';
const _anyTimeText = 'Any time';
const _within1YearText = 'Within 1 year';
const _in15YearsText = 'In 1–5 years';
const _in510YearsText = 'In 5–10 years';
const _anyCurrencyText = 'Any currency';
const _targetAmountText = 'Target amount';
const _useNumbersWithAtText = 'Use numbers with at most 2 decimal places.';
const _minimumIsAboveTheText = 'Minimum is above the maximum.';

/// When a goal is due, as year ranges relative to this year.
enum Timeline {
  any(_anyTimeText),
  withinYear(_within1YearText),
  oneToFive(_in15YearsText),
  fiveToTen(_in510YearsText),
  tenPlus('10+ years away');

  const Timeline(this.label);

  final String label;

  (int?, int?) years(int now) => switch (this) {
    any => (null, null),
    withinYear => (null, now + 1),
    oneToFive => (now + 1, now + 5),
    fiveToTen => (now + 5, now + 10),
    tenPlus => (now + 10, null),
  };

  static Timeline of(GoalFilters f, int now) =>
      values.firstWhere((t) => t.years(now) == (f.yearFrom, f.yearTo), orElse: () => any);
}

/// One row of goal-type chips, then small menus for currency, timeline,
/// amount and sort. Every change applies straight away.
class GoalFiltersBar extends StatelessWidget {
  const GoalFiltersBar({
    super.key,
    required this.filters,
    required this.sort,
    required this.onApply,
    required this.onSortChanged,
    int? currentYear,
  }) : _year = currentYear;

  final GoalFilters filters;
  final GoalSort sort;
  final ValueChanged<GoalFilters> onApply;
  final ValueChanged<GoalSort> onSortChanged;
  final int? _year;

  int get year => _year ?? DateTime.now().year;

  GoalFilters _with({
    Object? currency = _keep,
    Object? type = _keep,
    Object? min = _keep,
    Object? max = _keep,
    (int?, int?)? years,
  }) {
    final c = identical(currency, _keep) ? filters.currency : currency as Currency?;
    return GoalFilters(
      currency: c,
      type: identical(type, _keep) ? filters.type : type as GoalType?,
      // Amounts are in each goal's own currency, so they only apply with a currency.
      minTargetAmount: c == null
          ? null
          : (identical(min, _keep) ? filters.minTargetAmount : min as int?),
      maxTargetAmount: c == null
          ? null
          : (identical(max, _keep) ? filters.maxTargetAmount : max as int?),
      yearFrom: years == null ? filters.yearFrom : years.$1,
      yearTo: years == null ? filters.yearTo : years.$2,
    );
  }

  static const _keep = Object();

  Future<void> _editAmount(BuildContext context, Currency currency) async {
    final range = await showDialog<(int?, int?)>(
      context: context,
      builder: (_) => _AmountDialog(
        currency: currency,
        min: filters.minTargetAmount,
        max: filters.maxTargetAmount,
      ),
    );
    if (range != null) onApply(_with(min: range.$1, max: range.$2));
  }

  @override
  Widget build(BuildContext context) {
    final timeline = Timeline.of(filters, year);
    final currency = filters.currency;
    final hasAmount = filters.minTargetAmount != null || filters.maxTargetAmount != null;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: .horizontal,
          child: Row(
            children: [
              _TypeChip(
                label: _allGoalsText,
                selected: filters.type == null,
                onTap: () => onApply(_with(type: null)),
              ),
              for (final t in GoalType.values)
                _TypeChip(
                  icon: t.icon,
                  label: t.label,
                  selected: filters.type == t,
                  onTap: () => onApply(_with(type: filters.type == t ? null : t)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: .center,
          children: [
            _MenuPill<Currency?>(
              icon: Icons.payments_outlined,
              label: currency == null ? _anyCurrencyText : currency.code,
              active: currency != null,
              options: [(null, _anyCurrencyText), for (final c in Currency.values) (c, c.code)],
              onSelected: (c) => onApply(_with(currency: c)),
            ),
            _MenuPill<Timeline>(
              icon: Icons.event_outlined,
              label: timeline.label,
              active: timeline != Timeline.any,
              options: [for (final t in Timeline.values) (t, t.label)],
              onSelected: (t) => onApply(_with(years: t.years(year))),
            ),
            if (currency != null)
              _Pill(
                icon: Icons.tune,
                label: hasAmount ? _amountLabel(currency) : _targetAmountText,
                active: hasAmount,
                onTap: () => _editAmount(context, currency),
              ),
            _MenuPill<GoalSort>(
              icon: Icons.sort,
              label: sort.label,
              active: false,
              options: [for (final s in GoalSort.values) (s, s.label)],
              onSelected: onSortChanged,
            ),
            if (!filters.isEmpty)
              TextButton.icon(
                onPressed: () => onApply(GoalFilters.none),
                icon: const Icon(Icons.close, size: 16),
                label: const Text(_clearFiltersText),
              ),
          ],
        ),
      ],
    );
  }

  String _amountLabel(Currency c) {
    String fmt(int v) => '${c.symbol.trim()}${Scaled.formatCompact(v)}';
    return switch ((filters.minTargetAmount, filters.maxTargetAmount)) {
      (final min?, final max?) => '${fmt(min)} – ${fmt(max)}',
      (final min?, null) => 'From ${fmt(min)}',
      (null, final max?) => 'Up to ${fmt(max)}',
      _ => _targetAmountText,
    };
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(right: 8),
    child: ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? AppColors.onGold : AppColors.gold),
      label: Text(label, style: TextStyle(color: selected ? AppColors.onGold : AppColors.text)),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.active, this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.gold : AppColors.text;
    return Material(
      color: active ? AppColors.goldTint : AppColors.layer,
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.gold : AppColors.borderStrong),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: .min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, color: color)),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuPill<T> extends StatelessWidget {
  const _MenuPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(backgroundColor: WidgetStatePropertyAll(AppColors.layer)),
      menuChildren: [
        for (final (value, text) in options)
          MenuItemButton(onPressed: () => onSelected(value), child: Text(text)),
      ],
      builder: (context, controller, _) => _Pill(
        icon: icon,
        label: label,
        active: active,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.currency, this.min, this.max});

  final Currency currency;
  final int? min;
  final int? max;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _min = TextEditingController(text: _text(widget.min));
  late final _max = TextEditingController(text: _text(widget.max));
  String? _error;

  static String _text(int? v) => v == null ? '' : Scaled.formatCompact(v);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _done() {
    final min = _min.text.isEmpty ? null : Scaled.tryParse(_min.text);
    final max = _max.text.isEmpty ? null : Scaled.tryParse(_max.text);
    final error = switch (true) {
      _ when (_min.text.isNotEmpty && min == null) || (_max.text.isNotEmpty && max == null) =>
        _useNumbersWithAtText,
      _ when min != null && max != null && min > max => _minimumIsAboveTheText,
      _ => null,
    };
    if (error != null) return setState(() => _error = error);
    Navigator.pop(context, (min, max));
  }

  @override
  Widget build(BuildContext context) {
    final decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
    final symbol = widget.currency.symbol.trim();
    return AlertDialog(
      title: Text('Target amount (${widget.currency.code})'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _min,
              autofocus: true,
              inputFormatters: [decimal],
              decoration: InputDecoration(labelText: 'From ($symbol)'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _max,
              inputFormatters: [decimal],
              onSubmitted: (_) => _done(),
              decoration: InputDecoration(labelText: 'Up to ($symbol)', errorText: _error),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (null, null)),
          child: const Text(_anyAmountText),
        ),
        FilledButton(onPressed: _done, child: const Text(_applyText)),
      ],
    );
  }
}
