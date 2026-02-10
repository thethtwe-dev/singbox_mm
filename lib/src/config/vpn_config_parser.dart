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

    final List<String> parsedAlpn = _splitCsv(
      _firstValue(query, const <String>['alpn']),
    );

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
      alpn: parsedAlpn.isEmpty ? const <String>['h2', 'http/1.1'] : parsedAlpn,
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

    final String padded = _normalizeBase64Padding(normalized);
    try {
      return utf8.decode(base64.decode(padded));
    } on FormatException {
      try {
        return utf8.decode(base64Url.decode(padded));
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
