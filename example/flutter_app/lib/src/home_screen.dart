import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:fayda_decoder/testing.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_decoder.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<FaydaResult>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (result != null && mounted) _show(result);
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await decodePhoto(file);
      if (mounted) _show(result);
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file is not a readable image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSample() {
    // A synthetic card signed with the package's public test key.
    _show(
      decodePayload(buildTestPayload(), includeFace: true),
      publicKeyPem: faydaTestPublicKeyPem,
    );
  }

  void _show(FaydaResult result, {String? publicKeyPem}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ResultScreen(result: result, publicKeyPem: publicKeyPem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Fayda Decoder')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Read the QR code on the back of an Ethiopian Fayda ID card '
                'and check its signature. Everything stays on this device.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan with camera'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pick a photo of the card'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _busy ? null : _showSample,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Try a sample card'),
              ),
              if (_busy) ...[
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                const Text('Reading the card...', textAlign: TextAlign.center),
              ],
              const Spacer(),
              Text(
                'Community project. Not affiliated with NIDP.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
