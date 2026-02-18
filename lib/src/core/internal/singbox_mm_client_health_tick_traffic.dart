part of '../singbox_mm_client.dart';

Future<void> _evaluateNoTrafficHealthInternal(
  SignboxVpn client,
  VpnHealthCheckOptions options, {
  required bool hasPositiveHealthSignal,
  required bool connectivityProbeSucceeded,
  required bool allowFailureCounting,
}) async {
  if (!options.failoverOnNoTraffic && !options.failoverOnSilentPacketLoss) {
    return;
  }
  if (!allowFailureCounting) {
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
    client._consecutiveSilentPacketLossSignals = 0;
    _markEndpointProgressInternal(client, client._activeEndpointIndex, now);
    _markEndpointSuccessInternal(client, client._activeEndpointIndex);
    return;
  }

  client._lastTotalBytes = total;
  if (!client._hasSeenTraffic) {
    client._consecutiveSilentPacketLossSignals = 0;
    return;
  }

  final DateTime lastProgress = client._lastTrafficProgressAt ?? now;
  final Duration stallDuration = now.difference(lastProgress);

  if (hasPositiveHealthSignal && options.failoverOnSilentPacketLoss) {
    if (!options.connectivityProbeEnabled || !connectivityProbeSucceeded) {
      client._consecutiveSilentPacketLossSignals = 0;
      return;
    }
    if (stallDuration < options.silentPacketLossTimeout) {
      client._consecutiveSilentPacketLossSignals = 0;
      return;
    }
    final int requiredSignals = max(1, options.maxConsecutiveFailures);
    client._consecutiveSilentPacketLossSignals++;
    if (client._consecutiveSilentPacketLossSignals < requiredSignals) {
      return;
    }
    client._consecutiveSilentPacketLossSignals = 0;
    client._lastTrafficProgressAt = now;
    await _markEndpointFailureAndMaybeFailoverInternal(client, options);
    return;
  }

  client._consecutiveSilentPacketLossSignals = 0;
  if (!options.failoverOnNoTraffic ||
      stallDuration < options.noTrafficTimeout) {
    return;
  }

  client._lastTrafficProgressAt = now;
  await _markEndpointFailureAndMaybeFailoverInternal(client, options);
}
