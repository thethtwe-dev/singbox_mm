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
    if (options.pingEnabled || options.connectivityProbeEnabled) {
      final (
        bool hasPositiveSignal,
        bool shouldCountFailure,
      ) = await _runEndpointSignalChecksInternal(
        client,
        options,
        allowFailureCounting: !withinStartupGrace,
      );
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
  final int baseIntervalMs = options.checkInterval.inMilliseconds;
  if (baseIntervalMs < 1000) {
    client._healthTickCounter++;
    return true;
  }
  if (client._activeEndpointIndex < 0 ||
      client._activeEndpointIndex >= client._endpointHealthStates.length) {
    client._healthTickCounter++;
    return true;
  }

  final _EndpointHealthState state =
      client._endpointHealthStates[client._activeEndpointIndex];
  final bool stable =
      state.consecutiveFailures == 0 && state.lastSuccessAt != null;
  final int stride = stable ? 3 : 1;
  client._healthTickCounter++;
  return client._healthTickCounter % stride == 0;
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
