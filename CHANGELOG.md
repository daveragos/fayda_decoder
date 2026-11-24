## 0.1.1

- Read the FAN on cards that store it in space-separated groups
  (`9999  9999  9999  9999`). Those cards decoded and verified, but
  `fields.fan` came back `null`. `fan` is now digits only; `raw.map` keeps
  the original text.

## 0.1.0

First release.

### Decoding

- `decodePayload` parses Fayda V4 QR text into a sealed `FaydaResult` with
  typed fields; one malformed field becomes `null` instead of failing the
  parse. Passes the shared upstream test vectors.
- `isFaydaPayload` cheaply filters barcode-scanner callbacks.
- `decodeImage` and `decodeImageData` decode photos with a grayscale and
  upscale retry pipeline; `decodeImageInBackground` and
  `decodeImageDataInBackground` run it on an isolate (inline on the web).
- `RgbaImage.fromLuminance` and `RgbaImage.fromBgra` accept `camera` package
  frames from Android and iOS.
- Pluggable `QrScanner`; the default `ZxingQrScanner` is pure Dart and
  repairs zxing2's handling of non-ASCII (Ethiopic) text.

### Verification

- `verifySignature` and `FaydaSuccess.verify()` check the detached RS256 JWS
  against the bundled NIDP V4 key or a key you supply.

### Developer experience

- Value equality and `toJson` / `FaydaResult.fromJson` round-trips.
- `FaydaFields.formattedFan`, `age` and `ageAt`.
- Redacted `toString()` and payload-free error messages.
- `package:fayda_decoder/testing.dart`: `buildTestPayload`, `buildTestQrPng`,
  `buildTestQrImage` and `faydaTestPublicKeyPem` for tests without real
  cards.
- `fayda_decoder` command-line tool.
- Flutter example app with camera, gallery and sample-card flows.
