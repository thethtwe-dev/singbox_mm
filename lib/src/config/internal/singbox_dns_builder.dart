import '../../models/bypass_policy.dart';
import '../../models/singbox_feature_settings.dart';
import '../../models/vpn_profile.dart';

class SingboxDnsBuilder {
  const SingboxDnsBuilder();

  static const String _strictRemoteDns = 'https://1.1.1.1/dns-query';
  static const String _strictDirectDns = '1.1.1.1';
  static const String _strictFakeIpInet4Range = '198.18.0.0/15';

  Map<String, Object?> build({
    required VpnProfile profile,
    required BypassPolicy bypassPolicy,
    required SingboxFeatureSettings settings,
  }) {
    const String defaultDnsStrategy = 'prefer_ipv4';
    final String remoteDnsStrategy = _resolveDnsStrategy(
      strategy: settings.dns.remoteDomainStrategy,
      fallback: defaultDnsStrategy,
    );
    final String directDnsStrategy = _resolveDnsStrategy(
      strategy: settings.dns.directDomainStrategy,
      fallback: defaultDnsStrategy,
    );
    final String resolvedRemoteStrategy = _resolveDnsStrategy(
      strategy: 'prefer_ipv4',
      fallback: remoteDnsStrategy,
    );
    final String resolvedDirectStrategy = _resolveDnsStrategy(
      strategy: 'prefer_ipv4',
      fallback: directDnsStrategy,
    );

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
    final String resolvedRemoteAddress = _sanitizeDnsAddress(
      remoteAddress,
      fallback: _strictRemoteDns,
    );
    final String directAddress = useProviderPreset
        ? (hasExplicitDirectDns
              ? settings.dns.directDns
              : providerProfile.directDns)
        : (settings.dns.directDns.isNotEmpty
              ? settings.dns.directDns
              : _strictDirectDns);
    final String resolvedDirectAddress = _sanitizeDnsAddress(
      directAddress,
      fallback: _strictDirectDns,
      allowLocal: true,
    );
    final String dohFallbackAddress = settings.dns.dohFallbackDns.trim();
    final bool enableDohFallback =
        settings.dns.enableDohFallback &&
        _looksLikeDohAddress(resolvedRemoteAddress) &&
        dohFallbackAddress.isNotEmpty &&
        dohFallbackAddress.toLowerCase() != resolvedRemoteAddress.toLowerCase();
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
    final List<String> bootstrapDomains = _dedupeStrings(
      _collectBootstrapDomains(profile),
    );

    final List<Object?> rules = <Object?>[];
    if (directDomains.isNotEmpty) {
      rules.add(<String, Object?>{
        'domain_suffix': directDomains,
        'server': 'dns-direct',
      });
    }
    if (bootstrapDomains.isNotEmpty) {
      rules.add(<String, Object?>{
        'domain': bootstrapDomains,
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
    servers.add(<String, Object?>{'tag': 'dns-fakeip', 'address': 'fakeip'});
    rules.add(<String, Object?>{
      'query_type': const <String>['A'],
      'server': 'dns-fakeip',
    });

    servers.add(<String, Object?>{
      'tag': 'dns-remote',
      'address': resolvedRemoteAddress,
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
      'address': resolvedDirectAddress,
      'strategy': resolvedDirectStrategy,
    });

    final Map<String, Object?> dns = <String, Object?>{
      'servers': servers,
      'strategy': resolvedRemoteStrategy,
      'rules': rules,
      'final': preferDirectDohFallback ? 'dns-remote-fallback' : 'dns-remote',
      'independent_cache': true,
    };
    if (settings.dns.timeout != null) {
      dns['timeout'] = _formatDuration(settings.dns.timeout!);
    }
    dns['fakeip'] = <String, Object?>{
      'enabled': true,
      'inet4_range': _strictFakeIpInet4Range,
    };
    return dns;
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d';
    if (duration.inHours > 0) return '${duration.inHours}h';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m';
    return '${duration.inSeconds}s';
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

  String _sanitizeDnsAddress(
    String address, {
    required String fallback,
    bool allowLocal = false,
  }) {
    final String normalized = address.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    if (normalized.toLowerCase() == 'local') {
      if (allowLocal) {
        return 'local';
      }
      return fallback;
    }
    return normalized;
  }

  List<String> _collectBootstrapDomains(VpnProfile profile) {
    final Set<String> domains = <String>{};

    void addIfDomain(String? raw) => _addCandidateDomain(domains, raw);

    addIfDomain(profile.server);
    addIfDomain(profile.tls.serverName);
    addIfDomain(profile.websocketHeaders['Host']);
    addIfDomain(profile.websocketHeaders['host']);
    addIfDomain(profile.websocketHeaders[':authority']);
    addIfDomain(profile.websocketHeaders['authority']);

    _collectDomainsFromExtra(domains, profile.extra);

    return domains.toList(growable: false);
  }

  void _collectDomainsFromExtra(
    Set<String> domains,
    Map<String, Object?> extra,
  ) {
    const List<String> directHostKeys = <String>[
      'host',
      'sni',
      'server_name',
      'servername',
      'authority',
      'grpc_authority',
      '_sbmm_grpc_authority',
      'peer',
      'domain',
      'fallback_host',
      'address_resolver_domain',
    ];

    for (final String key in directHostKeys) {
      final Object? value = extra[key];
      if (value is String) {
        _addCandidateDomain(domains, value);
      } else if (value is List<dynamic>) {
        for (final dynamic item in value) {
          if (item is String) {
            _addCandidateDomain(domains, item);
          }
        }
      }
    }

    const List<String> headerContainerKeys = <String>[
      'headers',
      'ws_headers',
      'http_headers',
    ];
    for (final String key in headerContainerKeys) {
      final Object? raw = extra[key];
      if (raw is! Map<Object?, Object?>) {
        continue;
      }
      for (final MapEntry<Object?, Object?> entry in raw.entries) {
        if (entry.key is! String || entry.value is! String) {
          continue;
        }
        final String normalizedKey = (entry.key as String).toLowerCase();
        if (normalizedKey == 'host' ||
            normalizedKey == ':authority' ||
            normalizedKey == 'authority') {
          _addCandidateDomain(domains, entry.value as String);
        }
      }
    }
  }

  void _addCandidateDomain(Set<String> output, String? raw) {
    final String value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return;
    }

    for (final String candidate in value.split(',')) {
      final String normalized = candidate.trim();
      if (normalized.isEmpty) {
        continue;
      }

      String host = normalized;
      if (host.contains('://')) {
        final Uri? uri = Uri.tryParse(host);
        if (uri != null && uri.host.isNotEmpty) {
          host = uri.host.trim();
        }
      }
      if (host.contains('@')) {
        host = host.split('@').last.trim();
      }
      if (host.contains(':') && !host.contains(']')) {
        host = host.split(':').first.trim();
      }
      if (host.contains('/')) {
        host = host.split('/').first.trim();
      }
      if (host.contains('?')) {
        host = host.split('?').first.trim();
      }
      if (host.startsWith('[') && host.endsWith(']') && host.length > 2) {
        host = host.substring(1, host.length - 1);
      }
      if (host.startsWith('"') && host.endsWith('"') && host.length > 2) {
        host = host.substring(1, host.length - 1).trim();
      }

      if (host.isEmpty || _isIpLiteral(host)) {
        continue;
      }
      output.add(host.toLowerCase());
    }
  }

  bool _isIpLiteral(String value) {
    final String host = value.trim();
    if (host.isEmpty) {
      return false;
    }
    final RegExp ipv4Pattern = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
    if (ipv4Pattern.hasMatch(host)) {
      return true;
    }
    if (host.contains(':')) {
      return true;
    }
    return false;
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
