import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' show InvalidCipherTextException;
import 'package:sip_goal_planner/core/security/hybrid_cipher.dart';

/// A public key produced by the backend's new_key_pair() (RSA-3072, SPKI DER).
const _serverPublicKey =
    'MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAvDW/hvm8sJ6+EMijxKWd5YD9r3b79Ju2YuaT7KmiLmydsMEKa2velEFVPKIuXDLxdkuKhHc6S4nsHxNBGoiXx9gJ55tL3swaWLT2ErWW+Jq+2VqYk1FzbnZLwybOaDps6VJK4caoTwRdL0+LzpmDelnujiet+yk7m1KzpoxcU0c47TXaTiihZfgLdrfq6BexSee3zIFIkqYqcuzk7aB6ZmrJ33XkN9I7UIE3zaybf0+RcKtdknCPrzvLgeL7QTBiZc5TFTcg0trxfQr80nXT1xrb/jCPu2s315l2aip9AHIx0oZkEsvTnVfiQ8yqyLKr2A0aTcqreML0HL7wCizQqx4Hd7JzTtEcrwIEPmb4NuOoLiEXCOEi/kbyChmLhu6skpt2fNuh0fPrvb8vj7Jaq3RQ+/hqwjfbDPsxRtXv3xYxdEwuwBm/esQvmsD2AyU+9xHxbpyZRlcyyljdPUs98+iicrvX64wV/UbId7qNgVeuqaVvIlrDIC3dO6+8iOzDAgMBAAE=';

void main() {
  final key = HybridCipher.newAesKey();
  final aad = HybridCipher.requestAad('post', '/api/v1/goals');

  test('a sealed payload opens with the same key and path', () {
    final sealed = HybridCipher.seal(key, utf8.encode('{"name":"Home"}'), aad);

    expect(utf8.decode(HybridCipher.open(key, sealed, aad)), '{"name":"Home"}');
    expect(sealed, isNot(contains('Home')));
  });

  test('a payload sealed for one endpoint does not open for another', () {
    final sealed = HybridCipher.seal(key, utf8.encode('{}'), aad);

    expect(
      () => HybridCipher.open(key, sealed, HybridCipher.requestAad('POST', '/api/v1/auth/login')),
      throwsA(anything),
    );
    expect(() => HybridCipher.open(HybridCipher.newAesKey(), sealed, aad), throwsA(anything));
  });

  test('wraps a key with the server key format, fresh randomness each time', () {
    final a = base64Decode(HybridCipher.wrapKey(_serverPublicKey, key));
    final b = base64Decode(HybridCipher.wrapKey(_serverPublicKey, key));

    expect(a.length, 384); // RSA-3072
    expect(a, isNot(equals(b))); // OAEP is randomised
    expect(HybridCipher.newAesKey(), isA<Uint8List>().having((k) => k.length, 'length', 32));
  });

  test('opens a payload sealed by the Python server', () {
    // backend: seal(bytes(range(32)), b'{"ok":true}', response_aad(200, "GET", "/api/v1/goals"))
    const fromServer = '3Ug3pdeSYZJ9dk+FR18KXTyDBBR/j+LcYYO8GqzzTOYPPU4ksax5';
    final serverKey = Uint8List.fromList(List.generate(32, (i) => i));

    final plain = HybridCipher.open(
      serverKey,
      fromServer,
      HybridCipher.responseAad(200, 'GET', '/api/v1/goals'),
    );

    expect(utf8.decode(plain), '{"ok":true}');
    expect(
      () => HybridCipher.open(
        serverKey,
        fromServer,
        HybridCipher.responseAad(500, 'GET', '/api/v1/goals'),
      ),
      throwsA(isA<InvalidCipherTextException>()),
    );
  });
}
