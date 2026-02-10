part of '../singbox_mm_client.dart';

Future<void> _evaluateNoTrafficHealthInternal(
  SignboxVpn client,
  VpnHealthCheckOptions options, {
  required bool hasPositiveHealthSignal,
}) async {
  if (!options.failoverOnNoTraffic) {
    return;
  }
  // If the tunnel is reachable (ping or probe passed), treat no traffic as
  // likely idle user traffic instead of packet loss.
  if (hasPositiveHealthSignal) {
    return;
  }

  final VpnRuntimeStats stats = await client.getStats();
  final int total = stats.totalUploaded + stats.totalDownloaded;
  final DateTime now = DateTime.now().toUtc();

  if (client._lastTotalBytes == null) {
    client._lastTotalBytes = total;
    client._lastTrafficProgressAt ??= now;
    return;
  }

  if (total > client._lastTotalBytes!) {
    client._lastTotalBytes = total;
    client._hasSeenTraffic = true;
    client._lastTrafficProgressAt = now;
    _markEndpointProgressInternal(client, client._activeEndpointIndex, now);
    _markEndpointSuccessInternal(client, client._activeEndpointIndex);
    return;
  }

  client._lastTotalBytes = total;
  if (!client._hasSeenTraffic) {
    return;
  }

  final DateTime lastProgress = client._lastTrafficProgressAt ?? now;
  if (now.difference(lastProgress) < options.noTrafficTimeout) {
    return;
  }

  client._lastTrafficProgressAt = now;
  await _markEndpointFailureAndMaybeFailoverInternal(client, options);
}
