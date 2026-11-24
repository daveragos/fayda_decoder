import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/testing.dart';
import 'package:fayda_decoder_example/main.dart';
import 'package:fayda_decoder_example/src/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: child);

  testWidgets('home offers camera, photo and sample', (tester) async {
    await tester.pumpWidget(const FaydaExampleApp());
    expect(find.text('Scan with camera'), findsOneWidget);
    expect(find.text('Pick a photo of the card'), findsOneWidget);
    expect(find.text('Try a sample card'), findsOneWidget);
  });

  testWidgets('shows a verified synthetic card', (tester) async {
    final result = decodePayload(
      buildTestPayload(fullName: 'Hana Girma Wolde'),
      includeFace: true,
    );
    await tester.pumpWidget(
      host(ResultScreen(result: result, publicKeyPem: faydaTestPublicKeyPem)),
    );
    expect(find.text('Hana Girma Wolde'), findsOneWidget);
    expect(find.text('6140 1234 1234 1234'), findsOneWidget);
    expect(find.text('Signature verified (test key)'), findsOneWidget);
  });

  testWidgets('flags a card NIDP did not sign', (tester) async {
    // Signed with the test key, verified against the real NIDP key.
    final result = decodePayload(buildTestPayload());
    await tester.pumpWidget(host(ResultScreen(result: result)));
    expect(find.text('Signature does not match'), findsOneWidget);
  });

  testWidgets('explains failures', (tester) async {
    await tester.pumpWidget(
      host(ResultScreen(result: decodePayload('https://example.com'))),
    );
    expect(find.text('Not a Fayda ID'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
