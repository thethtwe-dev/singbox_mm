part of '../singbox_mm_client.dart';

extension SignboxVpnLifecycleApi on SignboxVpn {
  Future<void> initialize(SingboxRuntimeOptions options) async {
    await _initializeInternal(this, options);
  }

  void setFeatureSettings(SingboxFeatureSettings settings) {
    _setFeatureSettingsInternal(this, settings);
  }

  Future<void> dispose() async {
    await _disposeInternal(this);
  }

  Future<void> resetProfile({bool stopVpn = true}) async {
    await _resetProfileInternal(this, stopVpn: stopVpn);
  }
}
