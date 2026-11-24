// Decodes a Fayda ID QR and checks its signature.
//
//   dart run example/fayda_decoder_example.dart              # synthetic payload
//   dart run example/fayda_decoder_example.dart card.jpg     # photo of a card
//
// Everything runs offline; nothing leaves the machine.
import 'dart:convert';
import 'dart:io';

import 'package:fayda_decoder/fayda_decoder.dart';

// Fully synthetic payload (fake name, FAN, DOB and an 8x8 WebP "face").
const syntheticPayload =
    'UklGRjQAAABXRUJQVlA4ICgAAACQAQCdASoIAAgAAUAmJYgCdLoAA5gA_ufkv43m81rW_tTYqp5OAAAA'
    ':DLT:Abebe Kebede Alemu:V:4:G:M:A:6140123412341234:D:2002/11/26'
    ':SIGN:eyJhbGciOiJSUzI1NiIsImtpZCI6ImZha2UifQ.eyJzeW50aGV0aWMiOnRydWV9.ZmFrZS1zaWduYXR1cmU';

Future<void> main(List<String> args) async {
  // From a camera scanner (e.g. mobile_scanner) you already have the text:
  //   final result = decodePayload(barcode.rawValue!);
  // From a photo, decode the pixels too:
  final result = args.isEmpty
      ? decodePayload(syntheticPayload)
      : await decodeImage(File(args.first).readAsBytesSync());

  switch (result) {
    case FaydaSuccess(:final fields):
      print('Name:          ${fields.fullName}');
      print('Gender:        ${fields.gender?.code}');
      print('FAN:           ${fields.fan}');
      print('Date of birth: ${fields.dateOfBirth}');

      // Real cards verify against the bundled NIDP key. The synthetic
      // payload carries a fake signature, so it reports MALFORMED_JWS.
      final verification = verifySignature(result);
      final status = verification.verified
          ? 'valid (NIDP V4 key)'
          : 'not verified: ${verification.reason?.code}';
      print('Signature:     $status');

    case FaydaFailure(:final error):
      print('Could not decode: ${error.code.code}');
      print(error.message);
      exitCode = 1;
  }

  // The same result as JSON, matching the shared schema used by every port.
  print(const JsonEncoder.withIndent('  ').convert(result.toJson()));
}
