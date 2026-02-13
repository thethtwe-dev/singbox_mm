import '../../models/bypass_policy.dart';
import '../../models/singbox_feature_settings.dart';
import '../../models/traffic_throttle_policy.dart';
import '../../models/vpn_profile.dart';

class SingboxDnsBuilder {
  const SingboxDnsBuilder();

  Map<String, Object?> build({
    required VpnProfile profile,
    required BypassPolicy bypassPolicy,
    required TrafficThrottlePolicy throttlePolicy,
    required SingboxFeatureSettings settings,
    required bool forceIpv4Only,
  }) {
    final String defaultDnsStrategy = _resolveDnsStrategy(
      strategy: forceIpv4Only ? 'ipv4_only' : throttlePolicy.dnsStrategy,
      fallback: settings.route.ipv6RouteMode == SingboxIpv6RouteMode.only
          ? 'prefer_ipv6'
          : 'prefer_ipv4',
    );
    final String remoteDnsStrategy = _resolveDnsStrategy(
      strategy: settings.dns.remoteDomainStrategy,
      fallback: defaultDnsStrategy,
    );
    final String directDnsStrategy = _resolveDnsStrategy(
      strategy: settings.dns.directDomainStrategy,
      fallback: defaultDnsStrategy,
    );
    final String resolvedRemoteStrategy = forceIpv4Only
        ? 'ipv4_only'
        : remoteDnsStrategy;
    final String resolvedDirectStrategy = forceIpv4Only
        ? 'ipv4_only'
        : directDnsStrategy;

    final DnsProviderProfile providerProfile = dnsProviderProfileForPreset(
      settings.dns.providerPreset,
    );
    final bool useProviderPreset =
        settings.dns.providerPreset != DnsProviderPreset.custom;
    final bool hasExplicitDirectDns =
        settings.dns.directDns.trim().isNotEmpty &&
        settings.dns.directDns.trim().toLowerCase() != 'local';

    final String remoteAddress = useProviderPreset
        ? providerProfile.remoteDns
        : (settings.dns.remoteDns.isNotEmpty
              ? settings.dns.remoteDns
              : bypassPolicy.remoteDnsAddress);
    final String directAddress = useProviderPreset
        ? (hasExplicitDirectDns
              ? settings.dns.directDns
              : providerProfile.directDns)
        : (settings.dns.directDns.isNotEmpty
              ? settings.dns.directDns
              : 'local');
    final String dohFallbackAddress = settings.dns.dohFallbackDns.trim();
    final bool enableDohFallback =
        settings.dns.enableDohFallback &&
        _looksLikeDohAddress(remoteAddress) &&
        dohFallbackAddress.isNotEmpty &&
        dohFallbackAddress.toLowerCase() != remoteAddress.toLowerCase();
    final bool preferDirectDohFallback =
        enableDohFallback &&
        (profile.protocol == VpnProtocol.hysteria2 ||
            profile.protocol == VpnProtocol.tuic);

    final List<String> directDomains = _dedupeStrings(<String>[
      ...bypassPolicy.directDomains,
      ...settings.route.regionDirectDomains,
    ]);
    final List<String> directCidrs = _dedupeStrings(<String>[
      ...bypassPolicy.directCidrs,
      ...settings.route.regionDirectCidrs,
    ]);

    final List<Object?> rules = <Object?>[];
    if (directDomains.isNotEmpty) {
      rules.add(<String, Object?>{
        'domain_suffix': directDomains,
        'server': 'dns-direct',
      });
    }
    if (directCidrs.isNotEmpty) {
      rules.add(<String, Object?>{
        'ip_cidr': directCidrs,
        'server': 'dns-direct',
      });
    }

    if (enableDohFallback) {
      final List<String> fallbackDomains = _dedupeStrings(
        settings.dns.dohFallbackDomainSuffixes,
      );
      if (fallbackDomains.isNotEmpty) {
        rules.insert(0, <String, Object?>{
          'domain_suffix': fallbackDomains,
          'server': 'dns-remote-fallback',
        });
      }
    }

    final List<Object?> servers = <Object?>[];
    if (settings.dns.enableFakeIp) {
      servers.add(<String, Object?>{'tag': 'dns-fakeip', 'address': 'fakeip'});
      rules.insert(0, <String, Object?>{
        'query_type': const <String>['A', 'AAAA'],
        'server': 'dns-fakeip',
      });
    }

    servers.add(<String, Object?>{
      'tag': 'dns-remote',
      'address': remoteAddress,
      'detour': profile.tag,
      'strategy': resolvedRemoteStrategy,
    });
    if (enableDohFallback) {
      final Map<String, Object?> fallbackServer = <String, Object?>{
        'tag': 'dns-remote-fallback',
        'address': dohFallbackAddress,
        'detour': preferDirectDohFallback ? 'direct' : profile.tag,
        'strategy': resolvedRemoteStrategy,
      };
      if (preferDirectDohFallback &&
          _requiresAddressResolver(dohFallbackAddress)) {
        fallbackServer['address_resolver'] = 'dns-direct';
        fallbackServer['address_strategy'] = resolvedDirectStrategy;
      }
      servers.add(fallbackServer);
    }
    servers.add(<String, Object?>{
      'tag': 'dns-direct',
      'address': directAddress,
      'detour': 'direct',
      'strategy': resolvedDirectStrategy,
    });

    final Map<String, Object?> dns = <String, Object?>{
      'servers': servers,
      'strategy': resolvedRemoteStrategy,
      'rules': rules,
      'final': preferDirectDohFallback ? 'dns-remote-fallback' : 'dns-remote',
      'independent_cache': true,
    };
    if (settings.dns.enableFakeIp) {
      dns['fakeip'] = <String, Object?>{
        'enabled': true,
        'inet4_range': settings.dns.fakeIpInet4Range,
        'inet6_range': settings.dns.fakeIpInet6Range,
      };
    }
    return dns;
  }

  String _resolveDnsStrategy({
    required String strategy,
    required String fallback,
  }) {
    final String normalized = strategy.toLowerCase();
    switch (normalized) {
      case 'auto':
        return fallback;
      case 'prefer_ipv4':
      case 'prefer_ipv6':
      case 'ipv4_only':
      case 'ipv6_only':
        return normalized;
      default:
        return fallback;
    }
  }

  bool _looksLikeDohAddress(String address) {
    final String normalized = address.trim().toLowerCase();
    return normalized.startsWith('https://') ||
        normalized.startsWith('h3://') ||
        normalized.startsWith('tls://');
  }

  bool _requiresAddressResolver(String address) {
    final Uri? uri = Uri.tryParse(address.trim());
    final String host = uri?.host.trim() ?? '';
    if (host.isEmpty) {
      return false;
    }
    // Literal IPv4 / IPv6 endpoints can be dialed directly without bootstrap DNS.
    final RegExp ipv4Pattern = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
    if (ipv4Pattern.hasMatch(host)) {
      return false;
    }
    if (host.contains(':')) {
      return false;
    }
    return true;
  }

  List<String> _dedupeStrings(List<String> input) {
    final Set<String> output = <String>{};
    for (final String raw in input) {
      final String value = raw.trim();
      if (value.isNotEmpty) {
        output.add(value);
      }
    }
    return output.toList(growable: false);
  }
}
