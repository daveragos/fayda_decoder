import 'dart:convert';
import 'dart:io';

import '../../fayda_decoder.dart';

/// Help text for the `fayda_decoder` executable.
const cliUsage = '''
Decode and verify the QR code on an Ethiopian Fayda ID card, offline.

Usage:
  fayda_decoder <image>            Decode a photo or screenshot of the card
  fayda_decoder --text <payload>   Decode QR text ("-" reads it from stdin)

Options:
  --json          Print the full result (and verification) as JSON
  --face <file>   Save the face thumbnail (WebP) to <file>
  --key <file>    Verify with this PEM public key instead of NIDP's
  --strict        Exit with code 3 unless the signature verifies
  -h, --help      Show this help
  --version       Print the version

Exit codes: 0 decoded, 1 no Fayda QR decoded, 2 usage or I/O error,
3 signature not verified (with --strict).''';

/// Runs the command line tool and returns its exit code.
///
/// [out], [err] and [readStdin] default to the process streams; tests pass
/// their own.
Future<int> runCli(
  List<String> args, {
  StringSink? out,
  StringSink? err,
  Future<String> Function()? readStdin,
}) async {
  out ??= stdout;
  err ??= stderr;
  readStdin ??= () => stdin.transform(utf8.decoder).join();

  int usageError(String message) {
    err!
      ..writeln('fayda_decoder: $message')
      ..writeln('Run "fayda_decoder --help" for usage.');
    return 2;
  }

  String? text, imagePath, facePath, keyPath;
  var json = false, strict = false;

  for (var i = 0; i < args.length; i++) {
    var arg = args[i];
    String? inlineValue;
    final eq = arg.indexOf('=');
    if (arg.startsWith('--') && eq != -1) {
      inlineValue = arg.substring(eq + 1);
      arg = arg.substring(0, eq);
    }
    switch (arg) {
      case '-h' || '--help':
        out.writeln(cliUsage);
        return 0;
      case '--version':
        out.writeln('$libraryName $libraryVersion');
        return 0;
      case '--json':
        json = true;
      case '--strict':
        strict = true;
      case '--text' || '--face' || '--key':
        final value = inlineValue ?? (i + 1 < args.length ? args[++i] : null);
        if (value == null) return usageError('$arg needs a value');
        switch (arg) {
          case '--text':
            text = value;
          case '--face':
            facePath = value;
          default:
            keyPath = value;
        }
      default:
        if (arg.startsWith('-') && arg != '-') {
          return usageError('unknown option $arg');
        }
        if (imagePath != null) return usageError('pass one image at a time');
        imagePath = arg;
    }
  }
  if ((text == null) == (imagePath == null)) {
    return usageError('pass an image file or --text');
  }

  final FaydaResult result;
  String? keyPem;
  try {
    if (keyPath != null) keyPem = await File(keyPath).readAsString();
    if (text != null) {
      final payload = text == '-' ? await readStdin() : text;
      result = decodePayload(payload, includeFace: facePath != null);
    } else {
      final bytes = await File(imagePath!).readAsBytes();
      result = await decodeImage(bytes, includeFace: facePath != null);
    }
  } on FileSystemException catch (e) {
    err.writeln('fayda_decoder: cannot read ${e.path}: '
        '${e.osError?.message ?? e.message}');
    return 2;
  } on FormatException {
    err.writeln('fayda_decoder: $imagePath is not a readable image');
    return 2;
  }

  switch (result) {
    case FaydaFailure(:final error):
      if (json) {
        out.writeln(_prettyJson(result.toJson()));
      } else {
        err.writeln('${error.code.code}: ${error.message}');
      }
      return 1;

    case FaydaSuccess(:final fields):
      final verification = result.verify(publicKeyPem: keyPem);
      String? faceNote;
      if (facePath != null) {
        final face = fields.face;
        if (face == null) {
          faceNote = 'not present in this QR';
        } else {
          try {
            await File(facePath).writeAsBytes(face.bytes);
            faceNote = 'saved to $facePath';
          } on FileSystemException catch (e) {
            err.writeln('fayda_decoder: cannot write ${e.path}: '
                '${e.osError?.message ?? e.message}');
            return 2;
          }
        }
      }

      if (json) {
        out.writeln(_prettyJson({
          ...result.toJson(),
          'verification': verification.toJson(),
        }));
      } else {
        final age = fields.age;
        final signature = verification.verified
            ? 'valid (${verification.keySource == KeySource.caller ? 'your key' : 'NIDP V4 key'})'
            : 'not verified (${verification.reason?.code})';
        out
          ..writeln('Name           ${fields.fullName}')
          ..writeln('Gender         ${fields.gender?.code ?? '-'}')
          ..writeln('FAN            ${fields.formattedFan ?? '-'}')
          ..writeln('Date of birth  ${fields.dateOfBirth ?? '-'}'
              '${age == null ? '' : ' (age $age)'}')
          ..writeln('Signature      $signature');
        if (faceNote != null) out.writeln('Face           $faceNote');
      }
      return strict && !verification.verified ? 3 : 0;
  }
}

String _prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
