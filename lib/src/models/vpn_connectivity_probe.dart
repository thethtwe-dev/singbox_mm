class VpnConnectivityProbe {
  const VpnConnectivityProbe({
    required this.url,
    required this.checkedAt,
    this.statusCode,
    this.latency,
    this.error,
  });

  final String url;
  final int? statusCode;
  final Duration? latency;
  final String? error;
  final DateTime checkedAt;

  bool get success {
    if (error != null) {
      return false;
    }
    final int? code = statusCode;
    if (code == null) {
      return false;
    }
    return code >= 200 && code < 400;
  }

  int? get latencyMs => latency?.inMilliseconds;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'url': url,
      'statusCode': statusCode,
      'latencyMs': latencyMs,
      'error': error,
      'checkedAt': checkedAt.toIso8601String(),
      'success': success,
    };
  }

  factory VpnConnectivityProbe.failure({
    required String url,
    required String error,
  }) {
    return VpnConnectivityProbe(
      url: url,
      error: error,
      checkedAt: DateTime.now().toUtc(),
    );
  }
}
