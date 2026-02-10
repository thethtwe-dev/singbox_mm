import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

const String _vpnConfig = String.fromEnvironment('VPN_CONFIG');
const int _holdSeconds = int.fromEnvironment('HOLD_SECONDS', defaultValue: 120);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connects vpn and keeps tunnel alive for host-side checks', (
    WidgetTester tester,
  ) async {
    if (_vpnConfig.trim().isEmpty) {
      fail('VPN_CONFIG dart-define is empty.');
    }

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(
      const SingboxRuntimeOptions(
        logLevel: 'info',
        tunInterfaceName: 'sb-tun',
        tunInet4Address: '172.19.0.1/30',
        androidBinaryAssetByAbi: <String, String>{
          'arm64-v8a': 'assets/singbox/android/arm64-v8a/sing-box',
          'armeabi-v7a': 'assets/singbox/android/armeabi-v7a/sing-box',
          'x86_64': 'assets/singbox/android/x86_64/sing-box',
        },
      ),
    );

    final bool granted = await vpn.requestVpnPermission();
    if (!granted) {
      fail(
        'VPN permission denied on device. Please accept the permission prompt and retry.',
      );
    }

    await vpn.connectManualConfigLink(
      configLink: _vpnConfig,
      requestPermission: false,
    );

    final bool connected = await _waitForState(
      vpn,
      VpnConnectionState.connected,
      timeout: const Duration(seconds: 25),
    );
    if (!connected) {
      fail('VPN did not reach connected state.');
    }

    debugPrint('[vpn-hold] connected=true holdSeconds=$_holdSeconds');
    await Future<void>.delayed(Duration(seconds: _holdSeconds));

    await vpn.stop();
    await _waitForState(
      vpn,
      VpnConnectionState.disconnected,
      timeout: const Duration(seconds: 8),
    );
    debugPrint('[vpn-hold] disconnected=true');
  });
}

Future<bool> _waitForState(
  SignboxVpn vpn,
  VpnConnectionState expected, {
  required Duration timeout,
}) async {
  final DateTime deadline = DateTime.now().toUtc().add(timeout);
  while (DateTime.now().toUtc().isBefore(deadline)) {
    final VpnConnectionState state = await vpn.getState();
    if (state == expected) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return false;
}
