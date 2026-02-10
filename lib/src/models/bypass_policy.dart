enum BypassPolicyPreset { balanced, aggressive, strict }

class BypassPolicy {
  const BypassPolicy({
    this.preset = BypassPolicyPreset.balanced,
    this.directDomains = const <String>[],
    this.directCidrs = const <String>[],
    this.blockedDomainKeywords = const <String>[
      'doubleclick',
      'adservice',
      'tracking',
    ],
    this.remoteDnsAddress = 'https://1.1.1.1/dns-query',
    this.bypassPrivateNetworks = true,
  });

  final BypassPolicyPreset preset;
  final List<String> directDomains;
  final List<String> directCidrs;
  final List<String> blockedDomainKeywords;
  final String remoteDnsAddress;
  final bool bypassPrivateNetworks;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'preset': preset.name,
      'directDomains': directDomains,
      'directCidrs': directCidrs,
      'blockedDomainKeywords': blockedDomainKeywords,
      'remoteDnsAddress': remoteDnsAddress,
      'bypassPrivateNetworks': bypassPrivateNetworks,
    };
  }
}
