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
  return client.connectManualProfile(
    profile: profile,
    bypassPolicy: resolvedPreset.bypassPolicy,
    throttlePolicy: resolvedPreset.throttlePolicy,
    featureSettings: resolvedPreset.featureSettings,
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
  return client.connectManualConfigLink(
    configLink: configLink,
    fallbackTag: fallbackTag,
    sbmmPassphrase: sbmmPassphrase,
    bypassPolicy: resolvedPreset.bypassPolicy,
    throttlePolicy: resolvedPreset.throttlePolicy,
    featureSettings: resolvedPreset.featureSettings,
    requestPermission: requestPermission,
  );
}
