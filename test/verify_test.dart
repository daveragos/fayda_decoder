@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/src/base64.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/signed_payload.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final payload = fixture['payload'] as String;
  final publicKeyPem = fixture['publicKeyPem'] as String;

  FaydaSuccess parse(String text) => decodePayload(text) as FaydaSuccess;

  /// Replaces the JWS after `:SIGN:`.
  String withJws(String jws) =>
      '${payload.substring(0, payload.lastIndexOf(':SIGN:'))}:SIGN:$jws';

  String jwsHeader(Map<String, Object?> header) =>
      base64UrlEncodeNoPad(utf8.encode(jsonEncode(header)));

  group('verifySignature', () {
    test('verifies the detached RS256 serialization with a caller key', () {
      final result =
          verifySignature(parse(payload), publicKeyPem: publicKeyPem);
      expect(result.verified, isTrue);
      expect(result.toJson(), {
        'verified': true,
        'algorithm': 'RS256',
        'payload_version': '4',
        'key_source': 'caller',
        'reason': null,
      });
    });

    test('rejects a changed external payload', () {
      final forged = payload.replaceFirst('Synthetic Person', 'Forged Person');
      final result = verifySignature(parse(forged), publicKeyPem: publicKeyPem);
      expect(result.verified, isFalse);
      expect(result.reason, VerificationFailureReason.invalidSignature);
    });

    test('rejects a changed signature', () {
      final jws = payload.substring(payload.lastIndexOf(':SIGN:') + 6);
      final sig = base64UrlDecodeLenient(jws.split('.')[2]);
      sig[sig.length ~/ 2] ^= 0x01;
      final tampered =
          withJws('${jws.split('.')[0]}..${base64UrlEncodeNoPad(sig)}');
      final result =
          verifySignature(parse(tampered), publicKeyPem: publicKeyPem);
      expect(result.reason, VerificationFailureReason.invalidSignature);
    });

    test('rejects a truncated signature', () {
      final jws = payload.substring(payload.lastIndexOf(':SIGN:') + 6);
      final truncated = withJws(jws.substring(0, jws.length - 8));
      final result =
          verifySignature(parse(truncated), publicKeyPem: publicKeyPem);
      expect(result.reason, VerificationFailureReason.invalidSignature);
    });

    test('the bundled NIDP key does not accept a self-signed payload', () {
      final result = verifySignature(parse(payload));
      expect(result.verified, isFalse);
      expect(result.keySource, KeySource.bundledNidpV4);
      expect(result.reason, VerificationFailureReason.invalidSignature);
    });

    test('SIGNATURE_MISSING when there is no JWS', () {
      final result = verifySignature(parse(withJws('')));
      expect(result.reason, VerificationFailureReason.signatureMissing);
      expect(result.algorithm, isNull);
    });

    test('MALFORMED_JWS when the payload segment is not empty', () {
      final result = verifySignature(parse(validPayload()));
      expect(result.reason, VerificationFailureReason.malformedJws);
    });

    test('MALFORMED_JWS when the header is not JSON', () {
      final result = verifySignature(parse(withJws('bm90LWpzb24..c2ln')));
      expect(result.reason, VerificationFailureReason.malformedJws);
    });

    test('UNSUPPORTED_ALGORITHM for anything but RS256', () {
      for (final header in [
        {'alg': 'HS256'},
        {'alg': 'none'},
        {'typ': 'JWT'},
      ]) {
        final result =
            verifySignature(parse(withJws('${jwsHeader(header)}..c2ln')));
        expect(result.reason, VerificationFailureReason.unsupportedAlgorithm);
      }
    });

    test('INVALID_SIGNATURE when the caller key is not a valid PEM', () {
      final result = verifySignature(parse(payload), publicKeyPem: 'not a key');
      expect(result.reason, VerificationFailureReason.invalidSignature);
      expect(result.keySource, KeySource.caller);
    });
  });

  test('verify() extension matches verifySignature', () {
    final result = parse(payload);
    expect(
      result.verify(publicKeyPem: publicKeyPem),
      verifySignature(result, publicKeyPem: publicKeyPem),
    );
  });

  test('bundled key matches the published SPKI SHA-256 fingerprint', () {
    final body = faydaV4PublicKeyPem
        .replaceAll(RegExp(r'-----[A-Z ]+-----'), '')
        .replaceAll(RegExp(r'\s+'), '');
    expect(
      sha256.convert(base64.decode(body)).toString(),
      '803dcd26057edc1423a5b9655f03c945b84a146be28caa754bc460a3fea6624a',
    );
  });
}
