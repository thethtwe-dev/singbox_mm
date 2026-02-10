class SingboxEndpointSummary {
  const SingboxEndpointSummary({
    required this.outboundIndex,
    required this.type,
    required this.tag,
    required this.remark,
    required this.server,
    required this.serverPort,
    required this.transportType,
    required this.tlsEnabled,
    required this.rawOutbound,
  });

  final int outboundIndex;
  final String type;
  final String? tag;
  final String? remark;
  final String? server;
  final int? serverPort;
  final String? transportType;
  final bool tlsEnabled;
  final Map<String, Object?> rawOutbound;

  bool get hasAddress =>
      server != null && server!.isNotEmpty && serverPort != null;
}
