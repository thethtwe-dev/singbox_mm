import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'singbox_mm_method_channel.dart';
import 'src/models/singbox_runtime_options.dart';
import 'src/models/vpn_connection_state.dart';
import 'src/models/vpn_connection_snapshot.dart';
import 'src/models/vpn_ping_result.dart';
import 'src/models/vpn_runtime_stats.dart';

/// Platform interface for the native VPN bridge.
abstract class SignboxVpnPlatform extends PlatformInterface {
  /// Creates a platform interface instance.
  SignboxVpnPlatform() : super(token: _token);

  static final Object _token = Object();
  static SignboxVpnPlatform _instance = MethodChannelSignboxVpn();

  /// Active platform implementation.
  static SignboxVpnPlatform get instance => _instance;

  /// Overrides the active platform implementation.
  static set instance(SignboxVpnPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Connection-state stream (`connecting`, `connected`, `error`, ...).
  Stream<VpnConnectionState> get stateStream =>
      const Stream<VpnConnectionState>.empty();

  /// Detailed state stream including diagnostics.
  Stream<VpnConnectionSnapshot> get stateDetailsStream =>
      const Stream<VpnConnectionSnapshot>.empty();

  /// Runtime traffic/stats stream.
  Stream<VpnRuntimeStats> get statsStream =>
      const Stream<VpnRuntimeStats>.empty();

  /// Initializes native runtime with [options].
  Future<void> initialize(SingboxRuntimeOptions options) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Requests VPN permission from the user.
  Future<bool> requestVpnPermission() {
    throw UnimplementedError(
      'requestVpnPermission() has not been implemented.',
    );
  }

  /// Requests Android notification permission when needed.
  Future<bool> requestNotificationPermission() {
    throw UnimplementedError(
      'requestNotificationPermission() has not been implemented.',
    );
  }

  /// Applies raw sing-box JSON config.
  Future<void> setConfig(String configJson) {
    throw UnimplementedError('setConfig() has not been implemented.');
  }

  /// Starts the VPN service.
  Future<void> startVpn() {
    throw UnimplementedError('startVpn() has not been implemented.');
  }

  /// Stops the VPN service.
  Future<void> stopVpn() {
    throw UnimplementedError('stopVpn() has not been implemented.');
  }

  /// Restarts the VPN service.
  Future<void> restartVpn() {
    throw UnimplementedError('restartVpn() has not been implemented.');
  }

  /// Returns current connection state.
  Future<VpnConnectionState> getState() {
    throw UnimplementedError('getState() has not been implemented.');
  }

  /// Returns detailed connection snapshot.
  Future<VpnConnectionSnapshot> getStateDetails() {
    throw UnimplementedError('getStateDetails() has not been implemented.');
  }

  /// Returns current runtime stats.
  Future<VpnRuntimeStats> getStats() {
    throw UnimplementedError('getStats() has not been implemented.');
  }

  /// Synchronizes state/stats from persisted runtime snapshot.
  Future<void> syncRuntimeState() {
    throw UnimplementedError('syncRuntimeState() has not been implemented.');
  }

  /// Returns last runtime error string, if any.
  Future<String?> getLastError() {
    throw UnimplementedError('getLastError() has not been implemented.');
  }

  /// Returns current sing-box core version string.
  Future<String?> getSingboxVersion() {
    throw UnimplementedError('getSingboxVersion() has not been implemented.');
  }

  /// Executes an active TCP/TLS ping test against [host]:[port].
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
