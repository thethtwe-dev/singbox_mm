import 'bypass_policy.dart';
import 'singbox_feature_settings.dart';
import 'traffic_throttle_policy.dart';
import 'vpn_failover_options.dart';

enum GfwPresetMode { compatibility, balanced, aggressive, extreme }

class GfwPresetPack {
  const GfwPresetPack({
    required this.mode,
    required this.name,
    required this.description,
    required this.bypassPolicy,
    required this.throttlePolicy,
    required this.featureSettings,
    required this.endpointPoolOptions,
  });

  final GfwPresetMode mode;
  final String name;
  final String description;
  final BypassPolicy bypassPolicy;
  final TrafficThrottlePolicy throttlePolicy;
  final SingboxFeatureSettings featureSettings;
  final EndpointPoolOptions endpointPoolOptions;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'mode': mode.name,
      'name': name,
      'description': description,
      'bypassPolicy': bypassPolicy.toMap(),
      'throttlePolicy': throttlePolicy.toMap(),
      'featureSettings': featureSettings.toMap(),
      'endpointPoolOptions': <String, Object?>{
        'autoFailover': endpointPoolOptions.autoFailover,
        'rotationStrategy': endpointPoolOptions.rotationStrategy.name,
      },
    };
  }

  static GfwPresetPack fromMode(GfwPresetMode mode) {
    switch (mode) {
      case GfwPresetMode.compatibility:
        return compatibility();
      case GfwPresetMode.balanced:
        return balanced();
      case GfwPresetMode.aggressive:
        return aggressive();
      case GfwPresetMode.extreme:
        return extreme();
    }
  }

  static List<GfwPresetPack> all() {
    return const <GfwPresetPack>[
      _compatibility,
      _balanced,
      _aggressive,
      _extreme,
    ];
  }

  static GfwPresetPack compatibility() => _compatibility;
  static GfwPresetPack balanced() => _balanced;
  static GfwPresetPack aggressive() => _aggressive;
  static GfwPresetPack extreme() => _extreme;

  static const GfwPresetPack _compatibility = GfwPresetPack(
    mode: GfwPresetMode.compatibility,
    name: 'Compatibility',
    description:
        'Conservative settings with stable defaults for broad network compatibility.',
    bypassPolicy: BypassPolicy(
      preset: BypassPolicyPreset.balanced,
      directDomains: <String>['lan', 'local'],
      bypassPrivateNetworks: true,
      remoteDnsAddress: 'https://1.1.1.1/dns-query',
    ),
    throttlePolicy: TrafficThrottlePolicy(
      enableMultiplex: false,
      enableTcpBrutal: false,
      tcpFastOpen: true,
      udpFragment: true,
      tunMtu: 1400,
      dnsStrategy: 'prefer_ipv4',
    ),
    featureSettings: SingboxFeatureSettings(
      advanced: AdvancedOptions(memoryLimit: false, debugMode: false),
      route: RouteOptions(
        region: 'other',
        blockAdvertisements: true,
        bypassLan: true,
        resolveDestination: true,
        ipv6RouteMode: SingboxIpv6RouteMode.disable,
      ),
      dns: DnsOptions(
        providerPreset: DnsProviderPreset.cloudflare,
        remoteDns: 'https://1.1.1.1/dns-query',
        directDns: 'local',
        enableDnsRouting: true,
        enableDohFallback: true,
        dohFallbackDns: 'https://dns.google/dns-query',
      ),
      inbound: InboundOptions(
        serviceMode: SingboxServiceMode.vpn,
        strictRoute: true,
        tunImplementation: SingboxTunImplementation.gvisor,
      ),
      tlsTricks: TlsTricksOptions(),
      misc: MiscOptions(
        connectionTestUrl: 'http://cp.cloudflare.com',
        urlTestInterval: Duration(minutes: 10),
        clashApiPort: 16756,
      ),
    ),
    endpointPoolOptions: EndpointPoolOptions(
      autoFailover: true,
      rotationStrategy: EndpointRotationStrategy.healthiest,
      healthCheck: VpnHealthCheckOptions(
        enabled: true,
        checkInterval: Duration(seconds: 2),
        noTrafficTimeout: Duration(seconds: 8),
        pingEnabled: true,
        pingTimeout: Duration(milliseconds: 900),
        connectivityProbeEnabled: true,
        connectivityProbeUrl: 'http://cp.cloudflare.com',
        connectivityProbeTimeout: Duration(milliseconds: 1500),
        maxConsecutiveFailures: 1,
      ),
    ),
  );

  static const GfwPresetPack _balanced = GfwPresetPack(
    mode: GfwPresetMode.balanced,
    name: 'Balanced',
    description:
        'Recommended baseline against throttling with low overhead and reliable failover.',
    bypassPolicy: BypassPolicy(
      preset: BypassPolicyPreset.aggressive,
      directDomains: <String>['lan', 'local'],
      blockedDomainKeywords: <String>[
        'doubleclick',
        'adservice',
        'tracking',
        'analytics',
      ],
      bypassPrivateNetworks: true,
      remoteDnsAddress: 'https://1.1.1.1/dns-query',
    ),
    throttlePolicy: TrafficThrottlePolicy(
      enableMultiplex: true,
      multiplexPadding: true,
      multiplexConnections: 4,
      multiplexMinStreams: 4,
      multiplexMaxStreams: 16,
      enableTcpBrutal: false,
      tcpBrutalUploadMbps: 80,
      tcpBrutalDownloadMbps: 240,
      tcpFastOpen: true,
      udpFragment: true,
      tunMtu: 1380,
      dnsStrategy: 'prefer_ipv4',
    ),
    featureSettings: SingboxFeatureSettings(
      advanced: AdvancedOptions(memoryLimit: false, debugMode: false),
      route: RouteOptions(
        region: 'other',
        blockAdvertisements: true,
        bypassLan: true,
        resolveDestination: true,
        ipv6RouteMode: SingboxIpv6RouteMode.disable,
      ),
      dns: DnsOptions(
        providerPreset: DnsProviderPreset.cloudflare,
        remoteDns: 'https://1.1.1.1/dns-query',
        directDns: 'local',
        enableDnsRouting: true,
        enableFakeIp: true,
        enableDohFallback: true,
        dohFallbackDns: 'https://dns.google/dns-query',
      ),
      inbound: InboundOptions(
        serviceMode: SingboxServiceMode.vpn,
        strictRoute: true,
        tunImplementation: SingboxTunImplementation.gvisor,
      ),
      tlsTricks: TlsTricksOptions(
        enableTlsFragment: true,
        tlsFragmentSize: IntRange(10, 30),
        tlsFragmentSleep: IntRange(2, 8),
        enableTlsMixedSniCase: true,
      ),
      misc: MiscOptions(
        connectionTestUrl: 'http://cp.cloudflare.com',
        urlTestInterval: Duration(minutes: 5),
        clashApiPort: 16756,
      ),
    ),
    endpointPoolOptions: EndpointPoolOptions(
      autoFailover: true,
      rotationStrategy: EndpointRotationStrategy.healthiest,
      healthCheck: VpnHealthCheckOptions(
        enabled: true,
        checkInterval: Duration(seconds: 2),
        noTrafficTimeout: Duration(seconds: 8),
        pingEnabled: true,
        pingTimeout: Duration(milliseconds: 900),
        connectivityProbeEnabled: true,
        connectivityProbeUrl: 'http://cp.cloudflare.com',
        connectivityProbeTimeout: Duration(milliseconds: 1500),
        maxConsecutiveFailures: 1,
      ),
    ),
  );

  static const GfwPresetPack _aggressive = GfwPresetPack(
    mode: GfwPresetMode.aggressive,
    name: 'Aggressive',
    description:
        'Stronger anti-throttling and stricter probing for unstable or heavily filtered networks.',
    bypassPolicy: BypassPolicy(
      preset: BypassPolicyPreset.strict,
      directDomains: <String>['lan', 'local'],
      blockedDomainKeywords: <String>[
        'doubleclick',
        'adservice',
        'tracking',
        'analytics',
        'metrics',
      ],
      bypassPrivateNetworks: true,
      remoteDnsAddress: 'https://1.1.1.1/dns-query',
    ),
    throttlePolicy: TrafficThrottlePolicy(
      enableMultiplex: true,
      multiplexPadding: true,
      multiplexConnections: 6,
      multiplexMinStreams: 6,
      multiplexMaxStreams: 24,
      enableTcpBrutal: false,
      tcpBrutalUploadMbps: 100,
      tcpBrutalDownloadMbps: 320,
      tcpFastOpen: true,
      udpFragment: true,
      tunMtu: 1360,
      dnsStrategy: 'prefer_ipv4',
    ),
    featureSettings: SingboxFeatureSettings(
      advanced: AdvancedOptions(memoryLimit: true, debugMode: false),
      route: RouteOptions(
        region: 'other',
        blockAdvertisements: true,
        bypassLan: true,
        resolveDestination: true,
        ipv6RouteMode: SingboxIpv6RouteMode.disable,
      ),
      dns: DnsOptions(
        providerPreset: DnsProviderPreset.cloudflare,
        remoteDns: 'https://1.1.1.1/dns-query',
        directDns: 'local',
        enableDnsRouting: true,
        enableFakeIp: true,
        enableDohFallback: true,
        dohFallbackDns: 'https://dns.google/dns-query',
      ),
      inbound: InboundOptions(
        serviceMode: SingboxServiceMode.vpn,
        strictRoute: true,
        tunImplementation: SingboxTunImplementation.gvisor,
      ),
      tlsTricks: TlsTricksOptions(
        enableTlsFragment: true,
        tlsFragmentSize: IntRange(8, 24),
        tlsFragmentSleep: IntRange(2, 6),
        enableTlsMixedSniCase: true,
        enableTlsPadding: true,
        tlsPadding: IntRange(20, 900),
      ),
      misc: MiscOptions(
        connectionTestUrl: 'http://cp.cloudflare.com',
        urlTestInterval: Duration(minutes: 3),
        clashApiPort: 16756,
      ),
    ),
    endpointPoolOptions: EndpointPoolOptions(
      autoFailover: true,
      rotationStrategy: EndpointRotationStrategy.healthiest,
      healthCheck: VpnHealthCheckOptions(
        enabled: true,
        checkInterval: Duration(seconds: 2),
        noTrafficTimeout: Duration(seconds: 8),
        pingEnabled: true,
        pingTimeout: Duration(milliseconds: 900),
        connectivityProbeEnabled: true,
        connectivityProbeUrl: 'http://cp.cloudflare.com',
        connectivityProbeTimeout: Duration(milliseconds: 1500),
        maxConsecutiveFailures: 1,
      ),
    ),
  );

  static const GfwPresetPack _extreme = GfwPresetPack(
    mode: GfwPresetMode.extreme,
    name: 'Extreme',
    description:
        'Maximum evasion settings for very hostile links. Higher overhead and battery usage.',
    bypassPolicy: BypassPolicy(
      preset: BypassPolicyPreset.strict,
      directDomains: <String>['lan', 'local'],
      blockedDomainKeywords: <String>[
        'doubleclick',
        'adservice',
        'tracking',
        'analytics',
        'metrics',
        'telemetry',
      ],
      bypassPrivateNetworks: true,
      remoteDnsAddress: 'https://1.1.1.1/dns-query',
    ),
    throttlePolicy: TrafficThrottlePolicy(
      enableMultiplex: true,
      multiplexPadding: true,
      multiplexConnections: 8,
      multiplexMinStreams: 8,
      multiplexMaxStreams: 32,
      enableTcpBrutal: false,
      tcpBrutalUploadMbps: 120,
      tcpBrutalDownloadMbps: 360,
      tcpFastOpen: true,
      udpFragment: true,
      tunMtu: 1340,
      dnsStrategy: 'prefer_ipv4',
    ),
    featureSettings: SingboxFeatureSettings(
      advanced: AdvancedOptions(memoryLimit: true, debugMode: false),
      route: RouteOptions(
        region: 'other',
        blockAdvertisements: true,
        bypassLan: true,
        resolveDestination: true,
        ipv6RouteMode: SingboxIpv6RouteMode.disable,
      ),
      dns: DnsOptions(
        providerPreset: DnsProviderPreset.cloudflare,
        remoteDns: 'https://1.1.1.1/dns-query',
        directDns: 'local',
        enableDnsRouting: true,
        enableFakeIp: true,
        enableDohFallback: true,
        dohFallbackDns: 'https://dns.google/dns-query',
      ),
      inbound: InboundOptions(
        serviceMode: SingboxServiceMode.vpn,
        strictRoute: true,
        tunImplementation: SingboxTunImplementation.gvisor,
      ),
      tlsTricks: TlsTricksOptions(
        enableTlsFragment: true,
        tlsFragmentSize: IntRange(6, 20),
        tlsFragmentSleep: IntRange(1, 5),
        enableTlsMixedSniCase: true,
        enableTlsPadding: true,
        tlsPadding: IntRange(50, 1200),
      ),
      misc: MiscOptions(
        connectionTestUrl: 'http://cp.cloudflare.com',
        urlTestInterval: Duration(minutes: 2),
        clashApiPort: 16756,
      ),
    ),
    endpointPoolOptions: EndpointPoolOptions(
      autoFailover: true,
      rotationStrategy: EndpointRotationStrategy.healthiest,
      healthCheck: VpnHealthCheckOptions(
        enabled: true,
        checkInterval: Duration(seconds: 2),
        noTrafficTimeout: Duration(seconds: 8),
        pingEnabled: true,
        pingTimeout: Duration(milliseconds: 900),
        connectivityProbeEnabled: true,
        connectivityProbeUrl: 'http://cp.cloudflare.com',
        connectivityProbeTimeout: Duration(milliseconds: 1500),
        maxConsecutiveFailures: 1,
      ),
    ),
  );
}
