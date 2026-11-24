import 'dart:convert';

import 'package:fayda_decoder/fayda_decoder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a decoded card, or why decoding failed.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result, this.publicKeyPem});

  final FaydaResult result;

  /// Verify with this key instead of NIDP's (used by the sample card).
  final String? publicKeyPem;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return switch (result) {
      FaydaSuccess() => _CardView(
        result: result,
        verification: result.verify(publicKeyPem: publicKeyPem),
      ),
      FaydaFailure(:final error) => _ErrorView(error: error),
    };
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.result, required this.verification});

  final FaydaSuccess result;
  final SignatureVerification verification;

  @override
  Widget build(BuildContext context) {
    final fields = result.fields;
    final theme = Theme.of(context);
    final face = fields.face;
    final age = fields.age;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fayda ID'),
        actions: [
          IconButton(
            tooltip: 'Copy JSON',
            icon: const Icon(Icons.data_object),
            onPressed: () {
              final json = const JsonEncoder.withIndent('  ').convert({
                ...result.toJson(),
                'verification': verification.toJson(),
              });
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Result copied as JSON')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: face == null
                  ? const SizedBox.square(
                      dimension: 112,
                      child: Icon(Icons.person_outline, size: 64),
                    )
                  : Image.memory(
                      face.bytes,
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, size: 64),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fields.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Center(child: SignatureBadge(verification: verification)),
          const SizedBox(height: 24),
          _Field(
            label: 'FAN',
            value: fields.formattedFan,
            copyValue: fields.fan,
          ),
          _Field(
            label: 'Gender',
            value: switch (fields.gender) {
              FaydaGender.male => 'Male',
              FaydaGender.female => 'Female',
              null => null,
            },
          ),
          _Field(
            label: 'Date of birth',
            copyValue: fields.dateOfBirth,
            value: fields.dateOfBirth == null
                ? null
                : '${fields.dateOfBirth}${age == null ? '' : '  (age $age)'}',
          ),
          _Field(label: 'Card format', value: 'V${result.payloadVersion}'),
        ],
      ),
    );
  }
}

/// Green when NIDP (or the given key) signed the card, amber otherwise.
class SignatureBadge extends StatelessWidget {
  const SignatureBadge({super.key, required this.verification});

  final SignatureVerification verification;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verified = verification.verified;
    final label = verified
        ? (verification.keySource == KeySource.bundledNidpV4
              ? 'Signed by NIDP'
              : 'Signature verified (test key)')
        : switch (verification.reason) {
            VerificationFailureReason.signatureMissing => 'No signature',
            VerificationFailureReason.invalidSignature =>
              'Signature does not match',
            _ => 'Signature not verified',
          };
    return Chip(
      avatar: Icon(
        verified ? Icons.verified : Icons.gpp_maybe_outlined,
        color: verified ? Colors.green : scheme.error,
      ),
      label: Text(label),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.copyValue});

  final String label;
  final String? value;
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    final copy = copyValue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value ?? 'Not readable on this card'),
      trailing: copy == null
          ? null
          : IconButton(
              tooltip: 'Copy $label',
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () => Clipboard.setData(ClipboardData(text: copy)),
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final FaydaError error;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (error.code) {
      FaydaErrorCode.noQrFound => (Icons.qr_code_2, 'No QR code found'),
      FaydaErrorCode.qrUnreadable => (
        Icons.blur_on,
        'Could not read the QR code',
      ),
      FaydaErrorCode.notFayda => (Icons.badge_outlined, 'Not a Fayda ID'),
      FaydaErrorCode.unsupportedVersion => (
        Icons.update,
        'Unsupported card version',
      ),
    };
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Fayda ID')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
