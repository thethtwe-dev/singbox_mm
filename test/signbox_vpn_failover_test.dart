import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:singbox_mm/singbox_mm.dart';
import 'package:singbox_mm/singbox_mm_platform_interface.dart';

class _ManagedFakePlatform
    with MockPlatformInterfaceMixin
    implements SignboxVpnPlatform {
  final StreamController<VpnConnectionState> _controller =
      StreamController<VpnConnectionState>.broadcast();

  final List<String> writtenConfigs = <String>[];
  int startCalls = 0;
  int stopCalls = 0;
  int restartCalls = 0;
  bool started = false;
  bool pingShouldFail = false;
  String? lastError;
  int txBytes = 0;
  int rxBytes = 0;

  @override
  Stream<VpnConnectionState> get stateStream => _controller.stream;

  @override
  Stream<VpnConnectionSnapshot> get stateDetailsStream =>
      _controller.stream.map((VpnConnectionState state) {
        return VpnConnectionSnapshot(
          state: state,
          timestamp: DateTime.now().toUtc(),
        );
      });

  @override
  Stream<VpnRuntimeStats> get statsStream =>
      const Stream<VpnRuntimeStats>.empty();

  void emit(VpnConnectionState state, {String? error}) {
    lastError = error;
    _controller.add(state);
  }

  @override
  Future<void> initialize(SingboxRuntimeOptions options) async {}

  @override
  Future<bool> requestVpnPermission() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> setConfig(String configJson) async {
    writtenConfigs.add(configJson);
  }

  @override
  Future<void> startVpn() async {
    startCalls++;
    started = true;
    lastError = null;
    emit(VpnConnectionState.connected);
  }

  @override
  Future<void> stopVpn() async {
    stopCalls++;
    started = false;
    lastError = null;
    emit(VpnConnectionState.disconnected);
  }

  @override
  Future<void> restartVpn() async {
    restartCalls++;
    started = true;
    lastError = null;
    emit(VpnConnectionState.connected);
  }

  @override
  Future<VpnConnectionState> getState() async {
    return started
        ? VpnConnectionState.connected
        : VpnConnectionState.disconnected;
  }

  @override
  Future<VpnConnectionSnapshot> getStateDetails() async {
    return VpnConnectionSnapshot(
      state: started
          ? VpnConnectionState.connected
          : VpnConnectionState.disconnected,
      timestamp: DateTime.now().toUtc(),
      lastError: lastError,
    );
  }

  @override
  Future<VpnRuntimeStats> getStats() async {
    return VpnRuntimeStats(
      totalUploaded: txBytes,
      totalDownloaded: rxBytes,
      activeConnections: started ? 1 : 0,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> syncRuntimeState() async {}

  @override
  Future<String?> getLastError() async => lastError;

  @override
  Future<String?> getSingboxVersion() async => 'sing-box test';

  @override
  Future<VpnPingResult> pingServer({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 3),
    bool useTls = false,
    String? tlsServerName,
    bool allowInsecure = false,
  }) async {
    if (pingShouldFail) {
      return VpnPingResult.failure(host: host, port: port, error: 'timeout');
    }
    return VpnPingResult(
      host: host,
      port: port,
      latency: const Duration(milliseconds: 30),
      checkedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  test('auto failover switches endpoint on error', () async {
    final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());
    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          tls: const TlsOptions(enabled: false),
        ),
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'b.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
          tls: const TlsOptions(enabled: false),
        ),
      ],
      options: const EndpointPoolOptions(
        autoFailover: true,
        healthCheck: VpnHealthCheckOptions(
          failoverOnNoTraffic: false,
          checkInterval: Duration(milliseconds: 50),
        ),
      ),
    );

    expect(vpn.activeEndpointProfile?.tag, 'edge-a');
    await vpn.startManaged();
    expect(fakePlatform.startCalls, 1);

    fakePlatform.emit(VpnConnectionState.error);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(vpn.activeEndpointProfile?.tag, 'edge-b');
    expect(fakePlatform.restartCalls, 1);
    expect(fakePlatform.writtenConfigs.length, 2);

    await vpn.dispose();
    await fakePlatform.dispose();
  });

  test('disconnected with user-stop marker does not auto-reconnect', () async {
    final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());
    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          tls: const TlsOptions(enabled: false),
        ),
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'b.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
          tls: const TlsOptions(enabled: false),
        ),
      ],
      options: const EndpointPoolOptions(
        autoFailover: true,
        healthCheck: VpnHealthCheckOptions(failoverOnNoTraffic: false),
      ),
    );

    await vpn.startManaged();
    expect(fakePlatform.startCalls, 1);

    fakePlatform.started = false;
    fakePlatform.emit(
      VpnConnectionState.disconnected,
      error: 'STOPPED_BY_USER',
    );
    await Future<void>.delayed(const Duration(milliseconds: 140));

    expect(vpn.activeEndpointProfile?.tag, 'edge-a');
    expect(fakePlatform.restartCalls, 0);
    expect(fakePlatform.startCalls, 1);

    await vpn.dispose();
    await fakePlatform.dispose();
  });

  test(
    'single-endpoint managed mode attempts in-place recovery on error',
    () async {
      final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());
      await vpn.applyEndpointPool(
        profiles: <VpnProfile>[
          VpnProfile.hysteria2(
            tag: 'hy2-only',
            server: '54.251.185.72',
            serverPort: 24312,
            password: 'hy2-pass',
            tls: const TlsOptions(
              enabled: true,
              serverName: '54.251.185.72',
              allowInsecure: true,
            ),
          ),
        ],
        options: const EndpointPoolOptions(
          autoFailover: true,
          healthCheck: VpnHealthCheckOptions(
            checkInterval: Duration(milliseconds: 40),
            maxConsecutiveFailures: 1,
            failoverOnNoTraffic: true,
            failoverOnError: true,
          ),
        ),
      );

      await vpn.startManaged();
      fakePlatform.emit(VpnConnectionState.error);
      await Future<void>.delayed(const Duration(milliseconds: 160));

      expect(fakePlatform.restartCalls, greaterThanOrEqualTo(1));
      expect(fakePlatform.writtenConfigs.length, greaterThanOrEqualTo(2));
      expect(vpn.activeEndpointProfile?.tag, 'hy2-only');

      await vpn.dispose();
      await fakePlatform.dispose();
    },
  );

  test('subscription import populates endpoint pool', () async {
    final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());

    const String rawSubscription = '''
vless://11111111-2222-3333-4444-555555555555@edge-a.example.com:443?security=none#edge-a
invalid-line
vless://11111111-2222-3333-4444-555555555556@edge-b.example.com:443?security=none#edge-b
''';
    final String encoded = base64.encode(utf8.encode(rawSubscription));

    final SubscriptionImportResult result = await vpn.importSubscription(
      rawSubscription: encoded,
      connect: false,
      options: const EndpointPoolOptions(
        autoFailover: true,
        healthCheck: VpnHealthCheckOptions(failoverOnNoTraffic: false),
      ),
    );

    expect(result.importedCount, 2);
    expect(result.invalidCount, 1);
    expect(vpn.endpointPool.length, 2);
    expect(vpn.activeEndpointProfile?.tag, 'edge-a');
    expect(fakePlatform.writtenConfigs, isNotEmpty);

    await vpn.dispose();
    await fakePlatform.dispose();
  });

  test('auto failover can trigger on connectivity probe failure', () async {
    final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform();
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());
    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          tls: const TlsOptions(enabled: false),
        ),
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'b.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
          tls: const TlsOptions(enabled: false),
        ),
      ],
      options: const EndpointPoolOptions(
        autoFailover: true,
        healthCheck: VpnHealthCheckOptions(
          checkInterval: Duration(milliseconds: 40),
          startupGracePeriod: Duration.zero,
          maxConsecutiveFailures: 1,
          failoverOnNoTraffic: false,
          connectivityProbeEnabled: true,
          connectivityProbeUrl: 'invalid://probe',
          failoverOnConnectivityFailure: true,
        ),
      ),
    );

    await vpn.startManaged();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(fakePlatform.restartCalls, greaterThanOrEqualTo(1));
    expect(fakePlatform.writtenConfigs.length, greaterThanOrEqualTo(2));

    await vpn.dispose();
    await fakePlatform.dispose();
  });

  test('startup grace window suppresses immediate failover churn', () async {
    final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform()
      ..pingShouldFail = true;
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());
    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          tls: const TlsOptions(enabled: false),
        ),
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'b.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
          tls: const TlsOptions(enabled: false),
        ),
      ],
      options: const EndpointPoolOptions(
        autoFailover: true,
        healthCheck: VpnHealthCheckOptions(
          checkInterval: Duration(milliseconds: 40),
          startupGracePeriod: Duration(milliseconds: 250),
          noTrafficTimeout: Duration(seconds: 10),
          pingEnabled: true,
          connectivityProbeEnabled: false,
          maxConsecutiveFailures: 1,
        ),
      ),
    );

    await vpn.startManaged();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(vpn.activeEndpointProfile?.tag, 'edge-a');
    expect(fakePlatform.restartCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 520));
    expect(fakePlatform.restartCalls, greaterThanOrEqualTo(1));
    expect(vpn.activeEndpointProfile?.tag, 'edge-b');

    await vpn.dispose();
    await fakePlatform.dispose();
  });

  test('ping failure is tolerated when connectivity probe succeeds', () async {
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

    final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform()
      ..pingShouldFail = true;
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());
    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          tls: const TlsOptions(enabled: false),
        ),
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'b.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
          tls: const TlsOptions(enabled: false),
        ),
      ],
      options: EndpointPoolOptions(
        autoFailover: true,
        healthCheck: VpnHealthCheckOptions(
          checkInterval: const Duration(milliseconds: 40),
          maxConsecutiveFailures: 1,
          failoverOnNoTraffic: false,
          pingEnabled: true,
          connectivityProbeEnabled: true,
          connectivityProbeUrl: 'http://127.0.0.1:${server.port}/healthz',
          failoverOnConnectivityFailure: true,
        ),
      ),
    );

    await vpn.startManaged();
    await Future<void>.delayed(const Duration(milliseconds: 220));

    expect(vpn.activeEndpointProfile?.tag, 'edge-a');
    expect(fakePlatform.restartCalls, 0);

    await vpn.dispose();
    await fakePlatform.dispose();
  });

  test(
    'no-traffic does not trigger failover while health checks are passing',
    () async {
      final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());
      await vpn.applyEndpointPool(
        profiles: <VpnProfile>[
          VpnProfile.vless(
            tag: 'edge-a',
            server: 'a.example.com',
            serverPort: 443,
            uuid: '11111111-2222-3333-4444-555555555555',
            tls: const TlsOptions(enabled: true),
          ),
          VpnProfile.vless(
            tag: 'edge-b',
            server: 'b.example.com',
            serverPort: 443,
            uuid: '11111111-2222-3333-4444-555555555556',
            tls: const TlsOptions(enabled: true),
          ),
        ],
        options: const EndpointPoolOptions(
          autoFailover: true,
          healthCheck: VpnHealthCheckOptions(
            checkInterval: Duration(milliseconds: 80),
            noTrafficTimeout: Duration(milliseconds: 100),
            pingEnabled: true,
            connectivityProbeEnabled: false,
            maxConsecutiveFailures: 1,
          ),
        ),
      );

      await vpn.startManaged();
      await Future<void>.delayed(const Duration(milliseconds: 260));

      expect(vpn.activeEndpointProfile?.tag, 'edge-a');
      expect(fakePlatform.restartCalls, 0);

      await vpn.dispose();
      await fakePlatform.dispose();
    },
  );

  test('adaptive mtu recovery is attempted before endpoint switch', () async {
    final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform()
      ..pingShouldFail = true;
    SignboxVpnPlatform.instance = fakePlatform;

    final SignboxVpn vpn = SignboxVpn();
    await vpn.initialize(const SingboxRuntimeOptions());
    await vpn.applyEndpointPool(
      profiles: <VpnProfile>[
        VpnProfile.vless(
          tag: 'edge-a',
          server: 'a.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555555',
          tls: const TlsOptions(enabled: true),
        ),
        VpnProfile.vless(
          tag: 'edge-b',
          server: 'b.example.com',
          serverPort: 443,
          uuid: '11111111-2222-3333-4444-555555555556',
          tls: const TlsOptions(enabled: true),
        ),
      ],
      throttlePolicy: const TrafficThrottlePolicy(
        tunMtu: 1400,
        enableAutoMtuProbe: true,
        mtuProbeCandidates: <int>[1400, 1380, 1360],
      ),
      options: const EndpointPoolOptions(
        autoFailover: true,
        healthCheck: VpnHealthCheckOptions(
          checkInterval: Duration(milliseconds: 80),
          startupGracePeriod: Duration.zero,
          noTrafficTimeout: Duration(seconds: 10),
          pingEnabled: true,
          pingTimeout: Duration(milliseconds: 10),
          connectivityProbeEnabled: false,
          maxConsecutiveFailures: 1,
        ),
      ),
    );

    await vpn.startManaged();
    await Future<void>.delayed(const Duration(milliseconds: 220));

    expect(vpn.activeEndpointProfile?.tag, 'edge-a');
    expect(fakePlatform.restartCalls, greaterThanOrEqualTo(1));
    expect(fakePlatform.writtenConfigs.length, greaterThanOrEqualTo(2));

    final Map<String, dynamic> firstConfig =
        jsonDecode(fakePlatform.writtenConfigs.first) as Map<String, dynamic>;
    final Map<String, dynamic> secondConfig =
        jsonDecode(fakePlatform.writtenConfigs[1]) as Map<String, dynamic>;
    final int firstMtu =
        ((firstConfig['inbounds'] as List<dynamic>).first
                as Map<String, dynamic>)['mtu']
            as int;
    final int secondMtu =
        ((secondConfig['inbounds'] as List<dynamic>).first
                as Map<String, dynamic>)['mtu']
            as int;
    expect(secondMtu, lessThan(firstMtu));

    await vpn.dispose();
    await fakePlatform.dispose();
  });

  test(
    'configured tun mtu is preserved as baseline before adaptive probing',
    () async {
      final _ManagedFakePlatform fakePlatform = _ManagedFakePlatform();
      SignboxVpnPlatform.instance = fakePlatform;

      final SignboxVpn vpn = SignboxVpn();
      await vpn.initialize(const SingboxRuntimeOptions());
      await vpn.applyEndpointPool(
        profiles: <VpnProfile>[
          VpnProfile.vless(
            tag: 'edge-a',
            server: 'a.example.com',
            serverPort: 443,
            uuid: '11111111-2222-3333-4444-555555555555',
            tls: const TlsOptions(enabled: true),
          ),
          VpnProfile.vless(
            tag: 'edge-b',
            server: 'b.example.com',
            serverPort: 443,
            uuid: '11111111-2222-3333-4444-555555555556',
            tls: const TlsOptions(enabled: true),
          ),
        ],
        throttlePolicy: const TrafficThrottlePolicy(
          tunMtu: 1380,
          enableAutoMtuProbe: true,
          mtuProbeCandidates: <int>[1400, 1380, 1360],
        ),
        options: const EndpointPoolOptions(
          autoFailover: true,
          healthCheck: VpnHealthCheckOptions(failoverOnNoTraffic: false),
        ),
      );

      final Map<String, dynamic> firstConfig =
          jsonDecode(fakePlatform.writtenConfigs.first) as Map<String, dynamic>;
      final int firstMtu =
          ((firstConfig['inbounds'] as List<dynamic>).first
                  as Map<String, dynamic>)['mtu']
              as int;
      expect(firstMtu, 1380);

      await vpn.dispose();
      await fakePlatform.dispose();
    },
  );
}
