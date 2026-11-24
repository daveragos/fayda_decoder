import 'dart:convert';

import 'base64.dart';
import 'result.dart';
import 'rsa.dart';

/// FaydaEncode V4 RS256 public key.
///
/// Provenance (from the upstream fayda-decoder project): recovered from the
/// official NIDP offline scanner at https://id.et/scanId, which selects this
/// key when the payload version is 4. It verifies real V4 cards.
///
/// SPKI SHA-256 fingerprint:
/// `803dcd26057edc1423a5b9655f03c945b84a146be28caa754bc460a3fea6624a`
///
/// NIDP does not publish a JWKS or rotation endpoint for the card-signing
/// key, so this is pinned. If NIDP rotates it, verification of newer cards
/// fails until this constant is updated, or until callers pass the new key
/// through `verifySignature(publicKeyPem: ...)`.
const faydaV4PublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxMWfApFZBq/qIotUjrkY
bdyXQcHOUgZsqZy3QUcXr50t+DfwYKkSfMnTZFHekptAWA4HM5upav6xqFuP+3Pi
KmajY2Imkl60bF4Bt9qcch74jPSObH/1CE0xs75dqLb+CfoTG1+i4n3Fz5cN9Mxp
EGE7pmvIdYtaAUCoKA/cjQ5QY426ttp4EQcnh5vmyr1e7ur9LjqVVsurfefxlsR+
sRfB2RFuaEGrLO/75UeUSY2x1nTHzOvycWYaCve1YfunHkXA8JvUy73+b33ixIgw
QuqUkOuyKhytFr5l6N1gfjTvOOysclCH5o8jy7KyzgyK17kHXPAaKuxYXH9pGtAF
0wIDAQAB
-----END PUBLIC KEY-----''';

final _bundledKey = RsaPublicKey.fromPem(faydaV4PublicKeyPem);

/// Why a signature did not verify.
enum VerificationFailureReason {
  /// The payload carried no JWS.
  signatureMissing('SIGNATURE_MISSING'),

  /// The JWS is not a compact detached `header..signature` with a JSON
  /// header.
  malformedJws('MALFORMED_JWS'),

  /// The JWS header's `alg` is not `RS256`.
  unsupportedAlgorithm('UNSUPPORTED_ALGORITHM'),

  /// No bundled key for this payload version, and no caller key was given.
  unsupportedVersion('UNSUPPORTED_VERSION'),

  /// The signature does not match the payload under the key, or the key or
  /// signature bytes could not be read.
  invalidSignature('INVALID_SIGNATURE');

  const VerificationFailureReason(this.code);

  /// The wire code shared by every port.
  final String code;
}

/// Which public key a verification used.
enum KeySource {
  /// The NIDP V4 key bundled with this package ([faydaV4PublicKeyPem]).
  bundledNidpV4('bundled_nidp_v4'),

  /// A key the caller passed in.
  caller('caller');

  const KeySource(this.code);

  /// The wire code shared by every port.
  final String code;
}

/// The outcome of [verifySignature].
final class SignatureVerification {
  /// Creates a verification outcome.
  const SignatureVerification({
    required this.verified,
    required this.algorithm,
    required this.payloadVersion,
    required this.keySource,
    required this.reason,
  });

  /// True only when the signature is valid for the payload under the key.
  final bool verified;

  /// `RS256` once the header has been read, otherwise null.
  final String? algorithm;

  /// The payload version that was verified.
  final String payloadVersion;

  /// Which key was used.
  final KeySource keySource;

  /// Null when [verified]; otherwise why not.
  final VerificationFailureReason? reason;

  /// snake_case JSON matching the other ports.
  Map<String, Object?> toJson() => {
        'verified': verified,
        'algorithm': algorithm,
        'payload_version': payloadVersion,
        'key_source': keySource.code,
        'reason': reason?.code,
      };

  @override
  String toString() => verified
      ? 'SignatureVerification(verified, ${keySource.code})'
      : 'SignatureVerification(${reason?.code}, ${keySource.code})';
}

/// Verifies the detached JWS carried by a parsed Fayda QR.
///
/// Fayda V4 uses compact JWS serialization with an empty payload segment:
/// `header..signature`. The external payload is every character before the
/// last `:SIGN:` in the QR text. RS256 signs:
///
/// `base64url(header) + "." + base64url(UTF-8(external payload))`
///
/// By default this uses the bundled NIDP V4 key. Pass [publicKeyPem] (a PEM
/// SubjectPublicKeyInfo) to override it, for key rotation or tests; the
/// caller is then responsible for trusting that key.
///
/// Runs fully offline and synchronously.
SignatureVerification verifySignature(
  FaydaSuccess result, {
  String? publicKeyPem,
}) {
  final keySource =
      publicKeyPem != null ? KeySource.caller : KeySource.bundledNidpV4;

  SignatureVerification failure(
    VerificationFailureReason reason, {
    String? algorithm,
  }) =>
      SignatureVerification(
        verified: false,
        algorithm: algorithm,
        payloadVersion: result.payloadVersion,
        keySource: keySource,
        reason: reason,
      );

  final jws = result.signature.jws;
  if (jws == null) return failure(VerificationFailureReason.signatureMissing);
  if (result.payloadVersion != '4' && publicKeyPem == null) {
    return failure(VerificationFailureReason.unsupportedVersion);
  }

  final parts = jws.split('.');
  if (parts.length != 3 ||
      parts[0].isEmpty ||
      parts[1].isNotEmpty ||
      parts[2].isEmpty) {
    return failure(VerificationFailureReason.malformedJws);
  }

  final Object? header;
  try {
    header = jsonDecode(utf8.decode(base64UrlDecodeLenient(parts[0])));
  } on FormatException {
    return failure(VerificationFailureReason.malformedJws);
  }
  if (header is! Map || header['alg'] != 'RS256') {
    return failure(VerificationFailureReason.unsupportedAlgorithm);
  }

  const algorithm = 'RS256';
  final markerIndex = result.raw.payload.lastIndexOf(':SIGN:');
  if (markerIndex == -1) {
    return failure(VerificationFailureReason.malformedJws,
        algorithm: algorithm);
  }
  final detachedPayload = result.raw.payload.substring(0, markerIndex);
  final signingInput =
      '${parts[0]}.${base64UrlEncodeNoPad(utf8.encode(detachedPayload))}';

  final bool verified;
  try {
    final key =
        publicKeyPem == null ? _bundledKey : RsaPublicKey.fromPem(publicKeyPem);
    verified = rsaPkcs1Sha256Verify(
      key,
      utf8.encode(signingInput),
      base64UrlDecodeLenient(parts[2]),
    );
  } on FormatException {
    return failure(
      VerificationFailureReason.invalidSignature,
      algorithm: algorithm,
    );
  }

  return SignatureVerification(
    verified: verified,
    algorithm: algorithm,
    payloadVersion: result.payloadVersion,
    keySource: keySource,
    reason: verified ? null : VerificationFailureReason.invalidSignature,
  );
}

/// Method-style access to [verifySignature].
extension FaydaSuccessVerification on FaydaSuccess {
  /// Same as `verifySignature(this, publicKeyPem: publicKeyPem)`.
  ///
  /// ```dart
  /// if (decodePayload(text) case final FaydaSuccess card
  ///     when card.verify().verified) {
  ///   // issued by NIDP, unaltered
  /// }
  /// ```
  SignatureVerification verify({String? publicKeyPem}) =>
      verifySignature(this, publicKeyPem: publicKeyPem);
}
