part of '../singbox_mm_client.dart';

Future<ManualConnectResult> _connectManualProfileInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
  required bool requestPermission,
}) async {
  final Map<String, Object?> config = await client.applyProfile(
    profile: profile,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    featureSettings: featureSettings,
  );
  await _maybeRequestPermissionsInternal(
    client,
    requestPermission: requestPermission,
  );
  await client.start();
  await _rememberEndpointForCurrentNetworkInternal(client, profile);
  return ManualConnectResult(profile: profile, appliedConfig: config);
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
  return ManualConnectResult(
    profile: result.profile,
    appliedConfig: result.appliedConfig,
    warnings: parsed.warnings,
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
      warnings: parsed.warnings,
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
