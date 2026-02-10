part of '../singbox_mm_client.dart';

Future<VpnProfile> _applyEndpointUsingPoolPolicyInternal(
  SignboxVpn client, {
  required int endpointIndex,
  required bool reconnect,
}) async {
  final VpnProfile selected = client._endpointPool[endpointIndex];
  await client.applyProfile(
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
  if (reconnect) {
    await client._guard(() => client._platform.restartVpn());
  }
  return selected;
}
