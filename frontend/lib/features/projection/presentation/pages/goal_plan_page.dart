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
import '../../../../shared/widgets/elevated_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../domain/entities/projection.dart';
import '../bloc/projection_bloc.dart';
import '../widgets/growth_chart.dart';
import '../widgets/plan_tables.dart';

const _goalDeletedText = 'Goal deleted.';
const _myGoalsText = 'My goals';
const _calculatingYourPlanText = 'Calculating your plan';
const _weCouldntCalculateYourText = 'We couldn’t calculate your plan.';
const _yourGoalIsSavedText = 'Your goal is saved — try again in a moment.';
const _itWillDisappearFromText = 'It will disappear from your goals. Its history is kept.';
const _cancelText = 'Cancel';
const _deleteText = 'Delete';
const _editGoalText = 'Edit goal';
const _inflationText = 'Inflation';
const _yourGoalInTodaysText = 'Your goal in today’s money';
const _howYourMoneyGrowsText = 'How your money grows, year by year';
const _compareTheTwoWaysText = 'Compare the two ways to invest';
const _howWeWorkThisText = 'How we work this out';
const _yourMonthlyPlanText = 'Your monthly plan';
const _goodNewsText = 'Good news:';
const _theMoneyYouVeText =
    'the money you’ve already invested is expected to reach this goal on its own.';
const _monthText = ' / month';
const _yourNumbersStepByText = 'Your numbers, step by step';

// Copy
const _levelLabel = 'Same amount every month';
const _assumptionsNote = 'Return and inflation are illustrative assumptions, not guarantees.';
const _sameEveryMonthText = 'Same every month';
const _investEveryMonthText = 'Invest every month';
const _startWithText = 'Start with';
const _youPutInText = 'You put in';
const _growthFromReturnsText = 'Growth from returns';
const _sipSystematicInvestmentPlanText = 'SIP (Systematic Investment Plan)';
const _aFixedAmountInvestedText =
    'A fixed amount invested in a mutual fund every month. We assume it goes in on the first day of each month.';
const _expectedReturnText = 'Expected return';
const _stepUpText = 'Step-up';
const _inflationAndTodaysMoneyText = 'Inflation and today’s money';

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
            ).showSnackBar(const SnackBar(content: Text(_goalDeletedText)));
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
        crossAxisAlignment: .stretch,
        children: [
          Align(
            alignment: .centerLeft,
            child: TextButton.icon(
              onPressed: () => context.canPop() ? context.pop() : context.go(Routes.goals),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text(_myGoalsText),
            ),
          ),
          const SizedBox(height: 8),
          switch (state) {
            ProjectionLoading(:final isSlow) => LoadingView(
              label: _calculatingYourPlanText,
              isSlow: isSlow,
              skeleton: const Column(
                children: [SkeletonBox(height: 120), SkeletonBox(height: 300)],
              ),
            ),
            ProjectionError(:final failure) => ErrorView(
              title: _weCouldntCalculateYourText,
              failure: failure,
              hint: _yourGoalIsSavedText,
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
  bool get hasStepUp => goal.annualStepUpBp > 0;

  String? get _otherLabel => !hasStepUp
      ? null
      : state.mode == PlanMode.level
      ? 'With $stepPct% yearly increase'
      : _sameEveryMonthText;

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
        content: const Text(_itWillDisappearFromText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(_cancelText),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(_deleteText),
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
      crossAxisAlignment: .stretch,
      children: [
        Wrap(
          alignment: .spaceBetween,
          crossAxisAlignment: .center,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: .start,
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
                  label: const Text(_editGoalText),
                ),
                OutlinedButton.icon(
                  onPressed: state.deleting ? null : () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(_deleteText),
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
              title: _inflationText,
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  const Text(_yourGoalInTodaysText, style: TextStyle(color: AppColors.text2)),
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
          title: _howYourMoneyGrowsText,
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              ChartLegend(goalLabel: finalShort, otherLabel: _otherLabel),
              const SizedBox(height: 16),
              GrowthChart(
                plan: state.selectedPlan,
                otherPlan: hasStepUp ? (state.mode == PlanMode.level ? p.stepUp : p.level) : null,
                corpus: Scaled.toDouble(goal.currentCorpus),
                target: target,
                currency: c,
                startYear: p.asOf.year,
              ),
              const SizedBox(height: 24),
              if (hasStepUp)
                Text(
                  state.mode == PlanMode.level ? _levelLabel : 'Increasing $stepPct% every year',
                  style: const TextStyle(fontWeight: .w600),
                ),
              YearlyTable(plan: state.selectedPlan, currency: c),
            ],
          ),
        ),
        if (hasStepUp) ...[
          const SizedBox(height: 16),
          _Card(
            title: _compareTheTwoWaysText,
            subtitle: 'Both reach $finalShort by $goalYear.',
            child: ComparisonTable(projection: p, currency: c, stepUpPct: stepPct),
          ),
        ],
        const SizedBox(height: 16),
        _Card(
          title: _howWeWorkThisText,
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

    return ElevatedCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text(_yourMonthlyPlanText, style: TextStyle(color: AppColors.text2)),
          const SizedBox(height: 12),
          if (state.goal.annualStepUpBp > 0) ...[
            SegmentedButton<PlanMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: .circular(10)),
                selectedBackgroundColor: AppColors.gold,
                selectedForegroundColor: AppColors.onGold,
              ),
              segments: [
                const ButtonSegment(value: PlanMode.level, label: Text(_levelLabel)),
                ButtonSegment(value: PlanMode.stepUp, label: Text('Increase $stepPct% every year')),
              ],
              selected: {state.mode},
              onSelectionChanged: (s) =>
                  context.read<ProjectionBloc>().add(PlanModeToggled(s.first)),
            ),
            const SizedBox(height: 20),
          ],
          if (p.onTrack)
            const NoticeBanner(
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              background: AppColors.successBg,
              title: _goodNewsText,
              body: _theMoneyYouVeText,
            )
          else ...[
            Text(
              state.mode == PlanMode.level ? _investEveryMonthText : _startWithText,
              style: const TextStyle(color: AppColors.text2),
            ),
            Text.rich(
              TextSpan(
                text: MoneyFormatter.full(plan.firstYearSip, c),
                children: const [
                  TextSpan(
                    text: _monthText,
                    style: TextStyle(fontSize: 18, color: AppColors.text2),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 44, fontWeight: .w300),
            ),
            Text(
              state.mode == PlanMode.level
                  ? 'The same amount until ${DateFormats.monthYear.format(state.goal.targetDate)}.'
                  : 'Rising to ${MoneyFormatter.full(plan.finalYearSip, c)} a month in the final year.',
              style: const TextStyle(color: AppColors.text2),
            ),
          ],
          const SizedBox(height: 12),
          const Text(_assumptionsNote, style: TextStyle(fontSize: 12, color: AppColors.text3)),
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
      padding: const .symmetric(vertical: 6),
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
        line(AppColors.seriesLevel, _youPutInText, plan.totalInvested, inPct),
        line(AppColors.gold, _growthFromReturnsText, plan.growth, growthPct),
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
    final hasStepUp = goal.annualStepUpBp > 0;
    final terms = [
      (_sipSystematicInvestmentPlanText, _aFixedAmountInvestedText),
      (
        _expectedReturnText,
        'The yearly growth you entered ($ret%). We convert it to the monthly rate that compounds to exactly $ret% '
            'over a year, so your returns also earn returns. It is an assumption, not a promise.',
      ),
      if (hasStepUp)
        (
          _stepUpText,
          'Raising your SIP by a fixed percentage ($step%) once a year, at the start of each new year.',
        ),
      (
        _inflationAndTodaysMoneyText,
        'Prices rise each year ($infl% here). Today’s money is the goal amount reduced by that rise for every '
            'year until your goal, so you can see its real buying power.',
      ),
    ];
    final steps = [
      'Your goal: ${MoneyFormatter.short(Scaled.toDouble(goal.targetAmount), c)} in ${goal.targetDate.year}.',
      'Money already invested grows to ${MoneyFormatter.short(projection.corpusFutureValue, c)}.',
      'The gap left to fill: ${MoneyFormatter.short(projection.gap, c)}.',
      'Monthly SIP that fills it in ${DateFormats.duration(projection.months)}: '
          '${MoneyFormatter.full(projection.level.firstYearSip, c)}'
          '${hasStepUp ? ', or ${MoneyFormatter.full(projection.stepUp.firstYearSip, c)} rising $step% a year' : ''}.',
    ];

    return Column(
      crossAxisAlignment: .start,
      children: [
        for (final (title, body) in terms)
          Padding(
            padding: const .only(bottom: 12),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(title, style: const TextStyle(fontWeight: .w600)),
                Text(body, style: const TextStyle(color: AppColors.text2, height: 1.4)),
              ],
            ),
          ),
        const Divider(height: 24),
        const Text(_yourNumbersStepByText, style: TextStyle(fontWeight: .w600)),
        const SizedBox(height: 8),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const .only(bottom: 6),
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
    return ElevatedCard(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: .w600)),
          if (subtitle case final s?) Text(s, style: const TextStyle(color: AppColors.text2)),
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
              crossAxisAlignment: .stretch,
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
