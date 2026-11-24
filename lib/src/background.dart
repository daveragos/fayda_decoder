import 'dart:typed_data';

import 'background_inline.dart'
    if (dart.library.isolate) 'background_isolate.dart' as runner;
import 'pipeline.dart';
import 'pixels.dart';
import 'result.dart';

/// [decodeImage] on a background isolate, so a Flutter UI keeps rendering
/// while the photo is processed.
///
/// On platforms without isolates (the web) it runs on the calling thread
/// after yielding to the event loop, so a progress indicator can paint
/// first.
///
/// Uses the default [ZxingQrScanner]. To use your own [QrScanner], call
/// [decodeImage] directly.
///
/// Throws a [FormatException] if [bytes] is not a readable image.
Future<FaydaResult> decodeImageInBackground(
  Uint8List bytes, {
  bool includeFace = false,
}) =>
    runner.run(() => decodeImage(bytes, includeFace: includeFace));

/// [decodeImageData] on a background isolate. See [decodeImageInBackground].
Future<FaydaResult> decodeImageDataInBackground(
  RgbaImage image, {
  bool includeFace = false,
}) =>
    runner.run(() => decodeImageData(image, includeFace: includeFace));
