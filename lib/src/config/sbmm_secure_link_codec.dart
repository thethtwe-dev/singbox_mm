import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Secure wrapper for VPN links using `sbmm://` envelopes.
///
/// Envelope crypto:
/// - KDF: PBKDF2-HMAC-SHA256
/// - Cipher: AES-256-GCM
/// - Nonce: 96 bits
class SbmmSecureLinkCodec {
  const SbmmSecureLinkCodec._();

  static const int currentVersion = 1;
  static const int defaultPbkdf2Iterations = 210000;

  static const int _keyLengthBytes = 32;
  static const int _saltLengthBytes = 16;
  static const int _nonceLengthBytes = 12;
  static const int _gcmTagLengthBits = 128;
  static const String _aad = 'sbmm:v1';
  static const String _schemePrefix = 'sbmm://';
  static const String _defaultHost = 'secure';

  static bool isSbmmLink(String value) {
    return value.trim().toLowerCase().startsWith(_schemePrefix);
  }

  static String wrapConfigLink({
    required String configLink,
    required String passphrase,
    int pbkdf2Iterations = defaultPbkdf2Iterations,
  }) {
    final String normalized = configLink.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Config link is empty.');
    }
    final String normalizedPassphrase = passphrase.trim();
    if (normalizedPassphrase.isEmpty) {
      throw const FormatException('sbmm passphrase cannot be empty.');
    }
    if (pbkdf2Iterations < 100000) {
      throw const FormatException('PBKDF2 iterations must be >= 100000.');
    }

    final Uint8List salt = _randomBytes(_saltLengthBytes);
    final Uint8List nonce = _randomBytes(_nonceLengthBytes);
    final Uint8List key = _deriveKey(
      passphrase: normalizedPassphrase,
      salt: salt,
      iterations: pbkdf2Iterations,
    );

    final Uint8List cipherText = _encryptAesGcm(
      plainText: Uint8List.fromList(utf8.encode(normalized)),
      key: key,
      nonce: nonce,
      aad: Uint8List.fromList(utf8.encode(_aad)),
    );

    final Map<String, Object?> envelope = <String, Object?>{
      'v': currentVersion,
      'alg': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iter': pbkdf2Iterations,
      'salt': _encodeBase64UrlNoPadding(salt),
      'nonce': _encodeBase64UrlNoPadding(nonce),
      'ct': _encodeBase64UrlNoPadding(cipherText),
    };
    final String token = _encodeBase64UrlNoPadding(
      Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
    );

    return '$_schemePrefix$_defaultHost?data=$token';
  }

  static String unwrapConfigLink({
    required String sbmmLink,
    required String passphrase,
  }) {
    final String normalized = sbmmLink.trim();
    if (!isSbmmLink(normalized)) {
      throw const FormatException('Input is not an sbmm:// link.');
    }
    final String normalizedPassphrase = passphrase.trim();
    if (normalizedPassphrase.isEmpty) {
      throw const FormatException('sbmm passphrase cannot be empty.');
    }

    final String token = _extractEnvelopeToken(normalized);
    final Uint8List envelopeBytes = _decodeBase64UrlNoPadding(token);
    final Object? envelopeRaw = _tryJsonDecode(utf8.decode(envelopeBytes));
    if (envelopeRaw is! Map<Object?, Object?>) {
      throw const FormatException('Invalid sbmm envelope JSON.');
    }
    final Map<String, Object?> envelope = <String, Object?>{};
    envelopeRaw.forEach((Object? key, Object? value) {
      if (key != null) {
        envelope[key.toString()] = value;
      }
    });

    final int version = _readInt(envelope['v']);
    if (version != currentVersion) {
      throw FormatException('Unsupported sbmm envelope version: $version.');
    }
    final int iterations = _readInt(envelope['iter']);
    if (iterations < 100000) {
      throw const FormatException('Invalid sbmm PBKDF2 iteration count.');
    }

    final Uint8List salt = _decodeBase64UrlNoPadding(
      _readString(envelope['salt'], field: 'salt'),
    );
    final Uint8List nonce = _decodeBase64UrlNoPadding(
      _readString(envelope['nonce'], field: 'nonce'),
    );
    final Uint8List cipherText = _decodeBase64UrlNoPadding(
      _readString(envelope['ct'], field: 'ct'),
    );

    if (salt.length != _saltLengthBytes) {
      throw const FormatException('Invalid sbmm salt length.');
    }
    if (nonce.length != _nonceLengthBytes) {
      throw const FormatException('Invalid sbmm nonce length.');
    }

    final Uint8List key = _deriveKey(
      passphrase: normalizedPassphrase,
      salt: salt,
      iterations: iterations,
    );

    final Uint8List plainBytes = _decryptAesGcm(
      cipherText: cipherText,
      key: key,
      nonce: nonce,
      aad: Uint8List.fromList(utf8.encode(_aad)),
    );

    final String plain = utf8.decode(plainBytes).trim();
    if (plain.isEmpty) {
      throw const FormatException('sbmm payload decrypted to empty config.');
    }
    return plain;
  }

  static Uint8List _encryptAesGcm({
    required Uint8List plainText,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
  }) {
    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine());
    final AEADParameters params = AEADParameters(
      KeyParameter(key),
      _gcmTagLengthBits,
      nonce,
      aad,
    );
    cipher.init(true, params);
    return cipher.process(plainText);
  }

  static Uint8List _decryptAesGcm({
    required Uint8List cipherText,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
  }) {
    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine());
    final AEADParameters params = AEADParameters(
      KeyParameter(key),
      _gcmTagLengthBits,
      nonce,
      aad,
    );
    cipher.init(false, params);
    try {
      return cipher.process(cipherText);
    } on ArgumentError {
      throw const FormatException(
        'sbmm decrypt failed: bad passphrase or tampered payload.',
      );
    } on InvalidCipherTextException {
      throw const FormatException(
        'sbmm decrypt failed: bad passphrase or tampered payload.',
      );
    }
  }

  static Uint8List _deriveKey({
    required String passphrase,
    required Uint8List salt,
    required int iterations,
  }) {
    final PBKDF2KeyDerivator derivator = PBKDF2KeyDerivator(
      HMac(SHA256Digest(), 64),
    );
    derivator.init(Pbkdf2Parameters(salt, iterations, _keyLengthBytes));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  static Uint8List _randomBytes(int length) {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256), growable: false),
    );
  }

  static String _extractEnvelopeToken(String sbmmLink) {
    final Uri uri;
    try {
      uri = Uri.parse(sbmmLink);
    } on FormatException catch (error) {
      throw FormatException('Invalid sbmm URI: ${error.message}');
    }
    if (uri.scheme.toLowerCase() != 'sbmm') {
      throw const FormatException('Expected sbmm:// scheme.');
    }

    final String? queryToken = _nonEmpty(uri.queryParameters['data']);
    if (queryToken != null) {
      return queryToken;
    }

    final String rawWithoutScheme = sbmmLink.substring(_schemePrefix.length);
    final int hashIndex = rawWithoutScheme.indexOf('#');
    final String withoutFragment = hashIndex >= 0
        ? rawWithoutScheme.substring(0, hashIndex)
        : rawWithoutScheme;
    final int queryIndex = withoutFragment.indexOf('?');
    final String beforeQuery = queryIndex >= 0
        ? withoutFragment.substring(0, queryIndex)
        : withoutFragment;
    final String tokenCandidate = beforeQuery.trim();
    if (tokenCandidate.isNotEmpty && !tokenCandidate.contains('/')) {
      return tokenCandidate;
    }

    final String? firstPath = uri.pathSegments.isNotEmpty
        ? _nonEmpty(uri.pathSegments.first)
        : null;
    if (firstPath != null) {
      return firstPath;
    }

    throw const FormatException(
      'sbmm payload token missing. Expected ?data=<token>.',
    );
  }

  static String _encodeBase64UrlNoPadding(Uint8List value) {
    return base64Url.encode(value).replaceAll('=', '');
  }

  static Uint8List _decodeBase64UrlNoPadding(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty base64url value.');
    }
    final int remainder = trimmed.length % 4;
    final String padded = remainder == 0
        ? trimmed
        : trimmed.padRight(trimmed.length + (4 - remainder), '=');
    try {
      return Uint8List.fromList(base64Url.decode(padded));
    } on FormatException {
      throw const FormatException('Invalid base64url value.');
    }
  }

  static dynamic _tryJsonDecode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      final int? parsed = int.tryParse(raw.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    throw const FormatException('Invalid integer field in sbmm envelope.');
  }

  static String _readString(Object? raw, {required String field}) {
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    throw FormatException('Missing/invalid sbmm envelope field: $field.');
  }

  static String? _nonEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
