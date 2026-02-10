part of '../singbox_mm_client.dart';

SingboxConfigDocument _parseConfigDocumentInternal(String configJson) {
  return SingboxConfigDocument.fromJson(configJson);
}

List<SingboxEndpointSummary> _extractConfigEndpointsInternal(
  SignboxVpn client,
  String configJson,
) {
  final SingboxConfigDocument document = client.parseConfigDocument(configJson);
  return document.endpointSummaries();
}

Future<void> _applyConfigDocumentInternal(
  SignboxVpn client,
  SingboxConfigDocument document,
) {
  return client.setRawConfig(document.toMap());
}

ParsedVpnSubscription _parseSubscriptionInternal(
  SignboxVpn client,
  String rawSubscription, {
  required String source,
  required bool tryBase64Decode,
  required bool deduplicate,
  required String? sbmmPassphrase,
}) {
  return client._subscriptionParser.parse(
    rawSubscription,
    source: source,
    tryBase64Decode: tryBase64Decode,
    deduplicate: deduplicate,
    sbmmPassphrase: sbmmPassphrase,
  );
}

List<VpnProfileSummary> _extractSubscriptionSummariesInternal(
  SignboxVpn client,
  String rawSubscription, {
  required String source,
  required bool tryBase64Decode,
  required bool deduplicate,
  required String? sbmmPassphrase,
}) {
  final ParsedVpnSubscription parsed = client.parseSubscription(
    rawSubscription,
    source: source,
    tryBase64Decode: tryBase64Decode,
    deduplicate: deduplicate,
    sbmmPassphrase: sbmmPassphrase,
  );

  return List<VpnProfileSummary>.generate(parsed.entries.length, (int index) {
    final ParsedVpnConfig entry = parsed.entries[index];
    return client.summarizeProfile(
      entry.profile,
      index: index,
      warnings: entry.warnings,
    );
  }, growable: false);
}
