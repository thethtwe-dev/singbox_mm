import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  test('supports serialization roundtrip for advanced settings surface', () {
    const SingboxFeatureSettings input = SingboxFeatureSettings(
      advanced: AdvancedOptions(
        memoryLimit: true,
        debugMode: true,
        logLevel: 'warn',
      ),
      route: RouteOptions(
        region: 'other',
        blockAdvertisements: true,
        bypassLan: true,
        resolveDestination: true,
        ipv6RouteMode: SingboxIpv6RouteMode.prefer,
        regionDirectDomains: <String>['example.com'],
        regionDirectCidrs: <String>['10.0.0.0/8'],
        extraBlockedKeywords: <String>['ads'],
      ),
      dns: DnsOptions(
        providerPreset: DnsProviderPreset.google,
        remoteDns: 'udp://1.1.1.1',
        remoteDomainStrategy: 'auto',
        directDns: '1.1.1.1',
        directDomainStrategy: 'auto',
        enableDnsRouting: true,
        enableFakeIp: true,
        fakeIpInet4Range: '198.18.0.0/15',
        fakeIpInet6Range: 'fc00::/18',
        enableDohFallback: true,
        dohFallbackDns: 'https://dns.google/dns-query',
        dohFallbackDomainSuffixes: <String>['gstatic.com'],
      ),
      inbound: InboundOptions(
        serviceMode: SingboxServiceMode.vpn,
        strictRoute: true,
        tunImplementation: SingboxTunImplementation.gvisor,
        mixedPort: 12334,
        transparentProxyPort: 12335,
        localDnsPort: 16450,
        shareVpnInLocalNetwork: false,
        splitTunnelingEnabled: true,
        includePackages: <String>['com.example.browser'],
        excludePackages: <String>['com.example.bank'],
      ),
      tlsTricks: TlsTricksOptions(
        enableTlsFragment: true,
        tlsFragmentSize: IntRange(10, 30),
        tlsFragmentSleep: IntRange(2, 8),
        enableTlsMixedSniCase: true,
        enableTlsPadding: true,
        tlsPadding: IntRange(1, 1500),
        rawOutboundPatch: <String, Object?>{
          'tls': <String, Object?>{
            'utls': <String, Object?>{'fingerprint': 'chrome'},
          },
        },
      ),
      warp: WarpOptions(
        enableWarp: true,
        detourMode: WarpDetourMode.detourProxiesThroughWarp,
        licenseKey: 'license-key',
        cleanIp: 'auto',
        port: 0,
        noiseCount: IntRange(1, 3),
        noiseMode: 'm4',
        noiseSize: IntRange(10, 30),
        noiseDelay: IntRange(10, 30),
        outboundTemplate: <String, Object?>{
          'type': 'wireguard',
          'tag': 'warp-out',
        },
      ),
      misc: MiscOptions(
        connectionTestUrl: 'http://cp.cloudflare.com',
        urlTestInterval: Duration(minutes: 10),
        clashApiPort: 16756,
        useXrayCoreWhenPossible: true,
      ),
      rawConfigPatch: <String, Object?>{
        'experimental': <String, Object?>{
          'cache_file': <String, Object?>{'enabled': true},
        },
      },
    );

    final Map<String, Object?> encoded = input.toMap();
    final SingboxFeatureSettings decoded = SingboxFeatureSettings.fromMap(
      encoded,
    );

    expect(decoded.advanced.memoryLimit, isTrue);
    expect(decoded.advanced.debugMode, isTrue);
    expect(decoded.route.blockAdvertisements, isTrue);
    expect(decoded.route.ipv6RouteMode, SingboxIpv6RouteMode.prefer);
    expect(decoded.dns.providerPreset, DnsProviderPreset.google);
    expect(decoded.dns.remoteDns, 'udp://1.1.1.1');
    expect(decoded.dns.enableFakeIp, isTrue);
    expect(decoded.dns.enableDohFallback, isTrue);
    expect(decoded.dns.dohFallbackDns, 'https://dns.google/dns-query');
    expect(decoded.dns.dohFallbackDomainSuffixes, <String>['gstatic.com']);
    expect(decoded.inbound.mixedPort, 12334);
    expect(decoded.inbound.splitTunnelingEnabled, isTrue);
    expect(decoded.inbound.includePackages, <String>['com.example.browser']);
    expect(decoded.inbound.excludePackages, <String>['com.example.bank']);
    expect(decoded.tlsTricks.enableTlsPadding, isTrue);
    expect(decoded.warp.enableWarp, isTrue);
    expect(decoded.warp.outboundTemplate['type'], 'wireguard');
    expect(decoded.misc.clashApiPort, 16756);
    expect(decoded.misc.useXrayCoreWhenPossible, isTrue);
    expect(
      (decoded.rawConfigPatch['experimental'] as Map<String, Object?>)
          .isNotEmpty,
      isTrue,
    );
  });

  test('dns preset helper resolves provider endpoints', () {
    final DnsOptions options = DnsOptions.fromProvider(
      preset: DnsProviderPreset.quad9,
    );
    expect(options.providerPreset, DnsProviderPreset.quad9);
    expect(options.remoteDns, 'https://dns.quad9.net/dns-query');
    expect(options.directDns, '9.9.9.9');
  });
}
