part of '../singbox_mm_client.dart';

Future<
  ({List<VpnPingResult> pingResults, VpnConnectivityProbe? connectivityProbe})
>
_collectDiagnosticsChecksInternal(
  SignboxVpn client, {
  required VpnConnectionState state,
  required VpnProfile? profile,
  required bool includeEndpointPoolPing,
  required bool includeConnectivityProbe,
  required Duration pingTimeout,
  required Duration connectivityTimeout,
  required List<VpnDiagnosticIssue> issues,
}) async {
  List<VpnPingResult> pingResults = const <VpnPingResult>[];
  VpnConnectivityProbe? connectivityProbe;

  if (includeEndpointPoolPing && client._endpointPool.isNotEmpty) {
    pingResults = await client.pingEndpointPool(
      timeout: pingTimeout,
      updateHealth: false,
      connectivityProbeTimeout: connectivityTimeout,
    );
    for (final VpnPingResult result in pingResults) {
      if (!result.success) {
        issues.add(_createPingFailureIssueInternal(result));
      }
    }
  } else if (includeEndpointPoolPing && profile != null) {
    final VpnPingResult result = await client.pingProfile(
      profile: profile,
      timeout: pingTimeout,
      connectivityProbeTimeout: connectivityTimeout,
    );
    pingResults = <VpnPingResult>[result];
    if (!result.success) {
      issues.add(_createPingFailureIssueInternal(result));
    }
  }

  if (includeConnectivityProbe) {
    connectivityProbe = await client.probeConnectivity(
      timeout: connectivityTimeout,
    );
    if (!connectivityProbe.success) {
      issues.add(
        _createConnectivityFailureIssueInternal(
          state: state,
          probe: connectivityProbe,
        ),
      );
    }
  }

  return (pingResults: pingResults, connectivityProbe: connectivityProbe);
}

VpnDiagnosticIssue _createPingFailureIssueInternal(VpnPingResult result) {
  return VpnDiagnosticIssue(
    code: 'PING_FAILED',
    message:
        'Ping (${result.checkMethod}) failed for ${result.tag ?? result.host}:${result.port} - ${result.error}',
    severity: VpnDiagnosticSeverity.warning,
    tag: result.tag,
  );
}

VpnDiagnosticIssue _createConnectivityFailureIssueInternal({
  required VpnConnectionState state,
  required VpnConnectivityProbe probe,
}) {
  return VpnDiagnosticIssue(
    code: 'CONNECTIVITY_FAILED',
    message:
        'Connectivity probe failed for ${probe.url}: ${probe.error ?? "unknown error"}',
    severity: state == VpnConnectionState.connected
        ? VpnDiagnosticSeverity.error
        : VpnDiagnosticSeverity.warning,
  );
}
