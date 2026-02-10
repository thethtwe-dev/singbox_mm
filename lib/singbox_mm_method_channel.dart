import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'singbox_mm_platform_interface.dart';
import 'src/models/singbox_runtime_options.dart';
import 'src/models/vpn_connection_state.dart';
import 'src/models/vpn_connection_snapshot.dart';
import 'src/models/vpn_ping_result.dart';
import 'src/models/vpn_runtime_stats.dart';

class MethodChannelSignboxVpn extends SignboxVpnPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('singbox_mm/methods');

  @visibleForTesting
  final EventChannel stateChannel = const EventChannel('singbox_mm/state');

  @visibleForTesting
  final EventChannel statsChannel = const EventChannel('singbox_mm/stats');

  late final Stream<Map<Object?, Object?>> _stateEventStream = stateChannel
      .receiveBroadcastStream()
      .map<Map<Object?, Object?>>((Object? event) {
        if (event is Map<Object?, Object?>) {
          return event;
        }
        return <Object?, Object?>{'state': event};
      })
      .asBroadcastStream();

  late final Stream<VpnConnectionState> _stateStream = _stateEventStream
      .map<VpnConnectionState>(
        (Map<Object?, Object?> event) =>
            vpnConnectionStateFromWire(event['state']),
      )
      .distinct();

  late final Stream<VpnConnectionSnapshot> _stateDetailsStream =
      _stateEventStream.map<VpnConnectionSnapshot>((
        Map<Object?, Object?> event,
      ) {
        return VpnConnectionSnapshot.fromMap(event);
      });

  late final Stream<VpnRuntimeStats> _statsStream = statsChannel
      .receiveBroadcastStream()
      .map<VpnRuntimeStats>((Object? event) {
        if (event is Map<Object?, Object?>) {
          return VpnRuntimeStats.fromMap(event);
        }
        return VpnRuntimeStats.empty();
      });

  @override
  Stream<VpnConnectionState> get stateStream => _stateStream;

  @override
  Stream<VpnConnectionSnapshot> get stateDetailsStream => _stateDetailsStream;

  @override
  Stream<VpnRuntimeStats> get statsStream => _statsStream;

  @override
  Future<void> initialize(SingboxRuntimeOptions options) {
    return methodChannel.invokeMethod<void>('initialize', options.toMap());
  }

  @override
  Future<bool> requestVpnPermission() async {
    final bool? granted = await methodChannel.invokeMethod<bool>(
      'requestVpnPermission',
    );
    return granted ?? false;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    final bool? granted = await methodChannel.invokeMethod<bool>(
      'requestNotificationPermission',
    );
    return granted ?? false;
  }

  @override
  Future<void> setConfig(String configJson) {
    return methodChannel.invokeMethod<void>('setConfig', <String, Object?>{
      'config': configJson,
    });
  }

  @override
  Future<void> startVpn() {
    return methodChannel.invokeMethod<void>('startVpn');
  }

  @override
  Future<void> stopVpn() {
    return methodChannel.invokeMethod<void>('stopVpn');
  }

  @override
  Future<void> restartVpn() {
    return methodChannel.invokeMethod<void>('restartVpn');
  }

  @override
  Future<VpnConnectionState> getState() async {
    final String? state = await methodChannel.invokeMethod<String>('getState');
    return vpnConnectionStateFromWire(state);
  }

  @override
  Future<VpnConnectionSnapshot> getStateDetails() async {
    final dynamic raw = await methodChannel.invokeMethod<dynamic>(
      'getStateDetails',
    );
    if (raw is Map<Object?, Object?>) {
      return VpnConnectionSnapshot.fromMap(raw);
    }
    final VpnConnectionState state = await getState();
    return VpnConnectionSnapshot(
      state: state,
      timestamp: DateTime.now().toUtc(),
    );
  }

  @override
  Future<VpnRuntimeStats> getStats() async {
    final dynamic raw = await methodChannel.invokeMethod<dynamic>('getStats');
    if (raw is Map<Object?, Object?>) {
      return VpnRuntimeStats.fromMap(raw);
    }
    return VpnRuntimeStats.empty();
  }

  @override
  Future<void> syncRuntimeState() {
    return methodChannel.invokeMethod<void>('syncRuntimeState');
  }

  @override
  Future<String?> getLastError() {
    return methodChannel.invokeMethod<String>('getLastError');
  }

  @override
  Future<String?> getSingboxVersion() {
    return methodChannel.invokeMethod<String>('getSingboxVersion');
  }

  @override
  Future<VpnPingResult> pingServer({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 3),
    bool useTls = false,
    String? tlsServerName,
    bool allowInsecure = false,
  }) async {
    final dynamic raw = await methodChannel
        .invokeMethod<dynamic>('pingServer', <String, Object?>{
          'host': host,
          'port': port,
          'timeoutMs': timeout.inMilliseconds,
          'useTls': useTls,
          'tlsServerName': tlsServerName,
          'allowInsecure': allowInsecure,
        });
    if (raw is Map<Object?, Object?>) {
      return VpnPingResult.fromMap(raw, host: host, port: port);
    }
    return VpnPingResult.failure(
      host: host,
      port: port,
      error: 'Invalid ping response',
    );
  }
}
