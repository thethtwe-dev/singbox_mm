part of '../vpn_config_parser.dart';

_ParseOutput _parseTrojanConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: 'trojan');
  parser._assertAddress(uri, scheme: 'trojan');

  final Map<String, String> query = parser._normalizeQuery(uri);
  final List<String> warnings = <String>[];
  final String? rawTransport = VpnConfigParser._firstValue(
    query,
    const <String>['type', 'net'],
  );
  final VpnTransport transport = parser._parseTransport(
    rawTransport,
    warnings: warnings,
  );

  final String password = VpnConfigParser._requireNonEmpty(
    Uri.decodeComponent(uri.userInfo),
    'trojan password',
  );
  final String? wsHost = parser._extractWsHost(query);

  final Map<String, Object?> extra = parser._buildTrojanExtra(query);
  parser._attachTransportAlias(extra, rawTransport);

  final VpnProfile profile = VpnProfile.trojan(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'trojan'),
    server: uri.host,
    serverPort: uri.port,
    password: password,
    transport: transport,
    websocketPath: parser._extractWsPath(query),
    websocketHeaders: wsHost == null
        ? const <String, String>{}
        : <String, String>{'Host': wsHost},
    grpcServiceName: parser._extractGrpcServiceName(query),
    maxEarlyData: parser._extractWsMaxEarlyData(query),
    earlyDataHeaderName: parser._extractWsEarlyDataHeaderName(query),
    tls: parser._buildTlsOptions(
      query,
      fallbackServerName: wsHost ?? uri.host,
      defaultEnabled: true,
      defaultAlpn:
          transport == VpnTransport.ws || transport == VpnTransport.httpUpgrade
          ? const <String>['http/1.1']
          : const <String>['h2', 'http/1.1'],
    ),
    extra: extra,
  );

  return _ParseOutput(profile, warnings: warnings);
}
