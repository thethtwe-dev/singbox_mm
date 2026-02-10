part of '../vpn_subscription_parser.dart';

class _SubscriptionEntriesResult {
  const _SubscriptionEntriesResult({
    required this.entries,
    required this.profiles,
    required this.failures,
  });

  final List<ParsedVpnConfig> entries;
  final List<VpnProfile> profiles;
  final List<SubscriptionParseFailure> failures;
}

_SubscriptionEntriesResult _parseSubscriptionEntries(
  VpnSubscriptionParser subscriptionParser,
  String payload, {
  required bool deduplicate,
  String? sbmmPassphrase,
}) {
  final List<ParsedVpnConfig> entries = <ParsedVpnConfig>[];
  final List<VpnProfile> profiles = <VpnProfile>[];
  final List<SubscriptionParseFailure> failures = <SubscriptionParseFailure>[];
  final Set<String> dedupeKeys = <String>{};

  for (final String line in const LineSplitter().convert(payload)) {
    final String entry = line.trim();
    if (entry.isEmpty || entry.startsWith('#')) {
      continue;
    }

    try {
      final ParsedVpnConfig parsed = subscriptionParser._parser.parse(
        entry,
        sbmmPassphrase: sbmmPassphrase,
      );
      final String dedupeKey = VpnSubscriptionParser._buildDedupeKey(
        parsed.profile,
      );
      if (deduplicate && dedupeKeys.contains(dedupeKey)) {
        continue;
      }
      dedupeKeys.add(dedupeKey);
      entries.add(parsed);
      profiles.add(parsed.profile);
    } on FormatException catch (error) {
      failures.add(
        SubscriptionParseFailure(entry: entry, reason: error.message),
      );
    }
  }

  return _SubscriptionEntriesResult(
    entries: entries,
    profiles: profiles,
    failures: failures,
  );
}

String _buildSubscriptionDedupeKey(VpnProfile profile) {
  final List<String> extraKeys = profile.extra.keys.toList(growable: false)
    ..sort();
  final String extraFingerprint = extraKeys
      .map((String key) => '$key=${profile.extra[key]}')
      .join(';');

  return '${profile.protocol.wireValue}|${profile.server}|${profile.serverPort}|${profile.uuid ?? ''}|${profile.password ?? ''}|${profile.method ?? ''}|${profile.transport.wireValue}|$extraFingerprint';
}
