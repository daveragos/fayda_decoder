# fayda_decoder

[![pub package](https://img.shields.io/pub/v/fayda_decoder.svg)](https://pub.dev/packages/fayda_decoder)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Read and verify the QR code on the Ethiopian **Fayda** national ID card,
entirely on-device. No network calls, no API key, no onboarding.

```dart
final result = decodePayload(qrText);
if (result case FaydaSuccess(:final fields) when result.verify().verified) {
  print('${fields.fullName}, FAN ${fields.formattedFan}');
}
```

> Community project. **Not affiliated with or endorsed by** Ethiopia's
> National ID Program (NIDP). "Fayda" is NIDP's brand. This is the Dart port
> of [fayda-decoder](https://github.com/Alpha-Mintamir/fayda-decoder) and
> passes the same shared test vectors.

## Features

- **Parse** name (Latin or Ethiopic), gender, FAN, date of birth and the face
  thumbnail into typed, immutable results.
- **Verify** the card's RS256 signature against NIDP's public key, offline.
- **Decode photos** of printed cards, including blurry, low-resolution and
  chat-app-recompressed ones, with an upscale-and-retry pipeline.
- **Camera frames** from the `camera` package (Android YUV, iOS BGRA).
- **Background decoding** on an isolate, with a web fallback.
- **Testing library** that builds signed, synthetic cards and QR images, so
  your tests never need a real person's card.
- **Command-line tool** for scripts, support and debugging.
- **Pure Dart**: Android, iOS, web (including WASM), macOS, Windows, Linux
  and servers.

## Which API do I need?

| You have | Use |
| --- | --- |
| QR text from a scanner (`mobile_scanner`, a hardware reader) | `decodePayload(text)` |
| Several barcodes and want to skip the non-Fayda ones | `isFaydaPayload(text)` |
| A photo or screenshot (JPEG, PNG, WebP, ...) | `decodeImageInBackground(bytes)` |
| A frame from the `camera` package | `RgbaImage.fromLuminance` / `fromBgra`, then `decodeImageDataInBackground` |
| A decoded card and want to know it is genuine | `result.verify()` |
| A server receiving cards from your app | `decodePayload` + `verifySignature` on the raw text |
| Tests | `package:fayda_decoder/testing.dart` |

## Install

```bash
dart pub add fayda_decoder     # or: flutter pub add fayda_decoder
```

## Flutter recipes

The [example app](example/flutter_app) puts all of these together.

### Scan with the camera

```dart
MobileScanner(
  controller: MobileScannerController(formats: const [BarcodeFormat.qrCode]),
  onDetect: (capture) {
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null || !isFaydaPayload(text)) continue; // other QR codes
      Navigator.of(context).pop(decodePayload(text, includeFace: true));
      return;
    }
  },
)
```

`isFaydaPayload` is a cheap structural check, so the scanner callback can
ignore unrelated codes without parsing them.

### Read a photo from the gallery

```dart
final file = await ImagePicker().pickImage(source: ImageSource.gallery);
if (file == null) return;
final result = await decodeImageInBackground(
  await file.readAsBytes(),
  includeFace: true,
);
```

`decodeImageInBackground` runs the pipeline on a background isolate, so
animations keep running; on the web it runs inline. It throws a
`FormatException` for files that are not images.

For the hardest photos, try the platform engine first and fall back to this
package (see [`photo_decoder.dart`](example/flutter_app/lib/src/photo_decoder.dart)):

```dart
final capture = await MobileScannerController(autoStart: false)
    .analyzeImage(file.path, formats: const [BarcodeFormat.qrCode]);
final text = capture?.barcodes.firstOrNull?.rawValue;
final result = text != null && isFaydaPayload(text)
    ? decodePayload(text)
    : await decodeImageInBackground(await file.readAsBytes());
```

### Decode `camera` package frames

```dart
controller.startImageStream((CameraImage frame) async {
  final plane = frame.planes.first;
  final image = Platform.isIOS
      ? RgbaImage.fromBgra(plane.bytes,
          width: frame.width, height: frame.height,
          bytesPerRow: plane.bytesPerRow) // ImageFormatGroup.bgra8888
      : RgbaImage.fromLuminance(plane.bytes,
          width: frame.width, height: frame.height,
          bytesPerRow: plane.bytesPerRow); // yuv420 / nv21: the Y plane
  final result = await decodeImageDataInBackground(image);
});
```

Throttle the stream (for example one frame every 500 ms); a full decode is
far slower than a frame interval.

### Show the result

Results are a sealed type, so `switch` covers every case:

```dart
switch (result) {
  case FaydaSuccess(:final fields):
    final check = result.verify();
    return Column(children: [
      if (fields.face case final face?) Image.memory(face.bytes), // WebP
      Text(fields.fullName),
      Text(fields.formattedFan ?? ''),          // 6140 1234 1234 1234
      Text('${fields.dateOfBirth} (age ${fields.age})'),
      Text(check.verified ? 'Signed by NIDP' : 'Not verified: ${check.reason?.code}'),
    ]);
  case FaydaFailure(:final error):
    return Text(error.message); // safe to show, never contains personal data
}
```

Results have value equality, so they work directly as Bloc, Riverpod or
`ValueNotifier` state, and `FaydaResult.fromJson(result.toJson())` round-trips
them for caching.

## Signature verification

Every card carries a detached RS256 JWS over the rest of the QR text.
`verify()` (or `verifySignature(result)`) checks it against the NIDP V4 key
bundled with this package:

```dart
final check = result.verify();
check.verified;       // true only for an unaltered, NIDP-issued card
check.reason?.code;   // SIGNATURE_MISSING, MALFORMED_JWS, UNSUPPORTED_ALGORITHM,
                      // UNSUPPORTED_VERSION or INVALID_SIGNATURE
```

Parsing alone never verifies: `result.signature` only says whether a JWS was
present. NIDP publishes no key endpoint, so the key is pinned. If NIDP rotates
it before this package is updated, pass the new key:
`result.verify(publicKeyPem: newKeyPem)`.

## On a server

Have the app send the **raw QR text**, not the parsed fields, and decode and
verify again on the server, where the client cannot tamper with the result:

```dart
// package:shelf handler
Future<Response> verifyCard(Request request) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, Object?>;
  final result = decodePayload(body['qr'] as String);
  if (result is! FaydaSuccess || !result.verify().verified) {
    return Response(422, body: 'Card could not be verified');
  }
  final fields = result.fields;
  // fields.fan, fields.fullName, fields.dateOfBirth ...
  return Response.ok(jsonEncode(fields.toJson()));
}
```

`FaydaResult.fromJson` trusts its input, so never use it to accept identity
data from a client.

## Command line

```bash
dart pub global activate fayda_decoder

fayda_decoder card.jpg                 # summary
fayda_decoder card.jpg --json          # full result + verification
fayda_decoder card.jpg --face face.webp
fayda_decoder --text "$QR_TEXT" --strict   # exit code 3 unless signed by NIDP
pbpaste | fayda_decoder --text -       # read QR text from stdin
```

Inside a project that depends on the package: `dart run fayda_decoder card.jpg`.
Exit codes: 0 decoded, 1 no Fayda QR, 2 usage or I/O error, 3 not verified
(with `--strict`).

## Testing your app

`package:fayda_decoder/testing.dart` builds synthetic cards signed with a
published test key, so you can cover real flows without a real card:

```dart
import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/testing.dart';

test('accepts a verified card', () {
  final payload = buildTestPayload(
    fullName: 'Hana Girma Wolde',
    gender: FaydaGender.female,
    dateOfBirth: DateTime(1999, 7, 21),
  );
  final result = decodePayload(payload) as FaydaSuccess;
  expect(result.verify(publicKeyPem: faydaTestPublicKeyPem).verified, isTrue);
});

test('rejects a forged card', () {
  // Signed with the test key, so NIDP's key rejects it.
  final result = decodePayload(buildTestPayload()) as FaydaSuccess;
  expect(result.verify().verified, isFalse);
});

test('photo flow', () async {
  final png = buildTestQrPng(buildTestPayload()); // e.g. from a mocked picker
  expect(await decodeImage(png), isA<FaydaSuccess>());
});
```

`overrides` produces malformed cards (`overrides: {'D': '1990/02/31'}`),
`signed: false` drops the signature, `buildTestQrImage` returns raw pixels for
camera-frame code. Never accept `faydaTestPublicKeyPem` in production: its
private key ships with the package.

## Errors

| Code | Meaning | Tell the user |
| --- | --- | --- |
| `NO_QR_FOUND` | No QR in the image | Retake the photo |
| `QR_UNREADABLE` | A QR was found but could not be decoded | Move closer, add light |
| `NOT_FAYDA` | The QR is not a Fayda payload | Wrong side of the card, or another document |
| `UNSUPPORTED_VERSION` | Fayda-shaped, unknown version (`raw.map` is still returned) | Update the app |

Partial success is success: one malformed field (say, an impossible date of
birth) becomes `null` and the rest still parse.

## Using another QR engine

The built-in `ZxingQrScanner` is pure Dart. To plug in zxing-cpp
(`flutter_zxing`), ML Kit or anything else while keeping this package's
preprocessing and parsing, implement `QrScanner`:

```dart
final class MyScanner implements QrScanner {
  @override
  Future<QrScan> scan(RgbaImage image) async {
    final texts = await myNativeDecode(image.data, image.width, image.height);
    return texts.isEmpty ? const QrScanNone() : QrScanDecoded(texts);
  }
}

final result = await decodeImage(bytes, scanner: MyScanner());
```

## Privacy

- No network I/O. Nothing leaves the device.
- Error messages never echo the payload, and `toString()` on results is
  redacted, so accidental logging does not leak personal data.
- The face is only returned with `includeFace: true`.

## Limitations

- The default scanner reports at most one QR per image. If a photo has
  another QR that it finds first, crop to the card or plug in a scanner that
  returns several.
- `zxing2` 0.2.x garbles non-ASCII text in byte segments. This package
  repairs it from the raw bytes, so Ethiopic names decode correctly.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The one hard rule: never commit or
share a real person's card data.

## License

MIT. See [LICENSE](LICENSE). Based on
[fayda-decoder](https://github.com/Alpha-Mintamir/fayda-decoder) by
Alpha-Mintamir and contributors.
