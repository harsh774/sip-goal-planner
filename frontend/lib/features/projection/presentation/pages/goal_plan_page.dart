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
import '../../../goals/domain/entities/goal.dart';
import '../../domain/entities/projection.dart';
import '../bloc/projection_bloc.dart';
import '../widgets/growth_chart.dart';
import '../widgets/plan_tables.dart';

class GoalPlanPage extends StatelessWidget {
  const GoalPlanPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProjectionBloc>()..add(ProjectionRequested(goalId)),
      child: BlocListener<ProjectionBloc, ProjectionState>(
        listener: (context, state) {
          if (state is GoalDeleted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Goal deleted.')));
            context.pop();
          }
          if (state case ProjectionLoaded(deleteFailure: final failure?)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
          }
        },
        child: _GoalPlanView(goalId: goalId),
      ),
    );
  }
}

class _GoalPlanView extends StatelessWidget {
  const _GoalPlanView({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectionBloc>().state;
    return AppShell(
      extendedDisclaimer: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.canPop() ? context.pop() : context.go(Routes.goals),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('My goals'),
            ),
          ),
          const SizedBox(height: 8),
          switch (state) {
            ProjectionLoading(:final isSlow) => LoadingView(
              label: 'Calculating your plan',
              isSlow: isSlow,
              skeleton: const Column(
                children: [SkeletonBox(height: 120), SkeletonBox(height: 300)],
              ),
            ),
            ProjectionError(:final failure) => ErrorView(
              title: 'We couldn’t calculate your plan.',
              failure: failure,
              hint: 'Your goal is saved — try again in a moment.',
              onRetry: () => context.read<ProjectionBloc>().add(ProjectionRequested(goalId)),
            ),
            GoalDeleted() => const SizedBox.shrink(),
            final ProjectionLoaded loaded => _Plan(state: loaded),
          },
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.state});

  final ProjectionLoaded state;

  Goal get goal => state.goal;
  Projection get p => state.projection;
  Currency get c => goal.currency;
  double get target => Scaled.toDouble(goal.targetAmount);
  String get stepPct => Scaled.formatCompact(goal.annualStepUpBp);

  Future<void> _edit(BuildContext context) async {
    final bloc = context.read<ProjectionBloc>();
    await context.push(Routes.editGoal(goal.id));
    bloc.add(ProjectionRequested(goal.id));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<ProjectionBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${goal.name}”?'),
        content: const Text('It will disappear from your goals. Its history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(const GoalDeleteRequested());
  }

  @override
  Widget build(BuildContext context) {
    final finalShort = MoneyFormatter.short(target, c);
    final goalYear = goal.targetDate.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name, style: const TextStyle(fontSize: 32)),
                Text(
                  '${MoneyFormatter.words(target, c)} by ${DateFormats.monthYear.format(goal.targetDate)} · '
                  '${DateFormats.duration(p.months)} to go',
                  style: const TextStyle(color: AppColors.text2),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit goal'),
                ),
                OutlinedButton.icon(
                  onPressed: state.deleting ? null : () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Hero(state: state, stepPct: stepPct),
        const SizedBox(height: 16),
        _Responsive(
          children: [
            _Card(
              title: 'What makes up your $finalShort in $goalYear',
              child: _Breakdown(plan: state.selectedPlan, currency: c),
            ),
            _Card(
              title: 'Inflation',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your goal in today’s money',
                    style: TextStyle(color: AppColors.text2),
                  ),
                  Text(MoneyFormatter.short(p.todayValue, c), style: const TextStyle(fontSize: 28)),
                  Text(
                    'At ${Scaled.formatCompact(goal.inflationBp)}% inflation a year, $finalShort in $goalYear '
                    'buys what ${MoneyFormatter.short(p.todayValue, c)} buys today.',
                    style: const TextStyle(color: AppColors.text2, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'How your money grows, year by year',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChartLegend(stepUpPct: stepPct, goalLabel: finalShort),
              const SizedBox(height: 16),
              GrowthChart(
                projection: p,
                corpus: Scaled.toDouble(goal.currentCorpus),
                target: target,
                currency: c,
              ),
              const SizedBox(height: 24),
              Text(
                state.mode == PlanMode.level
                    ? 'Same amount every month'
                    : 'Increasing $stepPct% every year',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              YearlyTable(plan: state.selectedPlan, currency: c),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Compare the two ways to invest',
          subtitle: 'Both reach $finalShort by $goalYear.',
          child: ComparisonTable(projection: p, currency: c, stepUpPct: stepPct),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'How we work this out',
          child: _Explainer(goal: goal, projection: p),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state, required this.stepPct});

  final ProjectionLoaded state;
  final String stepPct;

  @override
  Widget build(BuildContext context) {
    final p = state.projection;
    final c = state.goal.currency;
    final plan = state.selectedPlan;

    return Container(
      color: AppColors.layer,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your monthly plan', style: TextStyle(color: AppColors.text2)),
          const SizedBox(height: 12),
          SegmentedButton<PlanMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              shape: const RoundedRectangleBorder(),
              selectedBackgroundColor: AppColors.gold,
              selectedForegroundColor: AppColors.onGold,
            ),
            segments: [
              const ButtonSegment(value: PlanMode.level, label: Text('Same amount every month')),
              ButtonSegment(value: PlanMode.stepUp, label: Text('Increase $stepPct% every year')),
            ],
            selected: {state.mode},
            onSelectionChanged: (s) => context.read<ProjectionBloc>().add(PlanModeToggled(s.first)),
          ),
          const SizedBox(height: 20),
          if (p.onTrack)
            const NoticeBanner(
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              background: AppColors.successBg,
              title: 'Good news:',
              body: 'the money you’ve already invested is expected to reach this goal on its own.',
            )
          else ...[
            Text(
              state.mode == PlanMode.level ? 'Invest every month' : 'Start with',
              style: const TextStyle(color: AppColors.text2),
            ),
            Text.rich(
              TextSpan(
                text: MoneyFormatter.full(plan.firstYearSip, c),
                children: const [
                  TextSpan(
                    text: ' / month',
                    style: TextStyle(fontSize: 18, color: AppColors.text2),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300),
            ),
            Text(
              state.mode == PlanMode.level
                  ? 'The same amount until ${DateFormats.monthYear.format(state.goal.targetDate)}.'
                  : 'Rising to ${MoneyFormatter.full(plan.finalYearSip, c)} a month in the final year.',
              style: const TextStyle(color: AppColors.text2),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Return and inflation are illustrative assumptions, not guarantees.',
            style: TextStyle(fontSize: 12, color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.plan, required this.currency});

  final Plan plan;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final total = plan.finalBalance;
    final inPct = total == 0 ? 0 : plan.totalInvested / total * 100;
    final growthPct = 100 - inPct;
    Widget line(Color color, String label, double value, num pct) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.text2)),
          ),
          Text('${MoneyFormatter.short(value, currency)} (${pct.toStringAsFixed(0)}%)'),
        ],
      ),
    );
    return Column(
      children: [
        ClipRect(
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                Expanded(
                  flex: inPct.round().clamp(1, 99),
                  child: Container(color: AppColors.seriesLevel),
                ),
                Expanded(
                  flex: growthPct.round().clamp(1, 99),
                  child: Container(color: AppColors.gold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        line(AppColors.seriesLevel, 'You put in', plan.totalInvested, inPct),
        line(AppColors.gold, 'Growth from returns', plan.growth, growthPct),
      ],
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer({required this.goal, required this.projection});

  final Goal goal;
  final Projection projection;

  @override
  Widget build(BuildContext context) {
    final c = goal.currency;
    final ret = Scaled.formatCompact(goal.expectedReturnBp);
    final step = Scaled.formatCompact(goal.annualStepUpBp);
    final infl = Scaled.formatCompact(goal.inflationBp);
    final terms = [
      (
        'SIP (Systematic Investment Plan)',
        'A fixed amount invested in a mutual fund every month. We assume it goes in on the first day of each month.',
      ),
      (
        'Expected return',
        'The yearly growth you entered ($ret%). We convert it to the monthly rate that compounds to exactly $ret% '
            'over a year, so your returns also earn returns. It is an assumption, not a promise.',
      ),
      (
        'Step-up',
        'Raising your SIP by a fixed percentage ($step%) once a year, at the start of each new year.',
      ),
      (
        'Inflation and today’s money',
        'Prices rise each year ($infl% here). Today’s money is the goal amount reduced by that rise for every '
            'year until your goal, so you can see its real buying power.',
      ),
    ];
    final steps = [
      'Your goal: ${MoneyFormatter.short(Scaled.toDouble(goal.targetAmount), c)} in ${goal.targetDate.year}.',
      'Money already invested grows to ${MoneyFormatter.short(projection.corpusFutureValue, c)}.',
      'The gap left to fill: ${MoneyFormatter.short(projection.gap, c)}.',
      'Monthly SIP that fills it in ${DateFormats.duration(projection.months)}: '
          '${MoneyFormatter.full(projection.level.firstYearSip, c)}, or '
          '${MoneyFormatter.full(projection.stepUp.firstYearSip, c)} rising $step% a year.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, body) in terms)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(body, style: const TextStyle(color: AppColors.text2, height: 1.4)),
              ],
            ),
          ),
        const Divider(height: 24),
        const Text('Your numbers, step by step', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${i + 1}. $s', style: const TextStyle(height: 1.4)),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.layer,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Responsive extends StatelessWidget {
  const _Responsive({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 800
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: child),
                ],
              ],
            ),
          )
        : Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                child,
              ],
            ],
          ),
  );
}
