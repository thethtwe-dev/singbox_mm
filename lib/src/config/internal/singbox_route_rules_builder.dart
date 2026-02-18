import '../../models/bypass_policy.dart';
import '../../models/singbox_feature_settings.dart';
import '../../models/vpn_profile.dart';

class SingboxRouteRulesBuilder {
  const SingboxRouteRulesBuilder();

  List<Object?> build({
    required VpnProfile profile,
    required BypassPolicy bypassPolicy,
    required SingboxFeatureSettings settings,
    required bool includeDnsRoutingRule,
  }) {
    final List<Object?> rules = <Object?>[];

    rules.add(<String, Object?>{
      'port': 53,
      'network': 'udp',
      'outbound': 'dns-out',
    });
    rules.add(<String, Object?>{
      'port': 53,
      'network': 'tcp',
      'outbound': 'dns-out',
    });
    rules.add(<String, Object?>{
      'port': 853,
      'network': 'tcp',
      'outbound': 'dns-out',
    });

    rules.add(<String, Object?>{
      'ip_cidr': const <String>['172.19.0.2/32'],
      'port': 53,
      'outbound': 'dns-out',
    });
    rules.add(<String, Object?>{
      'ip_cidr': const <String>['172.19.0.2/32'],
      'port': 853,
      'outbound': 'dns-out',
    });

    rules.add(<String, Object?>{
      'ip_cidr': const <String>['::/0'],
      'outbound': 'block',
    });
    if (!_usesUdpNativeTransport(profile)) {
      rules.add(<String, Object?>{
        'network': 'udp',
        'port': 443,
        'outbound': 'block',
      });
      rules.add(<String, Object?>{'protocol': 'quic', 'outbound': 'block'});
    }

    if (includeDnsRoutingRule) {
      rules.add(<String, Object?>{'protocol': 'dns', 'outbound': 'dns-out'});
    }

    final bool bypassPrivateNetworks =
        settings.route.bypassLan || bypassPolicy.bypassPrivateNetworks;
    if (bypassPrivateNetworks) {
      rules.add(<String, Object?>{'ip_is_private': true, 'outbound': 'direct'});
    }

    final List<String> directDomains = _dedupeStrings(<String>[
      ...bypassPolicy.directDomains,
      ...settings.route.regionDirectDomains,
    ]);
    if (directDomains.isNotEmpty) {
      rules.add(<String, Object?>{
        'domain_suffix': directDomains,
        'outbound': 'direct',
      });
    }

    final List<String> directCidrs = _dedupeStrings(<String>[
      ...bypassPolicy.directCidrs,
      ...settings.route.regionDirectCidrs,
    ]);
    if (directCidrs.isNotEmpty) {
      rules.add(<String, Object?>{
        'ip_cidr': directCidrs,
        'outbound': 'direct',
      });
    }

    if (settings.route.blockAdvertisements) {
      final List<String> blockedKeywords = _dedupeStrings(<String>[
        ...bypassPolicy.blockedDomainKeywords,
        ...settings.route.extraBlockedKeywords,
      ]);
      if (blockedKeywords.isNotEmpty) {
        rules.add(<String, Object?>{
          'domain_keyword': blockedKeywords,
          'outbound': 'block',
        });
      }
    }

    return rules;
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

  bool _usesUdpNativeTransport(VpnProfile profile) {
    if (profile.protocol == VpnProtocol.hysteria2 ||
        profile.protocol == VpnProtocol.tuic ||
        profile.protocol == VpnProtocol.wireguard) {
      return true;
    }
    return profile.transport == VpnTransport.quic;
  }
}
