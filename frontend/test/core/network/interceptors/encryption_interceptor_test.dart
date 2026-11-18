import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_goal_planner/core/network/interceptors/encryption_interceptor.dart';
import 'package:sip_goal_planner/core/security/encryption_settings.dart';
import 'package:sip_goal_planner/core/security/hybrid_cipher.dart';
import 'package:sip_goal_planner/core/security/transport_key_source.dart';

/// An RSA key pair standing in for the server's, plus its public key as SPKI DER base64.
class _ServerKey {
  _ServerKey() {
    final random = FortunaRandom()
      ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random().nextInt(256)))));
    final pair =
        (RSAKeyGenerator()..init(
              ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), random),
            ))
            .generateKeyPair();
    private = pair.privateKey;
    final public = pair.publicKey;
    final rsaKey = ASN1Sequence(
      elements: [ASN1Integer(public.modulus), ASN1Integer(public.exponent)],
    )..encode();
    final spki = ASN1Sequence(
      elements: [
        ASN1Sequence(
          elements: [ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'), ASN1Null()],
        ),
        ASN1BitString(stringValues: rsaKey.encodedBytes),
      ],
    )..encode();
    publicKey = base64Encode(spki.encodedBytes!);
  }

  late final RSAPrivateKey private;
  late final String publicKey;

  Uint8List unwrap(String wrapped) => (OAEPEncoding.withSHA256(
    RSAEngine(),
  )..init(false, PrivateKeyParameter<RSAPrivateKey>(private))).process(base64Decode(wrapped));
}

class _Keys implements TransportKeySource {
  _Keys(this.publicKey);

  final String publicKey;
  int version = 1;
  int invalidated = 0;

  @override
  Future<TransportKey> current() async =>
      TransportKey(clientId: '1.0.0', version: version, publicKey: publicKey);

  @override
  void invalidate() {
    invalidated++;
    version++;
  }
}

class _Seen {
  _Seen(this.options, this.aes, this.body, this.query)
    : keyVersion = options.headers['X-Enc-Key-Version'] as String?;

  final RequestOptions options;

  /// Read at send time: a retry reuses and updates the same options object.
  final String? keyVersion;
  final Uint8List aes;
  final String? body;
  final String? query;
}

/// Plays the server's half: opens the sealed request, answers via [respond].
class _FakeServer implements HttpClientAdapter {
  _FakeServer(this.key, this.respond);

  final _ServerKey key;
  final ResponseBody Function(_Seen seen, Uint8List aes) respond;
  final requests = <_Seen>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final aes = key.unwrap(options.headers['X-Enc-Key'] as String);
    final path = options.uri.path;
    final sealedBody = requestStream == null
        ? null
        : utf8.decode(await requestStream.expand((c) => c).toList());
    final body = sealedBody == null || sealedBody.isEmpty
        ? null
        : utf8.decode(
            HybridCipher.open(aes, sealedBody, HybridCipher.requestAad(options.method, path)),
          );
    final query = switch (options.headers['X-Enc-Query']) {
      final String sealed => utf8.decode(
        HybridCipher.open(aes, sealed, HybridCipher.queryAad(options.method, path)),
      ),
      _ => null,
    };
    final seen = _Seen(options, aes, body, query);
    requests.add(seen);
    return respond(seen, aes);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _sealedJson(_Seen seen, Uint8List aes, Object json, {int status = 200}) {
  final sealed = HybridCipher.seal(
    aes,
    utf8.encode(jsonEncode(json)),
    HybridCipher.responseAad(status, seen.options.method, seen.options.uri.path),
  );
  return ResponseBody.fromString(
    sealed,
    status,
    headers: {
      'content-type': ['text/plain; charset=utf-8'],
      'x-enc-content-type': ['application/json'],
    },
  );
}

void main() {
  late _ServerKey serverKey;

  setUpAll(() => serverKey = _ServerKey());

  Future<(Dio, _FakeServer, _Keys)> build(
    ResponseBody Function(_Seen, Uint8List) respond, {
    bool enabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({'encrypted_transport': enabled});
    final settings = EncryptionSettings(await SharedPreferences.getInstance());
    final keys = _Keys(serverKey.publicKey);
    final server = _FakeServer(serverKey, respond);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = server;
    dio.interceptors.add(EncryptionInterceptor(dio, settings, keys));
    return (dio, server, keys);
  }

  test('seals body and query, and opens the sealed response', () async {
    final (dio, server, _) = await build((seen, aes) => _sealedJson(seen, aes, {'ok': true}));

    final response = await dio.post<Object?>(
      '/goals',
      data: {'name': 'Home'},
      queryParameters: {'q': 'home'},
    );

    final seen = server.requests.single;
    expect(response.data, {'ok': true});
    expect(seen.body, '{"name":"Home"}');
    expect(seen.query, 'q=home');
    expect(seen.options.uri.query, isEmpty);
    expect(seen.options.headers['X-Enc-Content-Type'], Headers.jsonContentType);
    expect(seen.options.headers['X-Enc-Key-Version'], '1');
  });

  test('form bodies are sealed in their form encoding', () async {
    final (dio, server, _) = await build((seen, aes) => _sealedJson(seen, aes, {}));

    await dio.post<Object?>(
      '/auth/login',
      data: {'username': 'a@b.com', 'password': 'x y'},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final seen = server.requests.single;
    expect(seen.options.headers['X-Enc-Content-Type'], Headers.formUrlEncodedContentType);
    expect(seen.body, 'username=a%40b.com&password=x+y');
  });

  test('a 204 with no body succeeds', () async {
    final (dio, _, _) = await build((_, _) => ResponseBody.fromString('', 204));

    final response = await dio.delete<Object?>('/goals/abc');

    expect(response.statusCode, 204);
    expect(response.data, isNull);
  });

  test('a stale key version refetches the key and retries once', () async {
    final (dio, server, keys) = await build((seen, aes) {
      if (seen.keyVersion == '1') {
        return ResponseBody.fromString(
          jsonEncode({
            'detail': [
              {'field': null, 'code': 'key_version_stale', 'message': 'stale'},
            ],
          }),
          409,
          headers: {
            'content-type': ['application/json'],
          },
        );
      }
      return _sealedJson(seen, aes, {'items': <Object>[]});
    });

    final response = await dio.get<Object?>('/goals', queryParameters: {'page': 1});

    expect(response.data, {'items': <Object>[]});
    expect(keys.invalidated, 1);
    expect(server.requests.map((r) => r.keyVersion), ['1', '2']);
    expect(server.requests.last.query, 'page=1');
  });

  test('sealed errors are opened for the caller', () async {
    final (dio, _, _) = await build(
      (seen, aes) =>
          _sealedJson(seen, aes, {'detail': 'Incorrect email or password.'}, status: 401),
    );

    final error = await dio
        .post<Object?>('/auth/login', data: {'username': 'x'})
        .then<DioException?>((_) => null, onError: (Object e) => e as DioException);

    expect(error?.response?.statusCode, 401);
    expect(error?.response?.data, {'detail': 'Incorrect email or password.'});
  });

  test('when encryption is off requests go out untouched', () async {
    SharedPreferences.setMockInitialValues({'encrypted_transport': false});
    final settings = EncryptionSettings(await SharedPreferences.getInstance());
    RequestOptions? sent;
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = _Recorder((o) => sent = o)
      ..interceptors.add(EncryptionInterceptor(Dio(), settings, _Keys(serverKey.publicKey)));

    await dio.post<Object?>('/goals', data: {'name': 'Home'});

    expect(sent?.headers.containsKey('X-Enc-Key'), isFalse);
    expect(sent?.data, {'name': 'Home'});
  });
}

class _Recorder implements HttpClientAdapter {
  _Recorder(this.onRequest);

  final void Function(RequestOptions) onRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? _) async {
    onRequest(o);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
