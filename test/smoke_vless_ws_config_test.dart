// Smoke test for the VLESS+WS CDN config.
//
// Verifies that the exact link:
//   vless://11111111-2222-3333-4444-777777777777@ws-origin.example.net:443
//     ?path=%2F&security=tls&alpn=http%2F1.1&encryption=none
//     &host=cdn-host.example.net&fp=chrome&type=ws&sni=cdn-host.example.net#jp
//
// produces a sing-box config where:
//   - transport.type = "ws", path = "/", Host header = "cdn-host.example.net"
//   - tls.enabled = true, server_name = "cdn-host.example.net"
//   - tls.alpn = ["http/1.1"]
//   - tls.utls is ABSENT  ← the key fix
//   - multiplex.enabled = false
//   - dns-remote detours through the VLESS outbound tag "jp"

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:singbox_mm/singbox_mm.dart';
import 'package:singbox_mm/singbox_mm_platform_interface.dart';

// ---------------------------------------------------------------------------
// Minimal fake platform — captures the config JSON, stubs everything else.
// ---------------------------------------------------------------------------
class _CapturePlatform
    with MockPlatformInterfaceMixin
    implements SignboxVpnPlatform {
  String? capturedConfig;

  @override
  Stream<VpnConnectionState> get stateStream =>
      Stream<VpnConnectionState>.value(VpnConnectionState.disconnected);

  @override
  Stream<VpnConnectionSnapshot> get stateDetailsStream =>
      Stream<VpnConnectionSnapshot>.value(
        VpnConnectionSnapshot(
          state: VpnConnectionState.disconnected,
          timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );

  @override
  Stream<VpnRuntimeStats> get statsStream =>
      const Stream<VpnRuntimeStats>.empty();

  @override
  Future<void> initialize(SingboxRuntimeOptions options) async {}

  @override
  Future<void> setConfig(String configJson) async {
    capturedConfig = configJson;
  }

  @override
  Future<String> validateConfig(String configJson) async {
    return configJson;
  }

  @override
  Future<void> startVpn() async {}

  @override
  Future<void> stopVpn() async {}

  @override
  Future<void> restartVpn() async {}

  @override
  Future<VpnConnectionState> getState() async =>
      VpnConnectionState.disconnected;

  @override
  Future<VpnConnectionSnapshot> getStateDetails() async =>
      VpnConnectionSnapshot(
        state: VpnConnectionState.disconnected,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  @override
  Future<VpnRuntimeStats> getStats() async => VpnRuntimeStats.empty();

  @override
  Future<void> syncRuntimeState() async {}

  @override
  Future<String?> getLastError() async => null;

  @override
  Future<String?> getSingboxVersion() async => 'smoke-test';

  @override
  Future<bool> requestVpnPermission() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<VpnPingResult> pingServer({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 3),
    bool useTls = false,
    String? tlsServerName,
    bool allowInsecure = false,
  }) async => VpnPingResult(
    host: host,
    port: port,
    latency: const Duration(milliseconds: 1),
    checkedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

void main() {
  const String vlessLink =
      'vless://11111111-2222-3333-4444-777777777777@ws-origin.example.net:443'
      '?path=%2F&security=tls&alpn=http%2F1.1&encryption=none'
      '&host=cdn-host.example.net&fp=chrome&type=ws&sni=cdn-host.example.net#jp';

  test('smoke: VLESS+WS CDN link generates correct sing-box config', () async {
    final _CapturePlatform platform = _CapturePlatform();
    SignboxVpnPlatform.instance = platform;

    final SignboxVpn vpn = SignboxVpn(platform: platform);
    await vpn.initialize(const SingboxRuntimeOptions());

    // Parse the link and apply the profile (same code path as connectBasic).
    final ParsedVpnConfig parsed = vpn.parseConfigLink(vlessLink);
    await vpn.applyProfile(profile: parsed.profile);

    // -----------------------------------------------------------------------
    // Decode the captured config JSON.
    // -----------------------------------------------------------------------
    expect(
      platform.capturedConfig,
      isNotNull,
      reason: 'config was not sent to platform',
    );
    final Map<String, dynamic> config =
        jsonDecode(platform.capturedConfig!) as Map<String, dynamic>;

    // Pretty-print for visibility in test output.
    final String pretty = const JsonEncoder.withIndent('  ').convert(config);
    // ignore: avoid_print
    print(
      '\n========== GENERATED SING-BOX CONFIG ==========\n$pretty\n'
      '================================================\n',
    );

    // -----------------------------------------------------------------------
    // Find the VLESS outbound.
    // -----------------------------------------------------------------------
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> vlessOutbound =
        (outbounds.firstWhere((dynamic o) => o is Map && o['type'] == 'vless')
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();

    // -----------------------------------------------------------------------
    // 1. Basic outbound fields.
    // -----------------------------------------------------------------------
    expect(vlessOutbound['type'], equals('vless'));
    expect(vlessOutbound['server'], equals('ws-origin.example.net'));
    expect(vlessOutbound['server_port'], equals(443));
    expect(
      vlessOutbound['uuid'],
      equals('11111111-2222-3333-4444-777777777777'),
    );

    // -----------------------------------------------------------------------
    // 2. Transport — WebSocket with correct path and Host header.
    // -----------------------------------------------------------------------
    expect(
      vlessOutbound.containsKey('transport'),
      isTrue,
      reason: 'transport key must be present',
    );
    final Map<String, dynamic> transport =
        (vlessOutbound['transport'] as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(transport['type'], equals('ws'), reason: 'transport.type');
    expect(transport['path'], equals('/'), reason: 'transport.path');
    final Map<String, dynamic> headers =
        (transport['headers'] as Map<dynamic, dynamic>).cast<String, dynamic>();
    expect(
      headers['Host'],
      equals('cdn-host.example.net'),
      reason: 'transport.headers.Host',
    );

    // -----------------------------------------------------------------------
    // 3. TLS — enabled, correct SNI, correct ALPN, NO utls block.
    // -----------------------------------------------------------------------
    expect(
      vlessOutbound.containsKey('tls'),
      isTrue,
      reason: 'tls key must be present',
    );
    final Map<String, dynamic> tls =
        (vlessOutbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();
    expect(tls['enabled'], isTrue, reason: 'tls.enabled');
    expect(
      tls['server_name'],
      equals('cdn-host.example.net'),
      reason: 'tls.server_name',
    );
    expect(
      tls['alpn'],
      equals(<String>['http/1.1']),
      reason: 'tls.alpn must be [http/1.1] only',
    );
    // Keep uTLS absent so sing-box honors explicit HTTP/1.1 ALPN for WS.
    expect(
      tls.containsKey('utls'),
      isFalse,
      reason: 'tls.utls must be omitted for http/1.1-only WS links',
    );

    // -----------------------------------------------------------------------
    // 4. VLESS-specific stability fields.
    // -----------------------------------------------------------------------
    final dynamic mux = vlessOutbound['multiplex'];
    if (mux != null) {
      expect(
        (mux as Map<dynamic, dynamic>)['enabled'],
        isFalse,
        reason: 'multiplex.enabled must be false for VLESS stability',
      );
    }

    // -----------------------------------------------------------------------
    // 5. DNS — fakeip enabled, remote DNS detours through the proxy.
    // -----------------------------------------------------------------------
    final Map<String, dynamic> dns = (config['dns'] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();
    final List<dynamic> dnsServers = dns['servers'] as List<dynamic>;

    // fakeip server must exist.
    final bool hasFakeip = dnsServers.any(
      (dynamic s) => s is Map && s['address'] == 'fakeip',
    );
    expect(hasFakeip, isTrue, reason: 'fakeip DNS server must be present');

    // dns-remote must route through the VLESS outbound.
    final Map<String, dynamic> remoteServer =
        (dnsServers.firstWhere(
                  (dynamic s) => s is Map && s['tag'] == 'dns-remote',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(
      remoteServer['detour'],
      equals('jp'),
      reason: 'dns-remote must detour through the VLESS outbound tag "jp"',
    );

    // -----------------------------------------------------------------------
    // 6. Route — DNS port 53 must be hijacked into the DNS module.
    // -----------------------------------------------------------------------
    final Map<String, dynamic> route =
        (config['route'] as Map<dynamic, dynamic>).cast<String, dynamic>();
    final List<dynamic> rules = route['rules'] as List<dynamic>;
    final bool hasDnsRule = rules.any(
      (dynamic r) => r is Map && r['port'] == 53 && r['action'] == 'hijack-dns',
    );
    expect(
      hasDnsRule,
      isTrue,
      reason: 'DNS port 53 must be handled by hijack-dns',
    );
  });
}
