part of '../singbox_mm_client.dart';

extension SignboxVpnRuntimeApi on SignboxVpn {
  Future<void> setRawConfig(Map<String, Object?> config) async {
    await _setRawConfigInternal(this, config);
  }

  Future<bool> requestVpnPermission() {
    return _requestVpnPermissionInternal(this);
  }

  Future<bool> requestNotificationPermission() {
    return _requestNotificationPermissionInternal(this);
  }

  Future<void> start() async {
    await _startInternal(this);
  }

  Future<void> stop() async {
    await _stopInternal(this);
  }

  Future<void> restart() async {
    await _restartInternal(this);
  }

  Future<VpnConnectionState> getState() {
    return _getStateInternal(this);
  }

  Future<VpnConnectionSnapshot> getStateDetails() {
    return _getStateDetailsInternal(this);
  }

  Future<VpnRuntimeStats> getStats() {
    return _getStatsInternal(this);
  }

  Future<void> syncRuntimeState() {
    return _syncRuntimeStateInternal(this);
  }

  Future<String?> getLastError() {
    return _getLastErrorInternal(this);
  }

  Future<String?> getSingboxVersion() {
    return _getSingboxVersionInternal(this);
  }

  Future<VpnCoreCapabilities> getCoreCapabilities({bool refresh = false}) {
    return _getCoreCapabilitiesInternal(this, refresh: refresh);
  }

  Future<bool> isProtocolSupportedByCore(
    VpnProtocol protocol, {
    bool refresh = false,
  }) async {
    final VpnCoreCapabilities caps = await getCoreCapabilities(
      refresh: refresh,
    );
    return caps.supportsProtocol(protocol);
  }

  Future<List<VpnProfile>> filterProfilesByCoreSupport({
    required List<VpnProfile> profiles,
    bool refresh = false,
  }) async {
    if (profiles.isEmpty) {
      return const <VpnProfile>[];
    }
    final VpnCoreCapabilities caps = await getCoreCapabilities(
      refresh: refresh,
    );
    return profiles
        .where((VpnProfile profile) => caps.supportsProtocol(profile.protocol))
        .toList(growable: false);
  }
}
