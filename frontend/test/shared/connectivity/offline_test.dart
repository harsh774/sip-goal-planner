import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/network/connectivity_service.dart';
import 'package:sip_goal_planner/shared/connectivity/connectivity_cubit.dart';
import 'package:sip_goal_planner/shared/connectivity/offline_gate.dart';

class _FakeConnectivity implements ConnectivityService {
  final changes = StreamController<bool>.broadcast();
  bool online = true;

  @override
  Stream<bool> get onlineChanges => changes.stream;

  @override
  Future<bool> isOnline() async => online;
}

void main() {
  test('follows the device going offline and back online', () async {
    final service = _FakeConnectivity();
    final cubit = ConnectivityCubit(service);
    final states = <bool>[];
    final sub = cubit.stream.listen(states.add);

    service.changes.add(false);
    service.changes.add(true);
    await Future<void>.delayed(Duration.zero);

    expect(states, containsAllInOrder([false, true]));
    await sub.cancel();
    await cubit.close();
  });

  testWidgets('the offline page covers the app and lifts on reconnect', (tester) async {
    final service = _FakeConnectivity();
    final cubit = ConnectivityCubit(service);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const OfflineGate(child: Text('app content')),
        ),
      ),
    );
    expect(find.text('Oops! No internet'), findsNothing);

    service.changes.add(false);
    await tester.pump();
    expect(find.text('Oops! No internet'), findsOneWidget);
    expect(find.text('app content'), findsOneWidget);

    service.changes.add(true);
    await tester.pump();
    expect(find.text('Oops! No internet'), findsNothing);
  });
}
