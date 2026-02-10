part of '../singbox_mm_client.dart';

extension SignboxVpnSubscriptionApi on SignboxVpn {
  ParsedVpnSubscription parseSubscription(
    String rawSubscription, {
    String source = 'inline',
    bool tryBase64Decode = true,
    bool deduplicate = true,
    String? sbmmPassphrase,
  }) {
    return _parseSubscriptionInternal(
      this,
      rawSubscription,
      source: source,
      tryBase64Decode: tryBase64Decode,
      deduplicate: deduplicate,
      sbmmPassphrase: sbmmPassphrase,
    );
  }

  List<VpnProfileSummary> extractSubscriptionSummaries(
    String rawSubscription, {
    String source = 'inline',
    bool tryBase64Decode = true,
    bool deduplicate = true,
    String? sbmmPassphrase,
  }) {
    return _extractSubscriptionSummariesInternal(
      this,
      rawSubscription,
      source: source,
      tryBase64Decode: tryBase64Decode,
      deduplicate: deduplicate,
      sbmmPassphrase: sbmmPassphrase,
    );
  }

  Future<SubscriptionImportResult> importSubscription({
    required String rawSubscription,
    String source = 'inline',
    bool tryBase64Decode = true,
    bool deduplicate = true,
    String? sbmmPassphrase,
    bool connect = false,
    EndpointPoolOptions options = const EndpointPoolOptions(),
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings? featureSettings,
  }) async {
    return _importSubscriptionInternal(
      this,
      rawSubscription: rawSubscription,
      source: source,
      tryBase64Decode: tryBase64Decode,
      deduplicate: deduplicate,
      sbmmPassphrase: sbmmPassphrase,
      connect: connect,
      options: options,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
    );
  }

  Future<AutoConnectResult> connectAutoSubscription({
    required String rawSubscription,
    String source = 'inline',
    bool tryBase64Decode = true,
    bool deduplicate = true,
    String? sbmmPassphrase,
    EndpointPoolOptions options = const EndpointPoolOptions(),
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings? featureSettings,
    bool requestPermission = true,
    bool preferLowestLatency = true,
    Duration pingTimeout = const Duration(seconds: 3),
  }) async {
    return _connectAutoSubscriptionInternal(
      this,
      rawSubscription: rawSubscription,
      source: source,
      tryBase64Decode: tryBase64Decode,
      deduplicate: deduplicate,
      sbmmPassphrase: sbmmPassphrase,
      options: options,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
      requestPermission: requestPermission,
      preferLowestLatency: preferLowestLatency,
      pingTimeout: pingTimeout,
    );
  }

  Future<AutoConnectResult> connectAutoWithPreset({
    required String rawSubscription,
    GfwPresetPack? preset,
    String source = 'inline',
    bool tryBase64Decode = true,
    bool deduplicate = true,
    String? sbmmPassphrase,
    bool requestPermission = true,
    bool preferLowestLatency = true,
    Duration pingTimeout = const Duration(seconds: 3),
  }) {
    return _connectAutoWithPresetInternal(
      this,
      rawSubscription: rawSubscription,
      preset: preset,
      source: source,
      tryBase64Decode: tryBase64Decode,
      deduplicate: deduplicate,
      sbmmPassphrase: sbmmPassphrase,
      requestPermission: requestPermission,
      preferLowestLatency: preferLowestLatency,
      pingTimeout: pingTimeout,
    );
  }
}
