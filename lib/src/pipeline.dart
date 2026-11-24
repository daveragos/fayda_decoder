import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'parser.dart';
import 'pixels.dart';
import 'qr_scanner.dart';
import 'result.dart';

/// Decodes a Fayda QR from encoded image bytes (JPEG, PNG, WebP, GIF, BMP,
/// TIFF and more, via `package:image`).
///
/// Use this for a photo picked from the gallery or a file. If you already
/// have raw RGBA pixels, use [decodeImageData]; if you already have the QR
/// text, use [decodePayload].
///
/// This is CPU-heavy pure Dart. In Flutter, run it off the UI thread:
/// `await Isolate.run(() => decodeImage(bytes))`.
///
/// Throws a [FormatException] if [bytes] is not an image format
/// `package:image` can read.
Future<FaydaResult> decodeImage(
  Uint8List bytes, {
  bool includeFace = false,
  QrScanner scanner = const ZxingQrScanner(),
}) {
  return decodeImageData(
    imageBytesToRgba(bytes),
    includeFace: includeFace,
    scanner: scanner,
  );
}

/// Decodes encoded image bytes to raw RGBA pixels.
///
/// Throws a [FormatException] if [bytes] cannot be decoded.
RgbaImage imageBytesToRgba(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    throw const FormatException(
      'fayda_decoder: unsupported or corrupt image data',
    );
  }
  final rgba = decoded.convert(format: img.Format.uint8, numChannels: 4);
  return RgbaImage(
    data: rgba.getBytes(order: img.ChannelOrder.rgba),
    width: rgba.width,
    height: rgba.height,
  );
}

/// Decodes a Fayda QR from raw RGBA pixels, for example a camera frame.
///
/// Decoding a clean screenshot is trivial; the value of this pipeline is
/// phone photos of physical printed cards (glare, angle, low resolution,
/// chat-app recompression). Variants are attempted in order of increasing
/// cost:
///
/// 1. as-is
/// 2. grayscale + contrast
/// 3. upscale 2x + grayscale + contrast
/// 4. upscale 3x + grayscale + contrast
///
/// It stops at the first decoded text that parses as a Fayda payload, not
/// just any QR, since other QR codes can be near the card.
Future<FaydaResult> decodeImageData(
  RgbaImage image, {
  bool includeFace = false,
  QrScanner scanner = const ZxingQrScanner(),
}) async {
  final variants = <RgbaImage Function()>[
    () => image,
    () => grayscaleContrast(image),
  ];
  var lastFactor = 1.0;
  for (final factor in const [2.0, 3.0]) {
    // Skip upscale variants the size cap turns into no-ops or duplicates.
    final effective = effectiveUpscaleFactor(image, factor);
    if (effective <= lastFactor) continue;
    lastFactor = effective;
    variants.add(() => grayscaleContrast(upscale(image, factor)));
  }

  var sawAnyQr = false;
  var sawUnreadableQr = false;
  FaydaFailure? faydaShapedFailure;

  for (final makeVariant in variants) {
    switch (await scanner.scan(makeVariant())) {
      case QrScanNone():
        continue;
      case QrScanUnreadable():
        sawUnreadableQr = true;
      case QrScanDecoded(:final texts):
        sawAnyQr = true;
        for (final text in texts) {
          final parsed = decodePayload(text, includeFace: includeFace);
          switch (parsed) {
            case FaydaSuccess():
              return parsed;
            // Fayda-shaped but an unknown version is a definitive answer,
            // but keep trying other variants in case a better read yields a
            // supported payload.
            case FaydaFailure(
                error: FaydaError(code: FaydaErrorCode.unsupportedVersion)
              ):
              faydaShapedFailure = parsed;
            case FaydaFailure():
              break;
          }
        }
    }
  }

  if (faydaShapedFailure != null) return faydaShapedFailure;

  if (sawAnyQr) {
    return const FaydaFailure(FaydaError(
      FaydaErrorCode.notFayda,
      'A QR code was found but it is not a Fayda ID payload (wrong side of '
      'the card, or a different document).',
    ));
  }

  if (sawUnreadableQr) {
    return const FaydaFailure(FaydaError(
      FaydaErrorCode.qrUnreadable,
      'A QR code was detected but could not be decoded. Retake the photo '
      'closer, flatter, and with more light.',
    ));
  }

  return const FaydaFailure(FaydaError(
    FaydaErrorCode.noQrFound,
    'No QR code was found in the image. Retake the photo closer and with '
    'more light.',
  ));
}
