part of '../vpn_subscription_parser.dart';

class _SubscriptionPayload {
  const _SubscriptionPayload({
    required this.payload,
    required this.decodedFromBase64,
  });

  final String payload;
  final bool decodedFromBase64;
}

_SubscriptionPayload _resolveSubscriptionPayload(
  String normalized, {
  required bool tryBase64Decode,
}) {
  String payload = normalized;
  bool decodedFromBase64 = false;
  if (tryBase64Decode &&
      !VpnSubscriptionParser._containsUriScheme(normalized)) {
    final String? decoded = VpnSubscriptionParser._decodeBase64(normalized);
    if (decoded != null && VpnSubscriptionParser._containsUriScheme(decoded)) {
      payload = decoded;
      decodedFromBase64 = true;
    }
  }

  return _SubscriptionPayload(
    payload: payload,
    decodedFromBase64: decodedFromBase64,
  );
}

bool _containsSubscriptionUriScheme(String value) {
  return RegExp(r'[a-zA-Z0-9+.-]+://').hasMatch(value);
}

String? _decodeSubscriptionBase64(String encoded) {
  final String normalized = encoded.replaceAll('\n', '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  final int remainder = normalized.length % 4;
  final String padded = remainder == 0
      ? normalized
      : normalized.padRight(normalized.length + (4 - remainder), '=');
  try {
    return utf8.decode(base64.decode(padded));
  } on FormatException {
    try {
      return utf8.decode(base64Url.decode(padded));
    } on FormatException {
      return null;
    }
  }
}
