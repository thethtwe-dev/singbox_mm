import 'dart:convert';

import '../models/vpn_profile.dart';
import 'sbmm_secure_link_codec.dart';
part 'internal/vpn_config_parser_hysteria.dart';
part 'internal/vpn_config_parser_sbmm.dart';
part 'internal/vpn_config_parser_ssh.dart';
part 'internal/vpn_config_parser_shadowsocks.dart';
part 'internal/vpn_config_parser_trojan.dart';
part 'internal/vpn_config_parser_tuic.dart';
part 'internal/vpn_config_parser_vless.dart';
part 'internal/vpn_config_parser_vmess.dart';
part 'internal/vpn_config_parser_wireguard.dart';
part 'internal/vpn_config_parser_wireguard_quick.dart';

class ParsedVpnConfig {
  const ParsedVpnConfig({
    required this.profile,
    required this.scheme,
    required this.rawConfig,
    this.warnings = const <String>[],
  });

  final VpnProfile profile;
  final String scheme;
  final String rawConfig;
  final List<String> warnings;
}

class VpnConfigParser {
  const VpnConfigParser();

  static const String _transportAliasExtraKey = '_sbmm_transport_alias';

  static const Set<String> supportedSchemes = <String>{
    'sbmm',
    'vless',
    'vmess',
    'ss',
    'shadowsocks',
    'trojan',
    'hysteria',
    'hysteria2',
    'hy2',
    'tuic',
    'wireguard',
    'wg',
    'ssh',
  };

  bool canParse(String rawConfig) {
    if (_looksLikeWireGuardQuick(rawConfig)) {
      return true;
    }
    final String? scheme = _extractScheme(rawConfig);
    return scheme != null && supportedSchemes.contains(scheme);
  }

  ParsedVpnConfig parse(
    String rawConfig, {
    String? fallbackTag,
    String? sbmmPassphrase,
  }) {
    final String trimmed = rawConfig.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Config link is empty.');
    }

    final _ParseOutput? wireGuardQuick = _tryParseWireGuardQuick(
      trimmed,
      fallbackTag: fallbackTag,
    );
    if (wireGuardQuick != null) {
      return ParsedVpnConfig(
        profile: wireGuardQuick.profile,
        scheme: 'wireguard',
        rawConfig: trimmed,
        warnings: wireGuardQuick.warnings,
      );
    }

    final String? scheme = _extractScheme(trimmed);
    if (scheme == null || !supportedSchemes.contains(scheme)) {
      throw FormatException('Unsupported config scheme in "$trimmed".');
    }

    if (scheme == 'sbmm') {
      return _parseSbmm(
        trimmed,
        fallbackTag: fallbackTag,
        sbmmPassphrase: sbmmPassphrase,
      );
    }

    final _ParseOutput output;
    switch (scheme) {
      case 'vless':
        output = _parseVless(trimmed, fallbackTag: fallbackTag);
        break;
      case 'vmess':
        output = _parseVmess(trimmed, fallbackTag: fallbackTag);
        break;
      case 'ss':
      case 'shadowsocks':
        output = _parseShadowsocks(trimmed, fallbackTag: fallbackTag);
        break;
      case 'trojan':
        output = _parseTrojan(trimmed, fallbackTag: fallbackTag);
        break;
      case 'hysteria':
      case 'hysteria2':
      case 'hy2':
        output = _parseHysteria2(
          trimmed,
          fallbackTag: fallbackTag,
          scheme: scheme,
        );
        break;
      case 'tuic':
        output = _parseTuic(trimmed, fallbackTag: fallbackTag);
        break;
      case 'wireguard':
      case 'wg':
        output = _parseWireGuard(
          trimmed,
          scheme: scheme,
          fallbackTag: fallbackTag,
        );
        break;
      case 'ssh':
        output = _parseSsh(trimmed, fallbackTag: fallbackTag);
        break;
      default:
        throw FormatException('Unsupported config scheme "$scheme".');
    }

    return ParsedVpnConfig(
      profile: output.profile,
      scheme: scheme,
      rawConfig: trimmed,
      warnings: output.warnings,
    );
  }

  ParsedVpnConfig _parseSbmm(
    String raw, {
    String? fallbackTag,
    String? sbmmPassphrase,
  }) => _parseSbmmConfig(
    this,
    raw,
    fallbackTag: fallbackTag,
    sbmmPassphrase: sbmmPassphrase,
  );

  _ParseOutput _parseVless(String raw, {String? fallbackTag}) =>
      _parseVlessConfig(this, raw, fallbackTag: fallbackTag);

  _ParseOutput _parseTrojan(String raw, {String? fallbackTag}) =>
      _parseTrojanConfig(this, raw, fallbackTag: fallbackTag);

  _ParseOutput _parseVmess(String raw, {String? fallbackTag}) =>
      _parseVmessConfig(this, raw, fallbackTag: fallbackTag);

  _ParseOutput? _tryParseVmessJson(String raw, {String? fallbackTag}) =>
      _tryParseVmessJsonConfig(this, raw, fallbackTag: fallbackTag);

  _ParseOutput _parseShadowsocks(String raw, {String? fallbackTag}) =>
      _parseShadowsocksConfig(this, raw, fallbackTag: fallbackTag);

  _ParseOutput _parseHysteria2(
    String raw, {
    required String scheme,
    String? fallbackTag,
  }) => _parseHysteria2Config(
    this,
    raw,
    scheme: scheme,
    fallbackTag: fallbackTag,
  );

  _ParseOutput _parseTuic(String raw, {String? fallbackTag}) =>
      _parseTuicConfig(this, raw, fallbackTag: fallbackTag);

  _ParseOutput _parseWireGuard(
    String raw, {
    required String scheme,
    String? fallbackTag,
  }) => _parseWireGuardConfig(
    this,
    raw,
    scheme: scheme,
    fallbackTag: fallbackTag,
  );

  _ParseOutput? _tryParseWireGuardQuick(String raw, {String? fallbackTag}) =>
      _tryParseWireGuardQuickConfig(this, raw, fallbackTag: fallbackTag);

  bool _looksLikeWireGuardQuick(String raw) =>
      _looksLikeWireGuardQuickConfig(raw);

  _ParseOutput _parseSsh(String raw, {String? fallbackTag}) =>
      _parseSshConfig(this, raw, fallbackTag: fallbackTag);

  _LegacyShadowsocks _parseLegacyShadowsocks(String raw) =>
      _parseLegacyShadowsocksConfig(this, raw);

  _SsCredentials _parseShadowsocksCredentials(
    String encoded, {
    bool allowBase64 = true,
  }) => _parseShadowsocksCredentialsConfig(
    this,
    encoded,
    allowBase64: allowBase64,
  );

  Uri _parseUri(String raw, {required String? expectedScheme}) {
    final Uri uri;
    try {
      uri = Uri.parse(raw);
    } on FormatException catch (error) {
      throw FormatException('Invalid URI: ${error.message}');
    }

    if (expectedScheme != null && uri.scheme.toLowerCase() != expectedScheme) {
      throw FormatException(
        'Expected $expectedScheme:// scheme, got ${uri.scheme}://.',
      );
    }
    return uri;
  }

  void _assertAddress(Uri uri, {required String scheme}) {
    if (uri.host.isEmpty || uri.port <= 0) {
      throw FormatException('$scheme link is missing host/port.');
    }
  }

  static String? _extractScheme(String value) {
    final Match? match = RegExp(
      r'^([a-zA-Z0-9+.-]+)://',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    return match.group(1)?.toLowerCase();
  }

  Map<String, String> _normalizeQuery(Uri uri) {
    final Map<String, String> output = <String, String>{};
    uri.queryParametersAll.forEach((String key, List<String> values) {
      if (values.isEmpty) {
        return;
      }
      final String value = values.last;
      output[key.toLowerCase()] = value;
    });
    return output;
  }

  /// Applies `extra.downloadSettings` overrides onto normalized query params.
  ///
  /// Exposed as a stable non-private wrapper so internal parser refactors
  /// cannot break member resolution during incremental builds.
  Map<String, String> applyDownloadSettingsOverrides(
    Map<String, String> query,
  ) => _applyDownloadSettingsOverrides(query);

  Map<String, String> _applyDownloadSettingsOverrides(
    Map<String, String> query,
  ) {
    if (query.isEmpty) {
      return query;
    }

    final Map<String, Object?> extra = _extractExtraMap(query);
    final Map<String, Object?> downloadSettings = _extractDownloadSettingsMap(
      query,
      extra: extra,
    );
    if (downloadSettings.isEmpty) {
      return query;
    }

    final Map<String, String> merged = Map<String, String>.from(query);

    void setIfPresent(String key, String? value) {
      if (value == null) {
        return;
      }
      final String normalized = value.trim();
      if (normalized.isEmpty) {
        return;
      }
      merged[key.toLowerCase()] = normalized;
    }

    final String? networkHint = _firstNonEmpty(<String?>[
      _stringFromDynamic(downloadSettings['network']),
      _stringFromDynamic(downloadSettings['transport']),
    ]);
    if (networkHint != null) {
      setIfPresent('type', networkHint);
      setIfPresent('net', networkHint);
    }

    setIfPresent('security', _stringFromDynamic(downloadSettings['security']));
    setIfPresent('sni', _stringFromDynamic(downloadSettings['serverName']));
    setIfPresent('sni', _stringFromDynamic(downloadSettings['server_name']));
    setIfPresent(
      '_sbmm_download_address',
      _firstNonEmpty(<String?>[
        _stringFromDynamic(downloadSettings['address']),
        _stringFromDynamic(downloadSettings['server']),
        _stringFromDynamic(downloadSettings['host']),
      ]),
    );
    setIfPresent(
      '_sbmm_download_port',
      _normalizePortValue(downloadSettings['port']),
    );

    final Map<String, Object?> xhttpSettings = _asObjectMap(
      downloadSettings['xhttpSettings'] ?? downloadSettings['xhttp_settings'],
    );
    if (xhttpSettings.isNotEmpty) {
      setIfPresent('path', _stringFromDynamic(xhttpSettings['path']));
      setIfPresent(
        'host',
        _firstNonEmpty(<String?>[
          _stringFromDynamic(xhttpSettings['host']),
          _stringFromDynamic(xhttpSettings['authority']),
          _stringFromDynamic(xhttpSettings[':authority']),
        ]),
      );

      final String? mode = _stringFromDynamic(xhttpSettings['mode']);
      setIfPresent('mode', mode);
      setIfPresent('xhttpmode', mode);
      setIfPresent('xhttp_mode', mode);
    }

    final Map<String, Object?> grpcSettings = _asObjectMap(
      downloadSettings['grpcSettings'] ?? downloadSettings['grpc_settings'],
    );
    if (grpcSettings.isNotEmpty) {
      setIfPresent(
        'servicename',
        _firstNonEmpty(<String?>[
          _stringFromDynamic(grpcSettings['serviceName']),
          _stringFromDynamic(grpcSettings['service_name']),
          _stringFromDynamic(grpcSettings['service']),
        ]),
      );
      setIfPresent(
        'authority',
        _firstNonEmpty(<String?>[
          _stringFromDynamic(grpcSettings['authority']),
          _stringFromDynamic(grpcSettings['host']),
          _stringFromDynamic(grpcSettings[':authority']),
        ]),
      );
      setIfPresent(
        'mode',
        _firstNonEmpty(<String?>[
          _stringFromDynamic(grpcSettings['mode']),
          _stringFromDynamic(grpcSettings['multiMode']),
          _stringFromDynamic(grpcSettings['multi_mode']),
        ]),
      );
    }

    final Map<String, Object?> tlsSettings = _asObjectMap(
      downloadSettings['tlsSettings'] ?? downloadSettings['tls_settings'],
    );
    if (tlsSettings.isNotEmpty) {
      setIfPresent(
        'sni',
        _firstNonEmpty(<String?>[
          _stringFromDynamic(tlsSettings['serverName']),
          _stringFromDynamic(tlsSettings['server_name']),
        ]),
      );
      setIfPresent(
        'fp',
        _firstNonEmpty(<String?>[
          _stringFromDynamic(tlsSettings['fingerprint']),
          _stringFromDynamic(tlsSettings['utlsFingerprint']),
          _stringFromDynamic(tlsSettings['utls_fingerprint']),
        ]),
      );

      final String? allowInsecure = _boolToQueryValue(
        tlsSettings['allowInsecure'] ??
            tlsSettings['allow_insecure'] ??
            tlsSettings['insecure'],
      );
      if (allowInsecure != null) {
        setIfPresent('allowinsecure', allowInsecure);
        setIfPresent('insecure', allowInsecure);
      }

      final String? alpn = _coerceAlpnCsv(tlsSettings['alpn']);
      if (alpn != null) {
        setIfPresent('alpn', alpn);
      }
    }

    return merged;
  }

  String? _normalizePortValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      final int port = value.toInt();
      if (port <= 0 || port > 65535) {
        return null;
      }
      return '$port';
    }
    if (value is String) {
      final int? port = int.tryParse(value.trim());
      if (port == null || port <= 0 || port > 65535) {
        return null;
      }
      return '$port';
    }
    return null;
  }

  _ResolvedEndpoint _resolveEndpoint(
    Uri uri,
    Map<String, String> query, {
    required String scheme,
  }) {
    String host = uri.host.trim();
    int port = uri.port;

    final String? overrideHost = _firstValue(query, const <String>[
      '_sbmm_download_address',
    ]);
    if (overrideHost != null && overrideHost.trim().isNotEmpty) {
      host = overrideHost.trim();
    }

    final int? overridePort = _parseInt(
      _firstValue(query, const <String>['_sbmm_download_port']),
    );
    if (overridePort != null && overridePort > 0 && overridePort <= 65535) {
      port = overridePort;
    }

    if (host.isEmpty || port <= 0) {
      throw FormatException('$scheme link is missing host/port.');
    }
    return _ResolvedEndpoint(host: host, port: port);
  }

  _ResolvedEndpoint _resolveEndpointFromBase(
    String host,
    int port,
    Map<String, String> query, {
    required String scheme,
  }) {
    String resolvedHost = host.trim();
    int resolvedPort = port;

    final String? overrideHost = _firstValue(query, const <String>[
      '_sbmm_download_address',
    ]);
    if (overrideHost != null && overrideHost.trim().isNotEmpty) {
      resolvedHost = overrideHost.trim();
    }

    final int? overridePort = _parseInt(
      _firstValue(query, const <String>['_sbmm_download_port']),
    );
    if (overridePort != null && overridePort > 0 && overridePort <= 65535) {
      resolvedPort = overridePort;
    }

    if (resolvedHost.isEmpty || resolvedPort <= 0) {
      throw FormatException('$scheme link is missing host/port.');
    }
    return _ResolvedEndpoint(host: resolvedHost, port: resolvedPort);
  }

  String? _extractWsPath(Map<String, String> query) {
    final String? raw = _firstValue(query, const <String>[
      'path',
      'ws-path',
      'ws_path',
    ]);
    if (raw == null) {
      return null;
    }
    return _sanitizeWsPath(raw);
  }

  String _sanitizeWsPath(String raw) {
    String path = raw.trim();
    if (path.isEmpty) {
      return '/';
    }
    path = path.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    path = path.replaceFirst(RegExp(r'^/+'), '/');

    final int queryIndex = path.indexOf('?');
    if (queryIndex < 0) {
      return path;
    }

    final String basePath = queryIndex == 0
        ? '/'
        : path.substring(0, queryIndex);
    final String rawQuery = path.substring(queryIndex + 1);
    if (rawQuery.isEmpty) {
      return basePath;
    }

    final List<String> keptPairs = <String>[];
    for (final String pair in rawQuery.split('&')) {
      final String trimmedPair = pair.trim();
      if (trimmedPair.isEmpty) {
        continue;
      }
      final int split = trimmedPair.indexOf('=');
      final String keyRaw = split < 0
          ? trimmedPair
          : trimmedPair.substring(0, split);
      final String key = _tryDecodeComponent(keyRaw)?.trim() ?? '';
      if (key.isEmpty) {
        continue;
      }
      final String lowered = key.toLowerCase();
      if (lowered == 'ed' || lowered == 'eh') {
        continue;
      }
      keptPairs.add(trimmedPair);
    }
    if (keptPairs.isEmpty) {
      return basePath;
    }
    return '$basePath?${keptPairs.join('&')}';
  }

  String? _extractWsHost(Map<String, String> query) {
    final String? direct = _firstValue(query, const <String>[
      'host',
      'ws-host',
      'ws_host',
      'authority',
      ':authority',
    ]);
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final String? headersRaw = _firstValue(query, const <String>[
      'headers',
      'ws_headers',
      'ws-headers',
      'http_headers',
      'http-headers',
    ]);
    if (headersRaw == null || headersRaw.trim().isEmpty) {
      final String? sniFallback = _firstValue(query, const <String>[
        'sni',
        'servername',
        'server_name',
      ]);
      if (sniFallback != null && sniFallback.trim().isNotEmpty) {
        return sniFallback.trim();
      }
      return null;
    }

    final String? fromMap = _extractHostFromHeaderMap(
      _tryJsonDecode(headersRaw),
    );
    if (fromMap != null) {
      return fromMap;
    }

    final String relaxed = headersRaw.replaceAll("'", '"');
    if (relaxed != headersRaw) {
      final String? relaxedMap = _extractHostFromHeaderMap(
        _tryJsonDecode(relaxed),
      );
      if (relaxedMap != null) {
        return relaxedMap;
      }
    }

    final String? fromPairs = _extractHostFromHeaderPairs(headersRaw);
    if (fromPairs != null) {
      return fromPairs;
    }

    if (relaxed != headersRaw) {
      final String? relaxedPairs = _extractHostFromHeaderPairs(relaxed);
      if (relaxedPairs != null) {
        return relaxedPairs;
      }
    }
    final String? sniFallback = _firstValue(query, const <String>[
      'sni',
      'servername',
      'server_name',
    ]);
    if (sniFallback != null && sniFallback.trim().isNotEmpty) {
      return sniFallback.trim();
    }
    return null;
  }

  Map<String, String> _extractTransportHeaders(Map<String, String> query) {
    final Map<String, String> headers = <String, String>{};

    void mergeHeaders(Map<String, String> source) {
      source.forEach((String rawKey, String rawValue) {
        final String key = _normalizeHeaderName(rawKey);
        final String value = _trimHeaderToken(rawValue);
        if (key.isEmpty || value.isEmpty) {
          return;
        }
        headers[key] = value;
      });
    }

    final String? inlineHeadersRaw = _firstValue(query, const <String>[
      'headers',
      'ws_headers',
      'ws-headers',
      'http_headers',
      'http-headers',
    ]);
    if (inlineHeadersRaw != null) {
      mergeHeaders(_parseHeadersFromRaw(inlineHeadersRaw));
    }

    final Map<String, Object?> extra = _extractExtraMap(query);
    mergeHeaders(_extractHeaderMap(extra['headers']));

    final Map<String, Object?> downloadSettings = _extractDownloadSettingsMap(
      query,
      extra: extra,
    );
    mergeHeaders(_extractHeaderMap(downloadSettings['headers']));

    final Map<String, Object?> xhttpSettings = _asObjectMap(
      downloadSettings['xhttpSettings'] ?? downloadSettings['xhttp_settings'],
    );
    mergeHeaders(_extractHeaderMap(xhttpSettings['headers']));

    final Map<String, Object?> xhttpExtra = _asObjectMap(
      xhttpSettings['extra'],
    );
    mergeHeaders(_extractHeaderMap(xhttpExtra['headers']));

    final String? xhttpHost = _firstNonEmpty(<String?>[
      _stringFromDynamic(xhttpSettings['host']),
      _stringFromDynamic(xhttpSettings['authority']),
      _stringFromDynamic(xhttpSettings[':authority']),
    ]);
    if (xhttpHost != null) {
      headers['Host'] = xhttpHost;
    }

    final String? resolvedHost = _firstNonEmpty(<String?>[
      _firstValue(query, const <String>[
        'host',
        'ws-host',
        'ws_host',
        'authority',
        ':authority',
      ]),
      headers['Host'],
      headers['host'],
      headers[':authority'],
      headers['authority'],
      _firstValue(query, const <String>['sni', 'servername', 'server_name']),
    ]);
    if (resolvedHost != null) {
      headers['Host'] = resolvedHost;
    }

    return headers;
  }

  String? _extractGrpcServiceName(Map<String, String> query) {
    final String? direct = _firstValue(query, const <String>[
      'servicename',
      'service_name',
      'grpc-service-name',
      'grpc_service_name',
      'grpcservicename',
      'grpc_service',
      'grpcservice',
    ]);
    if (direct != null && direct.trim().isNotEmpty) {
      return _normalizeGrpcServiceName(direct);
    }

    final String? fromPath = _extractWsPath(query);
    if (fromPath == null || fromPath.isEmpty || fromPath == '/') {
      return null;
    }
    return _normalizeGrpcServiceName(fromPath);
  }

  String? _extractGrpcAuthority(Map<String, String> query) {
    final String? direct = _firstValue(query, const <String>[
      'authority',
      ':authority',
      'grpc_authority',
      'grpcauthority',
      'grpc-authority',
      'host',
    ]);
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final Map<String, String> headers = _extractTransportHeaders(query);
    return _firstNonEmpty(<String?>[
      headers[':authority'],
      headers['authority'],
      headers['Host'],
      headers['host'],
    ]);
  }

  String? _extractGrpcMode(Map<String, String> query) {
    final String? mode = _firstValue(query, const <String>[
      'mode',
      'grpc_mode',
      'grpcmode',
      'grpc-mode',
    ]);
    if (mode == null) {
      return null;
    }
    final String normalized = mode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized != 'gun' && normalized != 'multi') {
      return null;
    }
    return normalized;
  }

  String _normalizeGrpcServiceName(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'grpc';
    }
    final String withoutPrefix = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return withoutPrefix.isEmpty ? 'grpc' : withoutPrefix;
  }

  List<String> _defaultAlpnForTransport(VpnTransport transport) {
    switch (transport) {
      case VpnTransport.grpc:
        return const <String>['h2'];
      case VpnTransport.ws:
      case VpnTransport.httpUpgrade:
        return const <String>['http/1.1'];
      case VpnTransport.tcp:
      case VpnTransport.quic:
      case VpnTransport.http:
        return const <String>['h2', 'http/1.1'];
    }
  }

  int _extractWsMaxEarlyData(Map<String, String> query) {
    final int? explicit = _parseInt(
      _firstValue(query, const <String>[
        'max_early_data',
        'maxearlydata',
        'max-early-data',
        'ed',
      ]),
    );
    if (explicit == null || explicit < 0) {
      return 0;
    }
    return explicit;
  }

  String? _extractWsEarlyDataHeaderName(Map<String, String> query) {
    final String? header = _firstValue(query, const <String>[
      'early_data_header_name',
      'early-data-header-name',
      'eh',
    ]);
    if (header == null) {
      return null;
    }
    final String normalized = header.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _extractHostFromHeaderMap(dynamic decoded) {
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }
    for (final MapEntry<Object?, Object?> entry in decoded.entries) {
      final String key = entry.key?.toString().trim().toLowerCase() ?? '';
      if (key == 'host' || key == ':authority' || key == 'authority') {
        final String value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  String? _extractHostFromHeaderPairs(String raw) {
    for (final String segment in raw.split(RegExp(r'[,;{}]'))) {
      final String line = segment.trim();
      if (line.isEmpty) {
        continue;
      }

      final int colon = line.indexOf(':');
      final int equals = line.indexOf('=');
      int split = -1;
      if (colon >= 0 && equals >= 0) {
        split = colon < equals ? colon : equals;
      } else if (colon >= 0) {
        split = colon;
      } else if (equals >= 0) {
        split = equals;
      }
      if (split <= 0 || split == line.length - 1) {
        continue;
      }

      final String key = _trimHeaderToken(
        line.substring(0, split),
      ).toLowerCase();
      if (key != 'host' && key != ':authority' && key != 'authority') {
        continue;
      }

      final String value = _trimHeaderToken(line.substring(split + 1));
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String _trimHeaderToken(String value) {
    String normalized = value.trim();
    while (normalized.length >= 2 &&
        ((normalized.startsWith('"') && normalized.endsWith('"')) ||
            (normalized.startsWith("'") && normalized.endsWith("'")))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    return normalized;
  }

  Map<String, String> _parseRawQuery(String rawQuery) {
    if (rawQuery.isEmpty) {
      return const <String, String>{};
    }
    final Map<String, String> output = <String, String>{};
    final List<String> pairs = rawQuery.split('&');
    for (final String pair in pairs) {
      if (pair.isEmpty) {
        continue;
      }
      final int split = pair.indexOf('=');
      if (split < 0) {
        final String key = pair.toLowerCase();
        output[_tryDecodeComponent(key) ?? key] = '';
        continue;
      }
      final String key = pair.substring(0, split).toLowerCase();
      final String value = pair.substring(split + 1);
      output[_tryDecodeComponent(key) ?? key] =
          _tryDecodeComponent(value) ?? value;
    }
    return output;
  }

  VpnTransport _parseTransport(String? value, {List<String>? warnings}) {
    final String normalized = value?.trim().toLowerCase() ?? 'tcp';
    switch (normalized) {
      case '':
      case 'tcp':
        return VpnTransport.tcp;
      case 'ws':
      case 'websocket':
        return VpnTransport.ws;
      case 'grpc':
        return VpnTransport.grpc;
      case 'quic':
        return VpnTransport.quic;
      case 'xhttp':
        // xray-style xhttp links are represented as sing-box `http`
        // transport and normalized further by SingboxConfigBuilder.
        warnings?.add(
          'xhttp transport detected; normalized to sing-box http transport.',
        );
        return VpnTransport.http;
      case 'h2':
      case 'http2':
      case 'http':
        return VpnTransport.http;
      case 'httpupgrade':
      case 'http-upgrade':
        return VpnTransport.httpUpgrade;
      case 'splithttp':
        warnings?.add(
          'splithttp transport detected; promoted to sing-box http (xhttp) transport.',
        );
        return VpnTransport.http;
      default:
        warnings?.add('Unsupported transport "$value", fallback to tcp.');
        return VpnTransport.tcp;
    }
  }

  String? _normalizeTransportAlias(String? value) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'xhttp') {
      return 'xhttp';
    }
    if (normalized == 'httpupgrade' || normalized == 'http-upgrade') {
      return 'httpupgrade';
    }
    return null;
  }

  void _attachTransportAlias(
    Map<String, Object?> extra,
    String? rawTransport, {
    String? forceAlias,
  }) {
    final String? alias =
        _normalizeTransportAlias(forceAlias) ??
        _normalizeTransportAlias(rawTransport);
    if (alias == null) {
      return;
    }
    extra[_transportAliasExtraKey] = alias;
  }

  bool _shouldPromoteHttpUpgradeToXhttp({
    required String? rawTransport,
    required Map<String, String> query,
  }) {
    final String normalizedTransport = rawTransport?.trim().toLowerCase() ?? '';
    if (normalizedTransport == 'xhttp') {
      return false;
    }
    if (normalizedTransport != 'httpupgrade' &&
        normalizedTransport != 'http-upgrade') {
      return false;
    }

    final String? coreHint = _firstValue(query, const <String>['core']);
    if (coreHint != null && coreHint.trim().toLowerCase() == 'xray') {
      return true;
    }

    if (_containsH2OrH3(_firstValue(query, const <String>['alpn']))) {
      return true;
    }

    final Map<String, Object?> extra = _extractExtraMap(query);
    final Map<String, Object?> downloadSettings = _extractDownloadSettingsMap(
      query,
      extra: extra,
    );
    if (_hasXhttpHints(extra) || _hasXhttpHints(downloadSettings)) {
      return true;
    }

    final String? xhttpModeHint = _firstValue(query, const <String>[
      'xhttpmode',
      'xhttp_mode',
    ]);
    if (xhttpModeHint != null && xhttpModeHint.trim().isNotEmpty) {
      return true;
    }

    final String? modeHint = _firstValue(query, const <String>['mode']);
    if (modeHint != null) {
      final String normalizedMode = modeHint.trim().toLowerCase();
      if (normalizedMode == 'xhttp' ||
          normalizedMode == 'splithttp' ||
          normalizedMode == 'auto' ||
          normalizedMode == 'stream-up' ||
          normalizedMode == 'stream-one' ||
          normalizedMode == 'packet-up' ||
          normalizedMode == 'packet' ||
          normalizedMode == 'packet-conn' ||
          normalizedMode == 'packet-stat') {
        return true;
      }
    }

    if (query.containsKey('packetaddr') ||
        query.containsKey('packet-addr') ||
        query.containsKey('packet_addr')) {
      return true;
    }

    return false;
  }

  TlsOptions _buildTlsOptions(
    Map<String, String> query, {
    required String fallbackServerName,
    required bool defaultEnabled,
    List<String> defaultAlpn = const <String>['h2', 'http/1.1'],
  }) {
    final String? security = _firstValue(query, const <String>[
      'security',
      'tls',
    ])?.toLowerCase();

    bool enabled = defaultEnabled;
    if (security == 'none' || security == '0' || security == 'false') {
      enabled = false;
    } else if (security == 'tls' ||
        security == 'reality' ||
        security == '1' ||
        security == 'true') {
      enabled = true;
    }

    if (!enabled) {
      return const TlsOptions(enabled: false);
    }

    final String? rawAlpn = _firstValue(query, const <String>['alpn']);
    final String normalizedAlpn = rawAlpn?.trim().toLowerCase() ?? '';
    final bool explicitEmptyAlpn =
        normalizedAlpn == 'none' ||
        normalizedAlpn == 'empty' ||
        normalizedAlpn == 'off' ||
        normalizedAlpn == 'false' ||
        normalizedAlpn == '0';
    final List<String> parsedAlpn = explicitEmptyAlpn
        ? const <String>[]
        : _splitCsv(rawAlpn);

    return TlsOptions(
      enabled: true,
      serverName:
          _firstValue(query, const <String>[
            'sni',
            'servername',
            'server_name',
          ]) ??
          fallbackServerName,
      allowInsecure:
          _parseBool(
            _firstValue(query, const <String>['allowinsecure', 'insecure']),
            fallback: false,
          ) ??
          false,
      utlsFingerprint:
          _firstValue(query, const <String>['fp', 'fingerprint', 'utls']) ??
          'chrome',
      realityPublicKey: _firstValue(query, const <String>[
        'pbk',
        'publickey',
        'public_key',
        'public-key',
      ]),
      realityShortId: _firstValue(query, const <String>[
        'sid',
        'shortid',
        'short_id',
        'short-id',
      ]),
      realitySpiderX: _firstValue(query, const <String>[
        'spx',
        'spiderx',
        'spider_x',
        'spider-x',
      ]),
      alpn: explicitEmptyAlpn
          ? const <String>[]
          : (parsedAlpn.isEmpty ? defaultAlpn : parsedAlpn),
    );
  }

  Map<String, Object?> _buildVlessExtra(Map<String, String> query) {
    final Map<String, Object?> extra = <String, Object?>{};
    final String? packetEncoding = _firstValue(query, const <String>[
      'packetencoding',
      'packet_encoding',
    ]);
    if (packetEncoding != null && packetEncoding.isNotEmpty) {
      extra['packet_encoding'] = packetEncoding;
    }
    final String? grpcAuthority = _extractGrpcAuthority(query);
    if (grpcAuthority != null && grpcAuthority.isNotEmpty) {
      extra['_sbmm_grpc_authority'] = grpcAuthority;
    }
    final String? grpcMode = _extractGrpcMode(query);
    if (grpcMode != null) {
      extra['_sbmm_grpc_mode'] = grpcMode;
    }

    return extra;
  }

  Map<String, Object?> _buildTrojanExtra(Map<String, String> query) {
    final Map<String, Object?> extra = <String, Object?>{};
    final String? packetEncoding = _firstValue(query, const <String>[
      'packetencoding',
      'packet_encoding',
    ]);
    if (packetEncoding != null && packetEncoding.isNotEmpty) {
      extra['packet_encoding'] = packetEncoding;
    }
    final String? grpcAuthority = _extractGrpcAuthority(query);
    if (grpcAuthority != null && grpcAuthority.isNotEmpty) {
      extra['_sbmm_grpc_authority'] = grpcAuthority;
    }
    final String? grpcMode = _extractGrpcMode(query);
    if (grpcMode != null) {
      extra['_sbmm_grpc_mode'] = grpcMode;
    }
    return extra;
  }

  Map<String, Object?> _buildVmessExtra(
    Map<String, String> query, {
    int? alterId,
    String? cipher,
  }) {
    final Map<String, Object?> extra = <String, Object?>{};
    final int? queryAlterId = _parseInt(
      _firstValue(query, const <String>['aid', 'alterid']),
    );
    final int? finalAlterId = alterId ?? queryAlterId;
    if (finalAlterId != null && finalAlterId >= 0) {
      extra['alter_id'] = finalAlterId;
    }

    final String? security =
        cipher ??
        _firstValue(query, const <String>['scy', 'cipher', 'security']);
    if (security != null &&
        security.isNotEmpty &&
        security.toLowerCase() != 'tls' &&
        security.toLowerCase() != 'reality' &&
        security.toLowerCase() != 'none') {
      extra['security'] = security;
    }

    final String? grpcAuthority = _extractGrpcAuthority(query);
    if (grpcAuthority != null && grpcAuthority.isNotEmpty) {
      extra['_sbmm_grpc_authority'] = grpcAuthority;
    }
    final String? grpcMode = _extractGrpcMode(query);
    if (grpcMode != null) {
      extra['_sbmm_grpc_mode'] = grpcMode;
    }

    return extra;
  }

  Map<String, Object?> _buildShadowsocksExtra(Map<String, String> query) {
    final Map<String, Object?> extra = <String, Object?>{};
    final String? plugin = _firstValue(query, const <String>['plugin']);
    if (plugin != null && plugin.isNotEmpty) {
      extra['plugin'] = plugin;
    }
    final String? grpcAuthority = _extractGrpcAuthority(query);
    if (grpcAuthority != null && grpcAuthority.isNotEmpty) {
      extra['_sbmm_grpc_authority'] = grpcAuthority;
    }
    final String? grpcMode = _extractGrpcMode(query);
    if (grpcMode != null) {
      extra['_sbmm_grpc_mode'] = grpcMode;
    }
    return extra;
  }

  String _resolveTag(Uri uri, {required String scheme, String? fallbackTag}) {
    return _buildTag(
      explicitTag: uri.fragment.isEmpty
          ? null
          : _tryDecodeComponent(uri.fragment),
      fallbackTag: fallbackTag,
      scheme: scheme,
      host: uri.host,
    );
  }

  String _buildTag({
    required String scheme,
    required String host,
    String? explicitTag,
    String? fallbackTag,
  }) {
    final String? candidate = _firstNonEmpty(<String?>[
      explicitTag,
      fallbackTag,
    ]);
    if (candidate != null) {
      return candidate;
    }
    final String suffix = host.isEmpty ? 'node' : host;
    return '$scheme-$suffix';
  }

  static String? _firstValue(Map<String, String> map, List<String> keys) {
    for (final String key in keys) {
      final String? value = map[key.toLowerCase()];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String _normalizeHeaderName(String rawKey) {
    final String key = rawKey.trim();
    final String lowered = key.toLowerCase();
    if (lowered == 'host' ||
        lowered == ':authority' ||
        lowered == 'authority') {
      return 'Host';
    }
    if (lowered == 'user-agent') {
      return 'User-Agent';
    }
    return key;
  }

  static String? _stringFromDynamic(Object? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static Map<String, Object?> _asObjectMap(Object? decoded) {
    if (decoded is! Map<Object?, Object?>) {
      return const <String, Object?>{};
    }
    final Map<String, Object?> result = <String, Object?>{};
    decoded.forEach((Object? key, Object? value) {
      if (key is String) {
        result[key] = value;
      }
    });
    return result;
  }

  static Map<String, String> _coerceStringMap(Object? decoded) {
    if (decoded is! Map<Object?, Object?>) {
      return const <String, String>{};
    }
    final Map<String, String> output = <String, String>{};
    decoded.forEach((Object? key, Object? value) {
      final String keyText = _stringFromDynamic(key) ?? '';
      final String valueText = _stringFromDynamic(value) ?? '';
      if (keyText.isEmpty || valueText.isEmpty) {
        return;
      }
      output[_normalizeHeaderName(keyText)] = _trimHeaderToken(valueText);
    });
    return output;
  }

  Map<String, String> _extractHeaderMap(Object? value) {
    if (value == null) {
      return const <String, String>{};
    }
    if (value is String) {
      return _parseHeadersFromRaw(value);
    }
    return _coerceStringMap(value);
  }

  Map<String, String> _parseHeadersFromRaw(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const <String, String>{};
    }

    final Map<String, String> fromJson = _coerceStringMap(
      _tryJsonDecode(trimmed),
    );
    if (fromJson.isNotEmpty) {
      return fromJson;
    }
    final String relaxed = trimmed.replaceAll("'", '"');
    if (relaxed != trimmed) {
      final Map<String, String> relaxedJson = _coerceStringMap(
        _tryJsonDecode(relaxed),
      );
      if (relaxedJson.isNotEmpty) {
        return relaxedJson;
      }
    }

    final String pairSource = trimmed.replaceAll(
      RegExp(r'^[{\s]+|[}\s]+$'),
      '',
    );
    final Map<String, String> pairs = <String, String>{};
    for (final String segment in pairSource.split(RegExp(r'[;,]'))) {
      final String line = segment.trim();
      if (line.isEmpty) {
        continue;
      }
      final int colon = line.indexOf(':');
      final int equals = line.indexOf('=');
      int split = -1;
      if (colon >= 0 && equals >= 0) {
        split = colon < equals ? colon : equals;
      } else if (colon >= 0) {
        split = colon;
      } else if (equals >= 0) {
        split = equals;
      }
      if (split <= 0 || split == line.length - 1) {
        continue;
      }
      final String key = _normalizeHeaderName(
        _trimHeaderToken(line.substring(0, split)),
      );
      final String value = _trimHeaderToken(line.substring(split + 1));
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      pairs[key] = value;
    }
    return pairs;
  }

  Map<String, Object?> _extractExtraMap(Map<String, String> query) {
    final String? raw = _firstValue(query, const <String>['extra']);
    if (raw == null || raw.trim().isEmpty) {
      return const <String, Object?>{};
    }
    final dynamic decoded =
        _tryJsonDecode(raw) ?? _tryJsonDecode(raw.replaceAll("'", '"'));
    return _asObjectMap(decoded);
  }

  Map<String, Object?> _extractDownloadSettingsMap(
    Map<String, String> query, {
    Map<String, Object?>? extra,
  }) {
    final Map<String, Object?> fromExtra = _asObjectMap(
      (extra ?? const <String, Object?>{})['downloadSettings'] ??
          (extra ?? const <String, Object?>{})['download_settings'],
    );
    if (fromExtra.isNotEmpty) {
      return fromExtra;
    }

    final String? raw = _firstValue(query, const <String>[
      'downloadsettings',
      'download_settings',
    ]);
    if (raw == null || raw.trim().isEmpty) {
      return const <String, Object?>{};
    }
    final dynamic decoded =
        _tryJsonDecode(raw) ?? _tryJsonDecode(raw.replaceAll("'", '"'));
    return _asObjectMap(decoded);
  }

  static bool _containsH2OrH3(String? rawAlpn) {
    for (final String value in _splitCsv(rawAlpn)) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'h2' ||
          normalized == 'http2' ||
          normalized == 'http/2' ||
          normalized == 'h3' ||
          normalized.startsWith('h3-')) {
        return true;
      }
    }
    return false;
  }

  static bool _hasXhttpHints(Map<String, Object?> source) {
    if (source.isEmpty) {
      return false;
    }

    final String? network = _firstNonEmpty(<String?>[
      _stringFromDynamic(source['network']),
      _stringFromDynamic(source['transport']),
    ]);
    if (network != null) {
      final String normalized = network.toLowerCase();
      if (normalized == 'xhttp' || normalized == 'splithttp') {
        return true;
      }
    }

    if (source.containsKey('xhttpSettings') ||
        source.containsKey('xhttp_settings')) {
      return true;
    }

    final Map<String, Object?> nested = _asObjectMap(
      source['downloadSettings'],
    );
    if (nested.isNotEmpty && _hasXhttpHints(nested)) {
      return true;
    }

    return false;
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final String? value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _requireNonEmpty(String? value, String label) {
    if (value == null || value.isEmpty) {
      throw FormatException('$label is required.');
    }
    return value;
  }

  static int? _parseInt(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  static bool? _parseBool(String? value, {required bool? fallback}) {
    if (value == null || value.isEmpty) {
      return fallback;
    }
    switch (value.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        return fallback;
    }
  }

  String? _boolToQueryValue(Object? value) {
    if (value is bool) {
      return value ? '1' : '0';
    }
    if (value is num) {
      return value != 0 ? '1' : '0';
    }
    if (value is String) {
      final bool? parsed = _parseBool(value, fallback: null);
      if (parsed != null) {
        return parsed ? '1' : '0';
      }
    }
    return null;
  }

  String? _coerceAlpnCsv(Object? value) {
    if (value == null) {
      return null;
    }

    final List<String> tokens = <String>[];

    void addToken(String raw) {
      for (final String item in _splitCsv(raw)) {
        final String normalized = item.trim();
        if (normalized.isEmpty || tokens.contains(normalized)) {
          continue;
        }
        tokens.add(normalized);
      }
    }

    if (value is String) {
      addToken(value);
    } else if (value is List<Object?>) {
      for (final Object? item in value) {
        if (item == null) {
          continue;
        }
        addToken(item.toString());
      }
    }

    if (tokens.isEmpty) {
      return null;
    }
    return tokens.join(',');
  }

  static List<String> _splitCsv(String? value) {
    if (value == null || value.isEmpty) {
      return const <String>[];
    }
    return value
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _decodeBase64(String encoded) {
    final String normalized = encoded.replaceAll('\n', '').trim();
    if (normalized.isEmpty) {
      return null;
    }

    // Try standard base64 first (after normalizing URL-safe chars).
    final String padded = _normalizeBase64Padding(normalized);
    try {
      return utf8.decode(base64.decode(padded));
    } on FormatException {
      // Fall back to URL-safe base64 using the original (pre-normalized)
      // string so that '-' and '_' chars are preserved for base64Url.
      try {
        return utf8.decode(base64Url.decode(normalized));
      } on FormatException {
        return null;
      }
    }
  }

  static String _normalizeBase64Padding(String input) {
    final String normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final int remainder = normalized.length % 4;
    if (remainder == 0) {
      return normalized;
    }
    return normalized.padRight(normalized.length + (4 - remainder), '=');
  }

  static dynamic _tryJsonDecode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  static String? _tryDecodeComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
  }

  static String? _stringFromMap(Map<String, Object?> map, List<String> keys) {
    for (final String key in keys) {
      final Object? value = map[key.toLowerCase()];
      if (value == null) {
        continue;
      }
      final String text = value.toString();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static int? _intFromMap(Map<String, Object?> map, List<String> keys) {
    final String? value = _stringFromMap(map, keys);
    return _parseInt(value);
  }

  static void _collectUnknownFields(
    Map<String, String> query, {
    required Set<String> knownKeys,
    required List<String> warnings,
  }) {
    query.forEach((String key, String value) {
      if (key.startsWith('_sbmm_')) {
        return;
      }
      if (!knownKeys.contains(key.toLowerCase())) {
        warnings.add('Unknown parameter found: "$key"');
      }
    });
  }
}

class _ParseOutput {
  const _ParseOutput(this.profile, {this.warnings = const <String>[]});

  final VpnProfile profile;
  final List<String> warnings;
}

class _ResolvedEndpoint {
  const _ResolvedEndpoint({required this.host, required this.port});

  final String host;
  final int port;
}

class _SsCredentials {
  const _SsCredentials({required this.method, required this.password});

  final String method;
  final String password;
}

class _LegacyShadowsocks {
  const _LegacyShadowsocks({
    required this.host,
    required this.port,
    required this.method,
    required this.password,
    required this.query,
    this.tag,
  });

  final String host;
  final int port;
  final String method;
  final String password;
  final String? tag;
  final Map<String, String> query;
}
