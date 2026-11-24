import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Decodes a photo of a card.
///
/// Tries the platform engine first (ML Kit on Android, Vision on iOS), which
/// is fast and strong, then falls back to fayda_decoder's own pure-Dart
/// pipeline on a background isolate. On the web, and on the iOS simulator,
/// only the fallback runs.
///
/// Throws a [FormatException] if the file is not a readable image.
Future<FaydaResult> decodePhoto(XFile file) async {
  if (!kIsWeb) {
    final controller = MobileScannerController(autoStart: false);
    try {
      final capture = await controller.analyzeImage(
        file.path,
        formats: const [BarcodeFormat.qrCode],
      );
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        final text = barcode.rawValue;
        if (text != null && isFaydaPayload(text)) {
          return decodePayload(text, includeFace: true);
        }
      }
    } on Object {
      // Not supported here, or the engine failed: use the fallback.
    } finally {
      await controller.dispose();
    }
  }
  return decodeImageInBackground(await file.readAsBytes(), includeFace: true);
}
