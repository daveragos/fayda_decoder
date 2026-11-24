import 'dart:convert';
import 'dart:typed_data';

final _base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+={0,2}$');

/// Strict base64url decode (`-_` alphabet, padding optional).
///
/// Returns null if [input] is not valid base64url, instead of silently
/// skipping garbage the way lenient decoders do.
Uint8List? base64UrlDecodeStrict(String input) {
  if (!_base64UrlPattern.hasMatch(input)) return null;
  final padded = input.endsWith('=');
  if (padded && input.length % 4 != 0) return null;
  final unpadded = padded ? input.replaceAll('=', '') : input;
  if (unpadded.length % 4 == 1) return null;
  try {
    return base64Url.decode(base64Url.normalize(unpadded));
  } on FormatException {
    return null;
  }
}

/// Lenient base64url decode used for JWS segments. Throws [FormatException].
Uint8List base64UrlDecodeLenient(String input) =>
    base64Url.decode(base64Url.normalize(input));

/// base64url encode without padding, as used by JWS.
String base64UrlEncodeNoPad(List<int> bytes) {
  final encoded = base64Url.encode(bytes);
  final end = encoded.indexOf('=');
  return end == -1 ? encoded : encoded.substring(0, end);
}
