class VpnPingResult {
  static const String methodTcpConnect = 'tcp_connect';
  static const String methodConnectivityProbe = 'connectivity_probe';

  const VpnPingResult({
    required this.host,
    required this.port,
    required this.checkedAt,
    this.tag,
    this.latency,
    this.error,
    this.checkMethod = methodTcpConnect,
  });

  final String host;
  final int port;
  final String? tag;
  final Duration? latency;
  final String? error;
  final DateTime checkedAt;
  final String checkMethod;

  bool get success => error == null && latency != null;
  int? get latencyMs => latency?.inMilliseconds;

  VpnPingResult copyWith({
    String? host,
    int? port,
    String? tag,
    Duration? latency,
    bool clearLatency = false,
    String? error,
    bool clearError = false,
    DateTime? checkedAt,
    String? checkMethod,
  }) {
    return VpnPingResult(
      host: host ?? this.host,
      port: port ?? this.port,
      tag: tag ?? this.tag,
      latency: clearLatency ? null : (latency ?? this.latency),
      error: clearError ? null : (error ?? this.error),
      checkedAt: checkedAt ?? this.checkedAt,
      checkMethod: checkMethod ?? this.checkMethod,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'host': host,
      'port': port,
      'tag': tag,
      'success': success,
      'latencyMs': latencyMs,
      'error': error,
      'checkMethod': checkMethod,
      'checkedAt': checkedAt.toIso8601String(),
    };
  }

  factory VpnPingResult.fromMap(
    Map<Object?, Object?> raw, {
    required String host,
    required int port,
    String? tag,
  }) {
    final Object? latencyRaw = raw['latencyMs'];
    final int? latencyMs;
    if (latencyRaw is int) {
      latencyMs = latencyRaw;
    } else if (latencyRaw is num) {
      latencyMs = latencyRaw.toInt();
    } else if (latencyRaw is String) {
      latencyMs = int.tryParse(latencyRaw);
    } else {
      latencyMs = null;
    }

    final bool ok = raw['ok'] == true || raw['success'] == true;
    final String? error = raw['error']?.toString();
    final String methodRaw = raw['checkMethod']?.toString().trim() ?? '';
    return VpnPingResult(
      host: host,
      port: port,
      tag: tag,
      latency: latencyMs == null ? null : Duration(milliseconds: latencyMs),
      error: ok ? null : (error ?? 'Ping failed'),
      checkMethod: methodRaw.isEmpty ? methodTcpConnect : methodRaw,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  factory VpnPingResult.failure({
    required String host,
    required int port,
    String? tag,
    required String error,
    String checkMethod = methodTcpConnect,
  }) {
    return VpnPingResult(
      host: host,
      port: port,
      tag: tag,
      error: error,
      checkMethod: checkMethod,
      checkedAt: DateTime.now().toUtc(),
    );
  }
}
