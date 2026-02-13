part of '../singbox_mm_client.dart';

Future<AutoConnectResult> _connectAutoSubscriptionInternal(
  SignboxVpn client, {
  required String rawSubscription,
  required String source,
  required bool tryBase64Decode,
  required bool deduplicate,
  required String? sbmmPassphrase,
  required EndpointPoolOptions options,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
  required bool requestPermission,
  required bool preferLowestLatency,
  required Duration pingTimeout,
}) async {
  final SubscriptionImportResult importResult = await client.importSubscription(
    rawSubscription: rawSubscription,
    source: source,
    tryBase64Decode: tryBase64Decode,
    deduplicate: deduplicate,
    sbmmPassphrase: sbmmPassphrase,
    connect: false,
    options: options,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    featureSettings: featureSettings,
  );

  if (importResult.importedCount == 0 || client._endpointPool.isEmpty) {
    throw const SignboxVpnException(
      code: 'EMPTY_SUBSCRIPTION',
      message: 'No valid VPN profiles found in subscription.',
    );
  }

  List<VpnPingResult> pingResults = const <VpnPingResult>[];
  VpnProfile? selectedProfile = client.activeEndpointProfile;
  if (preferLowestLatency && client._endpointPool.length > 1) {
    pingResults = await client.pingEndpointPool(
      timeout: pingTimeout,
      updateHealth: false,
      connectivityProbeUrl: options.healthCheck.connectivityProbeUrl,
      connectivityProbeTimeout: options.healthCheck.connectivityProbeTimeout,
    );
    final int bestIndex = _bestPingResultIndexInternal(pingResults);
    if (bestIndex >= 0) {
      selectedProfile = await client.selectEndpoint(
        index: bestIndex,
        reconnect: false,
      );
    }
  }

  await _maybeRequestPermissionsInternal(
    client,
    requestPermission: requestPermission,
  );
  await client.startManaged();

  return AutoConnectResult(
    importResult: importResult,
    selectedProfile: selectedProfile ?? client.activeEndpointProfile,
    pingResults: List<VpnPingResult>.unmodifiable(pingResults),
  );
}

Future<AutoConnectResult> _connectAutoWithPresetInternal(
  SignboxVpn client, {
  required String rawSubscription,
  required GfwPresetPack? preset,
  required String source,
  required bool tryBase64Decode,
  required bool deduplicate,
  required String? sbmmPassphrase,
  required bool requestPermission,
  required bool preferLowestLatency,
  required Duration pingTimeout,
}) async {
  final GfwPresetPack resolvedPreset = preset ?? GfwPresetPack.balanced();
  client._activeGfwPresetMode = resolvedPreset.mode;

  final ParsedVpnSubscription parsed = client.parseSubscription(
    rawSubscription,
    source: source,
    tryBase64Decode: tryBase64Decode,
    deduplicate: deduplicate,
    sbmmPassphrase: sbmmPassphrase,
  );

  List<VpnProfile> filteredProfiles = List<VpnProfile>.of(parsed.profiles);
  final List<SubscriptionParseFailure> presetFailures =
      <SubscriptionParseFailure>[];
  if (resolvedPreset.mode == GfwPresetMode.extreme) {
    filteredProfiles = filteredProfiles
        .where((VpnProfile profile) {
          final bool eligible = _isExtremeEligibleProfileInternal(profile);
          if (!eligible) {
            presetFailures.add(
              SubscriptionParseFailure(
                entry: _profileEndpointUriHintInternal(profile),
                reason:
                    'Filtered by Extreme preset. Allowed: VLESS-Reality, Hysteria2, TUIC.',
              ),
            );
          }
          return eligible;
        })
        .toList(growable: false);
  }

  if (filteredProfiles.isEmpty) {
    final String message = resolvedPreset.mode == GfwPresetMode.extreme
        ? 'No eligible profiles for Extreme preset. '
              'Use VLESS-Reality, Hysteria2, or TUIC.'
        : 'No valid VPN profiles found in subscription.';
    throw SignboxVpnException(code: 'EMPTY_SUBSCRIPTION', message: message);
  }

  final ParsedVpnSubscription filteredSubscription =
      _buildFilteredSubscriptionInternal(
        parsed,
        profiles: filteredProfiles,
        additionalFailures: presetFailures,
      );

  final Map<String, Object?> appliedConfig = await client.applyEndpointPool(
    profiles: filteredSubscription.profiles,
    options: resolvedPreset.endpointPoolOptions,
    bypassPolicy: resolvedPreset.bypassPolicy,
    throttlePolicy: resolvedPreset.throttlePolicy,
    featureSettings: resolvedPreset.featureSettings,
  );

  final String networkClass = await _resolveCurrentNetworkClassInternal(client);
  VpnProfile? selectedProfile = client.activeEndpointProfile;
  List<VpnPingResult> pingResults = const <VpnPingResult>[];

  final int preferredIndex = _preferredEndpointIndexForNetworkClassInternal(
    client,
    networkClass: networkClass,
  );
  final bool reusedNetworkAffinity = preferredIndex >= 0;
  if (preferredIndex >= 0 && preferredIndex != client._activeEndpointIndex) {
    selectedProfile = await client.selectEndpoint(
      index: preferredIndex,
      reconnect: false,
    );
  } else if (client._endpointPool.length > 1) {
    final int ladderIndex = _selectAdaptiveTransportIndexInternal(
      client,
      excludeCurrent: false,
    );
    if (ladderIndex >= 0 && ladderIndex != client._activeEndpointIndex) {
      selectedProfile = await client.selectEndpoint(
        index: ladderIndex,
        reconnect: false,
      );
    }
  }

  if (!reusedNetworkAffinity &&
      preferLowestLatency &&
      client._endpointPool.length > 1) {
    pingResults = await client.pingEndpointPool(
      timeout: pingTimeout,
      updateHealth: false,
      connectivityProbeUrl:
          resolvedPreset.endpointPoolOptions.healthCheck.connectivityProbeUrl,
      connectivityProbeTimeout: resolvedPreset
          .endpointPoolOptions
          .healthCheck
          .connectivityProbeTimeout,
    );
    final int bestIndex = _bestPresetPingResultIndexInternal(
      client,
      pingResults,
    );
    if (bestIndex >= 0 && bestIndex != client._activeEndpointIndex) {
      selectedProfile = await client.selectEndpoint(
        index: bestIndex,
        reconnect: false,
      );
    }
  }

  await _maybeRequestPermissionsInternal(
    client,
    requestPermission: requestPermission,
  );
  await client.startManaged();

  final VpnProfile? finalSelected =
      selectedProfile ?? client.activeEndpointProfile;
  if (finalSelected != null) {
    await _rememberEndpointForCurrentNetworkInternal(
      client,
      finalSelected,
      networkClass: networkClass,
    );
  }

  final SubscriptionImportResult importResult = SubscriptionImportResult(
    subscription: filteredSubscription,
    poolSize: client._endpointPool.length,
    appliedProfile: client.activeEndpointProfile,
    appliedConfig: appliedConfig,
  );
  return AutoConnectResult(
    importResult: importResult,
    selectedProfile: finalSelected,
    pingResults: List<VpnPingResult>.unmodifiable(pingResults),
  );
}

int _selectAdaptiveTransportIndexInternal(
  SignboxVpn client, {
  required bool excludeCurrent,
}) {
  int bestIndex = -1;
  int bestTier = 1 << 20;
  int bestScore = -1;

  for (int index = 0; index < client._endpointPool.length; index++) {
    if (excludeCurrent && index == client._activeEndpointIndex) {
      continue;
    }
    if (_isCoolingDownInternal(client, index)) {
      continue;
    }

    final VpnProfile profile = client._endpointPool[index];
    final _EndpointHealthState health = client._endpointHealthStates[index];
    final int tier = _adaptiveTransportTierInternal(profile);
    if (tier < bestTier || (tier == bestTier && health.score > bestScore)) {
      bestTier = tier;
      bestScore = health.score;
      bestIndex = index;
    }
  }
  return bestIndex;
}

int _bestPresetPingResultIndexInternal(
  SignboxVpn client,
  List<VpnPingResult> pingResults,
) {
  int bestIndex = -1;
  int bestTier = 1 << 20;
  int bestLatencyMs = 1 << 30;

  for (int index = 0; index < pingResults.length; index++) {
    final VpnPingResult result = pingResults[index];
    final int? latencyMs = result.latencyMs;
    if (!result.success || latencyMs == null) {
      continue;
    }

    final int tier = _adaptiveTransportTierInternal(
      client._endpointPool[index],
    );
    if (tier < bestTier || (tier == bestTier && latencyMs < bestLatencyMs)) {
      bestTier = tier;
      bestLatencyMs = latencyMs;
      bestIndex = index;
    }
  }
  return bestIndex;
}
