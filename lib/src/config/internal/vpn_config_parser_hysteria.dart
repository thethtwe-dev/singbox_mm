part of '../vpn_config_parser.dart';

_ParseOutput _parseHysteria2Config(
  VpnConfigParser parser,
  String raw, {
  required String scheme,
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: null);
  final String normalizedScheme = uri.scheme.toLowerCase();
  if (normalizedScheme != 'hysteria' &&
      normalizedScheme != 'hysteria2' &&
      normalizedScheme != 'hy2') {
    throw FormatException('Expected hysteria:// scheme, got ${uri.scheme}://.');
  }
  parser._assertAddress(uri, scheme: scheme);

  final Map<String, String> query = parser._normalizeQuery(uri);
  final String? decodedUserInfo = uri.userInfo.isEmpty
      ? null
      : Uri.decodeComponent(uri.userInfo);
  final String? password = VpnConfigParser._firstNonEmpty(<String?>[
    decodedUserInfo,
    VpnConfigParser._firstValue(query, const <String>['password', 'auth']),
  ]);
  if (password == null) {
    throw const FormatException('hysteria2 password is required.');
  }

  final Map<String, Object?> extra = <String, Object?>{};
  final String? obfsType = VpnConfigParser._firstValue(query, const <String>[
    'obfs',
  ]);
  final String? obfsPassword = VpnConfigParser._firstValue(
    query,
    const <String>['obfs_password', 'obfs-password', 'obfspassword'],
  );
  if (obfsType != null && obfsType.isNotEmpty) {
    extra['obfs'] = <String, Object?>{
      'type': obfsType,
      if (obfsPassword != null && obfsPassword.isNotEmpty)
        'password': obfsPassword,
    };
  }
  _putInt(extra, query, 'up_mbps', const <String>['upmbps', 'up_mbps', 'up']);
  _putInt(extra, query, 'down_mbps', const <String>[
    'downmbps',
    'down_mbps',
    'down',
  ]);

  final VpnProfile profile = VpnProfile.hysteria2(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'hysteria2'),
    server: uri.host,
    serverPort: uri.port,
    password: password,
    tls: parser._buildTlsOptions(
      query,
      fallbackServerName: uri.host,
      defaultEnabled: true,
      defaultAlpn: const <String>[],
    ),
    extra: extra,
  );

  return _ParseOutput(profile);
}

void _putString(
  Map<String, Object?> output,
  Map<String, String> source,
  String outputKey,
  List<String> sourceKeys,
) {
  final String? value = VpnConfigParser._firstValue(source, sourceKeys);
  if (value != null && value.isNotEmpty) {
    output[outputKey] = value;
  }
}

void _putInt(
  Map<String, Object?> output,
  Map<String, String> source,
  String outputKey,
  List<String> sourceKeys,
) {
  final int? value = VpnConfigParser._parseInt(
    VpnConfigParser._firstValue(source, sourceKeys),
  );
  if (value != null) {
    output[outputKey] = value;
  }
}
