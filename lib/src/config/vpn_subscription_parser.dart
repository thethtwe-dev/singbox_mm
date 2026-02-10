import 'dart:convert';

import '../models/vpn_profile.dart';
import 'vpn_config_parser.dart';
part 'internal/vpn_subscription_parser_entries.dart';
part 'internal/vpn_subscription_parser_payload.dart';

class SubscriptionParseFailure {
  const SubscriptionParseFailure({required this.entry, required this.reason});

  final String entry;
  final String reason;
}

class ParsedVpnSubscription {
  const ParsedVpnSubscription({
    required this.source,
    required this.profiles,
    required this.entries,
    required this.failures,
    required this.decodedFromBase64,
  });

  final String source;
  final List<VpnProfile> profiles;
  final List<ParsedVpnConfig> entries;
  final List<SubscriptionParseFailure> failures;
  final bool decodedFromBase64;
}

class VpnSubscriptionParser {
  const VpnSubscriptionParser({
    VpnConfigParser parser = const VpnConfigParser(),
  }) : _parser = parser;

  final VpnConfigParser _parser;

  ParsedVpnSubscription parse(
    String rawSubscription, {
    String source = 'inline',
    bool tryBase64Decode = true,
    bool deduplicate = true,
    String? sbmmPassphrase,
  }) {
    final String normalized = rawSubscription.trim();
    if (normalized.isEmpty) {
      return ParsedVpnSubscription(
        source: source,
        profiles: <VpnProfile>[],
        entries: <ParsedVpnConfig>[],
        failures: <SubscriptionParseFailure>[],
        decodedFromBase64: false,
      );
    }

    final _SubscriptionPayload payload = _resolveSubscriptionPayload(
      normalized,
      tryBase64Decode: tryBase64Decode,
    );
    final _SubscriptionEntriesResult parsedEntries = _parseSubscriptionEntries(
      this,
      payload.payload,
      deduplicate: deduplicate,
      sbmmPassphrase: sbmmPassphrase,
    );

    return ParsedVpnSubscription(
      source: source,
      profiles: List<VpnProfile>.unmodifiable(parsedEntries.profiles),
      entries: List<ParsedVpnConfig>.unmodifiable(parsedEntries.entries),
      failures: List<SubscriptionParseFailure>.unmodifiable(
        parsedEntries.failures,
      ),
      decodedFromBase64: payload.decodedFromBase64,
    );
  }

  static bool _containsUriScheme(String value) {
    return _containsSubscriptionUriScheme(value);
  }

  static String _buildDedupeKey(VpnProfile profile) {
    return _buildSubscriptionDedupeKey(profile);
  }

  static String? _decodeBase64(String encoded) {
    return _decodeSubscriptionBase64(encoded);
  }
}
