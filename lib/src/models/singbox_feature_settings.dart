enum SingboxServiceMode { vpn, proxyOnly }

enum SingboxTunImplementation { system, gvisor }

enum SingboxIpv6RouteMode { disable, prefer, only }

enum WarpDetourMode { detourProxiesThroughWarp, routeAllThroughWarp }

enum DnsProviderPreset { custom, cloudflare, google, quad9, adguard }

class DnsProviderProfile {
  const DnsProviderProfile({required this.remoteDns, required this.directDns});

  final String remoteDns;
  final String directDns;
}

DnsProviderProfile dnsProviderProfileForPreset(DnsProviderPreset preset) {
  switch (preset) {
    case DnsProviderPreset.custom:
      return const DnsProviderProfile(
        remoteDns: 'https://1.1.1.1/dns-query',
        directDns: 'local',
      );
    case DnsProviderPreset.cloudflare:
      return const DnsProviderProfile(
        remoteDns: 'https://1.1.1.1/dns-query',
        directDns: '1.1.1.1',
      );
    case DnsProviderPreset.google:
      return const DnsProviderProfile(
        remoteDns: 'https://dns.google/dns-query',
        directDns: '8.8.8.8',
      );
    case DnsProviderPreset.quad9:
      return const DnsProviderProfile(
        remoteDns: 'https://dns.quad9.net/dns-query',
        directDns: '9.9.9.9',
      );
    case DnsProviderPreset.adguard:
      return const DnsProviderProfile(
        remoteDns: 'https://dns.adguard-dns.com/dns-query',
        directDns: '94.140.14.14',
      );
  }
}

class IntRange {
  const IntRange(this.min, this.max) : assert(min >= 0), assert(max >= min);

  final int min;
  final int max;

  String get compact => '$min-$max';

  Map<String, Object?> toMap() {
    return <String, Object?>{'min': min, 'max': max};
  }

  factory IntRange.fromDynamic(dynamic raw, {required IntRange fallback}) {
    if (raw is Map<Object?, Object?>) {
      final int? min = _readInt(raw['min']);
      final int? max = _readInt(raw['max']);
      if (min != null && max != null && min >= 0 && max >= min) {
        return IntRange(min, max);
      }
      return fallback;
    }

    if (raw is String) {
      final List<String> parts = raw.split('-');
      if (parts.length == 2) {
        final int? min = int.tryParse(parts[0].trim());
        final int? max = int.tryParse(parts[1].trim());
        if (min != null && max != null && min >= 0 && max >= min) {
          return IntRange(min, max);
        }
      }
    }

    return fallback;
  }
}

class AdvancedOptions {
  const AdvancedOptions({
    this.memoryLimit = false,
    this.debugMode = false,
    this.logLevel,
  });

  final bool memoryLimit;
  final bool debugMode;
  final String? logLevel;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'memoryLimit': memoryLimit,
      'debugMode': debugMode,
      'logLevel': logLevel,
    };
  }

  factory AdvancedOptions.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const AdvancedOptions();
    }

    return AdvancedOptions(
      memoryLimit: _readBool(raw['memoryLimit'], false),
      debugMode: _readBool(raw['debugMode'], false),
      logLevel: _readNullableString(raw['logLevel']),
    );
  }
}

class RouteOptions {
  const RouteOptions({
    this.region = 'other',
    this.blockAdvertisements = false,
    this.bypassLan = false,
    this.resolveDestination = false,
    this.ipv6RouteMode = SingboxIpv6RouteMode.disable,
    this.regionDirectDomains = const <String>[],
    this.regionDirectCidrs = const <String>[],
    this.extraBlockedKeywords = const <String>[],
  });

  final String region;
  final bool blockAdvertisements;
  final bool bypassLan;
  final bool resolveDestination;
  final SingboxIpv6RouteMode ipv6RouteMode;
  final List<String> regionDirectDomains;
  final List<String> regionDirectCidrs;
  final List<String> extraBlockedKeywords;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'region': region,
      'blockAdvertisements': blockAdvertisements,
      'bypassLan': bypassLan,
      'resolveDestination': resolveDestination,
      'ipv6RouteMode': ipv6RouteMode.name,
      'regionDirectDomains': regionDirectDomains,
      'regionDirectCidrs': regionDirectCidrs,
      'extraBlockedKeywords': extraBlockedKeywords,
    };
  }

  factory RouteOptions.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const RouteOptions();
    }

    return RouteOptions(
      region: _readString(raw['region'], 'other'),
      blockAdvertisements: _readBool(raw['blockAdvertisements'], false),
      bypassLan: _readBool(raw['bypassLan'], false),
      resolveDestination: _readBool(raw['resolveDestination'], false),
      ipv6RouteMode: _readEnum(
        raw['ipv6RouteMode'],
        SingboxIpv6RouteMode.values,
        SingboxIpv6RouteMode.disable,
      ),
      regionDirectDomains: _readStringList(raw['regionDirectDomains']),
      regionDirectCidrs: _readStringList(raw['regionDirectCidrs']),
      extraBlockedKeywords: _readStringList(raw['extraBlockedKeywords']),
    );
  }
}

class DnsOptions {
  const DnsOptions({
    this.providerPreset = DnsProviderPreset.custom,
    this.remoteDns = 'https://1.1.1.1/dns-query',
    this.remoteDomainStrategy = 'auto',
    this.directDns = 'local',
    this.directDomainStrategy = 'auto',
    this.enableDnsRouting = true,
    this.enableFakeIp = false,
    this.fakeIpInet4Range = '198.18.0.0/15',
    this.fakeIpInet6Range = 'fc00::/18',
    this.enableDohFallback = true,
    this.dohFallbackDns = 'https://dns.google/dns-query',
    this.dohFallbackDomainSuffixes = const <String>[
      'cp.cloudflare.com',
      'connectivitycheck.gstatic.com',
      'gstatic.com',
      'googleapis.com',
    ],
  });

  final DnsProviderPreset providerPreset;
  final String remoteDns;
  final String remoteDomainStrategy;
  final String directDns;
  final String directDomainStrategy;
  final bool enableDnsRouting;
  final bool enableFakeIp;
  final String fakeIpInet4Range;
  final String fakeIpInet6Range;
  final bool enableDohFallback;
  final String dohFallbackDns;
  final List<String> dohFallbackDomainSuffixes;

  factory DnsOptions.fromProvider({
    required DnsProviderPreset preset,
    String remoteDomainStrategy = 'auto',
    String directDomainStrategy = 'auto',
    bool enableDnsRouting = true,
    bool enableFakeIp = false,
    String fakeIpInet4Range = '198.18.0.0/15',
    String fakeIpInet6Range = 'fc00::/18',
    bool enableDohFallback = true,
    String dohFallbackDns = 'https://dns.google/dns-query',
    List<String> dohFallbackDomainSuffixes = const <String>[
      'cp.cloudflare.com',
      'connectivitycheck.gstatic.com',
      'gstatic.com',
      'googleapis.com',
    ],
    String? remoteDnsOverride,
    String? directDnsOverride,
  }) {
    final DnsProviderProfile profile = dnsProviderProfileForPreset(preset);
    return DnsOptions(
      providerPreset: preset,
      remoteDns: remoteDnsOverride ?? profile.remoteDns,
      remoteDomainStrategy: remoteDomainStrategy,
      directDns: directDnsOverride ?? profile.directDns,
      directDomainStrategy: directDomainStrategy,
      enableDnsRouting: enableDnsRouting,
      enableFakeIp: enableFakeIp,
      fakeIpInet4Range: fakeIpInet4Range,
      fakeIpInet6Range: fakeIpInet6Range,
      enableDohFallback: enableDohFallback,
      dohFallbackDns: dohFallbackDns,
      dohFallbackDomainSuffixes: dohFallbackDomainSuffixes,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'providerPreset': providerPreset.name,
      'remoteDns': remoteDns,
      'remoteDomainStrategy': remoteDomainStrategy,
      'directDns': directDns,
      'directDomainStrategy': directDomainStrategy,
      'enableDnsRouting': enableDnsRouting,
      'enableFakeIp': enableFakeIp,
      'fakeIpInet4Range': fakeIpInet4Range,
      'fakeIpInet6Range': fakeIpInet6Range,
      'enableDohFallback': enableDohFallback,
      'dohFallbackDns': dohFallbackDns,
      'dohFallbackDomainSuffixes': dohFallbackDomainSuffixes,
    };
  }

  factory DnsOptions.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const DnsOptions();
    }

    return DnsOptions(
      providerPreset: _readEnum(
        raw['providerPreset'],
        DnsProviderPreset.values,
        DnsProviderPreset.custom,
      ),
      remoteDns: _readString(raw['remoteDns'], 'https://1.1.1.1/dns-query'),
      remoteDomainStrategy: _readString(raw['remoteDomainStrategy'], 'auto'),
      directDns: _readString(raw['directDns'], 'local'),
      directDomainStrategy: _readString(raw['directDomainStrategy'], 'auto'),
      enableDnsRouting: _readBool(raw['enableDnsRouting'], true),
      enableFakeIp: _readBool(raw['enableFakeIp'], false),
      fakeIpInet4Range: _readString(raw['fakeIpInet4Range'], '198.18.0.0/15'),
      fakeIpInet6Range: _readString(raw['fakeIpInet6Range'], 'fc00::/18'),
      enableDohFallback: _readBool(raw['enableDohFallback'], true),
      dohFallbackDns: _readString(
        raw['dohFallbackDns'],
        'https://dns.google/dns-query',
      ),
      dohFallbackDomainSuffixes:
          _readStringList(raw['dohFallbackDomainSuffixes']).isEmpty
          ? const <String>[
              'cp.cloudflare.com',
              'connectivitycheck.gstatic.com',
              'gstatic.com',
              'googleapis.com',
            ]
          : _readStringList(raw['dohFallbackDomainSuffixes']),
    );
  }
}

class InboundOptions {
  const InboundOptions({
    this.serviceMode = SingboxServiceMode.vpn,
    this.strictRoute = true,
    this.tunImplementation = SingboxTunImplementation.gvisor,
    this.mixedPort,
    this.transparentProxyPort,
    this.localDnsPort,
    this.shareVpnInLocalNetwork = false,
    this.splitTunnelingEnabled,
    this.includePackages = const <String>[],
    this.excludePackages = const <String>[],
  }) : assert(mixedPort == null || (mixedPort > 0 && mixedPort <= 65535)),
       assert(
         transparentProxyPort == null ||
             (transparentProxyPort > 0 && transparentProxyPort <= 65535),
       ),
       assert(
         localDnsPort == null || (localDnsPort > 0 && localDnsPort <= 65535),
       );

  final SingboxServiceMode serviceMode;
  final bool strictRoute;
  final SingboxTunImplementation tunImplementation;
  final int? mixedPort;
  final int? transparentProxyPort;
  final int? localDnsPort;
  final bool shareVpnInLocalNetwork;
  final bool? splitTunnelingEnabled;
  final List<String> includePackages;
  final List<String> excludePackages;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'serviceMode': serviceMode.name,
      'strictRoute': strictRoute,
      'tunImplementation': tunImplementation.name,
      'mixedPort': mixedPort,
      'transparentProxyPort': transparentProxyPort,
      'localDnsPort': localDnsPort,
      'shareVpnInLocalNetwork': shareVpnInLocalNetwork,
      'splitTunnelingEnabled': splitTunnelingEnabled,
      'includePackages': includePackages,
      'excludePackages': excludePackages,
    };
  }

  factory InboundOptions.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const InboundOptions();
    }

    final List<String> includePackages = _readStringList(
      raw['includePackages'],
    );
    final List<String> excludePackages = _readStringList(
      raw['excludePackages'],
    );
    final bool? splitTunnelingEnabled = raw.containsKey('splitTunnelingEnabled')
        ? _readNullableBool(raw['splitTunnelingEnabled'])
        : null;

    return InboundOptions(
      serviceMode: _readEnum(
        raw['serviceMode'],
        SingboxServiceMode.values,
        SingboxServiceMode.vpn,
      ),
      strictRoute: _readBool(raw['strictRoute'], true),
      tunImplementation: _readEnum(
        raw['tunImplementation'],
        SingboxTunImplementation.values,
        SingboxTunImplementation.gvisor,
      ),
      mixedPort: _readInt(raw['mixedPort']),
      transparentProxyPort: _readInt(raw['transparentProxyPort']),
      localDnsPort: _readInt(raw['localDnsPort']),
      shareVpnInLocalNetwork: _readBool(raw['shareVpnInLocalNetwork'], false),
      splitTunnelingEnabled: splitTunnelingEnabled,
      includePackages: includePackages,
      excludePackages: excludePackages,
    );
  }
}

class TlsTricksOptions {
  const TlsTricksOptions({
    this.enableTlsFragment = false,
    this.tlsFragmentSize = const IntRange(10, 30),
    this.tlsFragmentSleep = const IntRange(2, 8),
    this.enableTlsMixedSniCase = false,
    this.enableTlsPadding = false,
    this.tlsPadding = const IntRange(1, 1500),
    this.rawOutboundPatch = const <String, Object?>{},
  });

  final bool enableTlsFragment;
  final IntRange tlsFragmentSize;
  final IntRange tlsFragmentSleep;
  final bool enableTlsMixedSniCase;
  final bool enableTlsPadding;
  final IntRange tlsPadding;
  final Map<String, Object?> rawOutboundPatch;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'enableTlsFragment': enableTlsFragment,
      'tlsFragmentSize': tlsFragmentSize.toMap(),
      'tlsFragmentSleep': tlsFragmentSleep.toMap(),
      'enableTlsMixedSniCase': enableTlsMixedSniCase,
      'enableTlsPadding': enableTlsPadding,
      'tlsPadding': tlsPadding.toMap(),
      'rawOutboundPatch': rawOutboundPatch,
    };
  }

  factory TlsTricksOptions.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const TlsTricksOptions();
    }

    return TlsTricksOptions(
      enableTlsFragment: _readBool(raw['enableTlsFragment'], false),
      tlsFragmentSize: IntRange.fromDynamic(
        raw['tlsFragmentSize'],
        fallback: const IntRange(10, 30),
      ),
      tlsFragmentSleep: IntRange.fromDynamic(
        raw['tlsFragmentSleep'],
        fallback: const IntRange(2, 8),
      ),
      enableTlsMixedSniCase: _readBool(raw['enableTlsMixedSniCase'], false),
      enableTlsPadding: _readBool(raw['enableTlsPadding'], false),
      tlsPadding: IntRange.fromDynamic(
        raw['tlsPadding'],
        fallback: const IntRange(1, 1500),
      ),
      rawOutboundPatch: _readObjectMap(raw['rawOutboundPatch']),
    );
  }
}

class WarpOptions {
  const WarpOptions({
    this.enableWarp = false,
    this.detourMode = WarpDetourMode.detourProxiesThroughWarp,
    this.licenseKey,
    this.cleanIp = 'auto',
    this.port = 0,
    this.noiseCount = const IntRange(1, 3),
    this.noiseMode = 'm4',
    this.noiseSize = const IntRange(10, 30),
    this.noiseDelay = const IntRange(10, 30),
    this.outboundTemplate = const <String, Object?>{},
  }) : assert(port >= 0 && port <= 65535);

  final bool enableWarp;
  final WarpDetourMode detourMode;
  final String? licenseKey;
  final String cleanIp;
  final int port;
  final IntRange noiseCount;
  final String noiseMode;
  final IntRange noiseSize;
  final IntRange noiseDelay;
  final Map<String, Object?> outboundTemplate;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'enableWarp': enableWarp,
      'detourMode': detourMode.name,
      'licenseKey': licenseKey,
      'cleanIp': cleanIp,
      'port': port,
      'noiseCount': noiseCount.toMap(),
      'noiseMode': noiseMode,
      'noiseSize': noiseSize.toMap(),
      'noiseDelay': noiseDelay.toMap(),
      'outboundTemplate': outboundTemplate,
    };
  }

  factory WarpOptions.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const WarpOptions();
    }

    return WarpOptions(
      enableWarp: _readBool(raw['enableWarp'], false),
      detourMode: _readEnum(
        raw['detourMode'],
        WarpDetourMode.values,
        WarpDetourMode.detourProxiesThroughWarp,
      ),
      licenseKey: _readNullableString(raw['licenseKey']),
      cleanIp: _readString(raw['cleanIp'], 'auto'),
      port: _readInt(raw['port']) ?? 0,
      noiseCount: IntRange.fromDynamic(
        raw['noiseCount'],
        fallback: const IntRange(1, 3),
      ),
      noiseMode: _readString(raw['noiseMode'], 'm4'),
      noiseSize: IntRange.fromDynamic(
        raw['noiseSize'],
        fallback: const IntRange(10, 30),
      ),
      noiseDelay: IntRange.fromDynamic(
        raw['noiseDelay'],
        fallback: const IntRange(10, 30),
      ),
      outboundTemplate: _readObjectMap(raw['outboundTemplate']),
    );
  }
}

class MiscOptions {
  const MiscOptions({
    this.connectionTestUrl = 'http://cp.cloudflare.com',
    this.urlTestInterval = const Duration(minutes: 10),
    this.clashApiPort = 16756,
    this.useXrayCoreWhenPossible = false,
  }) : assert(
         clashApiPort == null || (clashApiPort > 0 && clashApiPort <= 65535),
       );

  final String connectionTestUrl;
  final Duration urlTestInterval;
  final int? clashApiPort;
  final bool useXrayCoreWhenPossible;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'connectionTestUrl': connectionTestUrl,
      'urlTestIntervalSeconds': urlTestInterval.inSeconds,
      'clashApiPort': clashApiPort,
      'useXrayCoreWhenPossible': useXrayCoreWhenPossible,
    };
  }

  factory MiscOptions.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const MiscOptions();
    }

    return MiscOptions(
      connectionTestUrl: _readString(
        raw['connectionTestUrl'],
        'http://cp.cloudflare.com',
      ),
      urlTestInterval: Duration(
        seconds: _readInt(raw['urlTestIntervalSeconds']) ?? 600,
      ),
      clashApiPort: _readInt(raw['clashApiPort']) ?? 16756,
      useXrayCoreWhenPossible: _readBool(raw['useXrayCoreWhenPossible'], false),
    );
  }
}

class SingboxFeatureSettings {
  const SingboxFeatureSettings({
    this.advanced = const AdvancedOptions(),
    this.route = const RouteOptions(),
    this.dns = const DnsOptions(),
    this.inbound = const InboundOptions(),
    this.tlsTricks = const TlsTricksOptions(),
    this.warp = const WarpOptions(),
    this.misc = const MiscOptions(),
    this.rawConfigPatch = const <String, Object?>{},
  });

  final AdvancedOptions advanced;
  final RouteOptions route;
  final DnsOptions dns;
  final InboundOptions inbound;
  final TlsTricksOptions tlsTricks;
  final WarpOptions warp;
  final MiscOptions misc;
  final Map<String, Object?> rawConfigPatch;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'advanced': advanced.toMap(),
      'route': route.toMap(),
      'dns': dns.toMap(),
      'inbound': inbound.toMap(),
      'tlsTricks': tlsTricks.toMap(),
      'warp': warp.toMap(),
      'misc': misc.toMap(),
      'rawConfigPatch': rawConfigPatch,
    };
  }

  factory SingboxFeatureSettings.fromMap(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return const SingboxFeatureSettings();
    }

    return SingboxFeatureSettings(
      advanced: AdvancedOptions.fromMap(raw['advanced']),
      route: RouteOptions.fromMap(raw['route']),
      dns: DnsOptions.fromMap(raw['dns']),
      inbound: InboundOptions.fromMap(raw['inbound']),
      tlsTricks: TlsTricksOptions.fromMap(raw['tlsTricks']),
      warp: WarpOptions.fromMap(raw['warp']),
      misc: MiscOptions.fromMap(raw['misc']),
      rawConfigPatch: _readObjectMap(raw['rawConfigPatch']),
    );
  }
}

bool _readBool(dynamic raw, bool fallback) {
  if (raw is bool) {
    return raw;
  }
  return fallback;
}

bool? _readNullableBool(dynamic raw) {
  if (raw is bool) {
    return raw;
  }
  return null;
}

int? _readInt(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw);
  }
  return null;
}

String _readString(dynamic raw, String fallback) {
  if (raw is String && raw.isNotEmpty) {
    return raw;
  }
  return fallback;
}

String? _readNullableString(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return raw;
  }
  return null;
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .whereType<String>()
      .where((String item) => item.isNotEmpty)
      .toList();
}

Map<String, Object?> _readObjectMap(dynamic raw) {
  if (raw is! Map<Object?, Object?>) {
    return const <String, Object?>{};
  }

  final Map<String, Object?> output = <String, Object?>{};
  raw.forEach((Object? key, Object? value) {
    if (key is String) {
      output[key] = value;
    }
  });
  return output;
}

T _readEnum<T extends Enum>(dynamic raw, List<T> values, T fallback) {
  if (raw is String) {
    for (final T value in values) {
      if (value.name == raw) {
        return value;
      }
    }
  }
  return fallback;
}
