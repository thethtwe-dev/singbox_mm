part of '../singbox_mm_client.dart';

Future<ManualConnectResult> _connectManualProfileInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
  required bool requestPermission,
}) async {
  final SingboxFeatureSettings effectiveSettings =
      featureSettings ?? client._featureSettings;
  final Map<String, Object?> config = await client.applyProfile(
    profile: profile,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    featureSettings: effectiveSettings,
  );
  await _maybeRequestPermissionsInternal(
    client,
    requestPermission: requestPermission,
  );
  await client.start();
  ManualConnectResult result = ManualConnectResult(
    profile: profile,
    appliedConfig: config,
  );
  result = await _maybeApplyDualCoreFallbackInternal(
    client,
    result: result,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    featureSettings: effectiveSettings,
  );
  await _rememberEndpointForCurrentNetworkInternal(client, profile);
  return result;
}

Future<ManualConnectResult> _connectManualConfigLinkInternal(
  SignboxVpn client, {
  required String configLink,
  required String? fallbackTag,
  required String? sbmmPassphrase,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
  required bool requestPermission,
}) async {
  final ParsedVpnConfig parsed = client.parseConfigLink(
    configLink,
    fallbackTag: fallbackTag,
    sbmmPassphrase: sbmmPassphrase,
  );
  final ManualConnectResult result = await client.connectManualProfile(
    profile: parsed.profile,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    featureSettings: featureSettings,
    requestPermission: requestPermission,
  );
  final List<String> warnings = <String>[
    ...parsed.warnings,
    ...result.warnings,
  ];
  return ManualConnectResult(
    profile: result.profile,
    appliedConfig: result.appliedConfig,
    warnings: warnings,
  );
}

Future<ManualConnectResult> _connectManualWithPresetInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required GfwPresetPack? preset,
  required bool requestPermission,
}) {
  final GfwPresetPack resolvedPreset = preset ?? GfwPresetPack.balanced();
  client._activeGfwPresetMode = resolvedPreset.mode;
  _assertPresetProfileAllowedInternal(
    profile: profile,
    mode: resolvedPreset.mode,
  );
  return _connectManualProfileWithPresetPoolInternal(
    client,
    profile: profile,
    preset: resolvedPreset,
    requestPermission: requestPermission,
  );
}

Future<ManualConnectResult> _connectManualConfigLinkWithPresetInternal(
  SignboxVpn client, {
  required String configLink,
  required String? fallbackTag,
  required String? sbmmPassphrase,
  required GfwPresetPack? preset,
  required bool requestPermission,
}) {
  final GfwPresetPack resolvedPreset = preset ?? GfwPresetPack.balanced();
  client._activeGfwPresetMode = resolvedPreset.mode;
  final ParsedVpnConfig parsed = client.parseConfigLink(
    configLink,
    fallbackTag: fallbackTag,
    sbmmPassphrase: sbmmPassphrase,
  );
  _assertPresetProfileAllowedInternal(
    profile: parsed.profile,
    mode: resolvedPreset.mode,
  );
  return _connectManualProfileWithPresetPoolInternal(
    client,
    profile: parsed.profile,
    preset: resolvedPreset,
    requestPermission: requestPermission,
  ).then(
    (ManualConnectResult result) => ManualConnectResult(
      profile: result.profile,
      appliedConfig: result.appliedConfig,
      warnings: <String>[...parsed.warnings, ...result.warnings],
    ),
  );
}

Future<ManualConnectResult> _connectManualProfileWithPresetPoolInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required GfwPresetPack preset,
  required bool requestPermission,
}) async {
  final Map<String, Object?> config = await client.applyEndpointPool(
    profiles: <VpnProfile>[profile],
    options: preset.endpointPoolOptions,
    bypassPolicy: preset.bypassPolicy,
    throttlePolicy: preset.throttlePolicy,
    featureSettings: preset.featureSettings,
  );
  await _maybeRequestPermissionsInternal(
    client,
    requestPermission: requestPermission,
  );
  await client.start();
  await _rememberEndpointForCurrentNetworkInternal(client, profile);
  return ManualConnectResult(profile: profile, appliedConfig: config);
}

Future<ManualConnectResult> _maybeApplyDualCoreFallbackInternal(
  SignboxVpn client, {
  required ManualConnectResult result,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings featureSettings,
}) async {
  if (!featureSettings.misc.useXrayCoreWhenPossible) {
    return result;
  }

  final VpnProfile profile = result.profile;
  if (!_isDualCoreEligibleProfileInternal(profile)) {
    return result;
  }

  String? lastError;
  try {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    lastError = await client.getLastError();
  } on Object {
    return result;
  }

  if (!_looksLikeTransportRejectionInternal(lastError)) {
    bool shouldFallbackByProbe = false;
    try {
      final VpnConnectivityProbe probe = await client.probeConnectivity(
        timeout: const Duration(seconds: 4),
      );
      shouldFallbackByProbe = !probe.success;
      if (shouldFallbackByProbe &&
          (lastError == null || lastError.trim().isEmpty) &&
          probe.error != null &&
          probe.error!.trim().isNotEmpty) {
        lastError = probe.error;
      }
    } on Object {
      // Keep original behavior when probe cannot run in current environment.
      shouldFallbackByProbe = false;
    }
    if (!shouldFallbackByProbe) {
      return result;
    }
  }

  final SingboxFeatureSettings compatSettings =
      _buildDualCoreCompatSettingsInternal(featureSettings);
  final Map<String, Object?> compatConfig = _buildConfigInternal(
    client,
    profile: profile,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    featureSettings: compatSettings,
    transportBuildMode: SingboxTransportBuildMode.xrayCompat,
  );
  _patchDualCoreCompatConfigInternal(compatConfig, profile: profile);
  await client.setRawConfig(compatConfig);
  await client.restart();

  final List<String> warnings = <String>[
    ...result.warnings,
    'Dual-core fallback applied: switched to xray-compat build mode '
        'after runtime rejection ($lastError).',
  ];
  return ManualConnectResult(
    profile: result.profile,
    appliedConfig: compatConfig,
    warnings: warnings,
  );
}

bool _isDualCoreEligibleProfileInternal(VpnProfile profile) {
  switch (profile.protocol) {
    case VpnProtocol.vless:
    case VpnProtocol.vmess:
    case VpnProtocol.trojan:
    case VpnProtocol.shadowsocks:
      break;
    case VpnProtocol.hysteria2:
    case VpnProtocol.tuic:
    case VpnProtocol.wireguard:
    case VpnProtocol.ssh:
      return false;
  }
  switch (profile.transport) {
    case VpnTransport.grpc:
    case VpnTransport.ws:
    case VpnTransport.http:
    case VpnTransport.httpUpgrade:
      return true;
    case VpnTransport.tcp:
    case VpnTransport.quic:
      return false;
  }
}

bool _looksLikeTransportRejectionInternal(String? value) {
  final String normalized = value?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.contains('permissiondenied') ||
      normalized.contains('forbidden') ||
      normalized.contains('unexpected http status') ||
      normalized.contains('malformed http response') ||
      normalized.contains('http2: frame too large') ||
      normalized.contains('v2ray-http-upgrade');
}

SingboxFeatureSettings _buildDualCoreCompatSettingsInternal(
  SingboxFeatureSettings source,
) {
  final DnsOptions dns = source.dns;
  return SingboxFeatureSettings(
    advanced: source.advanced,
    route: source.route,
    dns: DnsOptions(
      providerPreset: dns.providerPreset,
      remoteDns: dns.remoteDns,
      remoteDomainStrategy: dns.remoteDomainStrategy,
      directDns: 'local',
      directDomainStrategy: dns.directDomainStrategy,
      enableDnsRouting: dns.enableDnsRouting,
      enableFakeIp: false,
      fakeIpInet4Range: dns.fakeIpInet4Range,
      fakeIpInet6Range: dns.fakeIpInet6Range,
      enableDohFallback: dns.enableDohFallback,
      dohFallbackDns: dns.dohFallbackDns,
      dohFallbackDomainSuffixes: dns.dohFallbackDomainSuffixes,
    ),
    inbound: source.inbound,
    tlsTricks: source.tlsTricks,
    warp: source.warp,
    misc: source.misc,
    rawConfigPatch: source.rawConfigPatch,
  );
}

void _patchDualCoreCompatConfigInternal(
  Map<String, Object?> config, {
  required VpnProfile profile,
}) {
  final List<Object?> outbounds = List<Object?>.from(
    (config['outbounds'] as List<Object?>?) ?? const <Object?>[],
  );
  if (outbounds.isEmpty) {
    return;
  }
  Map<String, Object?>? primary;
  int primaryIndex = -1;
  for (int index = 0; index < outbounds.length; index++) {
    final Object? item = outbounds[index];
    final Map<String, Object?> candidate = _asObjectMapInternal(item);
    if (candidate.isEmpty) {
      continue;
    }
    if (candidate['tag'] == profile.tag) {
      primary = candidate;
      primaryIndex = index;
      break;
    }
  }
  if (primary == null || primaryIndex < 0) {
    return;
  }

  final Map<String, Object?> transport = _asObjectMapInternal(
    primary['transport'],
  );
  final String transportType =
      (transport['type'] as String?)?.trim().toLowerCase() ?? '';
  if (transportType == 'grpc') {
    transport.putIfAbsent('idle_timeout', () => '60s');
    transport.putIfAbsent('ping_timeout', () => '20s');
    final String grpcMode =
        (profile.extra['_sbmm_grpc_mode'] as String?)?.trim().toLowerCase() ??
        '';
    if (grpcMode == 'multi') {
      transport['permit_without_stream'] = true;
    } else if (grpcMode == 'gun') {
      transport['permit_without_stream'] = false;
    }
    primary['transport'] = transport;

    final Map<String, Object?> tls = _asObjectMapInternal(primary['tls']);
    if (tls.isNotEmpty) {
      tls['alpn'] = const <String>['h2'];
      primary['tls'] = tls;
    }
  }

  outbounds[primaryIndex] = primary;
  config['outbounds'] = outbounds;
}

Map<String, Object?> _asObjectMapInternal(Object? value) {
  if (value is Map<String, Object?>) {
    return <String, Object?>{...value};
  }
  if (value is Map<Object?, Object?>) {
    final Map<String, Object?> output = <String, Object?>{};
    value.forEach((Object? key, Object? element) {
      if (key is String) {
        output[key] = element;
      }
    });
    return output;
  }
  return <String, Object?>{};
}
