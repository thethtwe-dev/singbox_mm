part of '../vpn_config_parser.dart';

_ParseOutput _parseTrojanConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: 'trojan');
  parser._assertAddress(uri, scheme: 'trojan');

  final Map<String, String> query = parser.applyDownloadSettingsOverrides(
    parser._normalizeQuery(uri),
  );
  final _ResolvedEndpoint endpoint = parser._resolveEndpoint(
    uri,
    query,
    scheme: 'trojan',
  );
  final List<String> warnings = <String>[];
  final String? rawTransport = VpnConfigParser._firstValue(
    query,
    const <String>['type', 'net'],
  );
  final VpnTransport parsedTransport = parser._parseTransport(
    rawTransport,
    warnings: warnings,
  );
  final bool promoteHttpUpgrade = parser._shouldPromoteHttpUpgradeToXhttp(
    rawTransport: rawTransport,
    query: query,
  );
  final VpnTransport transport = promoteHttpUpgrade
      ? VpnTransport.http
      : parsedTransport;
  if (promoteHttpUpgrade) {
    warnings.add(
      'Detected xhttp-style profile; promoted httpupgrade to sing-box http transport.',
    );
  }

  final String password = VpnConfigParser._requireNonEmpty(
    Uri.decodeComponent(uri.userInfo),
    'trojan password',
  );
  final Map<String, String> transportHeaders = parser._extractTransportHeaders(
    query,
  );
  final String? wsHost = VpnConfigParser._firstNonEmpty(<String?>[
    transportHeaders['Host'],
    parser._extractWsHost(query),
  ]);

  final Map<String, Object?> extra = parser._buildTrojanExtra(query);
  parser._attachTransportAlias(
    extra,
    rawTransport,
    forceAlias: promoteHttpUpgrade ? 'xhttp' : null,
  );

  final VpnProfile profile = VpnProfile.trojan(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'trojan'),
    server: endpoint.host,
    serverPort: endpoint.port,
    password: password,
    transport: transport,
    websocketPath: parser._extractWsPath(query),
    websocketHeaders: transportHeaders,
    grpcServiceName: parser._extractGrpcServiceName(query),
    maxEarlyData: parser._extractWsMaxEarlyData(query),
    earlyDataHeaderName: parser._extractWsEarlyDataHeaderName(query),
    tls: parser._buildTlsOptions(
      query,
      fallbackServerName: wsHost ?? endpoint.host,
      defaultEnabled: true,
      defaultAlpn: parser._defaultAlpnForTransport(transport),
    ),
    extra: extra,
  );

  return _ParseOutput(profile, warnings: warnings);
}
