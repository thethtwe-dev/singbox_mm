part of '../vpn_config_parser.dart';

_ParseOutput _parseTuicConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: 'tuic');
  parser._assertAddress(uri, scheme: 'tuic');

  final Map<String, String> query = parser._normalizeQuery(uri);
  String? uuid;
  String? password;

  if (uri.userInfo.isNotEmpty) {
    final String userInfo = Uri.decodeComponent(uri.userInfo);
    final int split = userInfo.indexOf(':');
    if (split > 0 && split < userInfo.length - 1) {
      uuid = userInfo.substring(0, split);
      password = userInfo.substring(split + 1);
    } else if (split < 0 && userInfo.isNotEmpty) {
      uuid = userInfo;
    }
  }

  uuid = VpnConfigParser._firstNonEmpty(<String?>[
    uuid,
    VpnConfigParser._firstValue(query, const <String>['uuid', 'id']),
  ]);
  password = VpnConfigParser._firstNonEmpty(<String?>[
    password,
    VpnConfigParser._firstValue(query, const <String>['password', 'token']),
  ]);

  if (uuid == null || password == null) {
    throw const FormatException(
      'tuic link must include uuid and password in userinfo or query.',
    );
  }

  final Map<String, Object?> extra = <String, Object?>{};
  _putString(extra, query, 'congestion_control', const <String>[
    'congestion_control',
    'congestioncontrol',
  ]);
  _putString(extra, query, 'udp_relay_mode', const <String>[
    'udp_relay_mode',
    'udprelaymode',
  ]);
  _putInt(extra, query, 'heartbeat', const <String>[
    'heartbeat',
    'heartbeat_interval',
  ]);

  final VpnProfile profile = VpnProfile.tuic(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'tuic'),
    server: uri.host,
    serverPort: uri.port,
    uuid: uuid,
    password: password,
    tls: parser._buildTlsOptions(
      query,
      fallbackServerName: uri.host,
      defaultEnabled: true,
    ),
    extra: extra,
  );

  return _ParseOutput(profile);
}
