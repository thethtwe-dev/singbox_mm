part of '../singbox_mm_client.dart';

Future<VpnDiagnosticsReport> _runDiagnosticsInternal(
  SignboxVpn client, {
  required bool strictTls,
  required bool includeEndpointPoolPing,
  required bool includeConnectivityProbe,
  required Duration pingTimeout,
  required Duration connectivityTimeout,
}) async {
  final (
    state: VpnConnectionState state,
    stats: VpnRuntimeStats? stats,
    profile: VpnProfile? profile,
    issues: List<VpnDiagnosticIssue> issues,
  ) = await _collectDiagnosticsStateInternal(
    client,
    strictTls: strictTls,
  );

  final (
    pingResults: List<VpnPingResult> pingResults,
    connectivityProbe: VpnConnectivityProbe? connectivityProbe,
  ) = await _collectDiagnosticsChecksInternal(
    client,
    state: state,
    profile: profile,
    includeEndpointPoolPing: includeEndpointPoolPing,
    includeConnectivityProbe: includeConnectivityProbe,
    pingTimeout: pingTimeout,
    connectivityTimeout: connectivityTimeout,
    issues: issues,
  );

  return VpnDiagnosticsReport(
    generatedAt: DateTime.now().toUtc(),
    state: state,
    stats: stats,
    issues: List<VpnDiagnosticIssue>.unmodifiable(issues),
    pingResults: List<VpnPingResult>.unmodifiable(pingResults),
    connectivityProbe: connectivityProbe,
  );
}
