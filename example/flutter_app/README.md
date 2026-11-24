# fayda_decoder Flutter example

A small app showing the three ways to read a Fayda ID card with
`fayda_decoder`:

- **Scan with camera**: `mobile_scanner` reads the QR, `isFaydaPayload`
  filters out unrelated codes, and `decodePayload` parses the text.
- **Pick a photo**: the platform engine (ML Kit or Vision) is tried first,
  then `decodeImageInBackground` runs the package's own pipeline off the UI
  isolate. See `lib/src/photo_decoder.dart`.
- **Try a sample card**: a synthetic card from
  `package:fayda_decoder/testing.dart`, handy on simulators without a
  camera.

The result screen shows the face, fields and a signature badge from
`verifySignature`, and can copy the result as JSON.

```bash
flutter run
flutter test
```

iOS needs the camera and photo-library usage descriptions already set in
`ios/Runner/Info.plist`. Android needs no extra setup.
