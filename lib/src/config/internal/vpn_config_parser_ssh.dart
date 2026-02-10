part of '../vpn_config_parser.dart';

_ParseOutput _parseSshConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: 'ssh');
  if (uri.host.isEmpty) {
    throw const FormatException('ssh link is missing host.');
  }

  final Map<String, String> query = parser._normalizeQuery(uri);
  final List<String> warnings = <String>[];

  String? userFromUri;
  String? passwordFromUri;
  if (uri.userInfo.isNotEmpty) {
    final String decoded = Uri.decodeComponent(uri.userInfo);
    final int split = decoded.indexOf(':');
    if (split > 0 && split < decoded.length - 1) {
      userFromUri = decoded.substring(0, split);
      passwordFromUri = decoded.substring(split + 1);
    } else {
      userFromUri = decoded;
    }
  }

  final String user =
      VpnConfigParser._firstNonEmpty(<String?>[
        userFromUri,
        VpnConfigParser._firstValue(query, const <String>[
          'user',
          'username',
          'login',
        ]),
      ]) ??
      'root';

  final String? password = VpnConfigParser._firstNonEmpty(<String?>[
    passwordFromUri,
    VpnConfigParser._firstValue(query, const <String>[
      'password',
      'pass',
      'pwd',
    ]),
  ]);

  final String? privateKey = VpnConfigParser._firstValue(query, const <String>[
    'privatekey',
    'private_key',
    'key',
  ]);
  final String? privateKeyPath = VpnConfigParser._firstValue(
    query,
    const <String>['privatekeypath', 'private_key_path', 'key_path'],
  );
  final String? privateKeyPassphrase = VpnConfigParser._firstValue(
    query,
    const <String>[
      'privatekeypassphrase',
      'private_key_passphrase',
      'key_passphrase',
    ],
  );

  if ((password == null || password.isEmpty) &&
      (privateKey == null || privateKey.isEmpty) &&
      (privateKeyPath == null || privateKeyPath.isEmpty)) {
    throw const FormatException(
      'ssh link must include password or private key authentication.',
    );
  }

  final List<String> hostKey = _collectQueryListValues(
    uri,
    query,
    const <String>['hostkey', 'host_key'],
  );
  final List<String> hostKeyAlgorithms = _collectQueryListValues(
    uri,
    query,
    const <String>['hostkeyalgorithms', 'host_key_algorithms'],
  );

  final int serverPort;
  if (uri.hasPort) {
    if (uri.port <= 0) {
      throw const FormatException('ssh port must be within 1..65535.');
    }
    serverPort = uri.port;
  } else {
    serverPort =
        VpnConfigParser._parseInt(
          VpnConfigParser._firstValue(query, const <String>['port']),
        ) ??
        22;
  }

  if (hostKey.isEmpty) {
    warnings.add(
      'ssh host_key is not set; consider pinning server host keys for stronger trust.',
    );
  }

  final VpnProfile profile = VpnProfile.ssh(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'ssh'),
    server: uri.host,
    serverPort: serverPort,
    user: user,
    password: password,
    privateKey: privateKey,
    privateKeyPath: privateKeyPath,
    privateKeyPassphrase: privateKeyPassphrase,
    hostKey: hostKey,
    hostKeyAlgorithms: hostKeyAlgorithms,
    clientVersion: VpnConfigParser._firstValue(query, const <String>[
      'clientversion',
      'client_version',
    ]),
    detour: VpnConfigParser._firstValue(query, const <String>['detour']),
  );

  return _ParseOutput(profile, warnings: warnings);
}
