import 'package:flutter/material.dart';

import 'src/home_screen.dart';

void main() => runApp(const FaydaExampleApp());

/// Demo app: scan or pick a Fayda ID card and show the verified fields.
class FaydaExampleApp extends StatelessWidget {
  const FaydaExampleApp({super.key});

  static const _seed = Color(0xFF0B6E4F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fayda Decoder',
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
