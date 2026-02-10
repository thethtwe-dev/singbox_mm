part of '../singbox_mm_client.dart';

extension SignboxVpnEndpointApi on SignboxVpn {
  Future<Map<String, Object?>> applyProfile({
    required VpnProfile profile,
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings? featureSettings,
    bool clearEndpointPool = true,
  }) async {
    return _applyProfileInternal(
      this,
      profile: profile,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
      clearEndpointPool: clearEndpointPool,
    );
  }

  Future<Map<String, Object?>> applyEndpointPool({
    required List<VpnProfile> profiles,
    EndpointPoolOptions options = const EndpointPoolOptions(),
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings? featureSettings,
  }) async {
    return _applyEndpointPoolInternal(
      this,
      profiles: profiles,
      options: options,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
    );
  }

  Future<VpnProfile?> rotateEndpoint({bool reconnect = true}) async {
    return _rotateEndpointInternal(this, reconnect: reconnect);
  }

  Future<void> startManaged() async {
    await _startManagedInternal(this);
  }

  Future<VpnProfile?> selectEndpoint({
    required int index,
    bool reconnect = true,
  }) async {
    return _selectEndpointInternal(this, index: index, reconnect: reconnect);
  }

  Future<VpnProfile?> selectBestEndpointByPing({
    Duration timeout = const Duration(seconds: 3),
    bool reconnect = false,
  }) async {
    return _selectBestEndpointByPingInternal(
      this,
      timeout: timeout,
      reconnect: reconnect,
    );
  }
}
