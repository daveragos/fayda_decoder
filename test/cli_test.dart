@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/src/cli/cli.dart';
import 'package:fayda_decoder/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String keyPath;
  final payload = buildTestPayload();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('fayda_cli_');
    keyPath = '${temp.path}/test_key.pem';
    File(keyPath).writeAsStringSync(faydaTestPublicKeyPem);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(int, String, String)> run(List<String> args,
      {String stdinText = ''}) async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runCli(args,
        out: out, err: err, readStdin: () async => stdinText);
    return (code, out.toString(), err.toString());
  }

  test('--help and --version', () async {
    expect((await run(['--help'])).$2, contains('Usage:'));
    expect((await run(['--version'])).$2, contains(libraryVersion));
  });

  test('usage errors exit with 2', () async {
    for (final args in [
      <String>[],
      ['--text'],
      ['--bogus'],
      ['a.png', 'b.png'],
      ['a.png', '--text', 'x'],
    ]) {
      final (code, _, err) = await run(args);
      expect(code, 2, reason: '$args');
      expect(err, contains('fayda_decoder:'));
    }
  });

  test('decodes QR text and prints a summary', () async {
    final (code, out, _) = await run(['--text', payload, '--key', keyPath]);
    expect(code, 0);
    expect(out, contains('Abebe Kebede Alemu'));
    expect(out, contains('6140 1234 1234 1234'));
    expect(out, contains('valid (your key)'));
  });

  test('reads QR text from stdin', () async {
    final (code, out, _) = await run(['--text=-'], stdinText: '$payload\n');
    expect(code, 0);
    expect(out, contains('Abebe Kebede Alemu'));
  });

  test('--json prints the result and the verification', () async {
    final (code, out, _) =
        await run(['--text', payload, '--json', '--key=$keyPath']);
    expect(code, 0);
    final json = jsonDecode(out) as Map<String, Object?>;
    expect(FaydaResult.fromJson(json), decodePayload(payload));
    expect((json['verification'] as Map)['verified'], isTrue);
  });

  test('--strict exits with 3 when the signature does not verify', () async {
    // The test payload is not signed by NIDP.
    expect((await run(['--text', payload, '--strict'])).$1, 3);
    expect(
        (await run(['--text', payload, '--strict', '--key', keyPath])).$1, 0);
  });

  test('decodes an image and saves the face', () async {
    final image = File('${temp.path}/card.png')
      ..writeAsBytesSync(buildTestQrPng(payload));
    final facePath = '${temp.path}/face.webp';
    final (code, out, _) = await run([image.path, '--face', facePath]);
    expect(code, 0);
    expect(out, contains('saved to $facePath'));
    expect(File(facePath).readAsBytesSync(), faydaTestFace);
  });

  test('non-Fayda input exits with 1', () async {
    final (code, _, err) = await run(['--text', 'https://example.com']);
    expect(code, 1);
    expect(err, contains('NOT_FAYDA'));
  });

  test('unreadable files exit with 2', () async {
    expect((await run(['${temp.path}/missing.png'])).$1, 2);
    final junk = File('${temp.path}/junk.png')..writeAsBytesSync([1, 2, 3]);
    final (code, _, err) = await run([junk.path]);
    expect(code, 2);
    expect(err, contains('not a readable image'));
  });

  test('the executable runs', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/fayda_decoder.dart', '--version']);
    expect(result.exitCode, 0);
    expect(result.stdout, contains(libraryVersion));
  });
}
