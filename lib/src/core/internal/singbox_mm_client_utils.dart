part of '../singbox_mm_client.dart';

List<GfwPresetPack> _listGfwPresetPacksInternal() {
  return GfwPresetPack.all();
}

String _wrapSecureConfigLinkInternal({
  required String configLink,
  required String passphrase,
  required int pbkdf2Iterations,
}) {
  return SbmmSecureLinkCodec.wrapConfigLink(
    configLink: configLink,
    passphrase: passphrase,
    pbkdf2Iterations: pbkdf2Iterations,
  );
}

String _unwrapSecureConfigLinkInternal({
  required String sbmmLink,
  required String passphrase,
}) {
  return SbmmSecureLinkCodec.unwrapConfigLink(
    sbmmLink: sbmmLink,
    passphrase: passphrase,
  );
}

ParsedVpnConfig _parseConfigLinkInternal(
  SignboxVpn client,
  String configLink, {
  String? fallbackTag,
  String? sbmmPassphrase,
}) {
  return client._configParser.parse(
    configLink,
    fallbackTag: fallbackTag,
    sbmmPassphrase: sbmmPassphrase,
  );
}

VpnProfileSummary _summarizeProfileInternal(
  VpnProfile profile, {
  required int index,
  required List<String> warnings,
}) {
  return VpnProfileSummary(
    index: index,
    remark: profile.tag,
    protocol: profile.protocol,
    host: profile.server,
    port: profile.serverPort,
    transport: profile.transport,
    tlsEnabled: profile.tls.enabled,
    tlsServerName: profile.tls.serverName,
    warnings: List<String>.unmodifiable(warnings),
  );
}

VpnProfileSummary _extractConfigLinkSummaryInternal(
  SignboxVpn client,
  String configLink, {
  String? fallbackTag,
  String? sbmmPassphrase,
}) {
  final ParsedVpnConfig parsed = client.parseConfigLink(
    configLink,
    fallbackTag: fallbackTag,
    sbmmPassphrase: sbmmPassphrase,
  );
  return client.summarizeProfile(parsed.profile, warnings: parsed.warnings);
}
