part of '../singbox_mm_client.dart';

TrafficThrottlePolicy _effectiveThrottlePolicyForProfileInternal(
  SignboxVpn client, {
  required VpnProfile profile,
  required TrafficThrottlePolicy base,
}) {
  final bool enforceUdpFragment = profile.tls.enabled;
  final List<int> mtuCandidates = _resolveMtuCandidatesInternal(base);
  if (!profile.tls.enabled ||
      !base.enableAutoMtuProbe ||
      mtuCandidates.isEmpty) {
    if (enforceUdpFragment && !base.udpFragment) {
      return base.copyWith(udpFragment: true);
    }
    return base;
  }

  final int cursor = client._endpointMtuProbeCursorByTag[profile.tag] ?? 0;
  final int safeIndex = max(0, min(cursor, mtuCandidates.length - 1));
  return base.copyWith(tunMtu: mtuCandidates[safeIndex], udpFragment: true);
}

List<int> _resolveMtuCandidatesInternal(TrafficThrottlePolicy policy) {
  final Set<int> values = <int>{policy.tunMtu, ...policy.mtuProbeCandidates}
    ..removeWhere((int value) => value < 1280);
  final List<int> sorted = values.toList(growable: false)
    ..sort((int a, int b) => b.compareTo(a));
  return sorted;
}

void _markEndpointSuccessInternal(SignboxVpn client, int index) {
  if (index < 0 || index >= client._endpointHealthStates.length) {
    return;
  }
  final _EndpointHealthState state = client._endpointHealthStates[index];
  client._endpointHealthStates[index] = state.copyWith(
    score: min(
      100,
      state.score + client._endpointPoolOptions.healthCheck.successBonus,
    ),
    consecutiveFailures: 0,
    lastSuccessAt: DateTime.now().toUtc(),
  );
}

void _markEndpointFailureInternal(SignboxVpn client, int index) {
  if (index < 0 || index >= client._endpointHealthStates.length) {
    return;
  }
  final _EndpointHealthState state = client._endpointHealthStates[index];
  client._endpointHealthStates[index] = state.copyWith(
    score: max(
      0,
      state.score - client._endpointPoolOptions.healthCheck.failurePenalty,
    ),
    consecutiveFailures: state.consecutiveFailures + 1,
    lastFailureAt: DateTime.now().toUtc(),
  );
}

void _markEndpointProgressInternal(
  SignboxVpn client,
  int index,
  DateTime timestamp,
) {
  if (index < 0 || index >= client._endpointHealthStates.length) {
    return;
  }
  final _EndpointHealthState state = client._endpointHealthStates[index];
  client._endpointHealthStates[index] = state.copyWith(
    lastProgressAt: timestamp,
  );
}

int _bestPingResultIndexInternal(List<VpnPingResult> results) {
  final int tcpPreferred = _bestPingResultIndexByMethodInternal(
    results,
    VpnPingResult.methodTcpConnect,
  );
  if (tcpPreferred >= 0) {
    return tcpPreferred;
  }
  return _bestPingResultIndexByMethodInternal(results, null);
}

int _bestPingResultIndexByMethodInternal(
  List<VpnPingResult> results,
  String? method,
) {
  int bestIndex = -1;
  int bestLatencyMs = 1 << 30;

  for (int index = 0; index < results.length; index++) {
    final VpnPingResult result = results[index];
    if (method != null && result.checkMethod != method) {
      continue;
    }
    final int? latency = result.latencyMs;
    if (!result.success || latency == null) {
      continue;
    }
    if (latency < bestLatencyMs) {
      bestLatencyMs = latency;
      bestIndex = index;
    }
  }
  return bestIndex;
}

void _resetTrafficTrackingInternal(SignboxVpn client) {
  client._lastTotalBytes = null;
  client._lastTrafficProgressAt = DateTime.now().toUtc();
  client._hasSeenTraffic = false;
}
