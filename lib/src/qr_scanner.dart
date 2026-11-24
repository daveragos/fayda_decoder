import 'dart:async';
import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

import 'pixels.dart';

/// The outcome of scanning one image for QR codes.
sealed class QrScan {
  const QrScan();
}

/// One or more QR codes decoded to text.
final class QrScanDecoded extends QrScan {
  /// Every decoded text. A card photo can contain unrelated QR codes, so
  /// scanners may return more than one.
  const QrScanDecoded(this.texts);

  /// The decoded texts, in the order the scanner found them.
  final List<String> texts;
}

/// A QR code was located but could not be decoded.
final class QrScanUnreadable extends QrScan {
  /// Creates the unreadable outcome.
  const QrScanUnreadable();
}

/// No QR code was found.
final class QrScanNone extends QrScan {
  /// Creates the not-found outcome.
  const QrScanNone();
}

/// A QR engine the image pipeline can call.
///
/// The default is [ZxingQrScanner] (pure Dart). Implement this to plug in a
/// stronger or native engine, for example zxing-cpp through `flutter_zxing`
/// or ML Kit, while keeping this package's preprocessing and parsing.
abstract interface class QrScanner {
  /// Scans [image] for QR codes.
  FutureOr<QrScan> scan(RgbaImage image);
}

/// Pure-Dart QR scanner built on `package:zxing2` (a port of ZXing).
///
/// Works on every platform, including the web. It reports at most one QR per
/// image.
final class ZxingQrScanner implements QrScanner {
  /// Creates the scanner.
  const ZxingQrScanner();

  @override
  QrScan scan(RgbaImage image) {
    final source = RGBLuminanceSource(
      image.width,
      image.height,
      _toArgbOverWhite(image.data),
    );
    final hints = DecodeHints()
      ..put(DecodeHintType.tryHarder)
      ..put(DecodeHintType.possibleFormats, [BarcodeFormat.qrCode]);

    var located = false;
    // Hybrid (local) thresholding copes with glare and uneven light; the
    // global histogram binarizer sometimes wins on clean, low-res images.
    for (final binarizer in <Binarizer>[
      HybridBinarizer(source),
      GlobalHistogramBinarizer(source),
    ]) {
      try {
        final result =
            QRCodeReader().decode(BinaryBitmap(binarizer), hints: hints);
        if (result.text.isNotEmpty) return QrScanDecoded([result.text]);
      } on NotFoundException {
        // Nothing that looks like a QR with this binarizer.
      } on ReaderException {
        // Finder patterns located but the symbol failed to decode.
        located = true;
      } on Error {
        // zxing2 can throw ArgumentError and similar on noisy input (seen
        // with the global histogram binarizer on large photos). That is not
        // evidence of a QR, so report nothing found rather than crashing.
      }
    }
    return located ? const QrScanUnreadable() : const QrScanNone();
  }

  /// RGBA bytes to ARGB ints, composited over white so transparent
  /// screenshots do not turn into black squares.
  static Int32List _toArgbOverWhite(Uint8List rgba) {
    final out = Int32List(rgba.length ~/ 4);
    for (var i = 0, p = 0; p < out.length; i += 4, p++) {
      final a = rgba[i + 3];
      int r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      if (a != 255) {
        final inv = 255 - a;
        r = (r * a + 255 * inv) ~/ 255;
        g = (g * a + 255 * inv) ~/ 255;
        b = (b * a + 255 * inv) ~/ 255;
      }
      out[p] = (0xff << 24) | (r << 16) | (g << 8) | b;
    }
    return out;
  }
}
