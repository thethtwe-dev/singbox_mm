enum EndpointRotationStrategy { roundRobin, healthiest }

class VpnHealthCheckOptions {
  const VpnHealthCheckOptions({
    this.enabled = true,
    this.checkInterval = const Duration(seconds: 2),
    this.noTrafficTimeout = const Duration(seconds: 8),
    this.pingEnabled = true,
    this.pingTimeout = const Duration(milliseconds: 900),
    this.connectivityProbeEnabled = true,
    this.connectivityProbeUrl,
    this.connectivityProbeTimeout = const Duration(milliseconds: 1500),
    this.maxConsecutiveFailures = 1,
    this.failoverOnNoTraffic = true,
    this.failoverOnPingFailure = true,
    this.failoverOnConnectivityFailure = true,
    this.failoverOnError = true,
    this.failoverOnDisconnect = true,
    this.failurePenalty = 25,
    this.successBonus = 5,
    this.coolDown = const Duration(seconds: 20),
  });

  final bool enabled;
  final Duration checkInterval;
  final Duration noTrafficTimeout;
  final bool pingEnabled;
  final Duration pingTimeout;
  final bool connectivityProbeEnabled;
  final String? connectivityProbeUrl;
  final Duration connectivityProbeTimeout;
  final int maxConsecutiveFailures;
  final bool failoverOnNoTraffic;
  final bool failoverOnPingFailure;
  final bool failoverOnConnectivityFailure;
  final bool failoverOnError;
  final bool failoverOnDisconnect;
  final int failurePenalty;
  final int successBonus;
  final Duration coolDown;
}

class EndpointPoolOptions {
  const EndpointPoolOptions({
    this.autoFailover = true,
    this.rotationStrategy = EndpointRotationStrategy.healthiest,
    this.healthCheck = const VpnHealthCheckOptions(),
  });

  final bool autoFailover;
  final EndpointRotationStrategy rotationStrategy;
  final VpnHealthCheckOptions healthCheck;
}

class VpnEndpointHealth {
  const VpnEndpointHealth({
    required this.tag,
    required this.score,
    required this.consecutiveFailures,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastProgressAt,
  });

  final String tag;
  final int score;
  final int consecutiveFailures;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final DateTime? lastProgressAt;
}
