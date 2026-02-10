part of '../singbox_mm_client.dart';

Future<Map<String, Object?>> _applyProfileInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
  required bool clearEndpointPool,
}) async {
  await _assertCoreSupportsProfileInternal(client, profile);
  if (clearEndpointPool) {
    _clearEndpointPoolContextInternal(client);
    client._standaloneProfile = profile;
  } else {
    client._standaloneProfile = null;
  }
  if (featureSettings != null) {
    client._featureSettings = featureSettings;
  }
  final SingboxFeatureSettings effectiveSettings =
      featureSettings ?? client._featureSettings;
  final TrafficThrottlePolicy effectiveThrottlePolicy =
      _effectiveThrottlePolicyForProfileInternal(
        client,
        profile: profile,
        base: throttlePolicy,
      );
  final Map<String, Object?> config = _buildConfigInternal(
    client,
    profile: profile,
    bypassPolicy: bypassPolicy,
    throttlePolicy: effectiveThrottlePolicy,
    featureSettings: effectiveSettings,
  );
  await client.setRawConfig(config);
  return config;
}

Future<Map<String, Object?>> _applyConfigLinkInternal(
  SignboxVpn client, {
  required String configLink,
  required String? fallbackTag,
  required String? sbmmPassphrase,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
}) async {
  final ParsedVpnConfig parsed = client.parseConfigLink(
    configLink,
    fallbackTag: fallbackTag,
    sbmmPassphrase: sbmmPassphrase,
  );
  return client.applyProfile(
    profile: parsed.profile,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    featureSettings: featureSettings,
  );
}
