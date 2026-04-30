import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:singbox_mm/singbox_mm.dart';
import 'package:singbox_mm/singbox_mm_method_channel.dart';
import 'package:singbox_mm/singbox_mm_platform_interface.dart';

class FakeSignboxVpnPlatform
    with MockPlatformInterfaceMixin
    implements SignboxVpnPlatform {
  String? latestConfig;
  String? lastError;
  String? singboxVersion = 'sing-box test';
  bool initialized = false;
  bool started = false;
  int startCalls = 0;
  int stopCalls = 0;
  int restartCalls = 0;
  bool pingShouldFail = false;
  bool permissionGranted = true;
  bool notificationPermissionGranted = true;
  bool throwOnGetState = false;
  bool throwOnGetStats = false;
  int permissionRequests = 0;
  int syncCalls = 0;
  int pingRequests = 0;
  VpnConnectionSnapshot? stateDetailsOverride;
  final Map<String, int> pingLatencyByHost = <String, int>{};

  @override
  Stream<VpnConnectionState> get stateStream =>
      Stream<VpnConnectionState>.value(
        started
            ? VpnConnectionState.connected
            : VpnConnectionState.disconnected,
      );

  @override
  Stream<VpnConnectionSnapshot> get stateDetailsStream =>
      Stream<VpnConnectionSnapshot>.value(
        VpnConnectionSnapshot(
          state: started
              ? VpnConnectionState.connected
              : VpnConnectionState.disconnected,
          timestamp: DateTime.now().toUtc(),
        ),
      );

  @override
  Stream<VpnRuntimeStats> get statsStream =>
      const Stream<VpnRuntimeStats>.empty();

  @override
  Future<void> initialize(SingboxRuntimeOptions options) async {
    initialized = true;
  }

  @override
  Future<bool> requestVpnPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return notificationPermissionGranted;
  }

  @override
  Future<void> setConfig(String configJson) async {
    latestConfig = configJson;
  }

  @override
  Future<String> validateConfig(String configJson) async {
    return configJson;
  }

  @override
  Future<void> startVpn() async {
    startCalls++;
    started = true;
  }

  @override
  Future<void> stopVpn() async {
    stopCalls++;
    started = false;
  }

  @override
  Future<void> restartVpn() async {
    restartCalls++;
    started = true;
  }

  @override
  Future<VpnConnectionState> getState() async {
    if (throwOnGetState) {
      throw Exception('state unavailable');
    }
    return started
        ? VpnConnectionState.connected
        : VpnConnectionState.disconnected;
  }

  @override
  Future<VpnConnectionSnapshot> getStateDetails() async {
    if (stateDetailsOverride case final VpnConnectionSnapshot snapshot) {
      return snapshot;
    }
    return VpnConnectionSnapshot(
      state: started
          ? VpnConnectionState.connected
          : VpnConnectionState.disconnected,
      timestamp: DateTime.now().toUtc(),
    );
  }

  @override
  Future<VpnRuntimeStats> getStats() async {
    if (throwOnGetStats) {
      throw Exception('stats unavailable');
    }
    return VpnRuntimeStats.empty();
  }

  @override
  Future<void> syncRuntimeState() async {
    syncCalls++;
  }

  @override
  Future<String?> getLastError() async => lastError;

  @override
  Future<String?> getSingboxVersion() async => singboxVersion;

  @override
  Future<VpnPingResult> pingServer({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 3),
    bool useTls = false,
    String? tlsServerName,
    bool allowInsecure = false,
  }) async {
    pingRequests++;
    if (pingShouldFail) {
      return VpnPingResult.failure(host: host, port: port, error: 'timeout');
    }
    final int latency = pingLatencyByHost[host] ?? 42;
    return VpnPingResult(
      host: host,
      port: port,
      latency: Duration(milliseconds: latency),
      checkedAt: DateTime.now().toUtc(),
    );
  }
}

void main() {
  final SignboxVpnPlatform initialPlatform = SignboxVpnPlatform.instance;

  test('$MethodChannelSignboxVpn is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSignboxVpn>());
  });

  test('applyProfile generates and sends config', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      bypassPolicy: const BypassPolicy(directDomains: <String>['lan']),
      throttlePolicy: const TrafficThrottlePolicy(enableTcpBrutal: true),
    );

    expect(fakePlatform.initialized, isTrue);
    expect(fakePlatform.syncCalls, 1);
    expect(fakePlatform.latestConfig, isNotNull);

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;

    expect(config['inbounds'], isNotEmpty);
    expect(config['outbounds'], isNotEmpty);
    expect((config['route'] as Map<String, dynamic>)['final'], 'proxy-main');
  });

  test('generated config has no geosite/geoip db dependencies', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      bypassPolicy: const BypassPolicy(
        directDomains: <String>['google.com', 'facebook.com'],
        directCidrs: <String>['10.0.0.0/8'],
      ),
    );

    final String configJson = fakePlatform.latestConfig ?? '';
    final String lowered = configJson.toLowerCase();
    expect(lowered.contains('geosite'), isFalse);
    expect(lowered.contains('geoip'), isFalse);
  });

  test('applyProfile maps dashboard settings to sing-box config', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      bypassPolicy: const BypassPolicy(
        directDomains: <String>['lan'],
        directCidrs: <String>['10.0.0.0/8'],
      ),
      featureSettings: SingboxFeatureSettings(
        advanced: const AdvancedOptions(memoryLimit: true, debugMode: true),
        route: const RouteOptions(
          blockAdvertisements: true,
          bypassLan: true,
          resolveDestination: true,
          blockQuicOnTcpProfiles: true,
          ipv6RouteMode: SingboxIpv6RouteMode.prefer,
        ),
        dns: const DnsOptions(
          remoteDns: 'udp://1.1.1.1',
          directDns: '1.1.1.1',
          enableDnsRouting: true,
        ),
        inbound: const InboundOptions(
          strictRoute: false,
          tunImplementation: SingboxTunImplementation.gvisor,
          mixedPort: 12334,
          transparentProxyPort: 12335,
          shareVpnInLocalNetwork: true,
          includePackages: <String>['com.example.browser'],
          excludePackages: <String>['com.example.bank'],
        ),
        misc: const MiscOptions(clashApiPort: 16756),
        warp: const WarpOptions(
          enableWarp: true,
          detourMode: WarpDetourMode.detourProxiesThroughWarp,
          outboundTemplate: <String, Object?>{
            'type': 'wireguard',
            'tag': 'warp-out',
            'server': '162.159.193.10',
            'server_port': 2408,
            'private_key': 'test-private-key',
            'peer_public_key': 'test-peer-public-key',
            'local_address': <String>['172.16.0.2/32'],
          },
        ),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> log = config['log'] as Map<String, dynamic>;
    expect(log['level'], 'debug');

    final List<dynamic> inbounds = config['inbounds'] as List<dynamic>;
    final Map<String, dynamic> tunInbound =
        (inbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> && item['type'] == 'tun',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(tunInbound['strict_route'], isFalse);
    expect(tunInbound['stack'], 'gvisor');
    expect(tunInbound.containsKey('sniffing'), isFalse);
    expect(tunInbound.containsKey('sniff'), isFalse);
    expect(tunInbound.containsKey('sniff_override_destination'), isFalse);
    expect(tunInbound['mtu'], 1100);
    expect(tunInbound.containsKey('inet6_address'), isFalse);
    expect(tunInbound['include_package'], <String>['com.example.browser']);
    expect(tunInbound['exclude_package'], <String>['com.example.bank']);

    final Map<String, dynamic> mixedInbound =
        (inbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> && item['type'] == 'mixed',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(mixedInbound['listen'], '0.0.0.0');
    expect(mixedInbound['listen_port'], 12334);

    final Map<String, dynamic> dns = config['dns'] as Map<String, dynamic>;
    final List<dynamic> dnsServers = dns['servers'] as List<dynamic>;
    final Map<String, dynamic> remoteDns =
        (dnsServers.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'dns-remote',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(remoteDns['address'], 'udp://1.1.1.1');

    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> proxyOutbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'proxy-main',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(proxyOutbound['detour'], 'warp-out');

    final Map<String, dynamic> route = config['route'] as Map<String, dynamic>;
    final List<dynamic> rules = route['rules'] as List<dynamic>;
    expect(
      rules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) => rule['action'] == 'sniff',
      ),
      isTrue,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) =>
            rule['protocol'] == 'dns' && rule['action'] == 'hijack-dns',
      ),
      isTrue,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any((Map<String, dynamic> rule) {
        if (rule['action'] != 'hijack-dns' || rule['port'] != 53) {
          return false;
        }
        final Object? cidrRaw = rule['ip_cidr'];
        if (cidrRaw is! List<dynamic>) {
          return false;
        }
        return cidrRaw.contains('172.19.0.2/32');
      }),
      isTrue,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any((Map<String, dynamic> rule) {
        return rule['action'] == 'hijack-dns' && rule['port'] == 853;
      }),
      isFalse,
      reason: 'DNS-over-TLS traffic must not be parsed as plain DNS.',
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) => rule['ip_is_private'] == true,
      ),
      isTrue,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) => rule['domain_keyword'] != null,
      ),
      isTrue,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any((Map<String, dynamic> rule) {
        return rule['outbound'] == 'block' &&
            (rule['ip_cidr'] as List<dynamic>?)?.contains('::/0') == true;
      }),
      isFalse,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any((Map<String, dynamic> rule) {
        return rule['outbound'] == 'block' &&
            rule['network'] == 'udp' &&
            rule['port'] == 443;
      }),
      isTrue,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) =>
            rule['outbound'] == 'block' && rule['protocol'] == 'quic',
      ),
      isTrue,
    );

    final Map<String, dynamic> experimental =
        config['experimental'] as Map<String, dynamic>;
    final Map<String, dynamic> cacheFile =
        experimental['cache_file'] as Map<String, dynamic>;
    expect(cacheFile['enabled'], isFalse);
    final Map<String, dynamic> clashApi =
        experimental['clash_api'] as Map<String, dynamic>;
    expect(clashApi['external_controller'], '127.0.0.1:16756');
  });

  test('applyProfile keeps native tls block for hysteria2 outbound', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.hysteria2(
        tag: 'hy2-node',
        server: 'hy2.example.com',
        serverPort: 8443,
        password: 'hy2-pass',
        tls: const TlsOptions(
          enabled: true,
          serverName: 'hy2.example.com',
          allowInsecure: true,
        ),
        extra: const <String, Object?>{
          'obfs': <String, Object?>{
            'type': 'salamander',
            'password': 'hy2-obfs-pass',
          },
        },
      ),
      featureSettings: const SingboxFeatureSettings(
        tlsTricks: TlsTricksOptions(enableTlsFragment: true),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> hy2Outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> && item['tag'] == 'hy2-node',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();

    expect(hy2Outbound['type'], 'hysteria2');
    expect(hy2Outbound['tls'], isA<Map<dynamic, dynamic>>());
    expect(hy2Outbound['obfs'], <String, dynamic>{
      'type': 'salamander',
      'password': 'hy2-obfs-pass',
    });

    final Map<dynamic, dynamic> tls =
        hy2Outbound['tls'] as Map<dynamic, dynamic>;
    expect(tls['enabled'], isTrue);
    expect(tls['server_name'], 'hy2.example.com');
    expect(tls.containsKey('fragment'), isFalse);
    expect(tls.containsKey('utls'), isFalse);

    final List<dynamic> routeRules =
        (config['route'] as Map<String, dynamic>)['rules'] as List<dynamic>;
    expect(
      routeRules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) =>
            rule['outbound'] == 'block' &&
            rule['network'] == 'udp' &&
            rule['port'] == 443,
      ),
      isFalse,
    );
    expect(
      routeRules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) =>
            rule['outbound'] == 'block' && rule['protocol'] == 'quic',
      ),
      isFalse,
    );
  });

  test('vless quic transport keeps udp/quic route paths unblocked', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'vless-quic-path',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
        transport: VpnTransport.quic,
        tls: const TlsOptions(enabled: true),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> routeRules =
        (config['route'] as Map<String, dynamic>)['rules'] as List<dynamic>;
    expect(
      routeRules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) =>
            rule['outbound'] == 'block' &&
            rule['network'] == 'udp' &&
            rule['port'] == 443,
      ),
      isFalse,
    );
    expect(
      routeRules.whereType<Map<String, dynamic>>().any(
        (Map<String, dynamic> rule) =>
            rule['outbound'] == 'block' && rule['protocol'] == 'quic',
      ),
      isFalse,
    );
  });

  test('vless outbound forces multiplex disabled for stability', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'vless-mux-stable',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
        tls: const TlsOptions(enabled: true),
      ),
      throttlePolicy: const TrafficThrottlePolicy(
        enableMultiplex: true,
        multiplexPadding: true,
        multiplexConnections: 8,
        multiplexMinStreams: 4,
        multiplexMaxStreams: 16,
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'vless-mux-stable',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(outbound['type'], 'vless');
    expect(outbound['multiplex'], <String, dynamic>{'enabled': false});
  });

  test(
    'vless ws with http/1.1-only alpn strips utls to prevent h2 negotiation',
    () async {
      // Regression test: when transport=ws and alpn=http/1.1 only, sing-box's
      // uTLS fingerprint would override the explicit alpn list with Chrome's
      // built-in one (which includes h2). The CDN then negotiates HTTP/2,
      // breaking the WebSocket upgrade. The config builder must strip `utls`
      // in this case so sing-box honours the explicit alpn=[http/1.1].
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'vless-ws-cdn',
          server: 'ws-origin.example.net',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-777777777777',
          transport: VpnTransport.ws,
          websocketPath: '/',
          websocketHeaders: const <String, String>{
            'Host': 'cdn-host.example.net',
          },
          tls: const TlsOptions(
            enabled: true,
            serverName: 'cdn-host.example.net',
            utlsFingerprint: 'chrome',
            alpn: <String>['http/1.1'],
          ),
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'vless-ws-cdn',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(outbound['type'], 'vless');

      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();
      expect(tls['enabled'], isTrue);
      expect(tls['server_name'], 'cdn-host.example.net');
      expect(tls['alpn'], <String>['http/1.1']);
      // utls must be absent so sing-box uses the explicit alpn list
      expect(tls.containsKey('utls'), isFalse);

      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      expect(transport['type'], 'ws');
      expect(transport['path'], '/');
      expect(
        (transport['headers'] as Map<dynamic, dynamic>)['Host'],
        'cdn-host.example.net',
      );
    },
  );

  test(
    'vless ws link without explicit alpn defaults to http/1.1 and strips utls',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.connectManualConfigLink(
        configLink:
            'vless://11111111-2222-3333-4444-666666666666@ws-gateway.example.net:443?path=%2Fws%3Fed%3D2048&security=tls&encryption=none&host=ws-gateway.example.net&fp=randomized&type=ws&sni=ws-gateway.example.net#test-sg',
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'test-sg',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(tls['alpn'], <String>['http/1.1']);
      expect(tls.containsKey('utls'), isFalse);
      expect(transport['type'], 'ws');
      expect(transport['path'], '/ws');
      expect(transport['max_early_data'], 0);
      expect(transport.containsKey('early_data_header_name'), isFalse);
      expect(
        (transport['headers'] as Map<dynamic, dynamic>)['Host'],
        'ws-gateway.example.net',
      );
    },
  );

  test('vmess xhttp link normalizes to http transport without tls', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'vmess-xhttp',
      'add': 'app.example.com',
      'port': '80',
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'net': 'xhttp',
      'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
      'host': 'app.example.com',
      'tls': '',
      'security': 'none',
      'type': 'none',
    });
    final String vmessLink = 'vmess://${base64.encode(utf8.encode(vmessJson))}';

    await vpn.connectManualConfigLink(configLink: vmessLink);

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'vmess-xhttp',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> transport =
        (outbound['transport'] as Map<dynamic, dynamic>)
            .cast<String, dynamic>();

    expect(outbound['type'], 'vmess');
    expect(outbound['server'], 'app.example.com');
    expect(outbound['server_port'], 80);
    expect(outbound.containsKey('tls'), isFalse);

    expect(transport['type'], 'http');
    expect(transport['path'], '/QmCus87aYKFEQyuUX7rUfHXH4');
    expect(transport['host'], <String>['app.example.com']);
    expect(transport['method'], 'POST');
    // xhttp/http injects User-Agent header.
    expect(transport.containsKey('headers'), isTrue);
  });

  test('vmess xhttp with h3 alpn normalizes to http transport', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'vmess-xhttp-h3',
      'add': 'app.example.com',
      'port': '443',
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'net': 'xhttp',
      'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
      'host': 'app.example.com',
      'tls': 'tls',
      'security': 'tls',
      'alpn': 'h3,h2',
    });
    final String vmessLink = 'vmess://${base64.encode(utf8.encode(vmessJson))}';

    await vpn.connectManualConfigLink(configLink: vmessLink);

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'vmess-xhttp-h3',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> transport =
        (outbound['transport'] as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> tls = (outbound['tls'] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();

    expect(outbound['type'], 'vmess');
    expect(outbound['server_port'], 443);
    expect(transport['type'], 'http');
    expect(transport['path'], '/QmCus87aYKFEQyuUX7rUfHXH4');
    expect(transport['host'], <String>['app.example.com']);
    expect(transport['method'], 'POST');
    // xhttp/http keeps explicit ALPN order.
    expect(tls['alpn'], <String>['h3', 'h2']);
  });

  test(
    'vmess xhttp with tls and no hints normalizes to http transport',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      final String vmessJson = jsonEncode(<String, String>{
        'v': '2',
        'ps': 'vmess-xhttp-tls-default',
        'add': 'app.example.com',
        'port': '443',
        'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'net': 'xhttp',
        'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
        'host': 'app.example.com',
        'tls': 'tls',
        'security': 'tls',
      });
      final String vmessLink =
          'vmess://${base64.encode(utf8.encode(vmessJson))}';

      await vpn.connectManualConfigLink(configLink: vmessLink);

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'vmess-xhttp-tls-default',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();

      expect(outbound['type'], 'vmess');
      expect(outbound['server_port'], 443);
      expect(transport['type'], 'http');
      expect(transport['path'], '/QmCus87aYKFEQyuUX7rUfHXH4');
      expect(transport['host'], <String>['app.example.com']);
      expect(transport['method'], 'POST');
      // No ALPN hint: xhttp/http keeps h2 first, with http/1.1 fallback.
      expect(tls['alpn'], <String>['h2', 'http/1.1']);
    },
  );

  test(
    'vmess xhttp with explicit mode hint normalizes to http transport',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      final String vmessJson = jsonEncode(<String, String>{
        'v': '2',
        'ps': 'vmess-xhttp-mode-h3',
        'add': 'app.example.com',
        'port': '443',
        'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'net': 'xhttp',
        'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
        'host': 'app.example.com',
        'tls': 'tls',
        'security': 'tls',
        'alpn': 'h3,h2',
        'mode': 'h3',
      });
      final String vmessLink =
          'vmess://${base64.encode(utf8.encode(vmessJson))}';

      await vpn.connectManualConfigLink(configLink: vmessLink);

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'vmess-xhttp-mode-h3',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();

      expect(outbound['type'], 'vmess');
      expect(transport['type'], 'http');
      expect(transport['path'], '/QmCus87aYKFEQyuUX7rUfHXH4');
      expect(transport['host'], <String>['app.example.com']);
      expect(transport['method'], 'POST');
      // xhttp/http keeps explicit ALPN order.
      expect(tls['alpn'], <String>['h3', 'h2']);
    },
  );

  test('builder normalizes xhttp transport alias to http', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
        transport: VpnTransport.httpUpgrade,
        websocketPath: '/ws',
        websocketHeaders: const <String, String>{'Host': 'edge.example.com'},
      ),
      featureSettings: SingboxFeatureSettings(
        rawConfigPatch: <String, Object?>{
          'outbounds': <Object?>[
            <String, Object?>{
              'tag': 'proxy-main',
              'type': 'vless',
              'server': 'edge.example.com',
              'server_port': 443,
              'uuid': '11111111-2222-3333-4444-555555555555',
              'transport': <String, Object?>{
                'type': 'xhttp',
                'path': 'ws',
                'host': 'edge.example.com',
              },
            },
            <String, Object?>{'type': 'direct', 'tag': 'direct'},
            <String, Object?>{'type': 'block', 'tag': 'block'},
          ],
        },
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'proxy-main',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> transport =
        (outbound['transport'] as Map<dynamic, dynamic>)
            .cast<String, dynamic>();

    expect(transport['type'], 'http');
    expect(transport['path'], '/ws');
    expect(transport['host'], <String>['edge.example.com']);
    expect(transport.containsKey('method'), isFalse);
  });

  test('builder xray-compat mode maps xhttp alias to httpupgrade', () {
    const SingboxConfigBuilder builder = SingboxConfigBuilder();
    final VpnProfile profile = VpnProfile.vmess(
      tag: 'compat-node',
      server: 'app.example.com',
      serverPort: 443,
      uuid: '11111111-2222-3333-4444-555555555555',
      transport: VpnTransport.http,
      websocketPath: '/QmCus87aYKFEQyuUX7rUfHXH4',
      websocketHeaders: const <String, String>{'Host': 'app.example.com'},
      tls: const TlsOptions(
        enabled: true,
        serverName: 'app.example.com',
        alpn: <String>['h3', 'h2'],
      ),
      extra: const <String, Object?>{'_sbmm_transport_alias': 'xhttp'},
    );

    final Map<String, Object?> config = builder.build(
      profile: profile,
      transportBuildMode: SingboxTransportBuildMode.xrayCompat,
    );
    final List<Object?> outbounds =
        (config['outbounds'] as List<Object?>?) ?? const <Object?>[];
    final Map<String, Object?> outbound =
        (outbounds.firstWhere((Object? item) {
                  return item is Map<Object?, Object?> &&
                      item['tag'] == 'compat-node';
                })
                as Map<Object?, Object?>)
            .cast<String, Object?>();
    final Map<String, Object?> transport =
        (outbound['transport'] as Map<Object?, Object?>)
            .cast<String, Object?>();
    final Map<String, Object?> tls = (outbound['tls'] as Map<Object?, Object?>)
        .cast<String, Object?>();

    expect(transport['type'], 'httpupgrade');
    expect(transport['path'], '/QmCus87aYKFEQyuUX7rUfHXH4');
    expect(transport['host'], 'app.example.com');
    expect(
      (transport['headers'] as Map<Object?, Object?>)['Host'],
      'app.example.com',
    );
    expect(tls['alpn'], <String>['http/1.1']);
  });

  test(
    'builder resolves httpupgrade host from tls server_name fallback',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'proxy-main',
          server: 'edge.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          transport: VpnTransport.httpUpgrade,
          websocketPath: '/ws',
          tls: const TlsOptions(enabled: true, serverName: 'cdn.example.com'),
        ),
        featureSettings: SingboxFeatureSettings(
          rawConfigPatch: <String, Object?>{
            'outbounds': <Object?>[
              <String, Object?>{
                'tag': 'proxy-main',
                'type': 'vless',
                'server': 'edge.example.com',
                'server_port': 443,
                'uuid': '11111111-2222-3333-4444-555555555555',
                'transport': <String, Object?>{
                  'type': 'httpupgrade',
                  'path': '/ws',
                },
                'tls': <String, Object?>{
                  'enabled': true,
                  'server_name': 'cdn.example.com',
                },
              },
              <String, Object?>{'type': 'direct', 'tag': 'direct'},
              <String, Object?>{'type': 'block', 'tag': 'block'},
            ],
          },
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'proxy-main',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(transport['host'], 'cdn.example.com');
      expect(
        (transport['headers'] as Map<dynamic, dynamic>)['Host'],
        'cdn.example.com',
      );
      expect(
        (transport['headers'] as Map<dynamic, dynamic>)['User-Agent'],
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );
    },
  );

  test(
    'builder resolves httpupgrade host from outbound sni fallback',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'proxy-main',
          server: 'edge.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          transport: VpnTransport.httpUpgrade,
          websocketPath: '/ws',
          tls: const TlsOptions(enabled: true),
        ),
        featureSettings: SingboxFeatureSettings(
          rawConfigPatch: <String, Object?>{
            'outbounds': <Object?>[
              <String, Object?>{
                'tag': 'proxy-main',
                'type': 'vless',
                'server': 'edge.example.com',
                'server_port': 443,
                'uuid': '11111111-2222-3333-4444-555555555555',
                'sni': 'sni.edge.example.com',
                'transport': <String, Object?>{
                  'type': 'httpupgrade',
                  'path': '/ws',
                },
                'tls': <String, Object?>{'enabled': true},
              },
              <String, Object?>{'type': 'direct', 'tag': 'direct'},
              <String, Object?>{'type': 'block', 'tag': 'block'},
            ],
          },
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'proxy-main',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(transport['host'], 'sni.edge.example.com');
      expect(
        (transport['headers'] as Map<dynamic, dynamic>)['Host'],
        'sni.edge.example.com',
      );
    },
  );

  test('builder normalizes httpupgrade path to single leading slash', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vmess(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 80,
        uuid: '11111111-2222-3333-4444-555555555555',
        transport: VpnTransport.httpUpgrade,
        websocketPath: '/QmCus',
        tls: const TlsOptions(enabled: false),
      ),
      featureSettings: SingboxFeatureSettings(
        rawConfigPatch: <String, Object?>{
          'outbounds': <Object?>[
            <String, Object?>{
              'tag': 'proxy-main',
              'type': 'vmess',
              'server': 'edge.example.com',
              'server_port': 80,
              'uuid': '11111111-2222-3333-4444-555555555555',
              'transport': <String, Object?>{
                'type': 'httpupgrade',
                'path': '//QmCus',
                'host': 'edge.example.com',
              },
              'security': 'none',
            },
            <String, Object?>{'type': 'direct', 'tag': 'direct'},
            <String, Object?>{'type': 'block', 'tag': 'block'},
          ],
        },
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'proxy-main',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> transport =
        (outbound['transport'] as Map<dynamic, dynamic>)
            .cast<String, dynamic>();

    expect(transport['path'], '/QmCus');
  });

  test('httpupgrade tls forces http/1.1-only alpn', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
        transport: VpnTransport.httpUpgrade,
        websocketPath: '/ws',
        tls: const TlsOptions(
          enabled: true,
          serverName: 'edge.example.com',
          alpn: <String>['h3', 'h2'],
        ),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'proxy-main',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> tls = (outbound['tls'] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();

    expect(tls['alpn'], <String>['http/1.1']);
    expect(tls.containsKey('utls'), isFalse);
  });

  test('httpupgrade tls defaults alpn when empty', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
        transport: VpnTransport.httpUpgrade,
        websocketPath: '/ws',
        tls: const TlsOptions(
          enabled: true,
          serverName: 'edge.example.com',
          alpn: <String>[],
        ),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'proxy-main',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> tls = (outbound['tls'] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();

    expect(tls['alpn'], <String>['http/1.1']);
  });

  test(
    'httpupgrade on 443 recreates tls and enforces http/1.1 alpn when missing',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vmess(
          tag: 'proxy-main',
          server: 'edge.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          transport: VpnTransport.httpUpgrade,
          websocketPath: '/ws',
          tls: const TlsOptions(enabled: true, serverName: 'edge.example.com'),
        ),
        featureSettings: SingboxFeatureSettings(
          rawConfigPatch: <String, Object?>{
            'outbounds': <Object?>[
              <String, Object?>{
                'tag': 'proxy-main',
                'type': 'vmess',
                'server': 'edge.example.com',
                'server_port': 443,
                'uuid': '11111111-2222-3333-4444-555555555555',
                'transport': <String, Object?>{
                  'type': 'httpupgrade',
                  'path': '/ws',
                  'host': 'edge.example.com',
                },
              },
              <String, Object?>{'type': 'direct', 'tag': 'direct'},
              <String, Object?>{'type': 'block', 'tag': 'block'},
            ],
          },
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'proxy-main',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();

      expect(tls['enabled'], isTrue);
      expect(tls['alpn'], <String>['http/1.1']);
      expect(tls['server_name'], 'edge.example.com');
    },
  );

  test(
    'grpc link maps service name and omits unsupported authority field',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.connectManualConfigLink(
        configLink:
            'vless://11111111-2222-3333-4444-555555555555@edge.example.com:443?type=grpc&path=%2Fgrpc-api&authority=grpc.edge.example.com&security=tls&sni=edge.example.com#grpc-node',
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'grpc-node',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<dynamic, dynamic>).cast<String, dynamic>();

      expect(transport['type'], 'grpc');
      expect(transport['service_name'], 'grpc-api');
      expect(transport.containsKey('authority'), isFalse);
      expect(outbound.containsKey('_sbmm_grpc_authority'), isFalse);
      expect(outbound.containsKey('_sbmm_grpc_mode'), isFalse);
      expect(outbound['server'], 'grpc.edge.example.com');
      expect(tls['server_name'], 'grpc.edge.example.com');
      expect(tls['alpn'], const <String>['h2']);
    },
  );

  test(
    'grpc service path ending with /Tun is normalized for sing-box transport',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.connectManualConfigLink(
        configLink:
            'vless://11111111-2222-3333-4444-555555555555@edge.example.com:443?type=grpc&serviceName=%2Fedge-route%2FTun&security=tls&sni=edge.example.com#grpc-tun-path',
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'grpc-tun-path',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(transport['type'], 'grpc');
      expect(transport['service_name'], 'edge-route');
    },
  );

  test(
    'ws link honors explicit early-data override while stripping path hints',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.connectManualConfigLink(
        configLink:
            'vless://11111111-2222-3333-4444-555555555555@edge.example.com:443?type=ws&path=%2Fws%3Fed%3D2048%26foo%3Dbar%2520baz&max_early_data=4096&early_data_header_name=Sec-WebSocket-Protocol&security=tls&sni=edge.example.com#ws-ed-node',
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'ws-ed-node',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(transport['type'], 'ws');
      expect(transport['path'], '/ws?foo=bar%20baz');
      expect(transport['max_early_data'], 4096);
      expect(transport['early_data_header_name'], 'Sec-WebSocket-Protocol');
    },
  );

  test('reality link does not emit unsupported spider_x field', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.connectManualConfigLink(
      configLink:
          'vless://11111111-2222-3333-4444-555555555555@reality.example.com:443?type=tcp&security=reality&pbk=example-public-key&sid=abcd1234&spx=%2Fspider&fingerprint=firefox#reality-spx',
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        (outbounds.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'reality-spx',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> tls = (outbound['tls'] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();
    final Map<String, dynamic> reality =
        (tls['reality'] as Map<dynamic, dynamic>).cast<String, dynamic>();

    expect((tls['utls'] as Map<dynamic, dynamic>)['fingerprint'], 'firefox');
    expect(reality['public_key'], 'example-public-key');
    expect(reality['short_id'], 'abcd1234');
    expect(reality.containsKey('spider_x'), isFalse);
  });

  test('dns provider preset maps to expected resolver endpoints', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      featureSettings: SingboxFeatureSettings(
        dns: DnsOptions.fromProvider(preset: DnsProviderPreset.google),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> dns = config['dns'] as Map<String, dynamic>;
    final List<dynamic> servers = dns['servers'] as List<dynamic>;
    final Map<String, dynamic> remote =
        servers.firstWhere((dynamic item) {
              return item is Map<String, dynamic> &&
                  item['tag'] == 'dns-remote';
            })
            as Map<String, dynamic>;
    final Map<String, dynamic> direct =
        servers.firstWhere((dynamic item) {
              return item is Map<String, dynamic> &&
                  item['tag'] == 'dns-direct';
            })
            as Map<String, dynamic>;

    expect(remote['address'], 'https://dns.google/dns-query');
    expect(direct['address'], '8.8.8.8');
  });

  test('dns direct resolver keeps local when configured', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      featureSettings: const SingboxFeatureSettings(
        dns: DnsOptions(
          providerPreset: DnsProviderPreset.custom,
          directDns: 'local',
        ),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> dns = config['dns'] as Map<String, dynamic>;
    final List<dynamic> servers = dns['servers'] as List<dynamic>;
    final Map<String, dynamic> direct =
        servers.firstWhere((dynamic item) {
              return item is Map<String, dynamic> &&
                  item['tag'] == 'dns-direct';
            })
            as Map<String, dynamic>;

    expect(direct['address'], 'local');
  });

  test(
    'split tunneling can be disabled even when package filters are provided',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'proxy-main',
          server: 'edge.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
        ),
        featureSettings: const SingboxFeatureSettings(
          inbound: InboundOptions(
            splitTunnelingEnabled: false,
            includePackages: <String>['com.example.browser'],
            excludePackages: <String>['com.example.bank'],
          ),
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> inbounds = config['inbounds'] as List<dynamic>;
      final Map<String, dynamic> tunInbound =
          (inbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> && item['type'] == 'tun',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

      expect(tunInbound.containsKey('include_package'), isFalse);
      expect(tunInbound.containsKey('exclude_package'), isFalse);
    },
  );

  test(
    'plain dns rules are emitted even when dns protocol routing is disabled',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'proxy-main',
          server: 'edge.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
        ),
        featureSettings: const SingboxFeatureSettings(
          dns: DnsOptions(enableDnsRouting: false),
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final Map<String, dynamic> route =
          config['route'] as Map<String, dynamic>;
      final List<dynamic> rules = route['rules'] as List<dynamic>;

      expect(
        rules.whereType<Map<String, dynamic>>().any((
          Map<String, dynamic> rule,
        ) {
          return rule['action'] == 'hijack-dns' &&
              rule['port'] == 53 &&
              rule['network'] == 'udp' &&
              !rule.containsKey('ip_cidr');
        }),
        isTrue,
      );
      expect(
        rules.whereType<Map<String, dynamic>>().any((
          Map<String, dynamic> rule,
        ) {
          return rule['action'] == 'hijack-dns' &&
              rule['port'] == 53 &&
              rule['network'] == 'tcp' &&
              !rule.containsKey('ip_cidr');
        }),
        isTrue,
      );
      expect(
        rules.whereType<Map<String, dynamic>>().any((
          Map<String, dynamic> rule,
        ) {
          if (rule['action'] != 'hijack-dns' || rule['port'] != 53) {
            return false;
          }
          final Object? cidrRaw = rule['ip_cidr'];
          return cidrRaw is List<dynamic> && cidrRaw.contains('172.19.0.2/32');
        }),
        isTrue,
      );
      expect(
        rules.whereType<Map<String, dynamic>>().any((
          Map<String, dynamic> rule,
        ) {
          return rule['action'] == 'hijack-dns' && rule['port'] == 853;
        }),
        isFalse,
        reason: 'DNS-over-TLS traffic must not be parsed as plain DNS.',
      );
      expect(
        rules.whereType<Map<String, dynamic>>().any(
          (Map<String, dynamic> rule) => rule['protocol'] == 'dns',
        ),
        isFalse,
      );
    },
  );

  test('dns fake-ip and doh fallback are emitted when enabled', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      featureSettings: const SingboxFeatureSettings(
        dns: DnsOptions(
          remoteDns: 'https://1.1.1.1/dns-query',
          directDns: 'local',
          enableFakeIp: true,
          enableDohFallback: true,
          dohFallbackDns: 'https://dns.google/dns-query',
          dohFallbackDomainSuffixes: <String>['gstatic.com'],
        ),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> dns = config['dns'] as Map<String, dynamic>;
    final List<dynamic> servers = dns['servers'] as List<dynamic>;
    final List<String> tags = servers
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => item['tag'] as String? ?? '')
        .toList(growable: false);

    expect(tags.contains('dns-fakeip'), isTrue);
    expect(tags.contains('dns-remote-fallback'), isTrue);
    expect((dns['fakeip'] as Map<String, dynamic>)['enabled'], isTrue);
    expect(
      (dns['fakeip'] as Map<String, dynamic>).containsKey('inet6_range'),
      isFalse,
    );
    expect(dns['final'], 'dns-remote');

    final Map<String, dynamic> fallbackServer =
        (servers.firstWhere(
                  (dynamic item) =>
                      item is Map<String, dynamic> &&
                      item['tag'] == 'dns-remote-fallback',
                )
                as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(fallbackServer['detour'], 'proxy-main');

    final List<dynamic> rules = dns['rules'] as List<dynamic>;
    expect(
      rules.whereType<Map<String, dynamic>>().any((Map<String, dynamic> rule) {
        return rule['server'] == 'dns-remote-fallback' &&
            (rule['domain_suffix'] as List<dynamic>?)?.contains(
                  'gstatic.com',
                ) ==
                true;
      }),
      isTrue,
    );
    expect(
      rules.whereType<Map<String, dynamic>>().any((Map<String, dynamic> rule) {
        return rule['server'] == 'dns-fakeip' &&
            (rule['query_type'] as List<dynamic>?)?.length == 1 &&
            (rule['query_type'] as List<dynamic>?)?.contains('A') == true;
      }),
      isTrue,
    );
  });

  test(
    'dns keeps outbound domain bootstrap on dns-direct before fakeip catch-all',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'domain-bootstrap',
          server: 'ws-origin.example.net',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-777777777777',
          transport: VpnTransport.ws,
          websocketPath: '/',
          websocketHeaders: const <String, String>{
            'Host': 'cdn-host.example.net',
          },
          tls: const TlsOptions(
            enabled: true,
            serverName: 'cdn-host.example.net',
            alpn: <String>['http/1.1'],
          ),
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final Map<String, dynamic> dns = config['dns'] as Map<String, dynamic>;
      final List<dynamic> rules = dns['rules'] as List<dynamic>;
      int bootstrapRuleIndex = -1;
      int fakeIpRuleIndex = -1;

      for (int i = 0; i < rules.length; i++) {
        final dynamic raw = rules[i];
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final List<dynamic>? domains = raw['domain'] as List<dynamic>?;
        if (domains != null &&
            raw['server'] == 'dns-direct' &&
            domains.contains('ws-origin.example.net')) {
          bootstrapRuleIndex = i;
        }
        final List<dynamic>? queryType = raw['query_type'] as List<dynamic>?;
        if (raw['server'] == 'dns-fakeip' &&
            queryType != null &&
            queryType.contains('A')) {
          fakeIpRuleIndex = i;
        }
      }

      expect(bootstrapRuleIndex, greaterThanOrEqualTo(0));
      expect(fakeIpRuleIndex, greaterThanOrEqualTo(0));
      expect(bootstrapRuleIndex, lessThan(fakeIpRuleIndex));
    },
  );

  test(
    'dns bootstrap extracts domain hints from transport extra fields',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'domain-bootstrap-extra',
          server: '203.0.113.18',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          transport: VpnTransport.grpc,
          grpcServiceName: 'grpc-service',
          tls: const TlsOptions(enabled: true),
          extra: const <String, Object?>{
            'authority': 'grpc.edge.example.com',
            'headers': <String, String>{'Host': 'cdn.edge.example.com'},
          },
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> rules =
          (config['dns'] as Map<String, dynamic>)['rules'] as List<dynamic>;

      final Map<String, dynamic>? bootstrapRule = rules
          .whereType<Map<String, dynamic>>()
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (Map<String, dynamic>? rule) =>
                rule != null &&
                rule['server'] == 'dns-direct' &&
                rule['domain'] is List<dynamic>,
            orElse: () => null,
          );

      expect(bootstrapRule, isNotNull);
      final List<dynamic> domains = bootstrapRule!['domain'] as List<dynamic>;
      expect(domains.contains('grpc.edge.example.com'), isTrue);
      expect(domains.contains('cdn.edge.example.com'), isTrue);
    },
  );

  test(
    'hysteria2 prefers direct doh fallback as final dns server for resilience',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.hysteria2(
          tag: 'hy2-main',
          server: 'hy2.example.com',
          serverPort: 443,
          password: 'secret',
          tls: const TlsOptions(enabled: true, serverName: 'hy2.example.com'),
        ),
        featureSettings: const SingboxFeatureSettings(
          dns: DnsOptions(
            remoteDns: 'https://1.1.1.1/dns-query',
            directDns: 'local',
            enableDohFallback: true,
            dohFallbackDns: 'https://dns.google/dns-query',
            dohFallbackDomainSuffixes: <String>['google.com'],
          ),
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final Map<String, dynamic> dns = config['dns'] as Map<String, dynamic>;
      expect(dns['final'], 'dns-remote-fallback');

      final List<dynamic> servers = dns['servers'] as List<dynamic>;
      final Map<String, dynamic> fallbackServer =
          (servers.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'dns-remote-fallback',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      expect(fallbackServer['detour'], 'direct');
      expect(fallbackServer['address_resolver'], 'dns-direct');
    },
  );

  test(
    'strict-route mode omits inet6 TUN address when ipv6 route mode is disabled',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'ipv6-capture',
          server: 'edge.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
        ),
        featureSettings: const SingboxFeatureSettings(
          route: RouteOptions(ipv6RouteMode: SingboxIpv6RouteMode.disable),
          inbound: InboundOptions(strictRoute: true),
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> inbounds = config['inbounds'] as List<dynamic>;
      final Map<String, dynamic> tunInbound =
          (inbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> && item['type'] == 'tun',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      expect(tunInbound.containsKey('inet6_address'), isFalse);
    },
  );

  test(
    'hysteria2 with ipv6 disabled forces ipv4-only DNS and disables tun inet6 capture',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyProfile(
        profile: VpnProfile.hysteria2(
          tag: 'hy2-ipv4',
          server: 'hy2.example.com',
          serverPort: 8443,
          password: 'hy2-pass',
          tls: const TlsOptions(enabled: true, serverName: 'hy2.example.com'),
        ),
        featureSettings: const SingboxFeatureSettings(
          route: RouteOptions(ipv6RouteMode: SingboxIpv6RouteMode.disable),
          inbound: InboundOptions(strictRoute: true),
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> inbounds = config['inbounds'] as List<dynamic>;
      final Map<String, dynamic> tunInbound =
          (inbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> && item['type'] == 'tun',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      expect(tunInbound.containsKey('inet6_address'), isFalse);

      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> hy2Outbound =
          (outbounds.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'hy2-ipv4',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      expect(hy2Outbound['domain_strategy'], 'ipv4_only');

      final Map<String, dynamic> dns = config['dns'] as Map<String, dynamic>;
      expect(dns['strategy'], 'prefer_ipv4');
      final List<dynamic> servers = dns['servers'] as List<dynamic>;
      final Map<String, dynamic> remoteDns =
          (servers.firstWhere(
                    (dynamic item) =>
                        item is Map<String, dynamic> &&
                        item['tag'] == 'dns-remote',
                  )
                  as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      expect(remoteDns['strategy'], 'prefer_ipv4');
    },
  );

  test('wireguard profile is rejected for sing-box core >= 1.13.0', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
      ..singboxVersion = 'sing-box 1.13.0';
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    expect(
      () => vpn.applyProfile(
        profile: VpnProfile.wireguard(
          tag: 'wg-node',
          server: '203.0.113.10',
          serverPort: 51820,
          privateKey: 'private-key',
          peerPublicKey: 'peer-public-key',
          localAddress: const <String>['10.7.0.2/32'],
        ),
      ),
      throwsA(
        isA<SignboxVpnException>().having(
          (SignboxVpnException e) => e.code,
          'code',
          'UNSUPPORTED_PROTOCOL_FOR_CORE',
        ),
      ),
    );
    expect(fakePlatform.latestConfig, isNull);
  });

  test(
    'endpoint pool filters unsupported wireguard when core is >= 1.13.0',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..singboxVersion = '1.13.1';
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      await vpn.applyEndpointPool(
        profiles: <VpnProfile>[
          VpnProfile.wireguard(
            tag: 'wg-node',
            server: '203.0.113.10',
            serverPort: 51820,
            privateKey: 'private-key',
            peerPublicKey: 'peer-public-key',
            localAddress: const <String>['10.7.0.2/32'],
          ),
          VpnProfile.vless(
            tag: 'vless-node',
            server: 'edge.example.com',
            serverPort: 443,
            uuid: '11111111-2222-3333-4444-555555555555',
          ),
        ],
      );

      expect(vpn.endpointPool.length, 1);
      expect(vpn.activeEndpointProfile?.tag, 'vless-node');
      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final Map<String, dynamic> outbound =
          (config['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
      expect(outbound['type'], 'vless');
      expect(outbound['tag'], 'vless-node');
    },
  );

  test(
    'getCoreCapabilities reports protocol support by installed core version',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..singboxVersion = 'sing-box version 1.13.1';
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      final VpnCoreCapabilities caps = await vpn.getCoreCapabilities();
      expect(caps.displayVersion, 'sing-box version 1.13.1');
      expect(caps.hasParsedSemver, isTrue);
      expect(caps.supportsProtocol(VpnProtocol.vless), isTrue);
      expect(caps.supportsProtocol(VpnProtocol.ssh), isTrue);
      expect(caps.supportsProtocol(VpnProtocol.wireguard), isFalse);
      expect(caps.unsupportedProtocols, contains(VpnProtocol.wireguard));
    },
  );

  test(
    'getCoreCapabilities keeps permissive mode when core version is unknown',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..singboxVersion = 'custom-core';
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      final VpnCoreCapabilities caps = await vpn.getCoreCapabilities();
      expect(caps.displayVersion, 'custom-core');
      expect(caps.hasParsedSemver, isFalse);
      expect(caps.supportsProtocol(VpnProtocol.wireguard), isTrue);
      expect(caps.unsupportedProtocols, isEmpty);
    },
  );

  test(
    'isProtocolSupportedByCore helper reflects runtime capability matrix',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..singboxVersion = '1.13.1';
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      expect(await vpn.isProtocolSupportedByCore(VpnProtocol.vless), isTrue);
      expect(
        await vpn.isProtocolSupportedByCore(VpnProtocol.wireguard),
        isFalse,
      );
    },
  );

  test(
    'filterProfilesByCoreSupport removes unsupported protocol profiles',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..singboxVersion = '1.13.1';
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());

      final List<VpnProfile> filtered = await vpn.filterProfilesByCoreSupport(
        profiles: <VpnProfile>[
          VpnProfile.wireguard(
            tag: 'wg-node',
            server: '203.0.113.10',
            serverPort: 51820,
            privateKey: 'private-key',
            peerPublicKey: 'peer-public-key',
            localAddress: const <String>['10.7.0.2/32'],
          ),
          VpnProfile.vless(
            tag: 'vless-node',
            server: 'edge.example.com',
            serverPort: 443,
            uuid: '11111111-2222-3333-4444-555555555555',
          ),
        ],
      );

      expect(filtered.length, 1);
      expect(filtered.first.protocol, VpnProtocol.vless);
    },
  );

  test('start/stop uses platform control methods', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();

    await vpn.start();
    expect(await vpn.getState(), VpnConnectionState.connected);

    await vpn.stop();
    expect(await vpn.getState(), VpnConnectionState.disconnected);
  });

  test('config document extraction and apply', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    final String configJson = jsonEncode(<String, Object?>{
      'outbounds': <Object?>[
        <String, Object?>{
          'type': 'vless',
          'tag': 'node-a',
          'server': '4.4.4.4',
          'server_port': 443,
        },
      ],
    });

    final List<SingboxEndpointSummary> endpoints = vpn.extractConfigEndpoints(
      configJson,
    );
    expect(endpoints.length, 1);
    expect(endpoints.first.server, '4.4.4.4');
    expect(endpoints.first.serverPort, 443);
    expect(endpoints.first.remark, 'node-a');

    final SingboxConfigDocument document = vpn.parseConfigDocument(configJson);
    document.updateEndpoint(
      outboundIndex: 0,
      server: '9.9.9.9',
      serverPort: 9443,
      remark: 'node-b',
    );

    await vpn.applyConfigDocument(document);
    expect(fakePlatform.latestConfig, isNotNull);
    final Map<String, dynamic> applied =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> outbound =
        (applied['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
    expect(outbound['server'], '9.9.9.9');
    expect(outbound['server_port'], 9443);
    expect(outbound['tag'], 'node-b');
  });

  test('extract profile summaries for UI rendering', () {
    final SignboxVpn vpn = SignboxVpn();
    final VpnProfileSummary summary = vpn.extractConfigLinkSummary(
      'vless://11111111-2222-3333-4444-555555555555@203.0.113.10:29485?type=tcp&security=none#demo-node',
    );
    expect(summary.remark, 'demo-node');
    expect(summary.host, '203.0.113.10');
    expect(summary.port, 29485);
    expect(summary.protocol, VpnProtocol.vless);
    expect(summary.transport, VpnTransport.tcp);

    const String rawSubscription =
        'vless://11111111-2222-3333-4444-555555555555@edge-a.example.com:443?security=tls#edge-a\n'
        'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@edge-b.example.com:8388#edge-b';
    final List<VpnProfileSummary> summaries = vpn.extractSubscriptionSummaries(
      rawSubscription,
    );

    expect(summaries.length, 2);
    expect(summaries.first.index, 0);
    expect(summaries.first.remark, 'edge-a');
    expect(summaries.first.host, 'edge-a.example.com');
    expect(summaries.last.remark, 'edge-b');
    expect(summaries.last.port, 8388);
  });

  test('runDiagnostics includes standalone profile checks', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'edge-standalone',
        server: 'standalone.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
        tls: const TlsOptions(enabled: false),
      ),
    );

    final VpnDiagnosticsReport report = await vpn.runDiagnostics(
      strictTls: true,
      includeConnectivityProbe: false,
    );

    expect(report.pingResults.length, 1);
    expect(
      report.issues.any(
        (VpnDiagnosticIssue issue) => issue.code == 'TLS_DISABLED',
      ),
      isTrue,
    );
  });

  test('manual connect flow starts vpn from config link', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    final ManualConnectResult result = await vpn.connectManualConfigLink(
      configLink:
          'vless://11111111-2222-3333-4444-555555555555@manual.example.com:443?security=tls#manual-node',
    );

    expect(result.profile.tag, 'manual-node');
    expect(result.warnings, isEmpty);
    expect(fakePlatform.permissionRequests, 1);
    expect(fakePlatform.started, isTrue);
    expect(vpn.activeProfile?.tag, 'manual-node');
  });

  test(
    'manual connect dual-core fallback rewrites grpc transport on runtime rejection',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      fakePlatform.lastError =
          'PermissionDenied: unexpected HTTP status 403 Forbidden';
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();

      final ManualConnectResult result = await vpn.connectManualConfigLink(
        configLink:
            'vless://11111111-2222-3333-4444-555555555555@manual.example.com:443?type=grpc&serviceName=grpc-node&mode=multi&security=tls&sni=manual.example.com#manual-grpc',
        featureSettings: const SingboxFeatureSettings(
          misc: MiscOptions(useXrayCoreWhenPossible: true),
        ),
      );

      expect(
        result.warnings.any(
          (String warning) => warning.contains('Dual-core fallback applied'),
        ),
        isTrue,
      );
      expect(fakePlatform.startCalls, 1);
      expect(fakePlatform.restartCalls, 1);

      final List<Object?> outbounds =
          (result.appliedConfig['outbounds'] as List<Object?>?) ??
          const <Object?>[];
      final Map<String, dynamic> outbound =
          (outbounds.firstWhere((Object? item) {
                    return item is Map<Object?, Object?> &&
                        item['tag'] == 'manual-grpc';
                  })
                  as Map<Object?, Object?>)
              .cast<String, dynamic>();
      final Map<String, dynamic> transport =
          (outbound['transport'] as Map<Object?, Object?>)
              .cast<String, dynamic>();
      expect(transport['type'], 'grpc');
      expect(transport['idle_timeout'], '60s');
      expect(transport['ping_timeout'], '20s');
      expect(transport['permit_without_stream'], isTrue);

      final Map<String, dynamic> tls =
          (outbound['tls'] as Map<Object?, Object?>).cast<String, dynamic>();
      expect(tls['alpn'], <String>['h2']);
    },
  );

  test('manual connect supports sbmm wrapped link with passphrase', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    const String rawConfig =
        'vless://11111111-2222-3333-4444-555555555555@manual.example.com:443?security=tls#manual-node';
    final String wrapped = vpn.wrapSecureConfigLink(
      configLink: rawConfig,
      passphrase: 'sbmm-test-secret',
    );

    final ManualConnectResult result = await vpn.connectManualConfigLink(
      configLink: wrapped,
      sbmmPassphrase: 'sbmm-test-secret',
    );

    expect(result.profile.tag, 'manual-node');
    expect(result.warnings.any((String item) => item.contains('sbmm')), isTrue);
    expect(fakePlatform.started, isTrue);
  });

  test('manual connect with gfw preset applies hardened config', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.connectManualConfigLinkWithPreset(
      configLink:
          'vless://11111111-2222-3333-4444-555555555555@manual.example.com:443?security=tls#manual-node',
      preset: GfwPresetPack.aggressive(),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> outbound =
        (config['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
    final Map<String, dynamic> tls = outbound['tls'] as Map<String, dynamic>;
    expect(tls['fragment'], isTrue);
    expect(tls['padding'], isNull);
  });

  test(
    'manual connect with extreme preset rejects non-reality fallback links',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();

      await expectLater(
        () => vpn.connectManualConfigLinkWithPreset(
          configLink:
              'vless://11111111-2222-3333-4444-555555555555@manual.example.com:29485?type=tcp&security=none#manual-node',
          preset: GfwPresetPack.extreme(),
        ),
        throwsA(
          isA<SignboxVpnException>().having(
            (SignboxVpnException error) => error.code,
            'code',
            'EXTREME_PRESET_PROTOCOL_BLOCKED',
          ),
        ),
      );
    },
  );

  test('raw tls fragment object is normalized for sing-box core', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'normalize-fragment',
        server: 'manual.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      featureSettings: const SingboxFeatureSettings(
        tlsTricks: TlsTricksOptions(
          rawOutboundPatch: <String, Object?>{
            'tls': <String, Object?>{
              'fragment': <String, Object?>{
                'enabled': true,
                'size': '10-30',
                'sleep': '2-8',
              },
            },
          },
        ),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> outbound =
        (config['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
    final Map<String, dynamic> tls = outbound['tls'] as Map<String, dynamic>;
    expect(tls['fragment'], isTrue);
  });

  test('udp_fragment object patch is normalized for tls outbounds', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'normalize-udp-fragment',
        server: 'manual.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
      ),
      featureSettings: const SingboxFeatureSettings(
        tlsTricks: TlsTricksOptions(
          rawOutboundPatch: <String, Object?>{
            'udp_fragment': <String, Object?>{'enabled': true, 'size': 1200},
          },
        ),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> outbound =
        (config['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
    expect(outbound['udp_fragment'], isTrue);
  });

  test('tls tricks are skipped for non-tls outbound types', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.applyProfile(
      profile: VpnProfile.shadowsocks(
        tag: 'ss-node',
        server: 'ss.example.com',
        serverPort: 8388,
        method: 'chacha20-ietf-poly1305',
        password: 'secret',
      ),
      featureSettings: const SingboxFeatureSettings(
        tlsTricks: TlsTricksOptions(enableTlsFragment: true),
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final Map<String, dynamic> outbound =
        (config['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
    expect(outbound.containsKey('tls'), isFalse);
  });

  test(
    'builder strips leaked tls object for security none outbounds',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();

      await vpn.applyProfile(
        profile: VpnProfile.vless(
          tag: 'proxy-main',
          server: 'edge.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          tls: const TlsOptions(enabled: false),
        ),
        featureSettings: SingboxFeatureSettings(
          rawConfigPatch: <String, Object?>{
            'outbounds': <Object?>[
              <String, Object?>{
                'tag': 'proxy-main',
                'type': 'vless',
                'server': 'edge.example.com',
                'server_port': 443,
                'uuid': '11111111-2222-3333-4444-555555555555',
                'tls': <String, Object?>{},
              },
              <String, Object?>{'type': 'direct', 'tag': 'direct'},
              <String, Object?>{'type': 'block', 'tag': 'block'},
            ],
          },
        ),
      );

      final Map<String, dynamic> config =
          jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
      final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
      final Map<String, dynamic> outbound =
          outbounds.firstWhere((dynamic item) {
                return item is Map<String, dynamic> &&
                    item['tag'] == 'proxy-main';
              })
              as Map<String, dynamic>;

      expect(outbound.containsKey('tls'), isFalse);
    },
  );

  test('builder strips tls when outbound security is none', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'proxy-main',
        server: 'edge.example.com',
        serverPort: 80,
        uuid: '11111111-2222-3333-4444-555555555555',
        transport: VpnTransport.httpUpgrade,
        websocketPath: '/ws',
        tls: const TlsOptions(enabled: false),
      ),
      featureSettings: SingboxFeatureSettings(
        rawConfigPatch: <String, Object?>{
          'outbounds': <Object?>[
            <String, Object?>{
              'tag': 'proxy-main',
              'type': 'vless',
              'server': 'edge.example.com',
              'server_port': 80,
              'uuid': '11111111-2222-3333-4444-555555555555',
              'security': 'none',
              'transport': <String, Object?>{
                'type': 'httpupgrade',
                'path': '/ws',
                'host': 'edge.example.com',
              },
              'tls': <String, Object?>{
                'enabled': true,
                'server_name': 'edge.example.com',
              },
            },
            <String, Object?>{'type': 'direct', 'tag': 'direct'},
            <String, Object?>{'type': 'block', 'tag': 'block'},
          ],
        },
      ),
    );

    final Map<String, dynamic> config =
        jsonDecode(fakePlatform.latestConfig!) as Map<String, dynamic>;
    final List<dynamic> outbounds = config['outbounds'] as List<dynamic>;
    final Map<String, dynamic> outbound =
        outbounds.firstWhere((dynamic item) {
              return item is Map<String, dynamic> &&
                  item['tag'] == 'proxy-main';
            })
            as Map<String, dynamic>;

    expect(outbound.containsKey('tls'), isFalse);
  });

  test('manual connect throws when permission denied', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
      ..permissionGranted = false;
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    expect(
      () => vpn.connectManualConfigLink(
        configLink:
            'vless://11111111-2222-3333-4444-555555555555@manual.example.com:443?security=tls#manual-node',
      ),
      throwsA(isA<SignboxVpnException>()),
    );
  });

  test('auto connect selects best endpoint by ping', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
      ..pingLatencyByHost['slow.example.com'] = 90
      ..pingLatencyByHost['fast.example.com'] = 20;
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    const String rawSubscription =
        'vless://11111111-2222-3333-4444-555555555555@slow.example.com:443?security=tls#slow\n'
        'vless://11111111-2222-3333-4444-555555555556@fast.example.com:443?security=tls#fast';

    final AutoConnectResult result = await vpn.connectAutoSubscription(
      rawSubscription: rawSubscription,
      pingTimeout: const Duration(seconds: 1),
    );

    expect(result.importResult.importedCount, 2);
    expect(result.selectedProfile?.tag, 'fast');
    expect(result.pingResults.length, 2);
    expect(fakePlatform.permissionRequests, 1);
    expect(fakePlatform.started, isTrue);
    expect(vpn.activeEndpointProfile?.tag, 'fast');
  });

  test(
    'auto connect with extreme preset enforces protocol gate and transport ladder',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..pingLatencyByHost['reality.example.com'] = 120
        ..pingLatencyByHost['hy2.example.com'] = 20;
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();

      const String rawSubscription =
          'vless://11111111-2222-3333-4444-555555555555@fallback.example.com:443?security=tls#fallback\n'
          'vless://11111111-2222-3333-4444-555555555556@reality.example.com:443?security=reality&pbk=example-public-key&sid=abcd#reality\n'
          'hysteria2://hy2-pass@hy2.example.com:8443?sni=hy2.example.com#hy2';

      final AutoConnectResult result = await vpn.connectAutoWithPreset(
        rawSubscription: rawSubscription,
        preset: GfwPresetPack.extreme(),
      );

      expect(result.importResult.importedCount, 2);
      expect(result.importResult.invalidCount, 1);
      expect(result.selectedProfile?.tag, 'reality');
      expect(vpn.endpointPool.length, 2);
      expect(
        vpn.endpointPool.map((VpnProfile profile) => profile.tag),
        containsAll(<String>['reality', 'hy2']),
      );
    },
  );

  test(
    'auto connect with extreme preset reuses per-network preferred endpoint',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..stateDetailsOverride = VpnConnectionSnapshot(
          state: VpnConnectionState.connected,
          timestamp: DateTime.now().toUtc(),
          underlyingTransports: const <String>['wifi'],
        )
        ..pingLatencyByHost['reality.example.com'] = 120
        ..pingLatencyByHost['hy2.example.com'] = 20;
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();

      const String rawSubscription =
          'vless://11111111-2222-3333-4444-555555555555@reality.example.com:443?security=reality&pbk=example-public-key&sid=abcd#reality\n'
          'hysteria2://hy2-pass@hy2.example.com:8443?sni=hy2.example.com#hy2';

      final AutoConnectResult first = await vpn.connectAutoWithPreset(
        rawSubscription: rawSubscription,
        preset: GfwPresetPack.extreme(),
        preferLowestLatency: false,
      );
      expect(first.selectedProfile?.tag, 'reality');

      fakePlatform.pingRequests = 0;
      final AutoConnectResult second = await vpn.connectAutoWithPreset(
        rawSubscription: rawSubscription,
        preset: GfwPresetPack.extreme(),
        preferLowestLatency: true,
      );
      expect(second.selectedProfile?.tag, 'reality');
      expect(second.pingResults, isEmpty);
      expect(fakePlatform.pingRequests, 0);
    },
  );

  test('select endpoint manually and auto-select best endpoint', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
      ..pingLatencyByHost['edge-a.example.com'] = 35
      ..pingLatencyByHost['edge-b.example.com'] = 10;
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'edge-a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
        ),
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'edge-b.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
        ),
      ],
      options: const EndpointPoolOptions(autoFailover: false),
    );

    final VpnProfile? manual = await vpn.selectEndpoint(
      index: 1,
      reconnect: false,
    );
    expect(manual?.tag, 'edge-b');
    expect(vpn.activeEndpointProfile?.tag, 'edge-b');

    final VpnProfile? auto = await vpn.selectBestEndpointByPing(
      timeout: const Duration(seconds: 1),
      reconnect: false,
    );
    expect(auto?.tag, 'edge-b');
  });

  test('list gfw preset packs through client helper', () {
    final SignboxVpn vpn = SignboxVpn();
    final List<GfwPresetPack> presets = vpn.listGfwPresetPacks();
    expect(presets.length, 5);
    expect(presets.first.mode, GfwPresetMode.compatibility);
    expect(presets.last.mode, GfwPresetMode.myanmar);
  });

  test('extension-wrapped runtime/lifecycle APIs remain callable', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
      ..notificationPermissionGranted = false
      ..lastError = 'simulated-error'
      ..singboxVersion = 'sing-box 1.11-test';
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.initialize(const SingboxRuntimeOptions());
    expect(await vpn.requestVpnPermission(), isTrue);
    final bool notificationGranted = await vpn.requestNotificationPermission();
    expect(notificationGranted, Platform.isAndroid ? isFalse : isTrue);
    expect(await vpn.getSingboxVersion(), 'sing-box 1.11-test');
    expect(await vpn.getLastError(), 'simulated-error');
    await vpn.syncRuntimeState();
    expect(fakePlatform.syncCalls, 2);

    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'edge-a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
        ),
      ],
      options: const EndpointPoolOptions(autoFailover: false),
    );
    expect(vpn.endpointPool, isNotEmpty);

    await vpn.resetProfile(stopVpn: false);
    expect(vpn.endpointPool, isEmpty);
    expect(vpn.activeProfile, isNull);
    await vpn.dispose();
  });

  test('runDiagnostics aggregates ping and connectivity failures', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
      ..pingShouldFail = true;
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    await vpn.applyProfile(
      profile: VpnProfile.vless(
        tag: 'diag-standalone',
        server: 'diag.example.com',
        serverPort: 443,
        uuid: '11111111-2222-3333-4444-555555555555',
        tls: const TlsOptions(enabled: false),
      ),
      featureSettings: const SingboxFeatureSettings(
        misc: MiscOptions(connectionTestUrl: 'bad-connectivity-url'),
      ),
    );

    final VpnDiagnosticsReport report = await vpn.runDiagnostics(
      strictTls: true,
      includeEndpointPoolPing: true,
      includeConnectivityProbe: true,
    );

    final Set<String> issueCodes = report.issues
        .map((VpnDiagnosticIssue issue) => issue.code)
        .toSet();
    expect(report.pingResults.length, 1);
    expect(issueCodes.contains('TLS_DISABLED'), isTrue);
    expect(issueCodes.contains('PING_FAILED'), isTrue);
    expect(issueCodes.contains('CONNECTIVITY_FAILED'), isTrue);
    expect(report.stats, isNotNull);
  });

  test('runDiagnostics reports state/stats collection failures', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
      ..throwOnGetState = true
      ..throwOnGetStats = true;
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    final VpnDiagnosticsReport report = await vpn.runDiagnostics(
      includeEndpointPoolPing: false,
      includeConnectivityProbe: false,
    );

    final Set<String> issueCodes = report.issues
        .map((VpnDiagnosticIssue issue) => issue.code)
        .toSet();
    expect(issueCodes.contains('STATE_UNAVAILABLE'), isTrue);
    expect(issueCodes.contains('STATS_UNAVAILABLE'), isTrue);
    expect(issueCodes.contains('PROFILE_MISSING'), isTrue);
    expect(report.state, VpnConnectionState.disconnected);
    expect(report.stats, isNull);
  });

  test('pingProfile and pingEndpointPool are supported', () async {
    final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform();
    SignboxVpnPlatform.instance = fakePlatform;
    final SignboxVpn vpn = SignboxVpn();

    final VpnProfile profile = VpnProfile.vless(
      tag: 'edge-a',
      server: 'edge.example.com',
      serverPort: 443,
      uuid: '11111111-2222-3333-4444-555555555555',
    );

    final VpnPingResult ping = await vpn.pingProfile(profile: profile);
    expect(ping.success, isTrue);
    expect(ping.latencyMs, 42);
    expect(ping.checkMethod, VpnPingResult.methodTcpConnect);
    expect(ping.tag, 'edge-a');

    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        profile,
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'edge2.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
        ),
      ],
      options: const EndpointPoolOptions(autoFailover: false),
    );

    final List<VpnPingResult> results = await vpn.pingEndpointPool();
    expect(results.length, 2);
    expect(results.every((VpnPingResult item) => item.success), isTrue);
    expect(
      results.every(
        (VpnPingResult item) =>
            item.checkMethod == VpnPingResult.methodTcpConnect,
      ),
      isTrue,
    );
  });

  test(
    'pingProfile falls back to connectivity probe for UDP profiles',
    () async {
      final FakeSignboxVpnPlatform fakePlatform = FakeSignboxVpnPlatform()
        ..pingShouldFail = true;
      SignboxVpnPlatform.instance = fakePlatform;
      final SignboxVpn vpn = SignboxVpn();

      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((HttpRequest request) async {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      });

      final VpnProfile profile = VpnProfile.wireguard(
        tag: 'wg-edge',
        server: 'wg.example.com',
        serverPort: 51820,
        privateKey: 'test-private-key',
        peerPublicKey: 'test-peer-key',
        localAddress: const <String>['10.0.0.2/32'],
      );

      final VpnPingResult ping = await vpn.pingProfile(
        profile: profile,
        connectivityProbeUrl: 'http://127.0.0.1:${server.port}/healthz',
        connectivityProbeTimeout: const Duration(seconds: 1),
      );

      expect(ping.success, isTrue);
      expect(ping.checkMethod, VpnPingResult.methodConnectivityProbe);
      expect(ping.latencyMs, isNotNull);
    },
  );
}
