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

  /// Builds an image from an 8-bit luminance (grayscale) buffer.
  ///
  /// This is the Y plane of a YUV420 or NV21 camera frame, which is all a QR
  /// decoder needs. With the `camera` package on Android
  /// (`ImageFormatGroup.yuv420` or `nv21`):
  ///
  /// ```dart
  /// final y = cameraImage.planes.first;
  /// final image = RgbaImage.fromLuminance(
  ///   y.bytes,
  ///   width: cameraImage.width,
  ///   height: cameraImage.height,
  ///   bytesPerRow: y.bytesPerRow,
  /// );
  /// ```
  ///
  /// [bytesPerRow] defaults to [width]; pass the plane's row stride when rows
  /// are padded.
  factory RgbaImage.fromLuminance(
    Uint8List luminance, {
    required int width,
    required int height,
    int? bytesPerRow,
  }) {
    final stride = bytesPerRow ?? width;
    _checkSource(luminance, width, height, stride, 1);
    final out = Uint8List(width * height * 4);
    var o = 0;
    for (var y = 0; y < height; y++) {
      final row = y * stride;
      for (var x = 0; x < width; x++) {
        final v = luminance[row + x];
        out[o] = v;
        out[o + 1] = v;
        out[o + 2] = v;
        out[o + 3] = 255;
        o += 4;
      }
    }
    return RgbaImage(data: out, width: width, height: height);
  }

  /// Builds an image from BGRA8888 pixels, the iOS camera format.
  ///
  /// With the `camera` package on iOS (`ImageFormatGroup.bgra8888`):
  ///
  /// ```dart
  /// final plane = cameraImage.planes.first;
  /// final image = RgbaImage.fromBgra(
  ///   plane.bytes,
  ///   width: cameraImage.width,
  ///   height: cameraImage.height,
  ///   bytesPerRow: plane.bytesPerRow,
  /// );
  /// ```
  ///
  /// [bytesPerRow] defaults to `width * 4`.
  factory RgbaImage.fromBgra(
    Uint8List bgra, {
    required int width,
    required int height,
    int? bytesPerRow,
  }) {
    final stride = bytesPerRow ?? width * 4;
    _checkSource(bgra, width, height, stride, 4);
    final out = Uint8List(width * height * 4);
    var o = 0;
    for (var y = 0; y < height; y++) {
      var i = y * stride;
      for (var x = 0; x < width; x++, i += 4, o += 4) {
        out[o] = bgra[i + 2];
        out[o + 1] = bgra[i + 1];
        out[o + 2] = bgra[i];
        out[o + 3] = bgra[i + 3];
      }
    }
    return RgbaImage(data: out, width: width, height: height);
  }

  static void _checkSource(
    Uint8List source,
    int width,
    int height,
    int stride,
    int bytesPerPixel,
  ) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image dimensions must be positive');
    }
    if (stride < width * bytesPerPixel) {
      throw ArgumentError.value(
          stride, 'bytesPerRow', 'Must be at least width * $bytesPerPixel');
    }
    final needed = stride * (height - 1) + width * bytesPerPixel;
    if (source.length < needed) {
      throw ArgumentError.value(source.length, 'length',
          'Buffer too small for ${width}x$height with $stride bytes per row');
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
