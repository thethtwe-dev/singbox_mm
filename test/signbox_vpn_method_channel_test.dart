import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm_method_channel.dart';
import 'package:singbox_mm/src/models/vpn_connection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelSignboxVpn platform = MethodChannelSignboxVpn();
  const MethodChannel channel = MethodChannel('singbox_mm/methods');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getState':
              return 'connected';
            case 'getStateDetails':
              return <String, Object?>{
                'state': 'connected',
                'timestamp': 1700000000000,
                'detailCode': 'OK',
                'networkValidated': true,
              };
            case 'getStats':
              return <String, Object?>{
                'uplinkBytes': 100,
                'downlinkBytes': 200,
                'activeConnections': 1,
                'updatedAt': 1234,
              };
            case 'pingServer':
              return <String, Object?>{'ok': true, 'latencyMs': 28};
            case 'requestVpnPermission':
              return true;
            case 'requestNotificationPermission':
              return true;
            case 'syncRuntimeState':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getState returns parsed enum', () async {
    expect(await platform.getState(), VpnConnectionState.connected);
  });

  test('getStats parses map payload', () async {
    final stats = await platform.getStats();
    expect(stats.totalUploaded, 100);
    expect(stats.totalDownloaded, 200);
    expect(stats.activeConnections, 1);
  });

  test('pingServer parses ping payload', () async {
    final result = await platform.pingServer(host: '1.1.1.1', port: 443);
    expect(result.success, isTrue);
    expect(result.latencyMs, 28);
    expect(result.checkMethod, 'tcp_connect');
  });

  test('getStateDetails parses detailed payload', () async {
    final details = await platform.getStateDetails();
    expect(details.state, VpnConnectionState.connected);
    expect(details.detailCode, 'OK');
    expect(details.networkValidated, isTrue);
  });

  test('requestVpnPermission returns bool payload', () async {
    expect(await platform.requestVpnPermission(), isTrue);
  });

  test('requestNotificationPermission returns bool payload', () async {
    expect(await platform.requestNotificationPermission(), isTrue);
  });

  test('syncRuntimeState invokes platform method', () async {
    await platform.syncRuntimeState();
  });
}
