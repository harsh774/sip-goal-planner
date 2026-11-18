import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/core/error/failure.dart';
import 'package:sip_goal_planner/core/error/result.dart';
import 'package:sip_goal_planner/core/usecase/usecase.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal.dart';
import 'package:sip_goal_planner/features/goals/domain/usecases/goal_usecases.dart';
import 'package:sip_goal_planner/features/goals/presentation/bloc/goal_list_bloc.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_goal_totals.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_projection.dart';

import '../../../helpers/fixtures.dart';

class _MockGetGoals extends Mock implements GetGoals {}

void main() {
  late _MockGetGoals getGoals;
  final totals = CalculateGoalTotals(CalculateProjection(clock: () => asOf));

  setUpAll(() => registerFallbackValue(const NoParams()));
  setUp(() => getGoals = _MockGetGoals());

  GoalListBloc build() => GoalListBloc(
    getGoals: getGoals,
    calculateTotals: totals,
    slowAfter: const Duration(milliseconds: 20),
  );

  void answer(Result<List<Goal>> result, {Duration delay = Duration.zero}) =>
      when(() => getGoals(any())).thenAnswer((_) => Future.delayed(delay, () => result));

  blocTest<GoalListBloc, GoalListState>(
    'shows the slow-connection state when loading takes longer than the threshold',
    setUp: () => answer(Success([goalFixture()]), delay: const Duration(milliseconds: 60)),
    build: build,
    act: (bloc) => bloc.add(const GoalsRequested(Currency.inr)),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const GoalListLoading(),
      const GoalListLoading(isSlow: true),
      isA<GoalListLoaded>().having((s) => s.overview.totals.monthlySip, 'total SIP', 32205),
    ],
  );

  blocTest<GoalListBloc, GoalListState>(
    'an empty list is its own state',
    setUp: () => answer(const Success([])),
    build: build,
    act: (bloc) => bloc.add(const GoalsRequested(Currency.inr)),
    expect: () => [const GoalListLoading(), const GoalListEmpty()],
  );

  blocTest<GoalListBloc, GoalListState>(
    'failures surface with the currency needed to retry',
    setUp: () => answer(const Err(NetworkFailure())),
    build: build,
    act: (bloc) => bloc.add(const GoalsRequested(Currency.usd)),
    expect: () => [const GoalListLoading(), const GoalListError(NetworkFailure(), Currency.usd)],
  );

  blocTest<GoalListBloc, GoalListState>(
    'changing the total currency recomputes locally without a new request',
    setUp: () => answer(Success([goalFixture()])),
    build: build,
    act: (bloc) async {
      bloc.add(const GoalsRequested(Currency.inr));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(const TotalCurrencyChanged(Currency.usd));
    },
    skip: 2,
    expect: () => [
      isA<GoalListLoaded>()
          .having((s) => s.overview.totals.currency, 'currency', Currency.usd)
          .having((s) => s.overview.totals.converted, 'converted', isTrue),
    ],
    verify: (_) => verify(() => getGoals(any())).called(1),
  );
}
