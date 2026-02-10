part of '../singbox_mm_client.dart';

Future<VpnProfile?> _rotateEndpointInternal(
  SignboxVpn client, {
  required bool reconnect,
}) async {
  if (client._endpointPool.length < 2) {
    return client.activeEndpointProfile;
  }
  final int nextIndex = _selectNextEndpointIndexInternal(
    client,
    excludeCurrent: true,
  );
  if (nextIndex < 0 || nextIndex == client._activeEndpointIndex) {
    return client.activeEndpointProfile;
  }

  client._activeEndpointIndex = nextIndex;
  final VpnProfile next = await _applyEndpointUsingPoolPolicyInternal(
    client,
    endpointIndex: nextIndex,
    reconnect: reconnect,
  );
  _markEndpointSuccessInternal(client, nextIndex);
  _resetTrafficTrackingInternal(client);
  return next;
}

Future<VpnProfile?> _selectEndpointInternal(
  SignboxVpn client, {
  required int index,
  required bool reconnect,
}) async {
  if (client._endpointPool.isEmpty) {
    return client.activeProfile;
  }
  if (index < 0 || index >= client._endpointPool.length) {
    throw RangeError.index(index, client._endpointPool, 'index');
  }
  if (index == client._activeEndpointIndex) {
    return client.activeEndpointProfile;
  }

  client._activeEndpointIndex = index;
  final VpnProfile selected = await _applyEndpointUsingPoolPolicyInternal(
    client,
    endpointIndex: index,
    reconnect: reconnect,
  );
  _markEndpointSuccessInternal(client, index);
  _resetTrafficTrackingInternal(client);
  return selected;
}

Future<VpnProfile?> _selectBestEndpointByPingInternal(
  SignboxVpn client, {
  required Duration timeout,
  required bool reconnect,
}) async {
  if (client._endpointPool.length < 2) {
    return client.activeProfile;
  }

  final List<VpnPingResult> results = await client.pingEndpointPool(
    timeout: timeout,
    updateHealth: false,
  );
  final int bestIndex = _bestPingResultIndexInternal(results);
  if (bestIndex < 0) {
    return client.activeEndpointProfile;
  }
  return client.selectEndpoint(index: bestIndex, reconnect: reconnect);
}
