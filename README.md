# fayda_decoder

Offline decoder and signature verifier for the QR code on the Ethiopian
**Fayda** national ID card. It turns the QR into typed Dart objects (or JSON)
and checks the card's digital signature, entirely on-device, with no network
calls and no API key.

This is the Dart port of
[fayda-decoder](https://github.com/Alpha-Mintamir/fayda-decoder). It follows
the same [spec](https://github.com/Alpha-Mintamir/fayda-decoder/blob/main/SPEC.md)
and passes the same shared test vectors as the TypeScript package.

> Community project. **Not affiliated with or endorsed by** Ethiopia's
> National ID Program (NIDP). "Fayda" is NIDP's brand.

- Pure Dart: works in Flutter (Android, iOS, desktop, web) and on the server.
- Parses name, gender, FAN (card number), date of birth and the face
  thumbnail.
- Verifies the RS256 signature against NIDP's V4 public key.
- Decodes photos of printed cards (glare, low resolution, chat-app
  recompression) with an upscale-and-retry pipeline.

## Install

```bash
dart pub add fayda_decoder
```

## Usage

### You already have the QR text

This is the common Flutter case: a camera scanner such as
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner) gives you the
text, and you only need to parse it.

```dart
import 'package:fayda_decoder/fayda_decoder.dart';

final result = decodePayload(barcode.rawValue!);

switch (result) {
  case FaydaSuccess(:final fields):
    print(fields.fullName);     // Abebe Kebede Alemu
    print(fields.gender?.code); // M
    print(fields.fan);          // 6140123412341234
    print(fields.dateOfBirth);  // 2002-11-26 (ISO, Gregorian)
  case FaydaFailure(:final error):
    print(error.code.code);     // NOT_FAYDA, UNSUPPORTED_VERSION, ...
    print(error.message);       // safe to show to users
}
```

### You have a photo

Pass encoded image bytes (JPEG, PNG, WebP, ...), for example from
`image_picker`. Decoding is CPU-heavy pure Dart, so in Flutter run it off the
UI thread:

```dart
import 'dart:isolate';

final bytes = await pickedFile.readAsBytes();
final result = await Isolate.run(() => decodeImage(bytes));
```

If you already have raw RGBA pixels (a camera frame, a canvas), use
`decodeImageData(RgbaImage(data: rgba, width: w, height: h))`.

`decodeImage` throws a `FormatException` if the bytes are not a readable
image.

### Verify the signature

Every card carries a detached RS256 JWS over the rest of the QR text. Check it
against the bundled NIDP V4 key:

```dart
if (result case final FaydaSuccess success) {
  final check = verifySignature(success);
  if (check.verified) {
    // The fields were issued by NIDP and have not been altered.
  } else {
    print(check.reason?.code); // INVALID_SIGNATURE, MALFORMED_JWS, ...
  }
}
```

Parsing never verifies on its own: `result.signature.toJson()['verified']` is
always `null` until you call `verifySignature`. If NIDP rotates its key, pass
the new one with `verifySignature(result, publicKeyPem: newKey)`.

### The face thumbnail

The face is biometric-adjacent data, so it is only returned when you ask for
it:

```dart
final result = decodePayload(text, includeFace: true);
if (result case FaydaSuccess(fields: FaydaFields(:final face?))) {
  Image.memory(face.bytes); // WebP; Flutter renders it directly
}
```

### JSON

`result.toJson()` produces the same shape as every other port (see
[`result.schema.json`](https://github.com/Alpha-Mintamir/fayda-decoder/blob/main/schema/result.schema.json)):

```json
{
  "ok": true,
  "document": "fayda",
  "payload_version": "4",
  "fields": {
    "full_name": "Abebe Kebede Alemu",
    "gender": "M",
    "fan": "6140123412341234",
    "date_of_birth": "2002-11-26",
    "face": null
  },
  "signature": { "present": true, "verified": null, "jws": "..." },
  "raw": { "payload": "...", "map": { "V": "4", "G": "M", "A": "...", "D": "..." } },
  "meta": { "library": "fayda_decoder", "version": "0.1.0" }
}
```

## Errors

| Code | Meaning | What to tell the user |
| --- | --- | --- |
| `NO_QR_FOUND` | No QR in the image | Retake the photo |
| `QR_UNREADABLE` | A QR was found but could not be decoded | Get closer, use more light |
| `NOT_FAYDA` | The QR is not a Fayda payload | Wrong side of the card, or a different document |
| `UNSUPPORTED_VERSION` | Fayda-shaped, unknown version (`raw.map` is still returned) | Update the app |

Partial success is success: if one field is malformed (say, an impossible
date of birth), that field is `null` and the rest still parse.

## Using another QR engine

The default engine, `ZxingQrScanner`, is pure Dart (built on `zxing2`). It
handles clean and moderately degraded photos, but native engines are
stronger on hard ones. To use zxing-cpp (through `flutter_zxing`) or ML Kit
while keeping this package's preprocessing and parsing, implement
`QrScanner`:

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

- No network I/O, ever. Everything runs on the device.
- Error messages never echo the payload, and `toString()` on results, fields
  and raw data is redacted, so accidental logging does not leak personal
  data.
- The face is only returned with `includeFace: true`.

## Limitations

- The default scanner reports at most one QR per image. If a photo contains
  another QR that it finds first, crop to the card or plug in a scanner that
  returns several (`QrScanDecoded` takes a list).
- `zxing2` 0.2.x garbles non-ASCII text in QR byte segments. This package
  repairs that from the raw segment bytes, so Ethiopic names decode
  correctly.
- The signing key is pinned. NIDP publishes no key endpoint, so a key
  rotation needs a package update or a `publicKeyPem` override.

## Development

```bash
dart test
dart analyze
```

`test/fixtures/vectors.json` is a copy of the upstream shared vectors. When
this package lives at `packages/dart` in the upstream monorepo, the tests read
`../../testdata/vectors.json` instead, so the ports cannot drift apart.
`tool/generate_signed_fixture.sh` regenerates the synthetic signed payload
used by the signature tests. All test data is synthetic. Never commit a real
person's card, photo or QR text.

## License

MIT. See [LICENSE](LICENSE). Based on
[fayda-decoder](https://github.com/Alpha-Mintamir/fayda-decoder) by
Alpha-Mintamir and contributors.
