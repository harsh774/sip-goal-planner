import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// Client half of the server's hybrid scheme (backend/app/core/transport_crypto.py):
/// a fresh AES-256 key per request, wrapped with the server's RSA key using
/// RSA-OAEP-SHA256; payloads sealed with AES-256-GCM as base64(nonce || ciphertext || tag).
abstract final class HybridCipher {
  static const _nonceBytes = 12;
  static final _random = Random.secure();

  static Uint8List newAesKey() => _bytes(32);

  static String seal(Uint8List key, Uint8List plaintext, Uint8List aad) {
    final nonce = _bytes(_nonceBytes);
    final sealed = _gcm(true, key, nonce, aad).process(plaintext);
    return base64Encode([...nonce, ...sealed]);
  }

  static Uint8List open(Uint8List key, String sealedB64, Uint8List aad) {
    final blob = base64Decode(sealedB64.trim());
    if (blob.length <= _nonceBytes) throw const FormatException('Sealed payload too short');
    final nonce = blob.sublist(0, _nonceBytes);
    return _gcm(false, key, nonce, aad).process(blob.sublist(_nonceBytes));
  }

  /// Wraps [aesKey] with an RSA public key given as base64 SubjectPublicKeyInfo DER.
  static String wrapKey(String publicKeySpkiB64, Uint8List aesKey) {
    final oaep = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(_parseSpki(base64Decode(publicKeySpkiB64))));
    return base64Encode(oaep.process(aesKey));
  }

  static Uint8List requestAad(String method, String path) =>
      utf8.encode('req:${method.toUpperCase()}:$path');

  static Uint8List queryAad(String method, String path) =>
      utf8.encode('req:${method.toUpperCase()}:$path?');

  static Uint8List responseAad(String method, String path) =>
      utf8.encode('res:${method.toUpperCase()}:$path');

  static GCMBlockCipher _gcm(bool encrypt, Uint8List key, Uint8List nonce, Uint8List aad) =>
      GCMBlockCipher(AESEngine())
        ..init(encrypt, AEADParameters(KeyParameter(key), 128, nonce, aad));

  static RSAPublicKey _parseSpki(Uint8List der) {
    // SubjectPublicKeyInfo ::= SEQUENCE { algorithm, BIT STRING { RSAPublicKey } }
    if (ASN1Parser(der).nextObject() case ASN1Sequence(
      elements: [_, ASN1BitString(stringValues: final List<int> keyBytes), ...],
    )) {
      if (ASN1Parser(Uint8List.fromList(keyBytes)).nextObject() case ASN1Sequence(
        elements: [
          ASN1Integer(integer: final BigInt modulus),
          ASN1Integer(integer: final BigInt exponent),
          ...,
        ],
      )) {
        return RSAPublicKey(modulus, exponent);
      }
    }
    throw const FormatException('Not an RSA SubjectPublicKeyInfo');
  }

  static Uint8List _bytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));
}
