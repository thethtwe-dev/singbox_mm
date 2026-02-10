part of '../singbox_mm_client.dart';

extension SignboxVpnConfigApi on SignboxVpn {
  List<GfwPresetPack> listGfwPresetPacks() {
    return _listGfwPresetPacksInternal();
  }

  String wrapSecureConfigLink({
    required String configLink,
    required String passphrase,
    int pbkdf2Iterations = SbmmSecureLinkCodec.defaultPbkdf2Iterations,
  }) {
    return _wrapSecureConfigLinkInternal(
      configLink: configLink,
      passphrase: passphrase,
      pbkdf2Iterations: pbkdf2Iterations,
    );
  }

  String unwrapSecureConfigLink({
    required String sbmmLink,
    required String passphrase,
  }) {
    return _unwrapSecureConfigLinkInternal(
      sbmmLink: sbmmLink,
      passphrase: passphrase,
    );
  }

  ParsedVpnConfig parseConfigLink(
    String configLink, {
    String? fallbackTag,
    String? sbmmPassphrase,
  }) {
    return _parseConfigLinkInternal(
      this,
      configLink,
      fallbackTag: fallbackTag,
      sbmmPassphrase: sbmmPassphrase,
    );
  }

  VpnProfileSummary summarizeProfile(
    VpnProfile profile, {
    int index = 0,
    List<String> warnings = const <String>[],
  }) {
    return _summarizeProfileInternal(profile, index: index, warnings: warnings);
  }

  VpnProfileSummary extractConfigLinkSummary(
    String configLink, {
    String? fallbackTag,
    String? sbmmPassphrase,
  }) {
    return _extractConfigLinkSummaryInternal(
      this,
      configLink,
      fallbackTag: fallbackTag,
      sbmmPassphrase: sbmmPassphrase,
    );
  }

  Future<Map<String, Object?>> applyConfigLink({
    required String configLink,
    String? fallbackTag,
    String? sbmmPassphrase,
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings? featureSettings,
  }) async {
    return _applyConfigLinkInternal(
      this,
      configLink: configLink,
      fallbackTag: fallbackTag,
      sbmmPassphrase: sbmmPassphrase,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      featureSettings: featureSettings,
    );
  }

  SingboxConfigDocument parseConfigDocument(String configJson) {
    return _parseConfigDocumentInternal(configJson);
  }

  List<SingboxEndpointSummary> extractConfigEndpoints(String configJson) {
    return _extractConfigEndpointsInternal(this, configJson);
  }

  Future<void> applyConfigDocument(SingboxConfigDocument document) {
    return _applyConfigDocumentInternal(this, document);
  }
}
