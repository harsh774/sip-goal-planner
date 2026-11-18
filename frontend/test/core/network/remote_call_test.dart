import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/network/api_exception.dart';
import 'package:sip_goal_planner/core/network/remote_call.dart';

void main() {
  test('parses a JSON object', () async {
    final id = await remoteObject(() async => {'id': 'a'}, (j) => j['id'] as String);
    expect(id, 'a');
  });

  test('a missing body or a wrongly typed field is a malformed response, not a crash', () async {
    await expectLater(
      remoteObject(() async => null, (j) => j['id'] as String),
      throwsA(isA<MalformedResponseApiException>()),
    );
    await expectLater(
      remoteObject(() async => {'id': 42}, (j) => j['id'] as String),
      throwsA(isA<MalformedResponseApiException>()),
    );
  });

  test('API errors pass through unchanged', () async {
    await expectLater(
      remoteObject(() async => throw const NotFoundApiException(null), (j) => j),
      throwsA(isA<NotFoundApiException>()),
    );
  });
}
