# Contributing

Thanks for helping. A few rules keep this project safe and the ports in
step.

## Privacy first

Never commit, paste or attach a real person's card: no QR text, photo, face
image, FAN or name. Use `buildTestPayload` and `buildTestQrPng` from
`package:fayda_decoder/testing.dart` for fixtures. Keep any real samples
you test with locally, outside the repository.

## Development

```bash
dart pub get
dart format .
dart analyze --fatal-infos
dart test                  # VM
dart test --platform chrome  # browser subset (test/platform_test.dart, test/testing_test.dart)
```

The Flutter example has its own checks:

```bash
cd example/flutter_app
flutter analyze && flutter test
```

Parsing behaviour follows the upstream
[spec](https://github.com/Alpha-Mintamir/fayda-decoder/blob/main/SPEC.md).
`test/fixtures/vectors.json` is a copy of its shared vectors; update it from
upstream rather than editing it by hand.

## Releasing

1. Bump `version` in `pubspec.yaml` and `libraryVersion` in
   `lib/src/version.dart` (a test checks they match), and add a
   `CHANGELOG.md` entry.
2. Commit, then tag and push: `git tag v0.1.1 && git push origin v0.1.1`.
3. `.github/workflows/publish.yml` publishes the tag to pub.dev.

The first release has to be published by hand with `dart pub publish`.
After that, enable automated publishing on pub.dev (package Admin tab,
GitHub Actions, tag pattern `v{{version}}`).
