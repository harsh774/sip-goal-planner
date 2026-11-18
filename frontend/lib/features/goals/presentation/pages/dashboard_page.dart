import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/currency.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/goal_query.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/empty_goals.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_filters_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/summary_strip.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AuthBloc>().state.user?.defaultCurrency ?? Currency.inr;
    return BlocProvider(
      create: (_) => sl<DashboardBloc>()..add(DashboardRequested(currency)),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  Future<void> _open(BuildContext context, String location) async {
    final bloc = context.read<DashboardBloc>();
    final createdId = await context.push<String>(location);
    if (createdId != null && location.startsWith(Routes.newGoal) && context.mounted) {
      await context.push(Routes.goal(createdId));
    }
    bloc.add(DashboardRequested(bloc.state.totalCurrency));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardBloc>().state;
    final bloc = context.read<DashboardBloc>();

    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(showNewGoal: !state.hasNoGoals, onNewGoal: () => _open(context, Routes.newGoal)),
          const SizedBox(height: 32),
          switch (state.status) {
            DashboardStatus.loading => LoadingView(
              label: 'Loading your goals',
              isSlow: state.isSlow,
              skeleton: const Column(
                children: [SkeletonBox(height: 96), SkeletonBox(), SkeletonBox()],
              ),
            ),
            DashboardStatus.failure => ErrorView(
              title: 'We couldn’t load your goals.',
              failure: state.failure!,
              hint: 'Your saved goals are safe.',
              onRetry: () => bloc.add(DashboardRequested(state.totalCurrency)),
            ),
            DashboardStatus.ready when state.hasNoGoals => EmptyGoals(
              onCreate: (location) => _open(context, location),
            ),
            DashboardStatus.ready => _Dashboard(
              state: state,
              onOpen: (id) => _open(context, Routes.goal(id)),
            ),
          },
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showNewGoal, required this.onNewGoal});

  final bool showNewGoal;
  final VoidCallback onNewGoal;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
        if (showNewGoal)
          FilledButton.icon(
            onPressed: onNewGoal,
            icon: const Icon(Icons.add),
            label: const Text('New goal'),
          ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.state, required this.onOpen});

  final DashboardState state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DashboardBloc>();
    final page = state.page!;
    final filters = state.query.filters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.summary case final summary?)
          SummaryStrip(
            summary: summary,
            filtered: !filters.isEmpty,
            onCurrencyChanged: (c) => bloc.add(DashboardTotalCurrencyChanged(c)),
          ),
        const SizedBox(height: 32),
        const _SectionTitle('Reaching soon', 'Your goals with the nearest target dates.'),
        CardGrid(
          maxColumns: 3,
          children: [
            for (final plan in state.reachingSoon)
              GoalCard(plan: plan, compact: true, onOpen: () => onOpen(plan.goal.id)),
          ],
        ),
        const SizedBox(height: 40),
        _SectionTitle('All goals', '${page.total} ${page.total == 1 ? 'goal' : 'goals'}'),
        GoalFiltersBar(
          key: ValueKey(filters),
          filters: filters,
          sort: state.query.sort,
          onApply: (f) => bloc.add(DashboardFiltersChanged(f)),
          onSortChanged: (s) => bloc.add(DashboardSortChanged(s)),
        ),
        const SizedBox(height: 16),
        if (state.failure case final failure?) ...[
          NoticeBanner(
            icon: Icons.error_outline,
            color: AppColors.danger,
            background: AppColors.dangerBg,
            title: 'Couldn’t update the list.',
            body: failure.message,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(height: 4, child: state.listLoading ? const LinearProgressIndicator() : null),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: state.listLoading ? 0.5 : 1,
          duration: const Duration(milliseconds: 150),
          child: page.items.isEmpty
              ? NoMatchingGoals(
                  onClear: () => bloc.add(const DashboardFiltersChanged(GoalFilters.none)),
                )
              : CardGrid(
                  children: [
                    for (final plan in page.items)
                      GoalCard(plan: plan, onOpen: () => onOpen(plan.goal.id)),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        PaginationBar(
          page: page.page,
          totalPages: page.totalPages,
          total: page.total,
          enabled: !state.listLoading,
          onPage: (p) => bloc.add(DashboardPageChanged(p)),
        ),
        const SizedBox(height: 16),
        const Text(
          'SIP amounts use the return you entered for each goal and are illustrative '
          'assumptions, not promises.',
          style: TextStyle(fontSize: 12, color: AppColors.text2),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(color: AppColors.text2)),
        ],
      ),
    );
  }
}
