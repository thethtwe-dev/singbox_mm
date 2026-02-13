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

  if (!client._endpointPoolOptions.autoFailover ||
      client._endpointPool.isEmpty) {
    return;
  }
  if (client._manualStopRequested || client._failoverInProgress) {
    return;
  }

  switch (state) {
    case VpnConnectionState.connected:
      client._lastConnectedAt = DateTime.now().toUtc();
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
      client._lastConnectedAt = null;
      // Native notification stop emits a marker error so managed mode can
      // suppress auto-failover reconnect and remain explicitly stopped.
      try {
        final VpnConnectionSnapshot snapshot = await client.getStateDetails();
        if (snapshot.lastError == SignboxVpn._stoppedByUserErrorMarker) {
          client._manualStopRequested = true;
          return;
        }
      } on Object {
        // Ignore state detail read failures and continue with failover logic.
      }
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
