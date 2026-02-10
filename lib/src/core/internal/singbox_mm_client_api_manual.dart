part of '../singbox_mm_client.dart';

extension SignboxVpnManualConnectApi on SignboxVpn {
  Future<ManualConnectResult> connectManualProfile({
    required VpnProfile profile,
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings? featureSettings,
    bool requestPermission = true,
  }) async {
    return _connectManualProfileInternal(
      this,
      profile: profile,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
      requestPermission: requestPermission,
    );
  }

  Future<ManualConnectResult> connectManualConfigLink({
    required String configLink,
    String? fallbackTag,
    String? sbmmPassphrase,
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings? featureSettings,
    bool requestPermission = true,
  }) async {
    return _connectManualConfigLinkInternal(
      this,
      configLink: configLink,
      fallbackTag: fallbackTag,
      sbmmPassphrase: sbmmPassphrase,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
      requestPermission: requestPermission,
    );
  }

  Future<ManualConnectResult> connectManualWithPreset({
    required VpnProfile profile,
    GfwPresetPack? preset,
    bool requestPermission = true,
  }) {
    return _connectManualWithPresetInternal(
      this,
      profile: profile,
      preset: preset,
      requestPermission: requestPermission,
    );
  }

  Future<ManualConnectResult> connectManualConfigLinkWithPreset({
    required String configLink,
    String? fallbackTag,
    String? sbmmPassphrase,
    GfwPresetPack? preset,
    bool requestPermission = true,
  }) {
    return _connectManualConfigLinkWithPresetInternal(
      this,
      configLink: configLink,
      fallbackTag: fallbackTag,
      sbmmPassphrase: sbmmPassphrase,
      preset: preset,
      requestPermission: requestPermission,
    );
  }
}
