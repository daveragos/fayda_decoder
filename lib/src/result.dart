import 'dart:convert';
import 'dart:typed_data';

/// Why a decode failed. Each code maps to one piece of caller UX.
enum FaydaErrorCode {
  /// No QR code was detected in the image. UX hint: retake the photo.
  noQrFound('NO_QR_FOUND'),

  /// A QR was detected but could not be decoded. UX hint: get closer, use
  /// more light.
  qrUnreadable('QR_UNREADABLE'),

  /// A QR was decoded but the payload is not a Fayda structure. UX hint:
  /// wrong side of the card, or a different document.
  notFayda('NOT_FAYDA'),

  /// Fayda-shaped payload with an unknown version. UX hint: update the
  /// library. The raw field map is still returned.
  unsupportedVersion('UNSUPPORTED_VERSION');

  const FaydaErrorCode(this.code);

  /// The wire code shared by every port, e.g. `NOT_FAYDA`.
  final String code;
}

/// Gender as printed on the card.
enum FaydaGender {
  /// `M`
  male('M'),

  /// `F`
  female('F');

  const FaydaGender(this.code);

  /// The single-letter code used in the payload and in JSON output.
  final String code;
}

/// The face thumbnail carried in the QR. Always a WebP image.
final class FaydaFace {
  /// Wraps already-validated WebP bytes.
  const FaydaFace(this.bytes);

  /// Raw WebP bytes. Flutter can render these with `Image.memory(bytes)`.
  final Uint8List bytes;

  /// Always `webp`.
  String get format => 'webp';

  /// Standard (not url-safe) base64 of [bytes].
  String get base64 => base64Encode(bytes);

  /// `{format, base64}`, matching the shared JSON schema.
  Map<String, Object?> toJson() => {'format': format, 'base64': base64};

  @override
  String toString() => 'FaydaFace(webp, ${bytes.length} bytes)';
}

/// The identity fields parsed from a Fayda QR.
///
/// Each field is validated on its own: a malformed value becomes null rather
/// than failing the whole parse.
final class FaydaFields {
  /// Creates the parsed field set.
  const FaydaFields({
    required this.fullName,
    required this.gender,
    required this.fan,
    required this.dateOfBirth,
    required this.face,
  });

  /// Full name, Latin or Ethiopic script. Never empty.
  final String fullName;

  /// `M` or `F`, or null if the payload carried something else.
  final FaydaGender? gender;

  /// Fayda Account Number (the card number), 10 to 20 digits.
  final String? fan;

  /// Date of birth as ISO `yyyy-mm-dd`, Gregorian calendar.
  final String? dateOfBirth;

  /// Present only when `includeFace: true` was passed and the face decoded to
  /// a valid WebP.
  final FaydaFace? face;

  /// [dateOfBirth] as a UTC midnight [DateTime], or null.
  DateTime? get dateOfBirthUtc {
    final iso = dateOfBirth;
    if (iso == null) return null;
    return DateTime.utc(
      int.parse(iso.substring(0, 4)),
      int.parse(iso.substring(5, 7)),
      int.parse(iso.substring(8, 10)),
    );
  }

  /// [fan] in groups of four, as printed on the card:
  /// `6140 1234 1234 1234`.
  String? get formattedFan {
    final digits = fan;
    if (digits == null) return null;
    final groups = [
      for (var i = 0; i < digits.length; i += 4)
        digits.substring(i, i + 4 > digits.length ? digits.length : i + 4),
    ];
    return groups.join(' ');
  }

  /// Age in completed years on [date], or null without a date of birth.
  ///
  /// For age gates: `fields.ageAt(DateTime.now())! >= 18`.
  int? ageAt(DateTime date) {
    final dob = dateOfBirthUtc;
    if (dob == null) return null;
    var years = date.year - dob.year;
    final hadBirthday = date.month > dob.month ||
        (date.month == dob.month && date.day >= dob.day);
    if (!hadBirthday) years--;
    return years;
  }

  /// Age in completed years today, or null without a date of birth.
  int? get age => ageAt(DateTime.now());

  /// snake_case JSON matching the shared schema.
  Map<String, Object?> toJson() => {
        'full_name': fullName,
        'gender': gender?.code,
        'fan': fan,
        'date_of_birth': dateOfBirth,
        'face': face?.toJson(),
      };

  /// Redacted: never prints personal data, so results are safe to log.
  @override
  String toString() => 'FaydaFields(<redacted>)';
}

/// The signature carried in the QR, as found by the parser.
///
/// Parsing never verifies it; call `verifySignature` for that.
final class FaydaSignature {
  /// Creates a parsed-signature record.
  const FaydaSignature({required this.jws});

  /// The compact detached JWS after `:SIGN:`, or null if empty.
  final String? jws;

  /// Whether the payload carried a signature at all.
  bool get present => jws != null;

  /// `{present, verified: null, jws}`, matching the shared schema.
  Map<String, Object?> toJson() =>
      {'present': present, 'verified': null, 'jws': jws};
}

/// Raw data kept alongside the parsed fields, since the format is unpublished
/// and observational.
final class FaydaRaw {
  /// Creates a raw-data record.
  const FaydaRaw({required this.payload, required this.map});

  /// The trimmed QR text.
  final String payload;

  /// The key/value tail, e.g. `{V: 4, G: M, A: ..., D: ...}`.
  final Map<String, String> map;

  /// `{payload, map}`.
  Map<String, Object?> toJson() => {'payload': payload, 'map': map};

  /// Redacted: never prints personal data.
  @override
  String toString() => 'FaydaRaw(<redacted>)';
}

/// A failure code plus a human-readable message.
///
/// Messages never echo the payload, so they are safe to show and log.
final class FaydaError {
  /// Creates an error.
  const FaydaError(this.code, this.message);

  /// The machine-readable code.
  final FaydaErrorCode code;

  /// A message safe to show to end users. Contains no personal data.
  final String message;

  /// `{code, message}`.
  Map<String, Object?> toJson() => {'code': code.code, 'message': message};

  @override
  String toString() => 'FaydaError(${code.code}): $message';
}

/// The result of decoding a Fayda QR: either [FaydaSuccess] or
/// [FaydaFailure].
///
/// ```dart
/// switch (decodePayload(text)) {
///   case FaydaSuccess(:final fields):
///     print(fields.fullName);
///   case FaydaFailure(:final error):
///     print(error.message);
/// }
/// ```
sealed class FaydaResult {
  const FaydaResult();

  /// True for [FaydaSuccess].
  bool get ok;

  /// JSON matching the shared `result.schema.json` used by every port.
  Map<String, Object?> toJson();
}

/// A payload that parsed as a supported Fayda structure.
final class FaydaSuccess extends FaydaResult {
  /// Creates a success result.
  const FaydaSuccess({
    required this.payloadVersion,
    required this.fields,
    required this.signature,
    required this.raw,
    required this.library,
    required this.libraryVersion,
  });

  @override
  bool get ok => true;

  /// Always `fayda`.
  String get document => 'fayda';

  /// The payload's `V` field, e.g. `4`.
  final String payloadVersion;

  /// The parsed identity fields.
  final FaydaFields fields;

  /// The signature as found in the payload (not verified).
  final FaydaSignature signature;

  /// The raw payload and key/value map.
  final FaydaRaw raw;

  /// Name of the library that produced this result.
  final String library;

  /// Version of the library that produced this result.
  final String libraryVersion;

  @override
  Map<String, Object?> toJson() => {
        'ok': true,
        'document': document,
        'payload_version': payloadVersion,
        'fields': fields.toJson(),
        'signature': signature.toJson(),
        'raw': raw.toJson(),
        'meta': {'library': library, 'version': libraryVersion},
      };

  /// Redacted: never prints personal data, so results are safe to log.
  @override
  String toString() => 'FaydaSuccess(payloadVersion: $payloadVersion)';
}

/// A decode that did not produce Fayda fields.
final class FaydaFailure extends FaydaResult {
  /// Creates a failure result.
  const FaydaFailure(this.error, {this.raw});

  @override
  bool get ok => false;

  /// What went wrong.
  final FaydaError error;

  /// Best-effort raw data, present when the payload was at least
  /// structurally Fayda-shaped (for example [FaydaErrorCode.unsupportedVersion]).
  final FaydaRaw? raw;

  @override
  Map<String, Object?> toJson() => {
        'ok': false,
        'error': error.toJson(),
        if (raw != null) 'raw': raw!.toJson(),
      };

  @override
  String toString() => 'FaydaFailure(${error.code.code})';
}
