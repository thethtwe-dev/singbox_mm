part of '../singbox_mm_client.dart';

Future<void> _runHealthCheckTickInternal(SignboxVpn client) async {
  try {
    if (client._endpointPool.isEmpty ||
        !client._endpointPoolOptions.autoFailover) {
      return;
    }
    if (client._failoverInProgress || client._manualStopRequested) {
      return;
    }

    final VpnHealthCheckOptions options =
        client._endpointPoolOptions.healthCheck;
    if (!options.enabled ||
        (!options.failoverOnNoTraffic &&
            !options.pingEnabled &&
            !options.connectivityProbeEnabled)) {
      return;
    }

    final VpnConnectionState state = await client.getState();
    if (state != VpnConnectionState.connected) {
      return;
    }

    bool hasPositiveHealthSignal = false;
    if (client._activeEndpointIndex >= 0 &&
        (options.pingEnabled || options.connectivityProbeEnabled)) {
      final (bool hasPositiveSignal, bool shouldCountFailure) =
          await _runEndpointSignalChecksInternal(client, options);
      hasPositiveHealthSignal = hasPositiveSignal;

      if (shouldCountFailure) {
        await _markEndpointFailureAndMaybeFailoverInternal(client, options);
        return;
      }
    }

    await _evaluateNoTrafficHealthInternal(
      client,
      options,
      hasPositiveHealthSignal: hasPositiveHealthSignal,
    );
  } on Object {
    // Health checks are best-effort and should not crash caller flow.
  }
}

Future<void> _markEndpointFailureAndMaybeFailoverInternal(
  SignboxVpn client,
  VpnHealthCheckOptions options,
) async {
  _markEndpointFailureInternal(client, client._activeEndpointIndex);
  final _EndpointHealthState endpointState =
      client._endpointHealthStates[client._activeEndpointIndex];
  if (endpointState.consecutiveFailures >= options.maxConsecutiveFailures) {
    await _attemptFailoverInternal(client);
  }
}
