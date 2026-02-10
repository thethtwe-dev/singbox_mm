import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

const String _rawConfig = String.fromEnvironment('VPN_CONFIG');
const String _rawPassphrase = String.fromEnvironment('SBMM_PASSPHRASE');
const int _stressSeconds = int.fromEnvironment(
  'STRESS_SECONDS',
  defaultValue: 90,
);
const bool _requireHandoverSignal = bool.fromEnvironment(
  'REQUIRE_HANDOVER_SIGNAL',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps tunnel alive during network handover stress', (
    WidgetTester tester,
  ) async {
    if (_rawConfig.trim().isEmpty) {
      fail('VPN_CONFIG dart-define is empty.');
    }

    final String sbmmPassphrase = _rawPassphrase.trim();
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

    final List<VpnConnectionState> states = <VpnConnectionState>[];
    final List<VpnConnectionSnapshot> snapshots = <VpnConnectionSnapshot>[];

    final StreamSubscription<VpnConnectionState> stateSub = vpn.stateStream
        .listen(states.add);
    final StreamSubscription<VpnConnectionSnapshot> detailSub = vpn
        .stateDetailsStream
        .listen(snapshots.add);

    try {
      await vpn.connectManualConfigLink(
        configLink: _rawConfig.trim(),
        sbmmPassphrase: sbmmPassphrase.isEmpty ? null : sbmmPassphrase,
        requestPermission: false,
      );

      final bool connected = await _waitForState(
        vpn,
        VpnConnectionState.connected,
        timeout: const Duration(seconds: 20),
      );
      if (!connected) {
        fail('VPN did not reach connected state before stress window.');
      }

      // Ignore startup transitions and only evaluate stability during stress.
      states.clear();
      snapshots.clear();

      final DateTime deadline = DateTime.now().toUtc().add(
        Duration(seconds: _stressSeconds),
      );
      while (DateTime.now().toUtc().isBefore(deadline)) {
        final VpnConnectionState state = await vpn.getState();
        if (state == VpnConnectionState.error ||
            state == VpnConnectionState.disconnected) {
          fail('VPN dropped during handover stress: $state');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      final VpnConnectivityProbe probe = await vpn.probeConnectivity(
        timeout: const Duration(seconds: 8),
      );
      final VpnRuntimeStats stats = await vpn.getStats();

      final int handoverSignalCount = snapshots
          .where(
            (VpnConnectionSnapshot item) =>
                item.detailCode == 'NETWORK_HANDOVER',
          )
          .length;
      final int unvalidatedCount = snapshots
          .where(
            (VpnConnectionSnapshot item) =>
                item.detailCode == 'NETWORK_UNVALIDATED',
          )
          .length;
      final int privateDnsBrokenCount = snapshots
          .where(
            (VpnConnectionSnapshot item) =>
                item.detailCode == 'PRIVATE_DNS_BROKEN',
          )
          .length;

      final Map<String, Object?> summary = <String, Object?>{
        'stressSeconds': _stressSeconds,
        'statesSeen': states
            .map((VpnConnectionState item) => item.name)
            .toList(growable: false),
        'handoverSignalCount': handoverSignalCount,
        'unvalidatedCount': unvalidatedCount,
        'privateDnsBrokenCount': privateDnsBrokenCount,
        'probeSuccess': probe.success,
        'probeStatusCode': probe.statusCode,
        'probeLatencyMs': probe.latencyMs,
        'totalUploaded': stats.totalUploaded,
        'totalDownloaded': stats.totalDownloaded,
      };
      debugPrint('[handover-stress] SUMMARY ${jsonEncode(summary)}');

      expect(probe.success, isTrue);
      expect(states.contains(VpnConnectionState.error), isFalse);
      expect(states.contains(VpnConnectionState.disconnected), isFalse);
      if (_requireHandoverSignal) {
        expect(handoverSignalCount, greaterThan(0));
      }
    } finally {
      await stateSub.cancel();
      await detailSub.cancel();
      try {
        await vpn.stop();
      } on Object {
        // Best-effort stop for integration cleanup.
      }
    }
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
