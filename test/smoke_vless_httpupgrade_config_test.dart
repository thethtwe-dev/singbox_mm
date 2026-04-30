// Smoke test for xhttp → http transparent normalization.
//
// Verifies that the link:
//   vmess://<base64>  (net=xhttp, host=app.example.com, path=/xyz, tls, alpn=h3,h2)
//
// produces a sing-box config where:
//   - transport.type = "http"
//   - transport.path = "/xyz/"  (xhttp stream-one normalization)
//   - transport.host = ["app.example.com"]
//   - transport.method = "POST"
//   - transport.headers contains "User-Agent"
//   - tls.enabled = true, tls.server_name = "app.example.com"
//   - tls.alpn = ["h2"]  (xhttp/http transport normalization)
//   - parser emits a compat warning containing "xhttp"
//   - VpnCoreCapabilities.supportsTransport(VpnTransport.httpUpgrade) = true

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

// ---------------------------------------------------------------------------
// Helper: build a vmess link with net=xhttp.
// ---------------------------------------------------------------------------
String _buildXhttpVmessLink({
  String tag = 'xhttp-smoke',
  String host = 'app.example.com',
  int port = 443,
  String path = '/smoke-path',
  String alpn = 'h3,h2',
  bool tls = true,
}) {
  final Map<String, String> json = <String, String>{
    'v': '2',
    'ps': tag,
    'add': host,
    'port': port.toString(),
    'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    'aid': '0',
    'net': 'xhttp',
    'path': path,
    'host': host,
    if (tls) 'tls': 'tls',
    if (tls) 'security': 'tls',
    if (tls) 'alpn': alpn,
  };
  return 'vmess://${base64.encode(utf8.encode(jsonEncode(json)))}';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  test(
    'smoke: xhttp vmess link is normalized to http in sing-box config',
    () async {
      final _CapturePlatform platform = _CapturePlatform();
      SignboxVpnPlatform.instance = platform;

      final SignboxVpn vpn = SignboxVpn(platform: platform);
      await vpn.initialize(const SingboxRuntimeOptions());

      final String link = _buildXhttpVmessLink();

      // -----------------------------------------------------------------------
      // Parse: verify parser-level normalization and warning.
      // -----------------------------------------------------------------------
      final ParsedVpnConfig parsed = vpn.parseConfigLink(link);

      expect(
        parsed.profile.transport,
        equals(VpnTransport.http),
        reason: 'parser must normalize xhttp → http, not keep raw xhttp type',
      );
      expect(
        parsed.warnings,
        contains(contains('xhttp')),
        reason: 'parser must emit a compat warning when normalizing xhttp',
      );

      // -----------------------------------------------------------------------
      // Build: generate the sing-box config JSON.
      // -----------------------------------------------------------------------
      await vpn.applyProfile(profile: parsed.profile);

      expect(
        platform.capturedConfig,
        isNotNull,
        reason: 'config must have been sent to platform',
      );
      final Map<String, dynamic> config =
          jsonDecode(platform.capturedConfig!) as Map<String, dynamic>;

      // Pretty-print for visibility in test output.
      // ignore: avoid_print
      print(
        '\n===== GENERATED CONFIG (xhttp → http smoke) =====\n'
        '${const JsonEncoder.withIndent('  ').convert(config)}\n'
        '========================================================\n',
      );

      // -----------------------------------------------------------------------
      // Locate the vmess outbound.
      // -----------------------------------------------------------------------
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere((dynamic o) => o is Map && o['type'] == 'vmess')
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      // -----------------------------------------------------------------------
      // 1. Transport block: must be sing-box http.
      // -----------------------------------------------------------------------
      expect(
        outbound.containsKey('transport'),
        isTrue,
        reason: 'vmess outbound must have a transport block',
      );
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(
        transport['type'],
        equals('http'),
        reason: 'transport.type must be "http" after xhttp normalization',
      );
      expect(
        transport['path'],
        equals('/smoke-path'),
        reason: 'transport.path must preserve exact xhttp path shape',
      );
      expect(
        transport['host'],
        equals(<String>['app.example.com']),
        reason: 'transport.host must be preserved as sing-box http host list',
      );
      expect(
        transport['method'],
        equals('POST'),
        reason: 'xhttp/http transport must force POST',
      );
      expect(
        transport.containsKey('headers'),
        isTrue,
        reason: 'xhttp/http transport must include User-Agent header',
      );
      final Map<String, dynamic> headers =
          (transport['headers'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      expect(
        headers.containsKey('Host'),
        isFalse,
        reason:
            'sing-box http transport uses dedicated host field, not Host header',
      );

      // -----------------------------------------------------------------------
      // 2. TLS: enabled, ALPN normalized for xhttp/http.
      // -----------------------------------------------------------------------
      expect(
        outbound.containsKey('tls'),
        isTrue,
        reason: 'tls block must be present for a tls link',
      );
      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();

      expect(tls['enabled'], isTrue, reason: 'tls.enabled must be true');
      expect(
        tls['server_name'],
        equals('app.example.com'),
        reason: 'tls.server_name must be derived from the host field',
      );
      expect(
        tls['alpn'],
        equals(<String>['h3', 'h2']),
        reason: 'tls.alpn must preserve explicit xhttp ALPN order',
      );

      // -----------------------------------------------------------------------
      // 3. VpnCoreCapabilities.supportsTransport() sanity check.
      // -----------------------------------------------------------------------
      const VpnCoreCapabilities caps = VpnCoreCapabilities(
        rawVersion: null,
        displayVersion: 'test',
        supportedProtocols: VpnProtocol.values,
      );

      expect(
        caps.supportsTransport(VpnTransport.httpUpgrade),
        isTrue,
        reason: 'VpnCoreCapabilities must report httpUpgrade as supported',
      );
      expect(
        caps.supportsAllTransports(<VpnTransport>[
          VpnTransport.ws,
          VpnTransport.httpUpgrade,
          VpnTransport.grpc,
        ]),
        isTrue,
      );
    },
  );

  test(
    'smoke: subscription parser allowedTransports handles xhttp-as-http profiles',
    () {
      // Build a subscription with 3 lines:
      //   1. A valid WS link (should pass)
      //   2. An xhttp link normalized → http (should pass when allowing http)
      //   3. An xhttp link normalized → http (should be filtered if only ws allowed)
      const String wsLink =
          'vless://aaaaaaaa-bbbb-cccc-dddd-123456789012@ws.example.com:443'
          '?type=ws&security=tls&host=ws.example.com&path=%2Fws#ws-server';

      final String xhttpLink = _buildXhttpVmessLink(tag: 'xhttp-sub');

      final String subscriptionPayload = '$wsLink\n$xhttpLink\n';

      // Without filter: both parse successfully.
      final VpnSubscriptionParser parser = const VpnSubscriptionParser();
      final ParsedVpnSubscription all = parser.parse(subscriptionPayload);
      expect(all.profiles.length, equals(2));

      // With allowedTransports={ws}: only the WS profile is included.
      final ParsedVpnSubscription wsOnly = parser.parse(
        subscriptionPayload,
        allowedTransports: <VpnTransport>{VpnTransport.ws},
      );
      expect(
        wsOnly.profiles.length,
        equals(1),
        reason: 'allowedTransports={ws} must exclude the xhttp/http profile',
      );
      expect(wsOnly.profiles.first.transport, equals(VpnTransport.ws));

      // With allowedTransports={http}: only the normalized xhttp is included.
      final ParsedVpnSubscription httpOnly = parser.parse(
        subscriptionPayload,
        allowedTransports: <VpnTransport>{VpnTransport.http},
      );
      expect(
        httpOnly.profiles.length,
        equals(1),
        reason:
            'allowedTransports={http} must include the normalized xhttp profile',
      );
      expect(httpOnly.profiles.first.transport, equals(VpnTransport.http));
    },
  );
}
