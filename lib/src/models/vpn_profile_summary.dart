import 'vpn_profile.dart';

class VpnProfileSummary {
  const VpnProfileSummary({
    required this.index,
    required this.remark,
    required this.protocol,
    required this.host,
    required this.port,
    required this.transport,
    required this.tlsEnabled,
    this.tlsServerName,
    this.warnings = const <String>[],
  });

  final int index;
  final String remark;
  final VpnProtocol protocol;
  final String host;
  final int port;
  final VpnTransport transport;
  final bool tlsEnabled;
  final String? tlsServerName;
  final List<String> warnings;

  String get endpoint => '$host:$port';

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'index': index,
      'remark': remark,
      'protocol': protocol.wireValue,
      'host': host,
      'port': port,
      'endpoint': endpoint,
      'transport': transport.wireValue,
      'tlsEnabled': tlsEnabled,
      'tlsServerName': tlsServerName,
      'warnings': List<String>.unmodifiable(warnings),
    };
  }
}
