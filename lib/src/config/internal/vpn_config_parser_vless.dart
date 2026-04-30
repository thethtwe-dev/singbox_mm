part of '../vpn_config_parser.dart';

_ParseOutput _parseVlessConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: 'vless');
  parser._assertAddress(uri, scheme: 'vless');

  final Map<String, String> query = parser.applyDownloadSettingsOverrides(
    parser._normalizeQuery(uri),
  );
  final _ResolvedEndpoint endpoint = parser._resolveEndpoint(
    uri,
    query,
    scheme: 'vless',
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

  final String uuid = VpnConfigParser._requireNonEmpty(
    Uri.decodeComponent(uri.userInfo),
    'vless uuid',
  );
  final Map<String, String> transportHeaders = parser._extractTransportHeaders(
    query,
  );
  final String? wsHost = VpnConfigParser._firstNonEmpty(<String?>[
    transportHeaders['Host'],
    parser._extractWsHost(query),
  ]);

  final Map<String, Object?> extra = parser._buildVlessExtra(query);
  parser._attachTransportAlias(
    extra,
    rawTransport,
    forceAlias: promoteHttpUpgrade ? 'xhttp' : null,
  );

  final VpnProfile profile = VpnProfile.vless(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'vless'),
    server: endpoint.host,
    serverPort: endpoint.port,
    uuid: uuid,
    flow: VpnConfigParser._firstValue(query, const <String>['flow']),
    transport: transport,
    websocketPath: parser._extractWsPath(query),
    websocketHeaders: transportHeaders,
    grpcServiceName: parser._extractGrpcServiceName(query),
    maxEarlyData: parser._extractWsMaxEarlyData(query),
    earlyDataHeaderName: parser._extractWsEarlyDataHeaderName(query),
    tls: parser._buildTlsOptions(
      query,
      fallbackServerName: wsHost ?? endpoint.host,
      defaultEnabled: false,
      defaultAlpn: parser._defaultAlpnForTransport(transport),
    ),
    extra: extra,
  );

  VpnConfigParser._collectUnknownFields(
    query,
    knownKeys: const <String>{
      'type', 'net', 'security', 'sni', 'fp', 'pbk', 'sid', 'spx', 'flow',
      'path', 'host', 'serviceName', 'mode', 'extra', 'alpn', 'allowInsecure',
      'headerType', 'quicSecurity', 'key', 'seed', 'header', 'uTLS',
      'downloadsettings', 'download_settings', 'core', 'packet_encoding',
      'packetencoding', 'packetaddr', 'packet-addr', 'packet_addr',
      'xhttpmode', 'xhttp_mode', 'aid', 'alterid',
    },
    warnings: warnings,
  );

  return _ParseOutput(profile, warnings: warnings);
}
