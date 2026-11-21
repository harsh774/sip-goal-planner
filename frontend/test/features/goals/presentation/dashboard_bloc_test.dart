import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/core/error/failure.dart';
import 'package:sip_goal_planner/core/error/result.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_query.dart';
import 'package:sip_goal_planner/features/goals/domain/usecases/goal_usecases.dart';
import 'package:sip_goal_planner/features/goals/presentation/bloc/dashboard_bloc.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_projection.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/plan_goals.dart';

import '../../../helpers/fixtures.dart';

class _MockGetGoals extends Mock implements GetGoals {}

class _MockGetSummary extends Mock implements GetGoalsSummary {}

Paged<Goal> _page(List<Goal> goals, {int page = 1, int total = 0, int totalPages = 1}) => Paged(
  items: goals,
  page: page,
  pageSize: 10,
  total: total == 0 ? goals.length : total,
  totalPages: totalPages,
);

GoalsSummary _summary(Currency c, {int count = 1}) => GoalsSummary(
  count: count,
  currency: c,
  totalMonthlySip: 32205,
  totalTarget: 10000000,
  converted: false,
  ratesAsOf: asOf,
);

void main() {
  late _MockGetGoals getGoals;
  late _MockGetSummary getSummary;
  const soonQuery = GoalQuery(sort: GoalSort.targetDate, pageSize: 3, excludeCompleted: true);

  setUpAll(() {
    registerFallbackValue(const GoalQuery());
    registerFallbackValue(const SummaryParams(GoalFilters.none, Currency.inr));
  });

  setUp(() {
    getGoals = _MockGetGoals();
    getSummary = _MockGetSummary();
  });

  DashboardBloc build() => DashboardBloc(
    getGoals: getGoals,
    getSummary: getSummary,
    planGoals: PlanGoals(CalculateProjection(clock: () => asOf)),
    slowAfter: const Duration(milliseconds: 20),
  );

  void answerGoals(Result<Paged<Goal>> result, {Duration delay = Duration.zero}) =>
      when(() => getGoals(any())).thenAnswer((_) => Future.delayed(delay, () => result));

  void answerSummary(Currency c, {int count = 1}) =>
      when(() => getSummary(any())).thenAnswer((_) async => Success(_summary(c, count: count)));

  blocTest<DashboardBloc, DashboardState>(
    'first load fetches reaching-soon, page 1 and the summary, and plans each goal locally',
    setUp: () {
      answerGoals(Success(_page([goalFixture()])));
      answerSummary(Currency.inr);
    },
    build: build,
    act: (bloc) => bloc.add(const DashboardRequested(Currency.inr)),
    expect: () => [
      isA<DashboardState>().having((s) => s.status, 'status', DashboardStatus.loading),
      isA<DashboardState>()
          .having((s) => s.status, 'status', DashboardStatus.ready)
          .having((s) => s.reachingSoon.single.levelSip, 'soon SIP', 32205)
          .having((s) => s.page!.items.single.levelSip, 'page SIP', 32205)
          .having((s) => s.summary!.totalMonthlySip, 'total', 32205),
    ],
    verify: (_) {
      verify(() => getGoals(soonQuery)).called(1);
      verify(() => getGoals(const GoalQuery())).called(1);
    },
  );

  blocTest<DashboardBloc, DashboardState>(
    'shows the slow-connection notice when the first load takes longer than the threshold',
    setUp: () {
      answerGoals(Success(_page([goalFixture()])), delay: const Duration(milliseconds: 60));
      answerSummary(Currency.inr);
    },
    build: build,
    act: (bloc) => bloc.add(const DashboardRequested(Currency.inr)),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<DashboardState>().having((s) => s.status, 'status', DashboardStatus.loading),
      isA<DashboardState>().having((s) => s.isSlow, 'slow', isTrue),
      isA<DashboardState>().having((s) => s.status, 'status', DashboardStatus.ready),
    ],
  );

  blocTest<DashboardBloc, DashboardState>(
    'a user with no goals gets the empty state',
    setUp: () {
      answerGoals(Success(_page([])));
      answerSummary(Currency.inr, count: 0);
    },
    build: build,
    act: (bloc) => bloc.add(const DashboardRequested(Currency.inr)),
    verify: (bloc) => expect(bloc.state.hasNoGoals, isTrue),
  );

  blocTest<DashboardBloc, DashboardState>(
    'all goals completed is not the empty state: reaching-soon is just empty',
    setUp: () {
      answerGoals(Success(_page([])));
      answerSummary(Currency.inr, count: 2);
    },
    build: build,
    act: (bloc) => bloc.add(const DashboardRequested(Currency.inr)),
    verify: (bloc) {
      expect(bloc.state.reachingSoon, isEmpty);
      expect(bloc.state.hasNoGoals, isFalse);
    },
  );

  blocTest<DashboardBloc, DashboardState>(
    'a failed first load is an error state with the failure',
    setUp: () {
      answerGoals(const Err(NetworkFailure()));
      answerSummary(Currency.inr);
    },
    build: build,
    act: (bloc) => bloc.add(const DashboardRequested(Currency.inr)),
    expect: () => [
      isA<DashboardState>().having((s) => s.status, 'status', DashboardStatus.loading),
      isA<DashboardState>()
          .having((s) => s.status, 'status', DashboardStatus.failure)
          .having((s) => s.failure, 'failure', const NetworkFailure()),
    ],
  );

  blocTest<DashboardBloc, DashboardState>(
    'changing page fetches only that page',
    setUp: () {
      answerGoals(Success(_page([goalFixture()], total: 25, totalPages: 3)));
      answerSummary(Currency.inr);
    },
    build: build,
    seed: () => const DashboardState(status: DashboardStatus.ready),
    act: (bloc) => bloc.add(const DashboardPageChanged(2)),
    verify: (bloc) {
      verify(() => getGoals(const GoalQuery(page: 2))).called(1);
      verifyNever(() => getSummary(any()));
      expect(bloc.state.listLoading, isFalse);
    },
  );

  blocTest<DashboardBloc, DashboardState>(
    'applying filters resets to page 1 and leaves the all-goals totals alone',
    setUp: () {
      answerGoals(Success(_page([goalFixture()])));
      answerSummary(Currency.inr);
    },
    build: build,
    seed: () => const DashboardState(status: DashboardStatus.ready, query: GoalQuery(page: 3)),
    act: (bloc) => bloc.add(const DashboardFiltersChanged(GoalFilters(currency: Currency.usd))),
    verify: (bloc) {
      const filters = GoalFilters(currency: Currency.usd);
      verify(() => getGoals(const GoalQuery(filters: filters))).called(1);
      verifyNever(() => getSummary(any()));
      expect(bloc.state.query.page, 1);
    },
  );

  blocTest<DashboardBloc, DashboardState>(
    'changing the total currency refetches only the summary',
    setUp: () => answerSummary(Currency.usd),
    build: build,
    seed: () => const DashboardState(status: DashboardStatus.ready),
    act: (bloc) => bloc.add(const DashboardTotalCurrencyChanged(Currency.usd)),
    verify: (bloc) {
      verifyNever(() => getGoals(any()));
      expect(bloc.state.summary!.currency, Currency.usd);
    },
  );

  blocTest<DashboardBloc, DashboardState>(
    'search waits for typing to pause, then asks the API once with the last text',
    setUp: () => answerGoals(Success(_page([goalFixture()]))),
    build: build,
    seed: () => const DashboardState(status: DashboardStatus.ready, query: GoalQuery(page: 2)),
    act: (bloc) async {
      bloc
        ..add(const DashboardSearchChanged('h'))
        ..add(const DashboardSearchChanged('ho'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      bloc.add(const DashboardSearchChanged(' home '));
    },
    wait: const Duration(milliseconds: 450),
    verify: (bloc) {
      verify(() => getGoals(const GoalQuery(search: 'home'))).called(1);
      verifyNoMoreInteractions(getGoals);
      verifyNever(() => getSummary(any()));
      expect(bloc.state.query.search, 'home');
    },
  );
}
