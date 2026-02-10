part of '../singbox_mm_client.dart';

Future<void> _disposeInternal(SignboxVpn client) async {
  _stopHealthMonitorInternal(client);
  await client._managedStateSubscription?.cancel();
  client._managedStateSubscription = null;
}

Future<void> _resetProfileInternal(
  SignboxVpn client, {
  required bool stopVpn,
}) async {
  client._manualStopRequested = true;
  _clearEndpointPoolContextInternal(client);
  client._standaloneProfile = null;
  client._featureSettings = const SingboxFeatureSettings();
  client._lastManagedState = VpnConnectionState.disconnected;
  _resetTrafficTrackingInternal(client);

  if (!stopVpn) {
    return;
  }

  try {
    await client._guard(() => client._platform.stopVpn());
  } on SignboxVpnException {
    // Reset should be resilient even if underlying state is already stopped.
  }
}

void _clearEndpointPoolContextInternal(SignboxVpn client) {
  _stopHealthMonitorInternal(client);
  client._endpointPool.clear();
  client._endpointHealthStates.clear();
  client._endpointMtuProbeCursorByTag.clear();
  client._activeEndpointIndex = -1;
  client._endpointPoolOptions = const EndpointPoolOptions();
  client._endpointBypassPolicy = const BypassPolicy();
  client._endpointThrottlePolicy = const TrafficThrottlePolicy();
  client._endpointFeatureSettings = const SingboxFeatureSettings();
}
