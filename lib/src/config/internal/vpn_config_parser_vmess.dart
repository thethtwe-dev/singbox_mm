part of '../vpn_config_parser.dart';

_ParseOutput _parseVmessConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final _ParseOutput? vmessJsonResult = parser._tryParseVmessJson(
    raw,
    fallbackTag: fallbackTag,
  );
  if (vmessJsonResult != null) {
    return vmessJsonResult;
  }

  final Uri uri = parser._parseUri(raw, expectedScheme: 'vmess');
  parser._assertAddress(uri, scheme: 'vmess');

  final Map<String, String> query = parser.applyDownloadSettingsOverrides(
    parser._normalizeQuery(uri),
  );
  final _ResolvedEndpoint endpoint = parser._resolveEndpoint(
    uri,
    query,
    scheme: 'vmess',
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

  final Map<String, String> transportHeaders = parser._extractTransportHeaders(
    query,
  );
  final String? wsHost = VpnConfigParser._firstNonEmpty(<String?>[
    transportHeaders['Host'],
    parser._extractWsHost(query),
  ]);
  final String uuid = VpnConfigParser._requireNonEmpty(
    Uri.decodeComponent(uri.userInfo),
    'vmess uuid',
  );

  final Map<String, Object?> extra = parser._buildVmessExtra(query);
  parser._attachTransportAlias(
    extra,
    rawTransport,
    forceAlias: promoteHttpUpgrade ? 'xhttp' : null,
  );

  final VpnProfile profile = VpnProfile.vmess(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'vmess'),
    server: endpoint.host,
    serverPort: endpoint.port,
    uuid: uuid,
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

_ParseOutput? _tryParseVmessJsonConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final String payloadWithTag = raw.substring('vmess://'.length);
  final int fragmentIndex = payloadWithTag.indexOf('#');
  final String payload = fragmentIndex >= 0
      ? payloadWithTag.substring(0, fragmentIndex)
      : payloadWithTag;

  final String? decodedPayload;
  if (payload.trimLeft().startsWith('{')) {
    decodedPayload = payload;
  } else {
    decodedPayload = VpnConfigParser._decodeBase64(payload.trim());
  }
  if (decodedPayload == null) {
    return null;
  }

  final dynamic decodedJson = VpnConfigParser._tryJsonDecode(decodedPayload);
  if (decodedJson is! Map<Object?, Object?>) {
    return null;
  }

  final Map<String, Object?> vmessMap = <String, Object?>{};
  decodedJson.forEach((Object? key, Object? value) {
    if (key != null) {
      vmessMap[key.toString().toLowerCase()] = value;
    }
  });

  final String? host = VpnConfigParser._stringFromMap(vmessMap, const <String>[
    'add',
    'address',
    'server',
    'host',
  ]);
  final int? port = VpnConfigParser._intFromMap(vmessMap, const <String>[
    'port',
  ]);
  final String? uuid = VpnConfigParser._stringFromMap(vmessMap, const <String>[
    'id',
    'uuid',
  ]);
  if (host == null ||
      host.isEmpty ||
      port == null ||
      port <= 0 ||
      uuid == null ||
      uuid.isEmpty) {
    return null;
  }

  final Map<String, String>
  query = parser.applyDownloadSettingsOverrides(<String, String>{
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['security']) !=
        null)
      'security': VpnConfigParser._stringFromMap(vmessMap, const <String>[
        'security',
      ])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['tls']) != null)
      'tls': VpnConfigParser._stringFromMap(vmessMap, const <String>['tls'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['sni']) != null)
      'sni': VpnConfigParser._stringFromMap(vmessMap, const <String>['sni'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['host']) !=
        null)
      'host': VpnConfigParser._stringFromMap(vmessMap, const <String>['host'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['path']) !=
        null)
      'path': VpnConfigParser._stringFromMap(vmessMap, const <String>['path'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>[
          'servicename',
        ]) !=
        null)
      'servicename': VpnConfigParser._stringFromMap(vmessMap, const <String>[
        'servicename',
      ])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['alpn']) !=
        null)
      'alpn': VpnConfigParser._stringFromMap(vmessMap, const <String>['alpn'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['mode']) !=
        null)
      'mode': VpnConfigParser._stringFromMap(vmessMap, const <String>['mode'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['dl']) != null)
      'dl': VpnConfigParser._stringFromMap(vmessMap, const <String>['dl'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>[
          'downloadsettings',
          'download_settings',
        ]) !=
        null)
      'downloadsettings': VpnConfigParser._stringFromMap(
        vmessMap,
        const <String>['downloadsettings', 'download_settings'],
      )!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>[
          'xhttpmode',
          'xhttp_mode',
        ]) !=
        null)
      'xhttpmode': VpnConfigParser._stringFromMap(vmessMap, const <String>[
        'xhttpmode',
        'xhttp_mode',
      ])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['fp']) != null)
      'fp': VpnConfigParser._stringFromMap(vmessMap, const <String>['fp'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>[
          'fingerprint',
        ]) !=
        null)
      'fingerprint': VpnConfigParser._stringFromMap(vmessMap, const <String>[
        'fingerprint',
      ])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['pbk']) != null)
      'pbk': VpnConfigParser._stringFromMap(vmessMap, const <String>['pbk'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['sid']) != null)
      'sid': VpnConfigParser._stringFromMap(vmessMap, const <String>['sid'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['spx']) != null)
      'spx': VpnConfigParser._stringFromMap(vmessMap, const <String>['spx'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>[
          'max_early_data',
        ]) !=
        null)
      'max_early_data': VpnConfigParser._stringFromMap(vmessMap, const <String>[
        'max_early_data',
      ])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['ed']) != null)
      'ed': VpnConfigParser._stringFromMap(vmessMap, const <String>['ed'])!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>[
          'early_data_header_name',
        ]) !=
        null)
      'early_data_header_name': VpnConfigParser._stringFromMap(
        vmessMap,
        const <String>['early_data_header_name'],
      )!,
    if (VpnConfigParser._stringFromMap(vmessMap, const <String>['eh']) != null)
      'eh': VpnConfigParser._stringFromMap(vmessMap, const <String>['eh'])!,
  });

  final List<String> warnings = <String>[];
  final String? rawTransport = VpnConfigParser._stringFromMap(
    vmessMap,
    const <String>['net', 'type'],
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

  final Map<String, String> transportHeaders = parser._extractTransportHeaders(
    query,
  );
  final _ResolvedEndpoint endpoint = parser._resolveEndpointFromBase(
    host,
    port,
    query,
    scheme: 'vmess',
  );
  final String? wsHost = VpnConfigParser._firstNonEmpty(<String?>[
    transportHeaders['Host'],
    parser._extractWsHost(query),
  ]);
  final String vmessTag = parser._buildTag(
    explicitTag: VpnConfigParser._stringFromMap(vmessMap, const <String>['ps']),
    fallbackTag: fallbackTag,
    scheme: 'vmess',
    host: endpoint.host,
  );

  final Map<String, Object?> extra = parser._buildVmessExtra(
    query,
    alterId: VpnConfigParser._intFromMap(vmessMap, const <String>['aid']),
    cipher: VpnConfigParser._stringFromMap(vmessMap, const <String>[
      'scy',
      'cipher',
    ]),
  );
  parser._attachTransportAlias(
    extra,
    rawTransport,
    forceAlias: promoteHttpUpgrade ? 'xhttp' : null,
  );

  final VpnProfile profile = VpnProfile.vmess(
    tag: vmessTag,
    server: endpoint.host,
    serverPort: endpoint.port,
    uuid: uuid,
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

  return _ParseOutput(profile, warnings: warnings);
}
