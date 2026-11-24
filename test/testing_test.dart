import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/testing.dart';
import 'package:test/test.dart';

void main() {
  FaydaSuccess decode(String payload) =>
      decodePayload(payload, includeFace: true) as FaydaSuccess;

  group('buildTestPayload', () {
    test('defaults decode to a complete card', () {
      final result = decode(buildTestPayload());
      expect(result.fields.fullName, 'Abebe Kebede Alemu');
      expect(result.fields.gender, FaydaGender.male);
      expect(result.fields.fan, '6140123412341234');
      expect(result.fields.dateOfBirth, '2002-11-26');
      expect(result.fields.face!.bytes, faydaTestFace);
    });

    test('is signed with the test key, not NIDP', () {
      final result = decode(buildTestPayload());
      expect(
          result.verify(publicKeyPem: faydaTestPublicKeyPem).verified, isTrue);
      expect(
          result.verify().reason, VerificationFailureReason.invalidSignature);
    });

    test('takes custom fields, including Ethiopic names', () {
      final result = decode(buildTestPayload(
        fullName: 'አልማዝ ተስፋዬ በቀለ',
        gender: FaydaGender.female,
        fan: '6140987654321098',
        dateOfBirth: DateTime(1994, 5, 7),
      ));
      expect(result.fields.fullName, 'አልማዝ ተስፋዬ በቀለ');
      expect(result.fields.gender, FaydaGender.female);
      expect(result.fields.dateOfBirth, '1994-05-07');
      expect(
          result.verify(publicKeyPem: faydaTestPublicKeyPem).verified, isTrue);
    });

    test('overrides produce malformed or missing fields', () {
      expect(
          decode(buildTestPayload(overrides: {'D': '1990/02/31'}))
              .fields
              .dateOfBirth,
          isNull);
      expect(decode(buildTestPayload(overrides: {'D': null})).raw.map,
          isNot(contains('D')));
      expect(decode(buildTestPayload(gender: null)).fields.gender, isNull);
      final v5 = decodePayload(buildTestPayload(version: '5'));
      expect(
          (v5 as FaydaFailure).error.code, FaydaErrorCode.unsupportedVersion);
    });

    test('can leave out the signature and the face', () {
      final result = decode(buildTestPayload(signed: false, face: const []));
      expect(result.signature.present, isFalse);
      expect(result.fields.face, isNull);
    });

    test('rejects names the format cannot carry', () {
      expect(() => buildTestPayload(fullName: 'a:b'), throwsArgumentError);
    });
  });

  group('buildTestQrPng', () {
    test('round-trips through decodeImage', () async {
      for (final name in ['Abebe Kebede Alemu', 'አልማዝ ተስፋዬ በቀለ']) {
        final payload = buildTestPayload(fullName: name);
        expect(
          await decodeImage(buildTestQrPng(payload), includeFace: true),
          equals(decodePayload(payload, includeFace: true)),
        );
      }
    });
  });
}
