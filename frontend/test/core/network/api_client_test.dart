import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/error/failure.dart';
import 'package:sip_goal_planner/core/network/api_client.dart';
import 'package:sip_goal_planner/core/network/api_exception.dart';

/// Answers every request with a fixed status and JSON body, optionally after a delay.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body, {this.delay = Duration.zero});

  final int status;
  final Object? body;
  final Duration delay;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async {
    await Future<void>.delayed(delay);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(int status, Object? body, {Duration delay = Duration.zero, Duration? timeout}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = _FakeAdapter(status, body, delay: delay);
  return ApiClient(dio, timeout: timeout ?? const Duration(seconds: 15));
}

void main() {
  test('returns decoded JSON on success', () async {
    expect(await _client(200, {'ok': true}).get('/x'), {'ok': true});
  });

  test('422 becomes a ValidationApiException with field codes', () async {
    final client = _client(422, {
      'detail': [
        {
          'field': 'target_date',
          'code': 'date_past',
          'message': 'Target date must be in the future.',
        },
        {'field': null, 'code': 'json_invalid', 'message': 'Bad JSON.'},
      ],
    });

    await expectLater(
      client.post('/goals'),
      throwsA(
        isA<ValidationApiException>().having((e) => e.fieldErrors, 'fieldErrors', {
          'target_date': const FieldIssue('date_past', 'Target date must be in the future.'),
          null: const FieldIssue('json_invalid', 'Bad JSON.'),
        }),
      ),
    );
  });

  test('409 email_taken is a validation error on the email field', () async {
    final client = _client(409, {
      'detail': [
        {'field': 'email', 'code': 'email_taken', 'message': 'This email already has an account.'},
      ],
    });

    final failure = await client
        .post('/auth/register')
        .then<Failure?>((_) => null, onError: (Object e) => (e as ApiException).toFailure());
    expect(failure, isA<ValidationFailure>());
    expect((failure! as ValidationFailure).fieldErrors['email']?.code, 'email_taken');
  });

  test('401, 404 and 500 map to their own exceptions', () async {
    await expectLater(
      _client(401, {'detail': 'Incorrect email or password.'}).get('/x'),
      throwsA(
        isA<UnauthorizedApiException>().having(
          (e) => e.message,
          'message',
          'Incorrect email or password.',
        ),
      ),
    );
    await expectLater(
      _client(404, {'detail': 'Goal not found.'}).get('/x'),
      throwsA(isA<NotFoundApiException>()),
    );
    await expectLater(
      _client(500, {'detail': 'boom'}).get('/x'),
      throwsA(isA<ServerApiException>()),
    );
  });

  test('a request slower than the timeout becomes a TimeoutApiException', () async {
    final client = _client(
      200,
      {'ok': true},
      delay: const Duration(milliseconds: 200),
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(client.get('/x'), throwsA(isA<TimeoutApiException>()));
  });
}
