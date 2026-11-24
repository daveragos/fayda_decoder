import 'dart:math' as math;
import 'dart:typed_data';

/// Raw 8-bit RGBA pixels, row-major, same layout as the DOM's `ImageData`.
final class RgbaImage {
  /// Wraps [data], which must hold exactly `width * height * 4` bytes.
  RgbaImage({required this.data, required this.width, required this.height}) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image dimensions must be positive');
    }
    if (data.length != width * height * 4) {
      throw ArgumentError.value(
        data.length,
        'data',
        'Expected width * height * 4 = ${width * height * 4} bytes',
      );
    }
  }

  /// RGBA bytes.
  final Uint8List data;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;
}

/// Cap on the long edge after upscaling, to bound memory.
const maxUpscaledEdge = 4500;

/// Luma grayscale with a linear contrast boost around mid-gray.
RgbaImage grayscaleContrast(RgbaImage image, {double contrast = 1.3}) {
  final src = image.data;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i += 4) {
    final luma = 0.299 * src[i] + 0.587 * src[i + 1] + 0.114 * src[i + 2];
    final v = ((luma - 128) * contrast + 128).round().clamp(0, 255);
    out[i] = v;
    out[i + 1] = v;
    out[i + 2] = v;
    out[i + 3] = 255;
  }
  return RgbaImage(data: out, width: image.width, height: image.height);
}

/// The factor [upscale] would actually apply after clamping the long edge to
/// [maxUpscaledEdge].
double effectiveUpscaleFactor(RgbaImage image, double factor) =>
    math.min(factor, maxUpscaledEdge / math.max(image.width, image.height));

/// Bilinear upscale.
///
/// Small photos of printed cards often fail because the QR finder patterns
/// are only a few pixels wide; a plain 2 to 3x upscale makes them resolve.
/// The factor is clamped so the long edge stays under [maxUpscaledEdge].
/// Returns [image] unchanged when the clamped factor is 1 or less.
RgbaImage upscale(RgbaImage image, double factor) {
  final clamped = effectiveUpscaleFactor(image, factor);
  if (clamped <= 1) return image;

  final sw = image.width, sh = image.height;
  final w = (sw * clamped).round();
  final h = (sh * clamped).round();
  final src = image.data;
  final out = Uint8List(w * h * 4);

  for (var y = 0; y < h; y++) {
    final sy = (y / h) * sh - 0.5;
    final y0 = math.max(0, sy.floor());
    final y1 = math.min(sh - 1, y0 + 1);
    final fy = sy - y0;
    for (var x = 0; x < w; x++) {
      final sx = (x / w) * sw - 0.5;
      final x0 = math.max(0, sx.floor());
      final x1 = math.min(sw - 1, x0 + 1);
      final fx = sx - x0;

      final i00 = (y0 * sw + x0) * 4;
      final i10 = (y0 * sw + x1) * 4;
      final i01 = (y1 * sw + x0) * 4;
      final i11 = (y1 * sw + x1) * 4;
      final o = (y * w + x) * 4;

      for (var c = 0; c < 4; c++) {
        final top = src[i00 + c] * (1 - fx) + src[i10 + c] * fx;
        final bottom = src[i01 + c] * (1 - fx) + src[i11 + c] * fx;
        out[o + c] = (top * (1 - fy) + bottom * fy).round().clamp(0, 255);
      }
    }
  }
  return RgbaImage(data: out, width: w, height: h);
}
