import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// An RSA public key: modulus and public exponent.
final class RsaPublicKey {
  /// Creates a key from its modulus and exponent.
  RsaPublicKey(this.modulus, this.exponent) {
    if (modulus <= BigInt.one || exponent <= BigInt.one) {
      throw const FormatException('Invalid RSA public key');
    }
  }

  /// Parses a PEM `-----BEGIN PUBLIC KEY-----` (SubjectPublicKeyInfo) block.
  factory RsaPublicKey.fromPem(String pem) {
    final body = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');
    return RsaPublicKey.fromSpkiDer(base64.decode(body));
  }

  /// Parses a DER SubjectPublicKeyInfo carrying an `rsaEncryption` key.
  factory RsaPublicKey.fromSpkiDer(Uint8List der) {
    final spki = _DerReader(der).readSequence();
    final algorithm = spki.readSequence();
    final oid = algorithm.read(_tagOid);
    if (!_bytesEqual(oid, _rsaEncryptionOid)) {
      throw const FormatException('Not an RSA public key');
    }
    final bitString = spki.read(_tagBitString);
    if (bitString.isEmpty || bitString[0] != 0) {
      throw const FormatException('Malformed public key bit string');
    }
    final rsaKey =
        _DerReader(Uint8List.sublistView(bitString, 1)).readSequence();
    final modulus = _toBigInt(rsaKey.read(_tagInteger));
    final exponent = _toBigInt(rsaKey.read(_tagInteger));
    return RsaPublicKey(modulus, exponent);
  }

  /// The modulus `n`.
  final BigInt modulus;

  /// The public exponent `e`.
  final BigInt exponent;

  /// The modulus length in bytes (`k` in RFC 8017).
  int get lengthInBytes => (modulus.bitLength + 7) >> 3;
}

/// RSASSA-PKCS1-v1_5 verification with SHA-256 (JWS `RS256`), per RFC 8017
/// section 8.2.2.
///
/// Uses encode-and-compare: builds the expected encoded message from
/// [message] and compares it in full against the decrypted signature, rather
/// than parsing the decrypted block. Parsing-based verifiers are the source of
/// the classic signature-forgery bugs.
bool rsaPkcs1Sha256Verify(
  RsaPublicKey key,
  List<int> message,
  List<int> signature,
) {
  final k = key.lengthInBytes;
  if (signature.length != k) return false;

  final s = _toBigInt(signature);
  if (s >= key.modulus) return false;
  final em = _toBytes(s.modPow(key.exponent, key.modulus), k);

  final digest = sha256.convert(message).bytes;
  final tLength = _sha256DigestInfoPrefix.length + digest.length;
  if (k < tLength + 11) return false;

  final expected = Uint8List(k)
    ..[0] = 0x00
    ..[1] = 0x01;
  final psEnd = k - tLength - 1;
  expected.fillRange(2, psEnd, 0xff);
  expected[psEnd] = 0x00;
  expected.setAll(psEnd + 1, _sha256DigestInfoPrefix);
  expected.setAll(k - digest.length, digest);

  return _constantTimeEquals(em, expected);
}

const _tagInteger = 0x02;
const _tagBitString = 0x03;
const _tagOid = 0x06;
const _tagSequence = 0x30;

/// 1.2.840.113549.1.1.1
const _rsaEncryptionOid = [
  0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, //
];

/// DER DigestInfo prefix for SHA-256 (RFC 8017 section 9.2, note 1).
const _sha256DigestInfoPrefix = [
  0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, //
  0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
];

/// Just enough DER to read a SubjectPublicKeyInfo.
final class _DerReader {
  _DerReader(this._bytes);

  final Uint8List _bytes;
  int _pos = 0;

  _DerReader readSequence() => _DerReader(read(_tagSequence));

  Uint8List read(int expectedTag) {
    if (_pos >= _bytes.length || _bytes[_pos] != expectedTag) {
      throw const FormatException('Unexpected DER tag');
    }
    _pos++;
    final length = _readLength();
    if (_pos + length > _bytes.length) {
      throw const FormatException('DER length out of range');
    }
    final value = Uint8List.sublistView(_bytes, _pos, _pos + length);
    _pos += length;
    return value;
  }

  int _readLength() {
    if (_pos >= _bytes.length) throw const FormatException('Truncated DER');
    final first = _bytes[_pos++];
    if (first < 0x80) return first;
    final count = first & 0x7f;
    if (count == 0 || count > 4 || _pos + count > _bytes.length) {
      throw const FormatException('Unsupported DER length');
    }
    var length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | _bytes[_pos++];
    }
    return length;
  }
}

BigInt _toBigInt(List<int> bytes) {
  if (bytes.isEmpty) return BigInt.zero;
  final hex = StringBuffer();
  for (final b in bytes) {
    hex.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return BigInt.parse(hex.toString(), radix: 16);
}

Uint8List _toBytes(BigInt value, int length) {
  final hex = value.toRadixString(16).padLeft(length * 2, '0');
  final out = Uint8List(length);
  if (hex.length > length * 2) return out; // cannot happen for value < n
  for (var i = 0; i < length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
