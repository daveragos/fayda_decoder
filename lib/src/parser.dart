import 'base64.dart';
import 'result.dart';
import 'version.dart';

const _supportedVersions = {'4'};
const _dltMarker = ':DLT:';
const _signMarker = ':SIGN:';

final _fanPattern = RegExp(r'^\d{10,20}$');
final _dobPattern = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$');

const _notFayda = FaydaFailure(FaydaError(
  FaydaErrorCode.notFayda,
  'The QR payload is not a recognizable Fayda ID structure.',
));

/// Parses the text content of a Fayda ID QR code.
///
/// Use this when something else (a camera scanner such as `mobile_scanner`,
/// or a hardware reader) already gave you the QR text.
///
/// Observed payload format (version 4):
/// `<base64url-webp-face>:DLT:<full name>:V:<version>:G:<M|F>:A:<FAN>:D:<yyyy/mm/dd>:SIGN:<JWS>`
///
/// Partial success is success: a malformed individual field becomes null and
/// does not fail the whole parse. Only structural failure is an error.
///
/// The face thumbnail is biometric-adjacent data, so it is returned only when
/// [includeFace] is true.
FaydaResult decodePayload(String text, {bool includeFace = false}) {
  final payload = text.trim();

  if (!payload.contains(_dltMarker) || !payload.contains(_signMarker)) {
    return _notFayda;
  }

  final dltIndex = payload.indexOf(_dltMarker);
  final facePart = payload.substring(0, dltIndex);
  final rest = payload.substring(dltIndex + _dltMarker.length);

  // The last :SIGN: is the JWS boundary, so a stray marker earlier in the
  // fields cannot cut them short.
  final signIndex = rest.lastIndexOf(_signMarker);
  if (signIndex == -1) return _notFayda;
  final fieldsPart = rest.substring(0, signIndex);
  final jws = rest.substring(signIndex + _signMarker.length);

  // The name is positional, not keyed: everything up to the first ':' of the
  // key/value tail. Never split the name eagerly.
  final segments = fieldsPart.split(':');
  final fullName = segments.first.trim();
  if (fullName.isEmpty) return _notFayda;

  final map = <String, String>{};
  for (var i = 1; i + 1 < segments.length; i += 2) {
    map[segments[i]] = segments[i + 1];
  }

  final raw = FaydaRaw(payload: payload, map: Map.unmodifiable(map));

  final version = map['V'];
  if (version == null || !_supportedVersions.contains(version)) {
    return FaydaFailure(
      const FaydaError(
        FaydaErrorCode.unsupportedVersion,
        'The payload is Fayda-shaped but uses an unsupported version. '
        'Update fayda_decoder; raw fields are available in `raw.map`.',
      ),
      raw: raw,
    );
  }

  return FaydaSuccess(
    payloadVersion: version,
    fields: FaydaFields(
      fullName: fullName,
      gender: _parseGender(map['G']),
      fan: _parseFan(map['A']),
      dateOfBirth: _parseDob(map['D']),
      face: includeFace ? _parseFace(facePart) : null,
    ),
    signature: FaydaSignature(jws: jws.isEmpty ? null : jws),
    raw: raw,
    library: libraryName,
    libraryVersion: libraryVersion,
  );
}

FaydaGender? _parseGender(String? value) => switch (value) {
      'M' => FaydaGender.male,
      'F' => FaydaGender.female,
      _ => null,
    };

String? _parseFan(String? value) =>
    value != null && _fanPattern.hasMatch(value) ? value : null;

/// `yyyy/mm/dd` (Gregorian) to ISO `yyyy-mm-dd`, or null if not a real date.
String? _parseDob(String? value) {
  if (value == null) return null;
  final match = _dobPattern.firstMatch(value);
  if (match == null) return null;
  final y = match[1]!, m = match[2]!, d = match[3]!;
  final year = int.parse(y), month = int.parse(m), day = int.parse(d);
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > _daysInMonth(year, month)) return null;
  return '$y-$m-$d';
}

int _daysInMonth(int year, int month) {
  const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && _isLeapYear(year)) return 29;
  return days[month - 1];
}

/// Proleptic Gregorian leap-year rule.
bool _isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// Decodes the face part; keeps it only if it is a WebP (RIFF container).
FaydaFace? _parseFace(String facePart) {
  if (facePart.isEmpty) return null;
  final bytes = base64UrlDecodeStrict(facePart);
  if (bytes == null || bytes.length < 4) return null;
  final isRiff = bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46; // F
  return isRiff ? FaydaFace(bytes) : null;
}
