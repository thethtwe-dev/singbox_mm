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
}) {
  final GfwPresetPack resolvedPreset = preset ?? GfwPresetPack.balanced();
  return client.connectAutoSubscription(
    rawSubscription: rawSubscription,
    source: source,
    tryBase64Decode: tryBase64Decode,
    deduplicate: deduplicate,
    sbmmPassphrase: sbmmPassphrase,
    options: resolvedPreset.endpointPoolOptions,
    bypassPolicy: resolvedPreset.bypassPolicy,
    throttlePolicy: resolvedPreset.throttlePolicy,
    featureSettings: resolvedPreset.featureSettings,
    requestPermission: requestPermission,
    preferLowestLatency: preferLowestLatency,
    pingTimeout: pingTimeout,
  );
}
