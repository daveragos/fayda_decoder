// Runs on every platform, including the browser (`dart test -p chrome`), so
// it must not import dart:io or test/helpers.dart.
import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/testing.dart';
import 'package:test/test.dart';

void main() {
  final payload = buildTestPayload(fullName: 'አልማዝ ተስፋዬ በቀለ');

  test('signs and verifies RS256 with BigInt on this platform', () {
    final result = decodePayload(payload) as FaydaSuccess;
    expect(result.verify(publicKeyPem: faydaTestPublicKeyPem).verified, isTrue);
    expect(result.verify().verified, isFalse);
  });

  test('decodes a QR image, falling back to inline work without isolates',
      () async {
    final result = await decodeImageInBackground(buildTestQrPng(payload),
        includeFace: true);
    expect(result, equals(decodePayload(payload, includeFace: true)));
  });

  test('camera frame helpers', () async {
    final rgba = buildTestQrImage(payload);
    final bgra = rgba.data.sublist(0);
    for (var i = 0; i < bgra.length; i += 4) {
      final r = bgra[i];
      bgra[i] = bgra[i + 2];
      bgra[i + 2] = r;
    }
    final frame =
        RgbaImage.fromBgra(bgra, width: rgba.width, height: rgba.height);
    expect(await decodeImageDataInBackground(frame), isA<FaydaSuccess>());
  });
}
