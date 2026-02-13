part of '../singbox_mm_client.dart';

int _selectInitialEndpointIndexInternal(SignboxVpn client) {
  if (client._endpointPool.length <= 1) {
    return 0;
  }
  if (client._activeGfwPresetMode != null) {
    final int preferred = _preferredEndpointIndexForNetworkClassInternal(
      client,
      networkClass: client._lastKnownNetworkClass,
    );
    if (preferred >= 0) {
      return preferred;
    }
  }
  if (client._endpointPoolOptions.rotationStrategy ==
      EndpointRotationStrategy.roundRobin) {
    return 0;
  }

  int bestIndex = 0;
  int bestScore = -1;
  int bestTier = 1 << 20;
  for (int i = 0; i < client._endpointPool.length; i++) {
    final int score = client._endpointHealthStates[i].score;
    final int tier = client._activeGfwPresetMode == null
        ? 0
        : _adaptiveTransportTierInternal(client._endpointPool[i]);
    if (score > bestScore || (score == bestScore && tier < bestTier)) {
      bestIndex = i;
      bestScore = score;
      bestTier = tier;
    }
  }
  return bestIndex;
}

int _selectNextEndpointIndexInternal(
  SignboxVpn client, {
  required bool excludeCurrent,
}) {
  if (client._endpointPool.isEmpty) {
    return -1;
  }
  if (client._endpointPool.length == 1) {
    return 0;
  }

  if (client._endpointPoolOptions.rotationStrategy ==
      EndpointRotationStrategy.roundRobin) {
    return _selectRoundRobinNextInternal(
      client,
      excludeCurrent: excludeCurrent,
    );
  }
  return _selectHealthiestNextInternal(client, excludeCurrent: excludeCurrent);
}

int _selectRoundRobinNextInternal(
  SignboxVpn client, {
  required bool excludeCurrent,
}) {
  final int size = client._endpointPool.length;
  final int start = client._activeEndpointIndex < 0
      ? 0
      : (client._activeEndpointIndex + 1) % size;
  for (int step = 0; step < size; step++) {
    final int candidate = (start + step) % size;
    if (excludeCurrent && candidate == client._activeEndpointIndex) {
      continue;
    }
    if (_isCoolingDownInternal(client, candidate)) {
      continue;
    }
    return candidate;
  }
  return start;
}

int _selectHealthiestNextInternal(
  SignboxVpn client, {
  required bool excludeCurrent,
}) {
  final DateTime now = DateTime.now().toUtc();
  int bestIndex = -1;
  int bestScore = -1;
  int bestTier = 1 << 20;

  for (int index = 0; index < client._endpointPool.length; index++) {
    if (excludeCurrent && index == client._activeEndpointIndex) {
      continue;
    }
    final _EndpointHealthState state = client._endpointHealthStates[index];
    final bool coolingDown =
        state.lastFailureAt != null &&
        now.difference(state.lastFailureAt!) <
            client._endpointPoolOptions.healthCheck.coolDown;
    if (coolingDown) {
      continue;
    }
    final int tier = client._activeGfwPresetMode == null
        ? 0
        : _adaptiveTransportTierInternal(client._endpointPool[index]);
    if (tier < bestTier || (tier == bestTier && state.score > bestScore)) {
      bestTier = tier;
      bestScore = state.score;
      bestIndex = index;
    }
  }

  if (bestIndex >= 0) {
    return bestIndex;
  }
  return _selectRoundRobinNextInternal(client, excludeCurrent: excludeCurrent);
}

bool _isCoolingDownInternal(SignboxVpn client, int index) {
  final DateTime? lastFailureAt =
      client._endpointHealthStates[index].lastFailureAt;
  if (lastFailureAt == null) {
    return false;
  }
  return DateTime.now().toUtc().difference(lastFailureAt) <
      client._endpointPoolOptions.healthCheck.coolDown;
}
