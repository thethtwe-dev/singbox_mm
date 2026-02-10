part of '../singbox_mm_client.dart';

void _ensureManagedStateSubscriptionInternal(SignboxVpn client) {
  if (client._managedStateSubscription != null) {
    return;
  }
  client._managedStateSubscription = client._platform.stateStream.listen((
    VpnConnectionState state,
  ) {
    unawaited(_handleManagedStateChangeInternal(client, state));
  });
}

Future<void> _handleManagedStateChangeInternal(
  SignboxVpn client,
  VpnConnectionState state,
) async {
  final VpnConnectionState previous = client._lastManagedState;
  client._lastManagedState = state;

  if (client._endpointPool.isEmpty ||
      !client._endpointPoolOptions.autoFailover) {
    return;
  }
  if (client._manualStopRequested || client._failoverInProgress) {
    return;
  }

  switch (state) {
    case VpnConnectionState.connected:
      _markEndpointSuccessInternal(client, client._activeEndpointIndex);
      _resetTrafficTrackingInternal(client);
      return;
    case VpnConnectionState.error:
      if (client._endpointPoolOptions.healthCheck.failoverOnError) {
        _markEndpointFailureInternal(client, client._activeEndpointIndex);
        await _attemptFailoverInternal(client);
      }
      return;
    case VpnConnectionState.disconnected:
      if (previous == VpnConnectionState.connected &&
          client._endpointPoolOptions.healthCheck.failoverOnDisconnect) {
        _markEndpointFailureInternal(client, client._activeEndpointIndex);
        await _attemptFailoverInternal(client);
      }
      return;
    case VpnConnectionState.connecting:
    case VpnConnectionState.disconnecting:
    case VpnConnectionState.preparing:
      return;
  }
}
