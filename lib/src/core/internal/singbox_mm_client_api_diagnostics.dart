part of '../singbox_mm_client.dart';

extension SignboxVpnDiagnosticsApi on SignboxVpn {
  Future<VpnPingResult> pingProfile({
    required VpnProfile profile,
    Duration timeout = const Duration(seconds: 3),
    String? connectivityProbeUrl,
    Duration? connectivityProbeTimeout,
    Map<String, String> connectivityProbeHeaders = const <String, String>{},
    bool allowConnectivityProbeFallback = true,
  }) async {
    return _pingProfileInternal(
      this,
      profile: profile,
      timeout: timeout,
      connectivityProbeUrl: connectivityProbeUrl,
      connectivityProbeTimeout: connectivityProbeTimeout,
      connectivityProbeHeaders: connectivityProbeHeaders,
      allowConnectivityProbeFallback: allowConnectivityProbeFallback,
    );
  }

  Future<List<VpnPingResult>> pingEndpointPool({
    Duration timeout = const Duration(seconds: 3),
    bool updateHealth = true,
    String? connectivityProbeUrl,
    Duration? connectivityProbeTimeout,
    Map<String, String> connectivityProbeHeaders = const <String, String>{},
  }) async {
    return _pingEndpointPoolInternal(
      this,
      timeout: timeout,
      updateHealth: updateHealth,
      connectivityProbeUrl: connectivityProbeUrl,
      connectivityProbeTimeout: connectivityProbeTimeout,
      connectivityProbeHeaders: connectivityProbeHeaders,
    );
  }

  List<VpnDiagnosticIssue> validateProfile(
    VpnProfile profile, {
    bool strictTls = false,
  }) {
    return _validateProfileInternal(this, profile, strictTls: strictTls);
  }

  Future<VpnConnectivityProbe> probeConnectivity({
    String? url,
    Duration timeout = const Duration(seconds: 8),
    Map<String, String> headers = const <String, String>{},
  }) async {
    return _probeConnectivityInternal(
      this,
      url: url,
      timeout: timeout,
      headers: headers,
    );
  }

  Future<VpnDiagnosticsReport> runDiagnostics({
    bool strictTls = false,
    bool includeEndpointPoolPing = true,
    bool includeConnectivityProbe = true,
    Duration pingTimeout = const Duration(seconds: 3),
    Duration connectivityTimeout = const Duration(seconds: 8),
  }) async {
    return _runDiagnosticsInternal(
      this,
      strictTls: strictTls,
      includeEndpointPoolPing: includeEndpointPoolPing,
      includeConnectivityProbe: includeConnectivityProbe,
      pingTimeout: pingTimeout,
      connectivityTimeout: connectivityTimeout,
    );
  }
}
