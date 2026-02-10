part of '../vpn_config_parser.dart';

_ParseOutput _parseShadowsocksConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: null);
  final String scheme = uri.scheme.toLowerCase();
  if (scheme != 'ss' && scheme != 'shadowsocks') {
    throw FormatException('Expected ss:// scheme, got ${uri.scheme}://.');
  }

  final _LegacyShadowsocks parsed;
  if (uri.host.isEmpty || uri.port <= 0) {
    parsed = parser._parseLegacyShadowsocks(raw);
  } else {
    if (uri.userInfo.isEmpty) {
      throw const FormatException(
        'shadowsocks link is missing credentials in userinfo.',
      );
    }
    final _SsCredentials credentials = parser._parseShadowsocksCredentials(
      Uri.decodeComponent(uri.userInfo),
    );
    parsed = _LegacyShadowsocks(
      host: uri.host,
      port: uri.port,
      method: credentials.method,
      password: credentials.password,
      query: parser._normalizeQuery(uri),
      tag: uri.fragment.isEmpty
          ? null
          : VpnConfigParser._tryDecodeComponent(uri.fragment),
    );
  }

  final Map<String, String> query = parsed.query;
  final List<String> warnings = <String>[];
  final VpnTransport transport = parser._parseTransport(
    VpnConfigParser._firstValue(query, const <String>['type', 'net']),
    warnings: warnings,
  );
  final String? wsHost = VpnConfigParser._firstValue(query, const <String>[
    'host',
  ]);

  final VpnProfile profile = VpnProfile.shadowsocks(
    tag: parser._buildTag(
      explicitTag: parsed.tag,
      fallbackTag: fallbackTag,
      scheme: 'ss',
      host: parsed.host,
    ),
    server: parsed.host,
    serverPort: parsed.port,
    method: parsed.method,
    password: parsed.password,
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
      fallbackServerName: parsed.host,
      defaultEnabled: false,
    ),
    extra: parser._buildShadowsocksExtra(query),
  );

  return _ParseOutput(profile, warnings: warnings);
}

_LegacyShadowsocks _parseLegacyShadowsocksConfig(
  VpnConfigParser parser,
  String raw,
) {
  final String trimmed = raw.trim();
  final String? scheme = VpnConfigParser._extractScheme(trimmed);
  if (scheme != 'ss' && scheme != 'shadowsocks') {
    throw FormatException(
      'Expected ss:// scheme, got "${scheme ?? 'unknown'}".',
    );
  }

  final int schemeSplit = trimmed.indexOf('://');
  String payload = trimmed.substring(schemeSplit + 3);

  String? tag;
  final int fragmentIndex = payload.indexOf('#');
  if (fragmentIndex >= 0) {
    tag = VpnConfigParser._tryDecodeComponent(
      payload.substring(fragmentIndex + 1),
    );
    payload = payload.substring(0, fragmentIndex);
  }

  String queryRaw = '';
  final int queryIndex = payload.indexOf('?');
  if (queryIndex >= 0) {
    queryRaw = payload.substring(queryIndex + 1);
    payload = payload.substring(0, queryIndex);
  }

  String authority = payload.trim();
  if (authority.startsWith('//')) {
    authority = authority.substring(2);
  }
  if (authority.isEmpty) {
    throw const FormatException('shadowsocks link payload is empty.');
  }

  final String candidate =
      VpnConfigParser._decodeBase64(authority) ?? authority;
  final int atIndex = candidate.lastIndexOf('@');
  if (atIndex <= 0 || atIndex == candidate.length - 1) {
    throw const FormatException(
      'Invalid shadowsocks legacy link; expected method:pass@host:port.',
    );
  }

  final _SsCredentials credentials = parser._parseShadowsocksCredentials(
    candidate.substring(0, atIndex),
    allowBase64: true,
  );

  final String destination = candidate.substring(atIndex + 1);
  final _HostPort hostPort = _parseHostPort(destination);

  return _LegacyShadowsocks(
    host: hostPort.host,
    port: hostPort.port,
    method: credentials.method,
    password: credentials.password,
    query: parser._parseRawQuery(queryRaw),
    tag: tag,
  );
}

_SsCredentials _parseShadowsocksCredentialsConfig(
  VpnConfigParser parser,
  String encoded, {
  bool allowBase64 = true,
}) {
  final String source = encoded.trim();
  if (source.isEmpty) {
    throw const FormatException('shadowsocks credentials are missing.');
  }

  final String normalized =
      VpnConfigParser._tryDecodeComponent(source) ?? source;
  final _SsCredentials? direct = _tryParseSsCredentials(normalized);
  if (direct != null) {
    return direct;
  }

  if (allowBase64) {
    final String? decoded = VpnConfigParser._decodeBase64(normalized);
    if (decoded != null) {
      final _SsCredentials? parsedDecoded = _tryParseSsCredentials(decoded);
      if (parsedDecoded != null) {
        return parsedDecoded;
      }
    }
  }

  throw const FormatException(
    'Invalid shadowsocks credentials; expected method:password.',
  );
}

_SsCredentials? _tryParseSsCredentials(String value) {
  final int separator = value.indexOf(':');
  if (separator <= 0 || separator == value.length - 1) {
    return null;
  }

  final String method = value.substring(0, separator).trim();
  final String password = value.substring(separator + 1).trim();
  if (method.isEmpty || password.isEmpty) {
    return null;
  }

  return _SsCredentials(method: method, password: password);
}

_HostPort _parseHostPort(String value) {
  final String server = value.trim();
  if (server.isEmpty) {
    throw const FormatException('shadowsocks destination is empty.');
  }

  late final String host;
  late final String portText;
  if (server.startsWith('[')) {
    final int endBracket = server.indexOf(']');
    if (endBracket < 0 || endBracket + 2 > server.length) {
      throw const FormatException('Invalid IPv6 host in shadowsocks link.');
    }
    if (server[endBracket + 1] != ':') {
      throw const FormatException('shadowsocks host is missing port.');
    }
    host = server.substring(1, endBracket);
    portText = server.substring(endBracket + 2);
  } else {
    final int split = server.lastIndexOf(':');
    if (split <= 0 || split == server.length - 1) {
      throw const FormatException('shadowsocks host is missing port.');
    }
    host = server.substring(0, split);
    portText = server.substring(split + 1);
  }

  final int? port = int.tryParse(portText);
  if (host.isEmpty || port == null || port <= 0) {
    throw const FormatException('Invalid shadowsocks host/port.');
  }
  return _HostPort(host: host, port: port);
}

class _HostPort {
  const _HostPort({required this.host, required this.port});

  final String host;
  final int port;
}
