part of '../singbox_mm_client.dart';

Future<void> _setRawConfigInternal(
  SignboxVpn client,
  Map<String, Object?> config,
) async {
  await client._guard(() => client._platform.setConfig(jsonEncode(config)));
}

Future<bool> _requestVpnPermissionInternal(SignboxVpn client) {
  return client._guard(() => client._platform.requestVpnPermission());
}

Future<bool> _requestNotificationPermissionInternal(SignboxVpn client) {
  if (!Platform.isAndroid) {
    return Future<bool>.value(true);
  }
  return client._guard(() => client._platform.requestNotificationPermission());
}

Future<void> _startInternal(SignboxVpn client) async {
  client._manualStopRequested = false;
  if (client._endpointPoolOptions.autoFailover &&
      client._endpointPool.isNotEmpty) {
    _ensureManagedStateSubscriptionInternal(client);
    _restartHealthMonitorIfNeededInternal(client);
    _resetTrafficTrackingInternal(client);
  }
  await client._guard(() => client._platform.startVpn());
}

Future<void> _stopInternal(SignboxVpn client) async {
  client._manualStopRequested = true;
  _stopHealthMonitorInternal(client);
  await client._guard(() => client._platform.stopVpn());
}

Future<void> _restartInternal(SignboxVpn client) async {
  client._manualStopRequested = false;
  await client._guard(() => client._platform.restartVpn());
}

Future<VpnConnectionState> _getStateInternal(SignboxVpn client) {
  return client._guard(() => client._platform.getState());
}

Future<VpnConnectionSnapshot> _getStateDetailsInternal(SignboxVpn client) {
  return client._guard(() => client._platform.getStateDetails());
}

Future<VpnRuntimeStats> _getStatsInternal(SignboxVpn client) {
  return client._guard(() => client._platform.getStats());
}

Future<void> _syncRuntimeStateInternal(SignboxVpn client) {
  return client._guard(() => client._platform.syncRuntimeState());
}

Future<String?> _getLastErrorInternal(SignboxVpn client) {
  return client._guard(() => client._platform.getLastError());
}

Future<String?> _getSingboxVersionInternal(SignboxVpn client) {
  return client._guard(() => client._platform.getSingboxVersion());
}

Future<void> _ensureVpnPermissionGrantedInternal(SignboxVpn client) async {
  final bool granted = await client.requestVpnPermission();
  if (!granted) {
    throw const SignboxVpnException(
      code: 'PERMISSION_DENIED',
      message: 'VPN permission denied by user.',
    );
  }
}

Future<void> _ensureNotificationPermissionGrantedInternal(
  SignboxVpn client,
) async {
  if (!Platform.isAndroid) {
    return;
  }
  final bool granted = await client.requestNotificationPermission();
  if (!granted) {
    throw const SignboxVpnException(
      code: 'NOTIFICATION_PERMISSION_DENIED',
      message:
          'Notification permission denied by user. Android 13+ requires it for foreground VPN notifications.',
    );
  }
}

Future<void> _maybeRequestPermissionsInternal(
  SignboxVpn client, {
  required bool requestPermission,
}) async {
  if (!requestPermission) {
    return;
  }
  await _ensureVpnPermissionGrantedInternal(client);
  await _ensureNotificationPermissionGrantedInternal(client);
}
