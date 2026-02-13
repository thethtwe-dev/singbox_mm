/// Rotation strategy for selecting the next endpoint in a pool.
enum EndpointRotationStrategy { roundRobin, healthiest }

/// Health-monitor settings that drive automatic endpoint failover.
class VpnHealthCheckOptions {
  /// Creates health-check options with resilient defaults.
  const VpnHealthCheckOptions({
    this.enabled = true,
    this.checkInterval = const Duration(seconds: 2),
    this.startupGracePeriod = const Duration(seconds: 12),
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

  /// Whether periodic health evaluation is enabled.
  final bool enabled;

  /// Interval between health-check ticks.
  final Duration checkInterval;

  /// Grace period before failover checks start after connect.
  final Duration startupGracePeriod;

  /// Allowed inactivity window before "no traffic" is treated as unhealthy.
  final Duration noTrafficTimeout;

  /// Enables endpoint ping checks.
  final bool pingEnabled;

  /// Timeout used by ping checks.
  final Duration pingTimeout;

  /// Enables HTTP connectivity probe checks.
  final bool connectivityProbeEnabled;

  /// Optional override URL for connectivity probes.
  final String? connectivityProbeUrl;

  /// Timeout used by connectivity probes.
  final Duration connectivityProbeTimeout;

  /// Maximum consecutive failures before hard unhealthy status.
  final int maxConsecutiveFailures;

  /// Enables failover when no-traffic condition is detected.
  final bool failoverOnNoTraffic;

  /// Enables failover when ping fails.
  final bool failoverOnPingFailure;

  /// Enables failover when connectivity probe fails.
  final bool failoverOnConnectivityFailure;

  /// Enables failover after runtime error state.
  final bool failoverOnError;

  /// Enables failover after disconnect state.
  final bool failoverOnDisconnect;

  /// Score penalty applied on each failure.
  final int failurePenalty;

  /// Score bonus applied on successful checks.
  final int successBonus;

  /// Cooldown before repeatedly selecting a recently failed endpoint.
  final Duration coolDown;
}

/// Endpoint-pool behavior for managed rotation and failover.
class EndpointPoolOptions {
  /// Creates endpoint-pool options.
  const EndpointPoolOptions({
    this.autoFailover = true,
    this.rotationStrategy = EndpointRotationStrategy.healthiest,
    this.healthCheck = const VpnHealthCheckOptions(),
  });

  /// Whether managed mode automatically switches endpoints on failures.
  final bool autoFailover;

  /// Strategy used when selecting the next endpoint.
  final EndpointRotationStrategy rotationStrategy;

  /// Health-check policy used by managed mode.
  final VpnHealthCheckOptions healthCheck;
}

/// Snapshot of current health score/status for one endpoint.
class VpnEndpointHealth {
  /// Creates a health snapshot.
  const VpnEndpointHealth({
    required this.tag,
    required this.score,
    required this.consecutiveFailures,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastProgressAt,
  });

  /// Endpoint tag.
  final String tag;

  /// Current score used for ranking.
  final int score;

  /// Number of consecutive failures since last success.
  final int consecutiveFailures;

  /// Last successful activity timestamp.
  final DateTime? lastSuccessAt;

  /// Last failure timestamp.
  final DateTime? lastFailureAt;

  /// Last timestamp when traffic progress was observed.
  final DateTime? lastProgressAt;
}
