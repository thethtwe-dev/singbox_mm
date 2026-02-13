part of '../singbox_mm_client.dart';

Future<bool> _attemptFailoverInternal(SignboxVpn client) async {
  if (!client._endpointPoolOptions.autoFailover ||
      client._endpointPool.isEmpty ||
      client._manualStopRequested ||
      client._failoverInProgress) {
    return false;
  }

  client._failoverInProgress = true;
  try {
    if (await _attemptMtuProbeRecoveryInternal(client)) {
      return true;
    }
    if (client._endpointPool.length < 2) {
      return _restartActiveEndpointInternal(client);
    }

    final int nextIndex = _selectNextEndpointIndexInternal(
      client,
      excludeCurrent: true,
    );
    if (nextIndex < 0 || nextIndex == client._activeEndpointIndex) {
      return false;
    }

    client._activeEndpointIndex = nextIndex;
    await _applyEndpointUsingPoolPolicyInternal(
      client,
      endpointIndex: nextIndex,
      reconnect: true,
    );
    _resetTrafficTrackingInternal(client);
    _markEndpointSuccessInternal(client, nextIndex);
    return true;
  } on Object catch (_) {
    // Keep current state and allow subsequent retries.
    return false;
  } finally {
    client._failoverInProgress = false;
  }
}

Future<bool> _restartActiveEndpointInternal(SignboxVpn client) async {
  if (client._activeEndpointIndex < 0 ||
      client._activeEndpointIndex >= client._endpointPool.length) {
    return false;
  }
  final VpnProfile active = client._endpointPool[client._activeEndpointIndex];
  try {
    await client.applyProfile(
      profile: active,
      bypassPolicy: client._endpointBypassPolicy,
      throttlePolicy: _effectiveThrottlePolicyForProfileInternal(
        client,
        profile: active,
        base: client._endpointThrottlePolicy,
      ),
      featureSettings: client._endpointFeatureSettings,
      clearEndpointPool: false,
    );
    await client._guard(() => client._platform.restartVpn());
    _resetTrafficTrackingInternal(client);
    _markEndpointSuccessInternal(client, client._activeEndpointIndex);
    return true;
  } on Object {
    return false;
  }
}

Future<bool> _attemptMtuProbeRecoveryInternal(SignboxVpn client) async {
  if (client._activeEndpointIndex < 0 ||
      client._activeEndpointIndex >= client._endpointPool.length) {
    return false;
  }

  final VpnProfile profile = client._endpointPool[client._activeEndpointIndex];
  if (!profile.tls.enabled ||
      !client._endpointThrottlePolicy.enableAutoMtuProbe) {
    return false;
  }

  final List<int> candidates = _resolveMtuCandidatesInternal(
    client._endpointThrottlePolicy,
  );
  if (candidates.length < 2) {
    return false;
  }

  final int configuredMtuIndex = max(
    0,
    candidates.indexOf(client._endpointThrottlePolicy.tunMtu),
  );
  final int currentIndex =
      client._endpointMtuProbeCursorByTag[profile.tag] ?? configuredMtuIndex;
  if (currentIndex >= candidates.length - 1) {
    return false;
  }

  final int nextIndex = currentIndex + 1;
  final int tunedMtu = candidates[nextIndex];
  client._endpointMtuProbeCursorByTag[profile.tag] = nextIndex;
  final bool forceUdpFragment = _shouldForceUdpFragmentForProfileInternal(
    profile,
  );

  final TrafficThrottlePolicy tunedPolicy = client._endpointThrottlePolicy
      .copyWith(
        tunMtu: tunedMtu,
        udpFragment: forceUdpFragment
            ? true
            : client._endpointThrottlePolicy.udpFragment,
      );

  return () async {
    try {
      await client.applyProfile(
        profile: profile,
        bypassPolicy: client._endpointBypassPolicy,
        throttlePolicy: tunedPolicy,
        featureSettings: client._endpointFeatureSettings,
        clearEndpointPool: false,
      );
      await client._guard(() => client._platform.restartVpn());
      _resetTrafficTrackingInternal(client);
      _markEndpointSuccessInternal(client, client._activeEndpointIndex);
      return true;
    } on Object {
      client._endpointMtuProbeCursorByTag[profile.tag] = currentIndex;
      return false;
    }
  }();
}
