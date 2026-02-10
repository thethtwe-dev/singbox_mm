part of '../singbox_mm_client.dart';

Future<(bool hasPositiveSignal, bool shouldCountFailure)>
_runEndpointSignalChecksInternal(
  SignboxVpn client,
  VpnHealthCheckOptions options,
) async {
  bool hasPositiveHealthSignal = false;
  bool shouldCountFailure = false;

  VpnPingResult? pingResult;
  VpnConnectivityProbe? probeResult;

  final List<Future<void>> checks = <Future<void>>[];
  final VpnProfile active = client._endpointPool[client._activeEndpointIndex];

  if (options.pingEnabled) {
    checks.add(() async {
      pingResult = await client.pingProfile(
        profile: active,
        timeout: options.pingTimeout,
        connectivityProbeUrl: options.connectivityProbeUrl,
        connectivityProbeTimeout: options.connectivityProbeTimeout,
      );
    }());
  }
  if (options.connectivityProbeEnabled) {
    checks.add(() async {
      probeResult = await client.probeConnectivity(
        url: options.connectivityProbeUrl,
        timeout: options.connectivityProbeTimeout,
      );
    }());
  }

  await Future.wait(checks);

  final bool pingSucceeded = pingResult?.success == true;
  final bool pingFailed = pingResult != null && !pingSucceeded;
  final bool probeSucceeded = probeResult?.success == true;
  final bool probeFailed = probeResult != null && !probeSucceeded;

  if (pingResult != null) {
    if (pingSucceeded) {
      hasPositiveHealthSignal = true;
      _markEndpointProgressInternal(
        client,
        client._activeEndpointIndex,
        pingResult!.checkedAt,
      );
    }
  }
  if (probeResult != null) {
    if (probeSucceeded) {
      hasPositiveHealthSignal = true;
      _markEndpointProgressInternal(
        client,
        client._activeEndpointIndex,
        probeResult!.checkedAt,
      );
    }
  }

  if (pingFailed && options.failoverOnPingFailure && !probeSucceeded) {
    shouldCountFailure = true;
  }
  if (probeFailed && options.failoverOnConnectivityFailure) {
    shouldCountFailure = true;
  }

  if (hasPositiveHealthSignal) {
    _markEndpointSuccessInternal(client, client._activeEndpointIndex);
  }

  return (hasPositiveHealthSignal, shouldCountFailure);
}
