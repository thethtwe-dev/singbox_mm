part of '../singbox_mm_client.dart';

List<GfwPresetPack> _listGfwPresetPacksInternal() {
  return GfwPresetPack.all();
}

bool _isVlessRealityProfileInternal(VpnProfile profile) {
  return profile.protocol == VpnProtocol.vless &&
      profile.tls.enabled &&
      (profile.tls.realityPublicKey?.isNotEmpty ?? false);
}

bool _isExtremeEligibleProfileInternal(VpnProfile profile) {
  switch (profile.protocol) {
    case VpnProtocol.vless:
      return _isVlessRealityProfileInternal(profile);
    case VpnProtocol.hysteria2:
    case VpnProtocol.tuic:
      return profile.tls.enabled;
    case VpnProtocol.vmess:
    case VpnProtocol.trojan:
    case VpnProtocol.shadowsocks:
    case VpnProtocol.wireguard:
    case VpnProtocol.ssh:
      return false;
  }
}

void _assertPresetProfileAllowedInternal({
  required VpnProfile profile,
  required GfwPresetMode? mode,
}) {
  if (mode != GfwPresetMode.extreme) {
    return;
  }
  if (_isExtremeEligibleProfileInternal(profile)) {
    return;
  }
  throw SignboxVpnException(
    code: 'EXTREME_PRESET_PROTOCOL_BLOCKED',
    message:
        'Extreme preset only allows VLESS-Reality, Hysteria2, or TUIC profiles.',
    details: <String, Object?>{
      'tag': profile.tag,
      'protocol': profile.protocol.wireValue,
      'server': profile.server,
      'port': profile.serverPort,
    },
  );
}

int _adaptiveTransportTierInternal(VpnProfile profile) {
  if (_isVlessRealityProfileInternal(profile)) {
    return 0;
  }
  if (profile.protocol == VpnProtocol.hysteria2) {
    return 1;
  }
  if (profile.protocol == VpnProtocol.tuic) {
    return 2;
  }
  if ((profile.protocol == VpnProtocol.vless ||
          profile.protocol == VpnProtocol.vmess) &&
      profile.tls.enabled) {
    return 3;
  }
  return 4;
}

String _profileEndpointUriHintInternal(VpnProfile profile) {
  return '${profile.protocol.wireValue}://${profile.server}:${profile.serverPort}#${profile.tag}';
}

ParsedVpnSubscription _buildFilteredSubscriptionInternal(
  ParsedVpnSubscription parsed, {
  required List<VpnProfile> profiles,
  List<SubscriptionParseFailure> additionalFailures =
      const <SubscriptionParseFailure>[],
}) {
  final Set<String> tags = profiles
      .map((VpnProfile profile) => profile.tag)
      .toSet();
  final List<ParsedVpnConfig> entries = parsed.entries
      .where((ParsedVpnConfig entry) => tags.contains(entry.profile.tag))
      .toList(growable: false);
  return ParsedVpnSubscription(
    source: parsed.source,
    profiles: List<VpnProfile>.unmodifiable(profiles),
    entries: List<ParsedVpnConfig>.unmodifiable(entries),
    failures: List<SubscriptionParseFailure>.unmodifiable(
      <SubscriptionParseFailure>[...parsed.failures, ...additionalFailures],
    ),
    decodedFromBase64: parsed.decodedFromBase64,
  );
}

String _networkClassFromSnapshotInternal(VpnConnectionSnapshot snapshot) {
  final Set<String> transports = snapshot.underlyingTransports
      .map((String item) => item.trim().toLowerCase())
      .where((String item) => item.isNotEmpty)
      .toSet();
  if (transports.contains('wifi')) {
    return 'wifi';
  }
  if (transports.contains('cellular')) {
    return 'cellular';
  }
  if (transports.contains('ethernet')) {
    return 'ethernet';
  }
  if (transports.contains('bluetooth')) {
    return 'bluetooth';
  }

  final String activeInterface =
      snapshot.activeInterface?.trim().toLowerCase() ?? '';
  if (activeInterface.startsWith('wlan') ||
      activeInterface.startsWith('wifi')) {
    return 'wifi';
  }
  if (activeInterface.startsWith('rmnet') ||
      activeInterface.startsWith('ccmni') ||
      activeInterface.startsWith('pdp') ||
      activeInterface.startsWith('wwan') ||
      activeInterface.startsWith('cell')) {
    return 'cellular';
  }
  if (activeInterface.startsWith('eth')) {
    return 'ethernet';
  }
  if (activeInterface.startsWith('bt')) {
    return 'bluetooth';
  }
  return SignboxVpn._unknownNetworkClass;
}

Future<String> _resolveCurrentNetworkClassInternal(SignboxVpn client) async {
  try {
    final VpnConnectionSnapshot details = await client.getStateDetails();
    final String current = _networkClassFromSnapshotInternal(details);
    if (current != SignboxVpn._unknownNetworkClass) {
      client._lastKnownNetworkClass = current;
      return current;
    }
  } on Object {
    // Keep best-effort network affinity and reuse previous key.
  }
  return client._lastKnownNetworkClass;
}

int _preferredEndpointIndexForNetworkClassInternal(
  SignboxVpn client, {
  required String networkClass,
}) {
  final String? preferredTag =
      client._preferredEndpointTagByNetworkClass[networkClass];
  if (preferredTag == null || preferredTag.isEmpty) {
    return -1;
  }
  return client._endpointPool.indexWhere(
    (VpnProfile profile) => profile.tag == preferredTag,
  );
}

Future<void> _rememberEndpointForCurrentNetworkInternal(
  SignboxVpn client,
  VpnProfile profile, {
  String? networkClass,
}) async {
  final String resolvedClass =
      networkClass ?? await _resolveCurrentNetworkClassInternal(client);
  if (resolvedClass == SignboxVpn._unknownNetworkClass) {
    return;
  }
  client._preferredEndpointTagByNetworkClass[resolvedClass] = profile.tag;
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
