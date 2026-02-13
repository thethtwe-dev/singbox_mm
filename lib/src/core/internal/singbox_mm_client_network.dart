part of '../singbox_mm_client.dart';

Future<VpnPingResult> _pingProfileInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required Duration timeout,
  String? connectivityProbeUrl,
  Duration? connectivityProbeTimeout,
  Map<String, String> connectivityProbeHeaders = const <String, String>{},
  bool allowConnectivityProbeFallback = true,
}) async {
  final VpnPingResult tcpResult = await _pingProfileTcpInternal(
    client,
    profile: profile,
    timeout: timeout,
  );
  if (!profile.protocol.isUdpOriented ||
      tcpResult.success ||
      !allowConnectivityProbeFallback) {
    return tcpResult;
  }

  final Duration fallbackTimeout =
      connectivityProbeTimeout ??
      Duration(milliseconds: max(timeout.inMilliseconds, 1500));
  final VpnConnectivityProbe probe = await _probeConnectivityInternal(
    client,
    url: connectivityProbeUrl,
    timeout: fallbackTimeout,
    headers: connectivityProbeHeaders,
  );

  if (probe.success) {
    return VpnPingResult(
      host: profile.server,
      port: profile.serverPort,
      tag: profile.tag,
      latency: probe.latency,
      checkedAt: probe.checkedAt,
      checkMethod: VpnPingResult.methodConnectivityProbe,
    );
  }

  return VpnPingResult.failure(
    host: profile.server,
    port: profile.serverPort,
    tag: profile.tag,
    checkMethod: VpnPingResult.methodConnectivityProbe,
    error:
        'UDP profile health check failed (tcp=${tcpResult.error ?? "failed"}, probe=${probe.error ?? "failed"})',
  );
}

Future<VpnPingResult> _pingProfileTcpInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required Duration timeout,
}) async {
  try {
    final VpnPingResult raw = await client._guard(
      () => client._platform.pingServer(
        host: profile.server,
        port: profile.serverPort,
        timeout: timeout,
        useTls: profile.tls.enabled,
        tlsServerName: profile.tls.serverName,
        allowInsecure: profile.tls.allowInsecure,
      ),
    );
    return raw.copyWith(
      tag: profile.tag,
      host: profile.server,
      port: profile.serverPort,
      checkMethod: VpnPingResult.methodTcpConnect,
    );
  } on Object catch (error) {
    return VpnPingResult.failure(
      host: profile.server,
      port: profile.serverPort,
      tag: profile.tag,
      checkMethod: VpnPingResult.methodTcpConnect,
      error: error.toString(),
    );
  }
}

Future<List<VpnPingResult>> _pingEndpointPoolInternal(
  SignboxVpn client, {
  required Duration timeout,
  required bool updateHealth,
  String? connectivityProbeUrl,
  Duration? connectivityProbeTimeout,
  Map<String, String> connectivityProbeHeaders = const <String, String>{},
}) async {
  if (client._endpointPool.isEmpty && client._standaloneProfile != null) {
    return <VpnPingResult>[
      await client.pingProfile(
        profile: client._standaloneProfile!,
        timeout: timeout,
        connectivityProbeUrl: connectivityProbeUrl,
        connectivityProbeTimeout: connectivityProbeTimeout,
        connectivityProbeHeaders: connectivityProbeHeaders,
      ),
    ];
  }

  final int poolSize = client._endpointPool.length;
  if (poolSize == 0) {
    return const <VpnPingResult>[];
  }

  final List<VpnPingResult?> slotResults = List<VpnPingResult?>.filled(
    poolSize,
    null,
    growable: false,
  );
  final int workerCount = min(4, poolSize);
  int nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final int index = nextIndex;
      if (index >= poolSize) {
        return;
      }
      nextIndex = index + 1;

      final VpnProfile profile = client._endpointPool[index];
      final VpnPingResult result = await client.pingProfile(
        profile: profile,
        timeout: timeout,
        connectivityProbeUrl: connectivityProbeUrl,
        connectivityProbeTimeout: connectivityProbeTimeout,
        connectivityProbeHeaders: connectivityProbeHeaders,
      );
      slotResults[index] = result;
    }
  }

  await Future.wait(List<Future<void>>.generate(workerCount, (_) => worker()));

  final List<VpnPingResult> results = slotResults
      .map((VpnPingResult? item) => item!)
      .toList(growable: false);

  if (updateHealth) {
    for (int index = 0; index < results.length; index++) {
      final VpnPingResult result = results[index];
      if (result.success) {
        _markEndpointProgressInternal(client, index, result.checkedAt);
        _markEndpointSuccessInternal(client, index);
      } else {
        _markEndpointFailureInternal(client, index);
      }
    }
  }
  return results;
}
