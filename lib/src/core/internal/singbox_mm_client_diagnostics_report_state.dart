part of '../singbox_mm_client.dart';

Future<
  ({
    VpnConnectionState state,
    VpnRuntimeStats? stats,
    VpnProfile? profile,
    List<VpnDiagnosticIssue> issues,
  })
>
_collectDiagnosticsStateInternal(
  SignboxVpn client, {
  required bool strictTls,
}) async {
  final List<VpnDiagnosticIssue> issues = <VpnDiagnosticIssue>[];
  VpnConnectionState state = VpnConnectionState.disconnected;
  VpnRuntimeStats? stats;
  final VpnProfile? profile = client.activeProfile;

  try {
    state = await client.getState();
  } on Object catch (error) {
    issues.add(
      VpnDiagnosticIssue(
        code: 'STATE_UNAVAILABLE',
        message: 'Unable to query VPN state: $error',
        severity: VpnDiagnosticSeverity.error,
      ),
    );
  }

  try {
    stats = await client.getStats();
  } on Object catch (error) {
    issues.add(
      VpnDiagnosticIssue(
        code: 'STATS_UNAVAILABLE',
        message: 'Unable to query VPN runtime stats: $error',
        severity: VpnDiagnosticSeverity.warning,
      ),
    );
  }

  if (client._endpointPool.isEmpty && profile == null) {
    issues.add(
      const VpnDiagnosticIssue(
        code: 'PROFILE_MISSING',
        message: 'No active profile configured.',
        severity: VpnDiagnosticSeverity.warning,
      ),
    );
  } else if (client._endpointPool.isEmpty && profile != null) {
    issues.addAll(client.validateProfile(profile, strictTls: strictTls));
  } else {
    for (final VpnProfile endpoint in client._endpointPool) {
      issues.addAll(client.validateProfile(endpoint, strictTls: strictTls));
    }
  }

  if (client._featureSettings.advanced.debugMode) {
    issues.add(
      const VpnDiagnosticIssue(
        code: 'DEBUG_MODE_ENABLED',
        message: 'Debug mode is enabled. Disable it for production.',
        severity: VpnDiagnosticSeverity.warning,
      ),
    );
  }

  return (state: state, stats: stats, profile: profile, issues: issues);
}
