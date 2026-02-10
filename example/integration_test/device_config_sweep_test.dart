import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

const String _rawConfigs = String.fromEnvironment('VPN_CONFIGS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs config sweep on connected device', (
    WidgetTester tester,
  ) async {
    if (_rawConfigs.trim().isEmpty) {
      fail('VPN_CONFIGS dart-define is empty. Provide configs joined by "||".');
    }

    final List<String> configs = _rawConfigs
        .split('||')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);

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

    final List<Map<String, Object?>> reports = <Map<String, Object?>>[];

    for (int index = 0; index < configs.length; index++) {
      final String config = configs[index];
      final Stopwatch watch = Stopwatch()..start();
      debugPrint('[device-sweep] #${index + 1} START');

      ParsedVpnConfig? parsed;
      try {
        parsed = vpn.parseConfigLink(config);
      } on Object catch (error) {
        watch.stop();
        reports.add(<String, Object?>{
          'index': index + 1,
          'tag': 'parse-error',
          'scheme': null,
          'connected': false,
          'probeSuccess': false,
          'uplinkBytes': 0,
          'downlinkBytes': 0,
          'error': 'parse: $error',
          'elapsedMs': watch.elapsedMilliseconds,
        });
        debugPrint('[device-sweep] #${index + 1} PARSE_ERROR $error');
        continue;
      }

      bool connected = false;
      VpnConnectivityProbe? probe;
      VpnRuntimeStats stats = VpnRuntimeStats.empty();
      String? lastError;
      String? error;

      try {
        await vpn.connectManualConfigLink(
          configLink: config,
          requestPermission: false,
        );

        connected = await _waitForState(
          vpn,
          VpnConnectionState.connected,
          timeout: const Duration(seconds: 20),
        );

        await Future<void>.delayed(const Duration(seconds: 8));
        stats = await vpn.getStats();
        probe = await vpn.probeConnectivity(
          timeout: const Duration(seconds: 8),
        );
        lastError = await vpn.getLastError();
      } on Object catch (runtimeError) {
        error = runtimeError.toString();
      } finally {
        try {
          await vpn.stop();
          await _waitForState(
            vpn,
            VpnConnectionState.disconnected,
            timeout: const Duration(seconds: 8),
          );
        } on Object {
          // Best effort stop between test entries.
        }
      }

      watch.stop();
      final Map<String, Object?> row = <String, Object?>{
        'index': index + 1,
        'tag': parsed.profile.tag,
        'scheme': parsed.scheme,
        'connected': connected,
        'probeSuccess': probe?.success ?? false,
        'probeStatusCode': probe?.statusCode,
        'probeError': probe?.error,
        'totalUploaded': stats.totalUploaded,
        'totalDownloaded': stats.totalDownloaded,
        'lastError': lastError,
        'error': error,
        'elapsedMs': watch.elapsedMilliseconds,
      };
      reports.add(row);
      debugPrint('[device-sweep] #${index + 1} RESULT ${jsonEncode(row)}');
    }

    final int connectedCount = reports
        .where((Map<String, Object?> row) => row['connected'] == true)
        .length;
    final int probeOkCount = reports
        .where((Map<String, Object?> row) => row['probeSuccess'] == true)
        .length;

    debugPrint(
      '[device-sweep] SUMMARY connected=$connectedCount/${reports.length} probe_ok=$probeOkCount/${reports.length}',
    );
    debugPrint('[device-sweep] REPORT ${jsonEncode(reports)}');

    expect(reports.length, configs.length);
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
