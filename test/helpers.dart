import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// One shared test vector from `testdata/vectors.json` upstream.
typedef Vector = ({
  String name,
  String payload,
  bool includeFace,
  Object? expected,
});

/// Loads the shared vectors. Inside the upstream monorepo (packages/dart) the
/// shared `testdata/vectors.json` wins, so drift shows up as a failure;
/// standalone, the bundled copy is used.
List<Vector> loadVectors() {
  final shared = File('../../testdata/vectors.json');
  final file =
      shared.existsSync() ? shared : File('test/fixtures/vectors.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return [
    for (final v
        in (json['vectors'] as List<Object?>).cast<Map<String, Object?>>())
      (
        name: v['name'] as String,
        payload: v['payload'] as String,
        includeFace:
            (v['options'] as Map<String, Object?>)['includeFace'] == true,
        expected: v['expected'],
      ),
  ];
}

/// The canonical valid synthetic payload (Latin name, V4).
String validPayload() => loadVectors()
    .firstWhere((v) => v.name.startsWith('valid v4, latin'))
    .payload;

/// Asserts that [actual] contains every nested key/value present in
/// [expected], like the upstream JS `expectSubset`.
void expectSubset(Object? actual, Object? expected, [String path = r'$']) {
  if (expected is Map) {
    expect(actual, isA<Map<Object?, Object?>>(), reason: path);
    final map = actual as Map<Object?, Object?>;
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(map.containsKey(key), isTrue, reason: '$path.$key missing');
      expectSubset(map[key], value, '$path.$key');
    }
  } else {
    expect(actual, equals(expected), reason: path);
  }
}
