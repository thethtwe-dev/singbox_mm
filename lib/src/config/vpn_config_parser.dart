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
      if (pair.isEmpty) {
        continue;
      }
      final int split = pair.indexOf('=');
      final String keyRaw = split < 0 ? pair : pair.substring(0, split);
      final String valueRaw = split < 0 ? '' : pair.substring(split + 1);
      final String key = _tryDecodeComponent(keyRaw)?.trim() ?? '';
      if (key.isEmpty) {
        continue;
      }
      final String lowered = key.toLowerCase();
      if (lowered == 'ed' || lowered == 'eh') {
        continue;
      }

      final String value = (_tryDecodeComponent(valueRaw) ?? valueRaw).trim();
      keptPairs.add(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
      );
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
      return _extractHostFromHeaderPairs(relaxed);
    }
    return null;
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

  String _trimHeaderToken(String value) {
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
      case 'http':
      case 'httpupgrade':
      case 'http-upgrade':
      case 'h2':
        return VpnTransport.httpUpgrade;
      default:
        warnings?.add('Unsupported transport "$value", fallback to tcp.');
        return VpnTransport.tcp;
    }
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
      ]),
      realityShortId: _firstValue(query, const <String>[
        'sid',
        'shortid',
        'short_id',
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

    return extra;
  }

  Map<String, Object?> _buildShadowsocksExtra(Map<String, String> query) {
    final Map<String, Object?> extra = <String, Object?>{};
    final String? plugin = _firstValue(query, const <String>['plugin']);
    if (plugin != null && plugin.isNotEmpty) {
      extra['plugin'] = plugin;
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
}

class _ParseOutput {
  const _ParseOutput(this.profile, {this.warnings = const <String>[]});

  final VpnProfile profile;
  final List<String> warnings;
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
