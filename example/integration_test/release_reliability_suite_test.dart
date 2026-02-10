import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

const String _rawConfig = String.fromEnvironment('VPN_CONFIG');
const String _rawPassphrase = String.fromEnvironment('SBMM_PASSPHRASE');
const String _rawPresetMode = String.fromEnvironment(
  'PRESET_MODE',
  defaultValue: 'balanced',
);
const String _rawCheckUrls = String.fromEnvironment('CHECK_URLS');
const int _durationSeconds = int.fromEnvironment(
  'DURATION_SECONDS',
  defaultValue: 75,
);
const int _sampleIntervalSeconds = int.fromEnvironment(
  'SAMPLE_INTERVAL_SECONDS',
  defaultValue: 10,
);
const int _probeTimeoutMs = int.fromEnvironment(
  'PROBE_TIMEOUT_MS',
  defaultValue: 8000,
);
const String _rawMinSuccessRatio = String.fromEnvironment(
  'MIN_SUCCESS_RATIO',
  defaultValue: '0.70',
);
const bool _requireValidatedNetwork = bool.fromEnvironment(
  'REQUIRE_VALIDATED_NETWORK',
  defaultValue: false,
);

const List<String> _defaultCheckUrls = <String>[
  'http://cp.cloudflare.com',
  'https://connectivitycheck.gstatic.com/generate_204',
  'https://www.google.com/generate_204',
  'https://www.facebook.com',
  'https://telegram.org',
  'https://www.viber.com',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('release reliability suite keeps tunnel stable under app probes', (
    WidgetTester tester,
  ) async {
    if (_rawConfig.trim().isEmpty) {
      fail('VPN_CONFIG dart-define is empty.');
    }

    final List<String> checkUrls = _resolveCheckUrls(_rawCheckUrls);
    if (checkUrls.isEmpty) {
      fail('No CHECK_URLS provided and default probe URL list resolved empty.');
    }

    final GfwPresetMode presetMode = _resolvePresetMode(_rawPresetMode);
    final GfwPresetPack preset = GfwPresetPack.fromMode(presetMode);
    final double minSuccessRatio =
        double.tryParse(_rawMinSuccessRatio.trim()) ?? 0.70;

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

    final String? sbmmPassphrase = _rawPassphrase.trim().isEmpty
        ? null
        : _rawPassphrase.trim();
    final Duration probeTimeout = Duration(milliseconds: _probeTimeoutMs);

    final List<Map<String, Object?>> samples = <Map<String, Object?>>[];
    int totalProbeChecks = 0;
    int totalProbeSuccess = 0;
    int pingSuccessCount = 0;
    int validatedNetworkSamples = 0;
    int maxTotalBytes = 0;
    bool disconnectedDuringRun = false;
    bool errorDuringRun = false;

    try {
      final ManualConnectResult connect = await vpn
          .connectManualConfigLinkWithPreset(
            configLink: _rawConfig.trim(),
            sbmmPassphrase: sbmmPassphrase,
            preset: preset,
            requestPermission: false,
          );

      final bool connected = await _waitForState(
        vpn,
        VpnConnectionState.connected,
        timeout: const Duration(seconds: 25),
      );
      if (!connected) {
        fail('VPN did not reach connected state before reliability sampling.');
      }

      final DateTime deadline = DateTime.now().toUtc().add(
        Duration(seconds: _durationSeconds),
      );

      while (DateTime.now().toUtc().isBefore(deadline)) {
        final VpnConnectionState state = await vpn.getState();
        final VpnConnectionSnapshot detail = await vpn.getStateDetails();
        final VpnRuntimeStats stats = await vpn.getStats();
        final VpnPingResult ping = await vpn.pingProfile(
          profile: connect.profile,
          timeout: probeTimeout,
        );

        if (detail.networkValidated == true) {
          validatedNetworkSamples++;
        }
        if (ping.success) {
          pingSuccessCount++;
        }

        final int totalBytes = stats.totalDownloaded + stats.totalUploaded;
        if (totalBytes > maxTotalBytes) {
          maxTotalBytes = totalBytes;
        }

        if (state == VpnConnectionState.disconnected) {
          disconnectedDuringRun = true;
        } else if (state == VpnConnectionState.error) {
          errorDuringRun = true;
        }

        final List<Map<String, Object?>> probeRows = <Map<String, Object?>>[];
        for (final String url in checkUrls) {
          final VpnConnectivityProbe probe = await vpn.probeConnectivity(
            url: url,
            timeout: probeTimeout,
          );
          totalProbeChecks++;
          if (probe.success) {
            totalProbeSuccess++;
          }
          probeRows.add(<String, Object?>{
            'url': url,
            'success': probe.success,
            'statusCode': probe.statusCode,
            'latencyMs': probe.latencyMs,
            'error': probe.error,
          });
        }

        final int sampleProbeSuccess = probeRows
            .where((Map<String, Object?> row) => row['success'] == true)
            .length;

        samples.add(<String, Object?>{
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'state': state.name,
          'detailCode': detail.detailCode,
          'networkValidated': detail.networkValidated,
          'privateDnsServerName': detail.privateDnsServerName,
          'activeInterface': detail.activeInterface,
          'underlyingTransports': detail.underlyingTransports,
          'pingSuccess': ping.success,
          'pingLatencyMs': ping.latencyMs,
          'totalUploaded': stats.totalUploaded,
          'totalDownloaded': stats.totalDownloaded,
          'downloadSpeed': stats.downloadSpeed,
          'uploadSpeed': stats.uploadSpeed,
          'probeSuccessCount': sampleProbeSuccess,
          'probeTotalCount': probeRows.length,
          'probes': probeRows,
        });

        await Future<void>.delayed(Duration(seconds: _sampleIntervalSeconds));
      }

      final double probeSuccessRatio = totalProbeChecks == 0
          ? 0
          : totalProbeSuccess / totalProbeChecks;
      final double pingSuccessRatio = samples.isEmpty
          ? 0
          : pingSuccessCount / samples.length;

      final Map<String, Object?> summary = <String, Object?>{
        'presetMode': presetMode.name,
        'samples': samples.length,
        'durationSeconds': _durationSeconds,
        'sampleIntervalSeconds': _sampleIntervalSeconds,
        'checkUrlCount': checkUrls.length,
        'probeSuccess': totalProbeSuccess,
        'probeChecks': totalProbeChecks,
        'probeSuccessRatio': probeSuccessRatio,
        'pingSuccessCount': pingSuccessCount,
        'pingSuccessRatio': pingSuccessRatio,
        'validatedNetworkSamples': validatedNetworkSamples,
        'maxTotalBytes': maxTotalBytes,
        'disconnectedDuringRun': disconnectedDuringRun,
        'errorDuringRun': errorDuringRun,
      };

      debugPrint('[release-reliability] SUMMARY ${jsonEncode(summary)}');
      debugPrint('[release-reliability] SAMPLES ${jsonEncode(samples)}');

      expect(disconnectedDuringRun, isFalse);
      expect(errorDuringRun, isFalse);
      expect(probeSuccessRatio, greaterThanOrEqualTo(minSuccessRatio));
      expect(maxTotalBytes, greaterThan(0));
      if (_requireValidatedNetwork) {
        expect(validatedNetworkSamples, greaterThan(0));
      }
    } finally {
      try {
        await vpn.stop();
      } on Object {
        // Best effort stop for integration cleanup.
      }
    }
  });
}

List<String> _resolveCheckUrls(String raw) {
  final String normalized = raw.trim();
  if (normalized.isEmpty) {
    return _defaultCheckUrls;
  }
  return normalized
      .split('||')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

GfwPresetMode _resolvePresetMode(String raw) {
  final String normalized = raw.trim().toLowerCase();
  for (final GfwPresetMode mode in GfwPresetMode.values) {
    if (mode.name == normalized) {
      return mode;
    }
  }
  fail(
    'Unsupported PRESET_MODE="$raw". Supported values: ${GfwPresetMode.values.map((GfwPresetMode item) => item.name).join(', ')}',
  );
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
