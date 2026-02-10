part of '../vpn_config_parser.dart';

ParsedVpnConfig _parseSbmmConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
  String? sbmmPassphrase,
}) {
  final String normalizedPassphrase = sbmmPassphrase?.trim() ?? '';
  if (normalizedPassphrase.isEmpty) {
    throw const FormatException(
      'sbmm link requires `sbmmPassphrase` to decrypt.',
    );
  }

  final String decryptedConfig = SbmmSecureLinkCodec.unwrapConfigLink(
    sbmmLink: raw,
    passphrase: normalizedPassphrase,
  );

  final ParsedVpnConfig parsedInner = parser.parse(
    decryptedConfig,
    fallbackTag: fallbackTag,
    sbmmPassphrase: normalizedPassphrase,
  );

  return ParsedVpnConfig(
    profile: parsedInner.profile,
    scheme: 'sbmm',
    rawConfig: raw,
    warnings: List<String>.unmodifiable(<String>[
      'Decoded from sbmm secure envelope (${parsedInner.scheme}).',
      ...parsedInner.warnings,
    ]),
  );
}
