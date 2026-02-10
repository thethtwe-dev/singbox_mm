part of '../vpn_config_parser.dart';

_ParseOutput _parseVlessConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: 'vless');
  parser._assertAddress(uri, scheme: 'vless');

  final Map<String, String> query = parser._normalizeQuery(uri);
  final List<String> warnings = <String>[];
  final VpnTransport transport = parser._parseTransport(
    VpnConfigParser._firstValue(query, const <String>['type', 'net']),
    warnings: warnings,
  );

  final String uuid = VpnConfigParser._requireNonEmpty(
    Uri.decodeComponent(uri.userInfo),
    'vless uuid',
  );
  final String? wsHost = VpnConfigParser._firstValue(query, const <String>[
    'host',
  ]);

  final VpnProfile profile = VpnProfile.vless(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'vless'),
    server: uri.host,
    serverPort: uri.port,
    uuid: uuid,
    flow: VpnConfigParser._firstValue(query, const <String>['flow']),
    transport: transport,
    websocketPath: VpnConfigParser._firstValue(query, const <String>['path']),
    websocketHeaders: wsHost == null
        ? const <String, String>{}
        : <String, String>{'Host': wsHost},
    grpcServiceName: VpnConfigParser._firstValue(query, const <String>[
      'servicename',
      'service_name',
    ]),
    tls: parser._buildTlsOptions(
      query,
      fallbackServerName: uri.host,
      defaultEnabled: false,
    ),
    extra: parser._buildVlessExtra(query),
  );

  return _ParseOutput(profile, warnings: warnings);
}
