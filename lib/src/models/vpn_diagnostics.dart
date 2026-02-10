import 'vpn_connectivity_probe.dart';
import 'vpn_connection_state.dart';
import 'vpn_ping_result.dart';
import 'vpn_runtime_stats.dart';

enum VpnDiagnosticSeverity { info, warning, error }

class VpnDiagnosticIssue {
  const VpnDiagnosticIssue({
    required this.code,
    required this.message,
    this.severity = VpnDiagnosticSeverity.warning,
    this.tag,
  });

  final String code;
  final String message;
  final VpnDiagnosticSeverity severity;
  final String? tag;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code,
      'message': message,
      'severity': severity.name,
      'tag': tag,
    };
  }
}

class VpnDiagnosticsReport {
  const VpnDiagnosticsReport({
    required this.generatedAt,
    required this.state,
    required this.issues,
    this.stats,
    this.pingResults = const <VpnPingResult>[],
    this.connectivityProbe,
  });

  final DateTime generatedAt;
  final VpnConnectionState state;
  final VpnRuntimeStats? stats;
  final List<VpnDiagnosticIssue> issues;
  final List<VpnPingResult> pingResults;
  final VpnConnectivityProbe? connectivityProbe;

  bool get hasErrors => issues.any(
    (VpnDiagnosticIssue issue) => issue.severity == VpnDiagnosticSeverity.error,
  );

  bool get hasWarnings => issues.any(
    (VpnDiagnosticIssue issue) =>
        issue.severity == VpnDiagnosticSeverity.warning,
  );

  bool get healthy => !hasErrors;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'generatedAt': generatedAt.toIso8601String(),
      'state': state.wireValue,
      'healthy': healthy,
      'issues': issues.map((VpnDiagnosticIssue issue) => issue.toMap()).toList(
        growable: false,
      ),
      'pingResults': pingResults.map((VpnPingResult item) => item.toMap()).toList(
        growable: false,
      ),
      'stats': stats?.toMap(),
      'connectivityProbe': connectivityProbe?.toMap(),
    };
  }
}
