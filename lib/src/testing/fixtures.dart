import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import '../base64.dart';
import '../pixels.dart';
import '../result.dart';
import '../rsa.dart';
import 'test_key.dart';

/// PEM public key that verifies payloads from [buildTestPayload].
///
/// ```dart
/// final result = decodePayload(buildTestPayload()) as FaydaSuccess;
/// verifySignature(result, publicKeyPem: faydaTestPublicKeyPem).verified; // true
/// verifySignature(result).verified; // false: not signed by NIDP
/// ```
///
/// The matching private key ships with this package, so anyone can sign
/// with it. Never accept it outside tests.
const faydaTestPublicKeyPem = testPublicKeyPem;

/// A tiny (8x8) synthetic WebP used as the default test face.
final Uint8List faydaTestFace = base64Url.decode(
  'UklGRjQAAABXRUJQVlA4ICgAAACQAQCdASoIAAgAAUAmJYgCdLoAA5gA_ufkv43m81rW_tTYqp5OAAAA',
);

final _testKey = RsaPrivateKey(
  modulus: BigInt.parse(testKeyHex.modulus, radix: 16),
  p: BigInt.parse(testKeyHex.p, radix: 16),
  q: BigInt.parse(testKeyHex.q, radix: 16),
  dp: BigInt.parse(testKeyHex.dp, radix: 16),
  dq: BigInt.parse(testKeyHex.dq, radix: 16),
  qInv: BigInt.parse(testKeyHex.qInv, radix: 16),
);

/// Builds a synthetic Fayda V4 QR payload for tests, so you never need a real
/// person's card.
///
/// By default it is signed with the test key: it verifies against
/// [faydaTestPublicKeyPem] and fails against the bundled NIDP key, which
/// also makes it a ready-made "forged card" fixture.
///
/// - [face]: WebP bytes, defaults to [faydaTestFace]. Pass an empty list for
///   a payload without a face.
/// - [gender], [fan], [dateOfBirth]: null leaves the key out.
/// - [fan] is written as given. Real cards store it in groups separated by
///   two spaces; pass `fan: '6140  1234  1234  1234'` to match them.
/// - [overrides]: raw key/value fields applied last, to produce malformed
///   data. A null value removes the key:
///   `overrides: {'D': '1990/02/31'}`, `overrides: {'V': '5'}`.
/// - [signed]: false leaves the signature empty.
///
/// Throws an [ArgumentError] if [fullName] contains `:`, which the format
/// cannot carry.
String buildTestPayload({
  String fullName = 'Abebe Kebede Alemu',
  FaydaGender? gender = FaydaGender.male,
  String? fan = '6140123412341234',
  DateTime? dateOfBirth,
  List<int>? face,
  String version = '4',
  bool signed = true,
  Map<String, String?> overrides = const {},
}) {
  if (fullName.contains(':')) {
    throw ArgumentError.value(fullName, 'fullName', 'Must not contain ":"');
  }
  final dob = dateOfBirth ?? DateTime(2002, 11, 26);
  final fields = <String, String?>{
    'V': version,
    'G': gender?.code,
    'A': fan,
    'D': '${_pad(dob.year, 4)}/${_pad(dob.month, 2)}/${_pad(dob.day, 2)}',
    ...overrides,
  }..removeWhere((_, value) => value == null);

  final tail = [
    for (final MapEntry(:key, :value) in fields.entries) '$key:$value',
  ].join(':');
  final facePart = base64UrlEncodeNoPad(face ?? faydaTestFace);
  final external = '$facePart:DLT:$fullName:$tail';
  if (!signed) return '$external:SIGN:';

  final header = base64UrlEncodeNoPad(utf8.encode('{"alg":"RS256"}'));
  final signingInput = '$header.${base64UrlEncodeNoPad(utf8.encode(external))}';
  final signature = rsaPkcs1Sha256Sign(_testKey, utf8.encode(signingInput));
  return '$external:SIGN:$header..${base64UrlEncodeNoPad(signature)}';
}

/// Renders [payload] as a QR code PNG (EC level L, like real cards), for
/// feeding `decodeImage` or a mocked image picker in tests.
///
/// The text is stored as one UTF-8 byte segment without an ECI header, the
/// way card QR codes are.
Uint8List buildTestQrPng(
  String payload, {
  int moduleSize = 4,
  int quietZone = 4,
}) =>
    img.encodePng(
      renderTestQr(payload, moduleSize: moduleSize, quietZone: quietZone),
    );

/// Renders [payload] as raw pixels, for testing `decodeImageData` and
/// camera-frame code paths. See [buildTestQrPng].
RgbaImage buildTestQrImage(
  String payload, {
  int moduleSize = 4,
  int quietZone = 4,
}) {
  final image = renderTestQr(
    payload,
    moduleSize: moduleSize,
    quietZone: quietZone,
  ).convert(numChannels: 4);
  return RgbaImage(
    data: image.getBytes(order: img.ChannelOrder.rgba),
    width: image.width,
    height: image.height,
  );
}

/// Renders [payload] as a black-on-white QR code image.
img.Image renderTestQr(
  String payload, {
  int moduleSize = 4,
  int quietZone = 4,
}) {
  // Encoder takes ISO-8859-1 text; passing UTF-8 bytes as Latin-1 characters
  // stores the raw UTF-8 bytes.
  final code = Encoder.encode(
    String.fromCharCodes(utf8.encode(payload)),
    ErrorCorrectionLevel.l,
  );
  final matrix = code.matrix!;
  final size = (matrix.width + quietZone * 2) * moduleSize;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) != 1) continue;
      img.fillRect(
        image,
        x1: (x + quietZone) * moduleSize,
        y1: (y + quietZone) * moduleSize,
        x2: (x + quietZone + 1) * moduleSize - 1,
        y2: (y + quietZone + 1) * moduleSize - 1,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
  }
  return image;
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');
