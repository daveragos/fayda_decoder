import 'dart:async';
import 'dart:convert';
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
        final text = _repairByteSegments(result);
        if (text.isNotEmpty) return QrScanDecoded([text]);
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

  /// zxing2 0.2.x reads byte-mode data into an `Int8List` and decodes it
  /// as-is, so every byte >= 0x80 turns into U+FFFD. That destroys
  /// non-ASCII text such as Ethiopic names. The raw bytes survive in the
  /// result metadata, so re-decode each byte segment and splice it back in
  /// place of its mangled form.
  static String _repairByteSegments(Result result) {
    final text = result.text;
    if (!text.contains('�')) return text;
    final segments = result.resultMetadata[ResultMetadataType.byteSegments];
    if (segments is! List) return text;

    final out = StringBuffer();
    var cursor = 0;
    for (final segment in segments.whereType<List<int>>()) {
      final bytes = Uint8List.fromList([for (final b in segment) b & 0xff]);
      // The mangled form, as zxing2 produced it with either codec it uses.
      final mangledCandidates = {
        const Utf8Codec(allowMalformed: true).decode(segment),
        const Latin1Codec(allowInvalid: true).decode(segment),
      };
      var index = -1;
      var mangled = '';
      for (final candidate in mangledCandidates) {
        final i = text.indexOf(candidate, cursor);
        if (i != -1 && (index == -1 || i < index)) {
          index = i;
          mangled = candidate;
        }
      }
      if (index == -1) return text; // Unexpected shape: leave it untouched.
      out
        ..write(text.substring(cursor, index))
        ..write(_decodeSegment(bytes));
      cursor = index + mangled.length;
    }
    out.write(text.substring(cursor));
    return out.toString();
  }

  /// UTF-8 when the bytes are valid UTF-8, otherwise ISO-8859-1 (the QR
  /// default).
  static String _decodeSegment(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
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
