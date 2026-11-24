import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'helpers.dart';

/// Scanner stub that returns scripted outcomes, one per pipeline variant.
final class _ScriptedScanner implements QrScanner {
  _ScriptedScanner(this._outcomes);

  final List<QrScan> _outcomes;
  int calls = 0;

  @override
  QrScan scan(RgbaImage image) {
    final i = calls++;
    return i < _outcomes.length ? _outcomes[i] : const QrScanNone();
  }
}

void main() {
  final valid = validPayload();

  group('decodeImage', () {
    test('decodes a clean QR image', () async {
      final result = await decodeImage(qrPng(valid), includeFace: true);
      expect(result, isA<FaydaSuccess>());
      result as FaydaSuccess;
      expect(result.fields.fullName, 'Abebe Kebede Alemu');
      expect(result.fields.face?.format, 'webp');
    });

    test('decodes an Ethiopic (UTF-8) name', () async {
      final ethiopic = loadVectors()
          .firstWhere((v) => v.name.startsWith('valid v4, ethiopic'))
          .payload;
      final result = await decodeImage(qrPng(ethiopic)) as FaydaSuccess;
      expect(result.fields.fullName, 'አልማዝ ተስፋዬ በቀለ');
    });

    test('decodes an Ethiopic name split across QR segments', () async {
      // Byte, numeric and byte segments, so the UTF-8 repair has to splice
      // each byte segment back into the right place. Rendered with
      // package:qr: byte('UklGRg:DLT:አልማዝ ተስፋዬ:V:4:G:F:A:'),
      // numeric('6140987654321098'), byte(':D:1994/05/07:SIGN:e30..c2ln').
      final png = File('test/fixtures/mixed_segments_qr.png').readAsBytesSync();
      final result = await decodeImage(png) as FaydaSuccess;
      expect(result.fields.fullName, 'አልማዝ ተስፋዬ');
      expect(result.fields.fan, '6140987654321098');
      expect(result.fields.dateOfBirth, '1994-05-07');
    });

    test('decodes a real-card-sized dense QR in a recompressed photo',
        () async {
      // ~1100 characters like real cards (version ~23, EC level L), with
      // 2px modules on a 1024px "photo", saved as a lossy JPEG.
      final random = Random(7);
      final face = [
        ...'RIFF'.codeUnits,
        for (var i = 0; i < 460; i++) random.nextInt(256),
      ];
      final payload =
          '${base64Url.encode(face).replaceAll('=', '')}:DLT:Abebe Kebede Alemu'
          ':V:4:G:M:A:6140123412341234:D:2002/11/26:SIGN:'
          '${base64Url.encode(List.filled(48, 1)).replaceAll('=', '')}'
          '..${base64Url.encode(List.filled(256, 7)).replaceAll('=', '')}';
      expect(payload.length, inInclusiveRange(1050, 1150));

      final qr = renderQr(payload, scale: 2);
      final photo = img.Image(width: 1024, height: 768);
      img.fill(photo, color: img.ColorRgb8(200, 190, 180));
      img.compositeImage(photo, qr, dstX: 40, dstY: 40);
      final result = await decodeImage(img.encodeJpg(photo, quality: 70),
          includeFace: true);
      expect(result, isA<FaydaSuccess>());
      result as FaydaSuccess;
      expect(result.raw.payload, payload);
      expect(result.fields.face!.bytes, face);
    });

    test('decodes a small, recompressed image via the upscale path', () async {
      // Shrink so modules are ~1.7px wide, then re-encode as JPEG to simulate
      // chat-app recompression of a photographed card.
      final qr = renderQr(valid);
      final small = img.copyResize(
        qr,
        width: (qr.width * 0.28).round(),
        interpolation: img.Interpolation.average,
      );
      final jpeg = img.encodeJpg(small, quality: 80);
      final result = await decodeImage(jpeg);
      expect(result, isA<FaydaSuccess>());
      expect((result as FaydaSuccess).fields.fan, '6140123412341234');
    });

    test('decodes a transparent PNG', () async {
      final qr = renderQr(valid);
      final transparent = img.Image(
        width: qr.width,
        height: qr.height,
        numChannels: 4,
      );
      for (final p in qr) {
        // Dark modules opaque black, light modules fully transparent black.
        final dark = p.r < 128;
        transparent.setPixelRgba(p.x, p.y, 0, 0, 0, dark ? 255 : 0);
      }
      final result = await decodeImage(img.encodePng(transparent));
      expect(result, isA<FaydaSuccess>());
    });

    test('returns NO_QR_FOUND for an image without a QR', () async {
      final blank = img.Image(width: 400, height: 300);
      img.fill(blank, color: img.ColorRgb8(240, 240, 240));
      final result = await decodeImage(img.encodePng(blank));
      expect((result as FaydaFailure).error.code, FaydaErrorCode.noQrFound);
    });

    test('returns NOT_FAYDA for a QR that is not a Fayda payload', () async {
      final result =
          await decodeImage(qrPng('https://example.com/unrelated', scale: 8));
      expect((result as FaydaFailure).error.code, FaydaErrorCode.notFayda);
    });

    test('throws FormatException for bytes that are not an image', () {
      expect(
        () => decodeImage(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException,
      );
    });
  });

  group('decodeImageData pipeline', () {
    final pixels =
        RgbaImage(data: Uint8List(16 * 16 * 4), width: 16, height: 16);

    test('tries every variant, then reports NO_QR_FOUND', () async {
      final scanner = _ScriptedScanner([]);
      final result = await decodeImageData(pixels, scanner: scanner);
      expect(scanner.calls, 4);
      expect((result as FaydaFailure).error.code, FaydaErrorCode.noQrFound);
    });

    test('stops at the first Fayda payload, skipping unrelated QRs', () async {
      final scanner = _ScriptedScanner([
        const QrScanUnreadable(),
        QrScanDecoded(['https://example.com', valid]),
      ]);
      final result = await decodeImageData(pixels, scanner: scanner);
      expect(scanner.calls, 2);
      expect(result, isA<FaydaSuccess>());
    });

    test('reports QR_UNREADABLE when a QR was seen but never decoded',
        () async {
      final scanner = _ScriptedScanner([const QrScanUnreadable()]);
      final result = await decodeImageData(pixels, scanner: scanner);
      expect((result as FaydaFailure).error.code, FaydaErrorCode.qrUnreadable);
    });

    test('prefers UNSUPPORTED_VERSION over NOT_FAYDA', () async {
      final v5 = valid.replaceFirst(':V:4:', ':V:5:');
      final scanner = _ScriptedScanner([
        QrScanDecoded([v5]),
        const QrScanDecoded(['https://example.com']),
      ]);
      final result = await decodeImageData(pixels, scanner: scanner);
      result as FaydaFailure;
      expect(result.error.code, FaydaErrorCode.unsupportedVersion);
      expect(result.raw!.map['V'], '5');
    });

    test('a later supported read beats an earlier unsupported one', () async {
      final v5 = valid.replaceFirst(':V:4:', ':V:5:');
      final scanner = _ScriptedScanner([
        QrScanDecoded([v5]),
        QrScanDecoded([valid]),
      ]);
      final result = await decodeImageData(pixels, scanner: scanner);
      expect(result, isA<FaydaSuccess>());
    });

    test('skips upscale variants the size cap turns into no-ops', () async {
      final large = RgbaImage(
        data: Uint8List(4600 * 2 * 4),
        width: 4600,
        height: 2,
      );
      final scanner = _ScriptedScanner([]);
      await decodeImageData(large, scanner: scanner);
      expect(scanner.calls, 2);
    });

    test('rejects pixel buffers of the wrong size', () {
      expect(
        () => RgbaImage(data: Uint8List(10), width: 2, height: 2),
        throwsArgumentError,
      );
    });
  });
}
