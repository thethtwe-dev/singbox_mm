part of '../singbox_mm_client.dart';

Future<Map<String, Object?>> _applyEndpointPoolInternal(
  SignboxVpn client, {
  required List<VpnProfile> profiles,
  required EndpointPoolOptions options,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
}) async {
  if (profiles.isEmpty) {
    throw ArgumentError('Endpoint pool cannot be empty.');
  }
  final List<VpnProfile> supportedProfiles =
      await _filterSupportedProfilesForCoreInternal(client, profiles);

  client._endpointPool
    ..clear()
    ..addAll(supportedProfiles);
  client._endpointHealthStates
    ..clear()
    ..addAll(
      List<_EndpointHealthState>.generate(
        supportedProfiles.length,
        (_) => const _EndpointHealthState(),
      ),
    );
  client._endpointPoolOptions = options;
  client._endpointBypassPolicy = bypassPolicy;
  client._endpointThrottlePolicy = throttlePolicy;
  final int initialMtuProbeCursor = _resolveInitialMtuProbeCursorInternal(
    throttlePolicy,
  );
  client._endpointMtuProbeCursorByTag
    ..clear()
    ..addEntries(
      supportedProfiles.map<MapEntry<String, int>>(
        (VpnProfile profile) =>
            MapEntry<String, int>(profile.tag, initialMtuProbeCursor),
      ),
    );
  client._endpointFeatureSettings = featureSettings ?? client._featureSettings;
  client._featureSettings = client._endpointFeatureSettings;
  client._standaloneProfile = null;
  client._activeEndpointIndex = _selectInitialEndpointIndexInternal(client);
  client._manualStopRequested = false;
  _resetTrafficTrackingInternal(client);

  final VpnProfile selected = client._endpointPool[client._activeEndpointIndex];
  final Map<String, Object?> config = await client.applyProfile(
    profile: selected,
    bypassPolicy: client._endpointBypassPolicy,
    throttlePolicy: _effectiveThrottlePolicyForProfileInternal(
      client,
      profile: selected,
      base: client._endpointThrottlePolicy,
    ),
    featureSettings: client._endpointFeatureSettings,
    clearEndpointPool: false,
  );
  await _rememberEndpointForCurrentNetworkInternal(client, selected);

  _ensureManagedStateSubscriptionInternal(client);
  _restartHealthMonitorIfNeededInternal(client);
  return config;
}

Future<void> _startManagedInternal(SignboxVpn client) async {
  client._manualStopRequested = false;
  _ensureManagedStateSubscriptionInternal(client);
  _restartHealthMonitorIfNeededInternal(client);
  _resetTrafficTrackingInternal(client);
  await client.start();
}
