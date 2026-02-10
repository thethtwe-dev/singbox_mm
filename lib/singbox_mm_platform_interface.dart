import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'singbox_mm_method_channel.dart';
import 'src/models/singbox_runtime_options.dart';
import 'src/models/vpn_connection_state.dart';
import 'src/models/vpn_connection_snapshot.dart';
import 'src/models/vpn_ping_result.dart';
import 'src/models/vpn_runtime_stats.dart';

abstract class SignboxVpnPlatform extends PlatformInterface {
  SignboxVpnPlatform() : super(token: _token);

  static final Object _token = Object();
  static SignboxVpnPlatform _instance = MethodChannelSignboxVpn();

  static SignboxVpnPlatform get instance => _instance;

  static set instance(SignboxVpnPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<VpnConnectionState> get stateStream =>
      const Stream<VpnConnectionState>.empty();

  Stream<VpnConnectionSnapshot> get stateDetailsStream =>
      const Stream<VpnConnectionSnapshot>.empty();

  Stream<VpnRuntimeStats> get statsStream =>
      const Stream<VpnRuntimeStats>.empty();

  Future<void> initialize(SingboxRuntimeOptions options) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<bool> requestVpnPermission() {
    throw UnimplementedError(
      'requestVpnPermission() has not been implemented.',
    );
  }

  Future<bool> requestNotificationPermission() {
    throw UnimplementedError(
      'requestNotificationPermission() has not been implemented.',
    );
  }

  Future<void> setConfig(String configJson) {
    throw UnimplementedError('setConfig() has not been implemented.');
  }

  Future<void> startVpn() {
    throw UnimplementedError('startVpn() has not been implemented.');
  }

  Future<void> stopVpn() {
    throw UnimplementedError('stopVpn() has not been implemented.');
  }

  Future<void> restartVpn() {
    throw UnimplementedError('restartVpn() has not been implemented.');
  }

  Future<VpnConnectionState> getState() {
    throw UnimplementedError('getState() has not been implemented.');
  }

  Future<VpnConnectionSnapshot> getStateDetails() {
    throw UnimplementedError('getStateDetails() has not been implemented.');
  }

  Future<VpnRuntimeStats> getStats() {
    throw UnimplementedError('getStats() has not been implemented.');
  }

  Future<void> syncRuntimeState() {
    throw UnimplementedError('syncRuntimeState() has not been implemented.');
  }

  Future<String?> getLastError() {
    throw UnimplementedError('getLastError() has not been implemented.');
  }

  Future<String?> getSingboxVersion() {
    throw UnimplementedError('getSingboxVersion() has not been implemented.');
  }

  Future<VpnPingResult> pingServer({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 3),
    bool useTls = false,
    String? tlsServerName,
    bool allowInsecure = false,
  }) {
    throw UnimplementedError('pingServer() has not been implemented.');
  }
}
