import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/currency.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../../../shared/widgets/loading_visuals.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/empty_goals.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_filters_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/summary_strip.dart';

const _loadingYourGoalsText = 'Loading your goals';
const _weCouldntLoadYourText = 'We couldn’t load your goals.';
const _yourSavedGoalsAreText = 'Your saved goals are safe.';
const _myGoalsText = 'My goals';
const _eachGoalShowsTheText = 'Each goal shows the monthly SIP needed to reach it on time.';
const _newGoalText = 'New goal';
const _couldntUpdateTheListText = 'Couldn’t update the list.';
const _reachingSoonText = 'Reaching soon';
const _yourGoalsWithTheText = 'Your goals with the nearest target dates.';
const _allGoalsText = 'All goals';
const _searchHintText = 'Search your goals by name';
const _clearSearchText = 'Clear search';
const _sipAmountsUseTheText =
    'SIP amounts use the return you entered for each goal and are illustrative assumptions, not promises.';

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

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final _allGoalsKey = GlobalKey();

  void _scrollToAllGoals() {
    if (_allGoalsKey.currentContext case final target?) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

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
        crossAxisAlignment: .stretch,
        children: [
          _Header(
            showNewGoal: !state.hasNoGoals,
            onNewGoal: () => _open(context, Routes.newGoal),
            onAllGoals: state.status == DashboardStatus.ready && !state.hasNoGoals
                ? _scrollToAllGoals
                : null,
          ),
          const SizedBox(height: 32),
          switch (state.status) {
            DashboardStatus.loading => LoadingView(
              label: _loadingYourGoalsText,
              isSlow: state.isSlow,
              skeleton: const _DashboardSkeleton(),
            ),
            DashboardStatus.failure => ErrorView(
              title: _weCouldntLoadYourText,
              failure: state.failure!,
              hint: _yourSavedGoalsAreText,
              onRetry: () => bloc.add(DashboardRequested(state.totalCurrency)),
            ),
            DashboardStatus.ready when state.hasNoGoals => EmptyGoals(
              onCreate: (location) => _open(context, location),
            ),
            DashboardStatus.ready => _Dashboard(
              allGoalsKey: _allGoalsKey,
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
  const _Header({required this.showNewGoal, required this.onNewGoal, this.onAllGoals});

  final bool showNewGoal;
  final VoidCallback onNewGoal;

  /// Scrolls down to the full list; null hides the button.
  final VoidCallback? onAllGoals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: .spaceBetween,
      crossAxisAlignment: .center,
      runSpacing: 16,
      children: [
        const Column(
          crossAxisAlignment: .start,
          children: [
            Text(_myGoalsText, style: TextStyle(fontSize: 32)),
            SizedBox(height: 4),
            Text(_eachGoalShowsTheText, style: TextStyle(color: AppColors.text2)),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: .center,
          children: [
            if (onAllGoals case final scroll?)
              OutlinedButton.icon(
                onPressed: scroll,
                icon: const Icon(Icons.south, size: 18),
                label: const Text(_allGoalsText),
              ),
            if (showNewGoal)
              GoldButton(onPressed: onNewGoal, icon: Icons.add, child: const Text(_newGoalText)),
          ],
        ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.allGoalsKey, required this.state, required this.onOpen});

  final Key allGoalsKey;
  final DashboardState state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DashboardBloc>();
    final page = state.page!;
    final filters = state.query.filters;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (state.summary case final summary?)
          SummaryStrip(
            summary: summary,
            onCurrencyChanged: (c) => bloc.add(DashboardTotalCurrencyChanged(c)),
          ),
        const SizedBox(height: 32),
        const _SectionTitle(_reachingSoonText, _yourGoalsWithTheText),
        CardGrid(
          maxColumns: 3,
          children: [
            for (final plan in state.reachingSoon)
              GoalCard(plan: plan, compact: true, onOpen: () => onOpen(plan.goal.id)),
          ],
        ),
        const SizedBox(height: 40),
        KeyedSubtree(
          key: allGoalsKey,
          child: _SectionTitle(
            _allGoalsText,
            state.query.search.isEmpty
                ? '${page.total} ${page.total == 1 ? 'goal' : 'goals'}'
                : '${page.total} matching “${state.query.search}”',
          ),
        ),
        _GoalSearchField(
          initial: state.query.search,
          onChanged: (text) => bloc.add(DashboardSearchChanged(text)),
        ),
        const SizedBox(height: 12),
        GoalFiltersBar(
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
            title: _couldntUpdateTheListText,
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
              ? const NoMatchingGoals()
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
        const Text(_sipAmountsUseTheText, style: TextStyle(fontSize: 12, color: AppColors.text2)),
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
      padding: const .only(bottom: 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: .w600)),
          Text(subtitle, style: const TextStyle(color: AppColors.text2)),
        ],
      ),
    );
  }
}

class _GoalSearchField extends StatefulWidget {
  const _GoalSearchField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_GoalSearchField> createState() => _GoalSearchFieldState();
}

class _GoalSearchFieldState extends State<_GoalSearchField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: .search,
      onChanged: (text) {
        setState(() {});
        widget.onChanged(text);
      },
      decoration: InputDecoration(
        hintText: _searchHintText,
        prefixIcon: const Icon(Icons.search, color: AppColors.text2),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: _clearSearchText,
                icon: const Icon(Icons.close),
                onPressed: _clear,
              ),
      ),
    );
  }
}

/// Loading placeholders in the shape of the dashboard.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: .stretch,
    children: [
      PanelSkeleton(height: 110),
      SizedBox(height: 32),
      CardGrid(
        maxColumns: 3,
        children: [GoalCardSkeleton(), GoalCardSkeleton(), GoalCardSkeleton()],
      ),
      SizedBox(height: 32),
      CardGrid(children: [GoalCardSkeleton(), GoalCardSkeleton()]),
    ],
  );
}
