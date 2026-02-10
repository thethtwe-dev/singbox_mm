part of '../singbox_mm_client.dart';

List<VpnDiagnosticIssue> _validateProfileInternal(
  SignboxVpn client,
  VpnProfile profile, {
  required bool strictTls,
}) {
  final List<VpnDiagnosticIssue> issues = <VpnDiagnosticIssue>[];

  if (profile.server.trim().isEmpty) {
    issues.add(
      VpnDiagnosticIssue(
        code: 'PROFILE_SERVER_EMPTY',
        message: 'Server host is empty.',
        severity: VpnDiagnosticSeverity.error,
        tag: profile.tag,
      ),
    );
  }

  if (profile.serverPort <= 0 || profile.serverPort > 65535) {
    issues.add(
      VpnDiagnosticIssue(
        code: 'PROFILE_PORT_INVALID',
        message: 'Server port must be within 1..65535.',
        severity: VpnDiagnosticSeverity.error,
        tag: profile.tag,
      ),
    );
  }

  if ((profile.protocol == VpnProtocol.vless ||
          profile.protocol == VpnProtocol.vmess ||
          profile.protocol == VpnProtocol.tuic) &&
      !SignboxVpn._uuidPattern.hasMatch(profile.uuid ?? '')) {
    issues.add(
      VpnDiagnosticIssue(
        code: 'PROFILE_UUID_INVALID',
        message: 'UUID format is invalid for ${profile.protocol.wireValue}.',
        severity: VpnDiagnosticSeverity.error,
        tag: profile.tag,
      ),
    );
  }

  if (SignboxVpn._tlsRecommendedProtocols.contains(profile.protocol) &&
      !profile.tls.enabled) {
    issues.add(
      VpnDiagnosticIssue(
        code: 'TLS_DISABLED',
        message:
            'TLS is disabled for ${profile.protocol.wireValue}; this is risky on hostile networks.',
        severity: strictTls
            ? VpnDiagnosticSeverity.error
            : VpnDiagnosticSeverity.warning,
        tag: profile.tag,
      ),
    );
  }

  if (profile.tls.enabled && profile.tls.allowInsecure) {
    issues.add(
      VpnDiagnosticIssue(
        code: 'TLS_INSECURE',
        message:
            'TLS certificate verification is disabled (allowInsecure=true).',
        severity: strictTls
            ? VpnDiagnosticSeverity.error
            : VpnDiagnosticSeverity.warning,
        tag: profile.tag,
      ),
    );
  }

  return issues;
}
