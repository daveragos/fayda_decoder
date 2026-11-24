/// Test helpers for apps and services that use `fayda_decoder`.
///
/// Build realistic, fully synthetic card payloads and QR images, signed
/// with a published test key, so tests never touch a real person's card:
///
/// ```dart
/// import 'package:fayda_decoder/fayda_decoder.dart';
/// import 'package:fayda_decoder/testing.dart';
///
/// final payload = buildTestPayload(fullName: 'Hana Girma Wolde');
/// final result = decodePayload(payload) as FaydaSuccess;
/// expect(result.verify(publicKeyPem: faydaTestPublicKeyPem).verified, isTrue);
///
/// final png = buildTestQrPng(payload);
/// expect(await decodeImage(png), isA<FaydaSuccess>());
/// ```
///
/// Import this only from tests and fixtures.
library;

export 'src/testing/fixtures.dart'
    show buildTestPayload, buildTestQrPng, faydaTestFace, faydaTestPublicKeyPem;
