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
  final VpnTransport transport = parser._parseTransport(
    VpnConfigParser._firstValue(query, const <String>['type', 'net']),
    warnings: warnings,
  );

  final String password = VpnConfigParser._requireNonEmpty(
    Uri.decodeComponent(uri.userInfo),
    'trojan password',
  );
  final String? wsHost = VpnConfigParser._firstValue(query, const <String>[
    'host',
  ]);

  final VpnProfile profile = VpnProfile.trojan(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'trojan'),
    server: uri.host,
    serverPort: uri.port,
    password: password,
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
      defaultEnabled: true,
    ),
    extra: parser._buildTrojanExtra(query),
  );

  return _ParseOutput(profile, warnings: warnings);
}
