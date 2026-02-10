part of '../singbox_mm_client.dart';

Future<void> _initializeInternal(
  SignboxVpn client,
  SingboxRuntimeOptions options,
) async {
  client._runtimeOptions = options;
  await client._guard(() => client._platform.initialize(options));
  await client.syncRuntimeState();
  await _resolveCoreCapabilitiesInternal(client, refresh: true);
}

void _setFeatureSettingsInternal(
  SignboxVpn client,
  SingboxFeatureSettings settings,
) {
  client._featureSettings = settings;
}

Map<String, Object?> _buildConfigInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings featureSettings,
}) {
  return client._configBuilder.build(
    profile: profile,
    bypassPolicy: bypassPolicy,
    throttlePolicy: throttlePolicy,
    settings: featureSettings,
    logLevel: client._runtimeOptions.logLevel,
    tunInterfaceName: client._runtimeOptions.tunInterfaceName,
    tunInet4Address: client._runtimeOptions.tunInet4Address,
  );
}
