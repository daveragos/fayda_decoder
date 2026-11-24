import 'dart:typed_data';

import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final payload = validPayload();
  final qr = renderQr(payload, scale: 4);

  /// The QR as a luminance plane with [padding] junk bytes after each row,
  /// like a camera Y plane with a row stride.
  (Uint8List, int) luminancePlane({int padding = 0}) {
    final stride = qr.width + padding;
    final plane = Uint8List(stride * qr.height)
      ..fillRange(0, stride * qr.height, 77);
    for (final p in qr) {
      plane[p.y * stride + p.x] = p.r.toInt();
    }
    return (plane, stride);
  }

  group('RgbaImage.fromLuminance', () {
    test('decodes a padded Y plane', () async {
      final (plane, stride) = luminancePlane(padding: 24);
      final image = RgbaImage.fromLuminance(plane,
          width: qr.width, height: qr.height, bytesPerRow: stride);
      expect(await decodeImageData(image), isA<FaydaSuccess>());
    });

    test('rejects buffers that are too small or strides that are too short',
        () {
      final (plane, _) = luminancePlane();
      expect(
          () => RgbaImage.fromLuminance(plane.sublist(1),
              width: qr.width, height: qr.height),
          throwsArgumentError);
      expect(
          () => RgbaImage.fromLuminance(plane,
              width: qr.width, height: qr.height, bytesPerRow: qr.width - 1),
          throwsArgumentError);
    });
  });

  group('RgbaImage.fromBgra', () {
    test('swaps channels and honours the row stride', () {
      // 2x1 image, 4 bytes of padding per row.
      final bgra = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 0, 0, 0, 0]);
      final image =
          RgbaImage.fromBgra(bgra, width: 2, height: 1, bytesPerRow: 12);
      expect(image.data, [3, 2, 1, 4, 7, 6, 5, 8]);
    });

    test('decodes a BGRA frame', () async {
      final bgra =
          qr.convert(numChannels: 4).getBytes(order: img.ChannelOrder.bgra);
      final image =
          RgbaImage.fromBgra(bgra, width: qr.width, height: qr.height);
      expect(await decodeImageData(image), isA<FaydaSuccess>());
    });
  });

  group('background decoding', () {
    test('decodeImageInBackground matches decodeImage', () async {
      final png = img.encodePng(qr);
      final background = await decodeImageInBackground(png, includeFace: true);
      expect(background, isA<FaydaSuccess>());
      expect(background, equals(await decodeImage(png, includeFace: true)));
    });

    test('decodeImageDataInBackground decodes camera pixels', () async {
      final (plane, _) = luminancePlane();
      final image =
          RgbaImage.fromLuminance(plane, width: qr.width, height: qr.height);
      expect(await decodeImageDataInBackground(image), isA<FaydaSuccess>());
    });

    test('errors cross the isolate boundary as FormatException', () {
      expect(decodeImageInBackground(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
    });
  });
}
