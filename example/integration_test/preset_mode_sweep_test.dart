import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

const String _rawConfigs = String.fromEnvironment('VPN_CONFIGS');
const String _rawModes = String.fromEnvironment('PRESET_MODES');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs preset mode sweep on connected device', (
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

    final List<GfwPresetMode> modes = _resolveModes(_rawModes);
    if (modes.isEmpty) {
      fail('No valid PRESET_MODES provided.');
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

    final List<Map<String, Object?>> reports = <Map<String, Object?>>[];

    for (final GfwPresetMode mode in modes) {
      final GfwPresetPack preset = GfwPresetPack.fromMode(mode);
      debugPrint(
        '[preset-sweep] MODE_START ${preset.mode.name} (${preset.name}) with ${configs.length} configs',
      );

      for (int index = 0; index < configs.length; index++) {
        final String config = configs[index];
        final Stopwatch watch = Stopwatch()..start();
        debugPrint('[preset-sweep] ${preset.mode.name} #${index + 1} START');

        ParsedVpnConfig? parsed;
        try {
          parsed = vpn.parseConfigLink(config);
        } on Object catch (error) {
          watch.stop();
          final Map<String, Object?> parseRow = <String, Object?>{
            'mode': preset.mode.name,
            'preset': preset.name,
            'index': index + 1,
            'tag': 'parse-error',
            'scheme': null,
            'connected': false,
            'probeSuccess': false,
            'probeLatencyMs': null,
            'pingLatencyMs': null,
            'uplinkBytes': 0,
            'downlinkBytes': 0,
            'lastError': null,
            'error': 'parse: $error',
            'elapsedMs': watch.elapsedMilliseconds,
          };
          reports.add(parseRow);
          debugPrint(
            '[preset-sweep] ${preset.mode.name} #${index + 1} PARSE_ERROR ${jsonEncode(parseRow)}',
          );
          continue;
        }

        bool connected = false;
        VpnConnectivityProbe? probe;
        VpnPingResult? ping;
        VpnRuntimeStats stats = VpnRuntimeStats.empty();
        String? lastError;
        String? error;

        try {
          final ManualConnectResult result = await vpn
              .connectManualConfigLinkWithPreset(
                configLink: config,
                preset: preset,
                requestPermission: false,
              );

          connected = await _waitForState(
            vpn,
            VpnConnectionState.connected,
            timeout: const Duration(seconds: 20),
          );

          await Future<void>.delayed(const Duration(seconds: 5));
          ping = await vpn.pingProfile(profile: result.profile);
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
          'mode': preset.mode.name,
          'preset': preset.name,
          'index': index + 1,
          'tag': parsed.profile.tag,
          'scheme': parsed.scheme,
          'connected': connected,
          'probeSuccess': probe?.success ?? false,
          'probeStatusCode': probe?.statusCode,
          'probeLatencyMs': probe?.latencyMs,
          'probeError': probe?.error,
          'pingSuccess': ping?.success,
          'pingLatencyMs': ping?.latencyMs,
          'pingError': ping?.error,
          'totalUploaded': stats.totalUploaded,
          'totalDownloaded': stats.totalDownloaded,
          'lastError': lastError,
          'error': error,
          'elapsedMs': watch.elapsedMilliseconds,
        };
        reports.add(row);
        debugPrint(
          '[preset-sweep] ${preset.mode.name} #${index + 1} RESULT ${jsonEncode(row)}',
        );
      }

      final List<Map<String, Object?>> modeRows = reports
          .where((Map<String, Object?> row) => row['mode'] == preset.mode.name)
          .toList(growable: false);

      final Map<String, Object?> modeSummary = _buildModeSummary(
        mode: preset.mode.name,
        rows: modeRows,
      );
      debugPrint('[preset-sweep] MODE_SUMMARY ${jsonEncode(modeSummary)}');
    }

    debugPrint('[preset-sweep] FINAL_REPORT ${jsonEncode(reports)}');
    expect(reports.length, configs.length * modes.length);
  });
}

List<GfwPresetMode> _resolveModes(String rawModes) {
  final String normalized = rawModes.trim();
  if (normalized.isEmpty) {
    return GfwPresetMode.values;
  }

  final Set<GfwPresetMode> output = <GfwPresetMode>{};
  final List<String> entries = normalized.split(',');
  for (final String entry in entries) {
    final String modeName = entry.trim().toLowerCase();
    for (final GfwPresetMode mode in GfwPresetMode.values) {
      if (mode.name == modeName) {
        output.add(mode);
      }
    }
  }
  return output.toList(growable: false);
}

Map<String, Object?> _buildModeSummary({
  required String mode,
  required List<Map<String, Object?>> rows,
}) {
  int connectedCount = 0;
  int probeOkCount = 0;
  int pingOkCount = 0;
  int elapsedTotalMs = 0;
  int elapsedCount = 0;
  int probeLatencyTotalMs = 0;
  int probeLatencyCount = 0;
  int pingLatencyTotalMs = 0;
  int pingLatencyCount = 0;

  for (final Map<String, Object?> row in rows) {
    if (row['connected'] == true) {
      connectedCount++;
    }
    if (row['probeSuccess'] == true) {
      probeOkCount++;
    }
    if (row['pingSuccess'] == true) {
      pingOkCount++;
    }

    final Object? elapsedRaw = row['elapsedMs'];
    if (elapsedRaw is int) {
      elapsedTotalMs += elapsedRaw;
      elapsedCount++;
    }

    final Object? probeLatencyRaw = row['probeLatencyMs'];
    if (probeLatencyRaw is int) {
      probeLatencyTotalMs += probeLatencyRaw;
      probeLatencyCount++;
    }

    final Object? pingLatencyRaw = row['pingLatencyMs'];
    if (pingLatencyRaw is int) {
      pingLatencyTotalMs += pingLatencyRaw;
      pingLatencyCount++;
    }
  }

  return <String, Object?>{
    'mode': mode,
    'total': rows.length,
    'connected': connectedCount,
    'probeOk': probeOkCount,
    'pingOk': pingOkCount,
    'avgElapsedMs': elapsedCount == 0 ? null : elapsedTotalMs ~/ elapsedCount,
    'avgProbeLatencyMs': probeLatencyCount == 0
        ? null
        : probeLatencyTotalMs ~/ probeLatencyCount,
    'avgPingLatencyMs': pingLatencyCount == 0
        ? null
        : pingLatencyTotalMs ~/ pingLatencyCount,
  };
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
