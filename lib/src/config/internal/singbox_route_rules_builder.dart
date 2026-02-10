import '../../models/bypass_policy.dart';
import '../../models/singbox_feature_settings.dart';

class SingboxRouteRulesBuilder {
  const SingboxRouteRulesBuilder();

  List<Object?> build({
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
      'ip_cidr': const <String>['172.19.0.2/32', 'fdfe:dcba:9876::2/128'],
      'port': 53,
      'outbound': 'dns-out',
    });
    rules.add(<String, Object?>{
      'ip_cidr': const <String>['172.19.0.2/32', 'fdfe:dcba:9876::2/128'],
      'port': 853,
      'outbound': 'dns-out',
    });

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
}
