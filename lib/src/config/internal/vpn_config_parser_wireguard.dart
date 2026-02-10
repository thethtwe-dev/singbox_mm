part of '../vpn_config_parser.dart';

_ParseOutput _parseWireGuardConfig(
  VpnConfigParser parser,
  String raw, {
  required String scheme,
  String? fallbackTag,
}) {
  final Uri uri = parser._parseUri(raw, expectedScheme: null);
  final String normalizedScheme = uri.scheme.toLowerCase();
  if (normalizedScheme != 'wireguard' && normalizedScheme != 'wg') {
    throw FormatException(
      'Expected wireguard:// scheme, got ${uri.scheme}://.',
    );
  }
  parser._assertAddress(uri, scheme: scheme);

  final Map<String, String> query = parser._normalizeQuery(uri);
  final List<String> warnings = <String>[
    'wireguard outbound is deprecated in sing-box >= 1.11.0 and removed in 1.13.0.',
  ];

  final String? privateKey = VpnConfigParser._firstNonEmpty(<String?>[
    uri.userInfo.isEmpty ? null : Uri.decodeComponent(uri.userInfo),
    VpnConfigParser._firstValue(query, const <String>[
      'privatekey',
      'private_key',
      'secretkey',
      'secret_key',
    ]),
  ]);

  final String? peerPublicKey = VpnConfigParser._firstValue(
    query,
    const <String>[
      'peerpublickey',
      'peer_public_key',
      'publickey',
      'public_key',
    ],
  );

  final List<String> localAddress = _collectQueryListValues(
    uri,
    query,
    const <String>[
      'address',
      'local_address',
      'localaddress',
      'ip',
      'local_ip',
    ],
  );

  if (privateKey == null || privateKey.isEmpty) {
    throw const FormatException(
      'wireguard private key is required (userinfo or query private_key).',
    );
  }
  if (peerPublicKey == null || peerPublicKey.isEmpty) {
    throw const FormatException(
      'wireguard peer public key is required (query peer_public_key).',
    );
  }
  if (localAddress.isEmpty) {
    throw const FormatException(
      'wireguard local address is required (query address/local_address).',
    );
  }

  final List<int>? reserved = _parseWireGuardReserved(
    VpnConfigParser._firstValue(query, const <String>['reserved']),
    warnings: warnings,
  );

  final VpnProfile profile = VpnProfile.wireguard(
    tag: parser._resolveTag(uri, fallbackTag: fallbackTag, scheme: 'wireguard'),
    server: uri.host,
    serverPort: uri.port,
    privateKey: privateKey,
    peerPublicKey: peerPublicKey,
    localAddress: localAddress,
    preSharedKey: VpnConfigParser._firstValue(query, const <String>[
      'presharedkey',
      'pre_shared_key',
    ]),
    reserved: reserved,
    mtu: VpnConfigParser._parseInt(
      VpnConfigParser._firstValue(query, const <String>['mtu']),
    ),
    workers: VpnConfigParser._parseInt(
      VpnConfigParser._firstValue(query, const <String>['workers']),
    ),
    systemInterface: VpnConfigParser._parseBool(
      VpnConfigParser._firstValue(query, const <String>[
        'system_interface',
        'systeminterface',
      ]),
      fallback: null,
    ),
    interfaceName: VpnConfigParser._firstValue(query, const <String>[
      'interface_name',
      'interfacename',
    ]),
    network: VpnConfigParser._firstValue(query, const <String>['network']),
    detour: VpnConfigParser._firstValue(query, const <String>['detour']),
  );

  return _ParseOutput(profile, warnings: warnings);
}

List<String> _collectQueryListValues(
  Uri uri,
  Map<String, String> normalizedQuery,
  List<String> keys,
) {
  final List<String> output = <String>[];
  final Map<String, List<String>> queryAll = <String, List<String>>{};
  uri.queryParametersAll.forEach((String key, List<String> values) {
    queryAll[key.toLowerCase()] = values;
  });

  for (final String key in keys) {
    final List<String>? values = queryAll[key.toLowerCase()];
    if (values != null) {
      for (final String value in values) {
        output.addAll(VpnConfigParser._splitCsv(value));
      }
    }
  }

  if (output.isNotEmpty) {
    return output
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  final String? single = VpnConfigParser._firstValue(normalizedQuery, keys);
  if (single == null || single.isEmpty) {
    return const <String>[];
  }
  return VpnConfigParser._splitCsv(single);
}

List<int>? _parseWireGuardReserved(
  String? value, {
  required List<String> warnings,
}) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final List<String> pieces = value
      .split(',')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
  if (pieces.length != 3) {
    warnings.add('wireguard reserved should contain exactly 3 integers.');
    return null;
  }

  final List<int> reserved = <int>[];
  for (final String piece in pieces) {
    final int? parsed = int.tryParse(piece);
    if (parsed == null || parsed < 0 || parsed > 255) {
      warnings.add(
        'wireguard reserved contains invalid byte "$piece" (must be 0..255).',
      );
      return null;
    }
    reserved.add(parsed);
  }
  return List<int>.unmodifiable(reserved);
}
