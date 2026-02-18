part of '../singbox_mm_client.dart';

Future<void> _runHealthCheckTickInternal(SignboxVpn client) async {
  try {
    if (!client._endpointPoolOptions.autoFailover ||
        client._endpointPool.isEmpty) {
      return;
    }
    if (client._failoverInProgress || client._manualStopRequested) {
      return;
    }
    if (client._activeEndpointIndex < 0 ||
        client._activeEndpointIndex >= client._endpointPool.length) {
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
    final DateTime now = DateTime.now().toUtc();
    final DateTime? connectedAt = client._lastConnectedAt;
    final bool withinStartupGrace =
        connectedAt != null &&
        now.difference(connectedAt) < options.startupGracePeriod;
    if (!_shouldRunActiveHealthChecksInternal(client, options)) {
      return;
    }

    bool hasPositiveHealthSignal = false;
    bool connectivityProbeSucceeded = false;
    if (options.pingEnabled || options.connectivityProbeEnabled) {
      final (
        bool hasPositiveSignal,
        bool shouldCountFailure,
        bool probeSucceeded,
      ) = await _runEndpointSignalChecksInternal(
        client,
        options,
        allowFailureCounting: !withinStartupGrace,
      );
      hasPositiveHealthSignal = hasPositiveSignal;
      connectivityProbeSucceeded = probeSucceeded;

      if (shouldCountFailure) {
        await _markEndpointFailureAndMaybeFailoverInternal(client, options);
        return;
      }
    }

    await _evaluateNoTrafficHealthInternal(
      client,
      options,
      hasPositiveHealthSignal: hasPositiveHealthSignal,
      connectivityProbeSucceeded: connectivityProbeSucceeded,
      allowFailureCounting: !withinStartupGrace,
    );
  } on Object {
    // Health checks are best-effort and should not crash caller flow.
  }
}

bool _shouldRunActiveHealthChecksInternal(
  SignboxVpn client,
  VpnHealthCheckOptions options,
) {
  client._healthTickCounter++;
  return true;
}

Future<void> _markEndpointFailureAndMaybeFailoverInternal(
  SignboxVpn client,
  VpnHealthCheckOptions options,
) async {
  _markEndpointFailureInternal(client, client._activeEndpointIndex);
  final _EndpointHealthState endpointState =
      client._endpointHealthStates[client._activeEndpointIndex];
  final int minimumFailures = client._endpointPool.length < 2
      ? max(2, options.maxConsecutiveFailures)
      : options.maxConsecutiveFailures;
  if (endpointState.consecutiveFailures >= minimumFailures) {
    await _attemptFailoverInternal(client);
  }
}
