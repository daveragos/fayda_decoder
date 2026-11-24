## 0.1.0

- Initial Dart port of fayda-decoder.
- `decodePayload`: parse Fayda V4 QR text into typed results and
  schema-compatible JSON. Passes the shared test vectors.
- `verifySignature`: verify the detached RS256 JWS against the bundled NIDP V4
  key, or a caller-supplied key.
- `decodeImage` / `decodeImageData`: decode card photos with the
  grayscale-and-upscale retry pipeline, using a pure-Dart scanner by default
  and any `QrScanner` you plug in.
