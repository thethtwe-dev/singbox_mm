part of '../singbox_mm_client.dart';

Future<SubscriptionImportResult> _importSubscriptionInternal(
  SignboxVpn client, {
  required String rawSubscription,
  required String source,
  required bool tryBase64Decode,
  required bool deduplicate,
  required String? sbmmPassphrase,
  required bool connect,
  required EndpointPoolOptions options,
  required BypassPolicy bypassPolicy,
  required TrafficThrottlePolicy throttlePolicy,
  required SingboxFeatureSettings? featureSettings,
}) async {
  final ParsedVpnSubscription parsed = client.parseSubscription(
    rawSubscription,
    source: source,
    tryBase64Decode: tryBase64Decode,
    deduplicate: deduplicate,
    sbmmPassphrase: sbmmPassphrase,
  );

  Map<String, Object?>? appliedConfig;
  VpnProfile? appliedProfile;
  if (parsed.profiles.isNotEmpty) {
    appliedConfig = await client.applyEndpointPool(
      profiles: parsed.profiles,
      options: options,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
    );
    appliedProfile = client.activeEndpointProfile;
    if (connect) {
      await client.startManaged();
    }
  }

  return SubscriptionImportResult(
    subscription: parsed,
    poolSize: client._endpointPool.length,
    appliedProfile: appliedProfile,
    appliedConfig: appliedConfig,
  );
}
