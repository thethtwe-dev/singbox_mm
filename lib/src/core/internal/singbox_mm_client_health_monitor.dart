part of '../singbox_mm_client.dart';

void _restartHealthMonitorIfNeededInternal(SignboxVpn client) {
  _stopHealthMonitorInternal(client);
  final VpnHealthCheckOptions check = client._endpointPoolOptions.healthCheck;
  if (!client._endpointPoolOptions.autoFailover || !check.enabled) {
    return;
  }
  client._healthTimer = Timer.periodic(check.checkInterval, (_) {
    unawaited(_runHealthCheckTickInternal(client));
  });
}

void _stopHealthMonitorInternal(SignboxVpn client) {
  client._healthTimer?.cancel();
  client._healthTimer = null;
}
