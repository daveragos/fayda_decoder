import 'dart:io';

import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/src/base64.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('decodePayload against shared test vectors', () {
    for (final vector in loadVectors()) {
      test(vector.name, () {
        final result =
            decodePayload(vector.payload, includeFace: vector.includeFace);
        expectSubset(result.toJson(), vector.expected);
      });
    }
  });

  group('decodePayload details', () {
    final valid = validPayload();

    test('returns typed fields', () {
      final result = decodePayload(valid, includeFace: true);
      expect(result, isA<FaydaSuccess>());
      result as FaydaSuccess;
      expect(result.ok, isTrue);
      expect(result.document, 'fayda');
      expect(result.fields.fullName, 'Abebe Kebede Alemu');
      expect(result.fields.gender, FaydaGender.male);
      expect(result.fields.fan, '6140123412341234');
      expect(result.fields.dateOfBirth, '2002-11-26');
      expect(result.fields.dateOfBirthUtc, DateTime.utc(2002, 11, 26));
      expect(result.fields.face!.bytes.sublist(0, 4), 'RIFF'.codeUnits);
      expect(result.signature.present, isTrue);
      expect(result.library, libraryName);
      expect(result.libraryVersion, libraryVersion);
    });

    test('keeps the raw payload and raw field map', () {
      final result = decodePayload('  $valid\n') as FaydaSuccess;
      expect(result.raw.payload, valid.trim());
      expect(result.raw.map, containsPair('V', '4'));
      expect(result.raw.map, containsPair('G', 'M'));
    });

    test('never returns the face unless includeFace is set', () {
      final result = decodePayload(valid) as FaydaSuccess;
      expect(result.fields.face, isNull);
    });

    test('does not echo the payload in error messages (no PII in errors)', () {
      final bad = decodePayload('6140123412341234 some random text');
      expect(bad, isA<FaydaFailure>());
      expect((bad as FaydaFailure).error.message,
          isNot(contains('6140123412341234')));
    });

    test('toString never prints personal data', () {
      final result = decodePayload(valid, includeFace: true) as FaydaSuccess;
      for (final s in [
        result.toString(),
        result.fields.toString(),
        result.raw.toString(),
        result.fields.face.toString(),
      ]) {
        expect(s, isNot(contains('Abebe')));
        expect(s, isNot(contains('6140123412341234')));
      }
    });

    test('uses the last :SIGN: as the JWS boundary so later fields still parse',
        () {
      final payload = valid.replaceFirst(
        ':DLT:Abebe Kebede Alemu:',
        ':DLT:Abebe :SIGN: Kebede Alemu:',
      );
      final result = decodePayload(payload) as FaydaSuccess;
      expect(result.payloadVersion, '4');
      expect(result.fields.fan, '6140123412341234');
      expect(result.signature.present, isTrue);
    });

    test('an empty JWS is reported as absent', () {
      final payload = valid.substring(0, valid.indexOf(':SIGN:') + 6);
      final result = decodePayload(payload) as FaydaSuccess;
      expect(result.signature.present, isFalse);
      expect(result.signature.jws, isNull);
    });

    test('decodes base64url with optional padding and rejects garbage', () {
      expect(base64UrlDecodeStrict('UklGRg==')!.sublist(0, 4),
          [0x52, 0x49, 0x46, 0x46]);
      expect(base64UrlDecodeStrict('UklGRg')!.sublist(0, 4),
          [0x52, 0x49, 0x46, 0x46]);
      expect(base64UrlDecodeStrict(r'abc\def'), isNull);
      expect(base64UrlDecodeStrict('ab+/'), isNull); // standard alphabet
      expect(base64UrlDecodeStrict('abcde'), isNull); // impossible length
      expect(base64UrlDecodeStrict('abc=='), isNull); // wrong padding
    });

    test('accepts an explicit year below 100', () {
      final payload = valid.replaceFirst(':D:2002/11/26:', ':D:0099/01/15:');
      final result = decodePayload(payload) as FaydaSuccess;
      expect(result.fields.dateOfBirth, '0099-01-15');
    });

    test('validates leap days with the Gregorian rule', () {
      String? dob(String d) =>
          (decodePayload(valid.replaceFirst(':D:2002/11/26:', ':D:$d:'))
                  as FaydaSuccess)
              .fields
              .dateOfBirth;
      expect(dob('2000/02/29'), '2000-02-29');
      expect(dob('2004/02/29'), '2004-02-29');
      expect(dob('1900/02/29'), isNull);
      expect(dob('2001/02/29'), isNull);
      expect(dob('2001/13/01'), isNull);
      expect(dob('2001/00/10'), isNull);
      expect(dob('2001/1/10'), isNull);
    });

    test('unknown gender becomes null', () {
      final result =
          decodePayload(valid.replaceFirst(':G:M:', ':G:X:')) as FaydaSuccess;
      expect(result.fields.gender, isNull);
    });

    test('missing version is UNSUPPORTED_VERSION with the raw map', () {
      final result = decodePayload(valid.replaceFirst(':V:4:', ':X:4:'));
      result as FaydaFailure;
      expect(result.error.code, FaydaErrorCode.unsupportedVersion);
      expect(result.raw!.map, containsPair('X', '4'));
    });
  });

  test('libraryVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)![1];
    expect(libraryVersion, version);
  });
}
