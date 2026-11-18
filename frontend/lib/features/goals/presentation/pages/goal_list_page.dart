import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../../../core/format/money_formatter.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../projection/domain/engine/projection_calculator.dart';
import '../../../projection/domain/usecases/calculate_goal_totals.dart';
import '../../domain/entities/goal_type.dart';
import '../bloc/goal_list_bloc.dart';
import '../widgets/goal_type_icon.dart';

class GoalListPage extends StatelessWidget {
  const GoalListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AuthBloc>().state.user?.defaultCurrency ?? Currency.inr;
    return BlocProvider(
      create: (_) => sl<GoalListBloc>()..add(GoalsRequested(currency)),
      child: const _GoalListView(),
    );
  }
}

class _GoalListView extends StatelessWidget {
  const _GoalListView();

  Future<void> _open(BuildContext context, String location) async {
    final bloc = context.read<GoalListBloc>();
    final currency = switch (bloc.state) {
      GoalListLoaded(:final overview) => overview.totals.currency,
      _ => context.read<AuthBloc>().state.user?.defaultCurrency ?? Currency.inr,
    };
    final createdId = await context.push<String>(location);
    if (createdId != null && location.startsWith(Routes.newGoal) && context.mounted) {
      await context.push(Routes.goal(createdId));
    }
    bloc.add(GoalsRequested(currency));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GoalListBloc>().state;

    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 16,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My goals', style: TextStyle(fontSize: 32)),
                  SizedBox(height: 4),
                  Text(
                    'Each goal shows the monthly SIP needed to reach it on time.',
                    style: TextStyle(color: AppColors.text2),
                  ),
                ],
              ),
              if (state is! GoalListEmpty)
                FilledButton.icon(
                  onPressed: () => _open(context, Routes.newGoal),
                  icon: const Icon(Icons.add),
                  label: const Text('New goal'),
                ),
            ],
          ),
          const SizedBox(height: 32),
          switch (state) {
            GoalListLoading(:final isSlow) => LoadingView(
              label: 'Loading your goals',
              isSlow: isSlow,
              skeleton: const Column(
                children: [SkeletonBox(height: 96), SkeletonBox(), SkeletonBox()],
              ),
            ),
            GoalListError(:final failure, :final totalCurrency) => ErrorView(
              title: 'We couldn’t load your goals.',
              failure: failure,
              hint: 'Your saved goals are safe.',
              onRetry: () => context.read<GoalListBloc>().add(GoalsRequested(totalCurrency)),
            ),
            GoalListEmpty() => _EmptyGoals(onCreate: (location) => _open(context, location)),
            GoalListLoaded(:final overview) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryStrip(totals: overview.totals, count: overview.summaries.length),
                const SizedBox(height: 24),
                _GoalGrid(
                  summaries: overview.summaries,
                  onOpen: (id) => _open(context, Routes.goal(id)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SIP amounts use the return you entered for each goal and are illustrative '
                  'assumptions, not promises.',
                  style: TextStyle(fontSize: 12, color: AppColors.text2),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.totals, required this.count});

  final GoalTotals totals;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.layer,
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 48,
        runSpacing: 24,
        children: [
          _Stat(label: 'Goals', value: '$count'),
          _Stat(
            label: 'Total monthly SIP needed',
            value: MoneyFormatter.full(totals.monthlySip, totals.currency),
            trailing: _CurrencyPicker(
              value: totals.currency,
              onChanged: (c) => context.read<GoalListBloc>().add(TotalCurrencyChanged(c)),
            ),
            note: totals.converted
                ? 'Approximate, at rates from ${DateFormats.dayMonthYear.format(totals.ratesAsOf)}'
                : null,
          ),
          _Stat(
            label: 'All goals added up',
            value: MoneyFormatter.short(totals.target, totals.currency),
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

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.value, required this.onChanged});

  final Currency value;
  final ValueChanged<Currency> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Currency>(
      value: value,
      underline: const SizedBox.shrink(),
      dropdownColor: AppColors.layer,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      items: [for (final c in Currency.values) DropdownMenuItem(value: c, child: Text(c.code))],
      onChanged: (c) => c == null ? null : onChanged(c),
    );
  }
}

class _GoalGrid extends StatelessWidget {
  const _GoalGrid({required this.summaries, required this.onOpen});

  final List<GoalSummary> summaries;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final s in summaries)
              SizedBox(
                width: width,
                child: _GoalCard(summary: s, onOpen: () => onOpen(s.goal.id)),
              ),
          ],
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.summary, required this.onOpen});

  final GoalSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final goal = summary.goal;
    final c = goal.currency;
    final monthsLeft = ProjectionCalculator.monthsBetween(DateTime.now(), goal.targetDate);
    final stepLine = goal.annualStepUpBp == 0
        ? 'Same amount every month'
        : 'or start at ${MoneyFormatter.full(summary.stepUpFirstSip, c)}, rising '
              '${Scaled.formatCompact(goal.annualStepUpBp)}% a year';

    return Material(
      color: AppColors.layer,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(goal.type.icon, color: AppColors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 20),
              const Text(
                'Invest every month',
                style: TextStyle(fontSize: 12, color: AppColors.text2),
              ),
              Text(
                summary.projection.onTrack
                    ? 'Nothing more needed'
                    : MoneyFormatter.full(summary.levelSip, c),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
              ),
              Text(stepLine, style: const TextStyle(color: AppColors.text2, fontSize: 13)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (summary.progressPct / 100).clamp(0, 1),
                backgroundColor: AppColors.border,
                color: AppColors.gold,
                minHeight: 4,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved ${MoneyFormatter.short(Scaled.toDouble(goal.currentCorpus), c)} · '
                      '${summary.progressPct.toStringAsFixed(summary.progressPct < 10 ? 1 : 0)}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.text2),
                    ),
                  ),
                  Text(
                    '${DateFormats.duration(monthsLeft)} left',
                    style: const TextStyle(fontSize: 12, color: AppColors.text2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('See full plan →', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onCreate});

  final ValueChanged<String> onCreate;

  static const _templates = [
    GoalType.home,
    GoalType.education,
    GoalType.retirement,
    GoalType.emergencyFund,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.layer,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.gold, size: 40),
          const SizedBox(height: 16),
          const Text('You haven’t added any goals yet', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          const Text(
            'Add something you’re saving for — like a home, a car or retirement. '
            'We’ll work out how much to invest each month to get there.',
            style: TextStyle(color: AppColors.text2, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => onCreate(Routes.newGoal),
            child: const Text('Create your first goal'),
          ),
          const SizedBox(height: 24),
          const Text('Or start from:', style: TextStyle(color: AppColors.text2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _templates)
                ActionChip(
                  avatar: Icon(t.icon, size: 16, color: AppColors.gold),
                  label: Text(t.label),
                  onPressed: () => onCreate('${Routes.newGoal}?type=${t.code}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
