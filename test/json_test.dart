@TestOn('vm')
library;

import 'dart:convert';

import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('FaydaResult JSON round-trip', () {
    for (final vector in loadVectors()) {
      test(vector.name, () {
        final result =
            decodePayload(vector.payload, includeFace: vector.includeFace);
        // Through a real JSON string, as a cache or network hop would.
        final json =
            jsonDecode(jsonEncode(result.toJson())) as Map<String, Object?>;
        final restored = FaydaResult.fromJson(json);
        expect(restored, equals(result));
        expect(restored.hashCode, result.hashCode);
        expect(restored.runtimeType, result.runtimeType);
      });
    }
  });

  group('equality', () {
    final payload = validPayload();

    test('identical decodes are equal', () {
      expect(decodePayload(payload, includeFace: true),
          equals(decodePayload(payload, includeFace: true)));
    });

    test('different fields or face opt-in are not equal', () {
      expect(decodePayload(payload),
          isNot(equals(decodePayload(payload, includeFace: true))));
      expect(decodePayload(payload),
          isNot(equals(decodePayload(payload.replaceFirst(':G:M:', ':G:F:')))));
    });
  });

  group('fromJson rejects malformed input without echoing values', () {
    final json = decodePayload(validPayload()).toJson();

    Map<String, Object?> edit(void Function(Map<String, Object?> j) change) {
      final copy = jsonDecode(jsonEncode(json)) as Map<String, Object?>;
      change(copy);
      return copy;
    }

    for (final (name, change)
        in <(String, void Function(Map<String, Object?>))>[
      ('missing ok', (j) => j.remove('ok')),
      ('wrong document', (j) => j['document'] = 'passport'),
      ('fan not a string', (j) => (j['fields'] as Map)['fan'] = 6140),
      ('unknown gender', (j) => (j['fields'] as Map)['gender'] = 'X'),
      ('missing meta', (j) => j.remove('meta')),
      (
        'non-string map value',
        (j) => ((j['raw'] as Map)['map'] as Map)['V'] = 4
      ),
    ]) {
      test(name, () {
        expect(
          () => FaydaResult.fromJson(edit(change)),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', isNot(contains('Abebe')))),
        );
      });
    }

    test('unknown error code', () {
      expect(
        () => FaydaResult.fromJson({
          'ok': false,
          'error': {'code': 'NOPE', 'message': 'x'},
        }),
        throwsFormatException,
      );
    });
  });
}
