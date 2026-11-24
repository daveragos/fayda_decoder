import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
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

/// Renders [text] as a QR code image (EC level L, like real cards), [scale]
/// pixels per module with a 4-module quiet zone.
img.Image renderQr(String text, {int scale = 6}) {
  // One UTF-8 byte segment without an ECI header, like the npm `qrcode`
  // package the upstream tests use.
  final qr = QrImage(QrCode(
    payload: QrPayload.fromTypedData(utf8.encode(text)),
    errorCorrectLevel: QrErrorCorrectLevel.low,
  ));
  const margin = 4;
  final size = (qr.moduleCount + margin * 2) * scale;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var row = 0; row < qr.moduleCount; row++) {
    for (var col = 0; col < qr.moduleCount; col++) {
      if (!qr.isDark(row, col)) continue;
      img.fillRect(
        image,
        x1: (col + margin) * scale,
        y1: (row + margin) * scale,
        x2: (col + margin + 1) * scale - 1,
        y2: (row + margin + 1) * scale - 1,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
  }
  return image;
}

/// [renderQr] encoded as PNG bytes.
Uint8List qrPng(String text, {int scale = 6}) =>
    img.encodePng(renderQr(text, scale: scale));
