part of '../vpn_config_parser.dart';

bool _looksLikeWireGuardQuickConfig(String raw) {
  final String normalized = raw.trim();
  if (normalized.isEmpty) {
    return false;
  }
  return RegExp(
        r'^\s*\[interface\]\s*$',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(normalized) &&
      RegExp(
        r'^\s*\[peer\]\s*$',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(normalized);
}

_ParseOutput? _tryParseWireGuardQuickConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  if (!_looksLikeWireGuardQuickConfig(raw)) {
    return null;
  }
  return _parseWireGuardQuickConfig(parser, raw, fallbackTag: fallbackTag);
}

_ParseOutput _parseWireGuardQuickConfig(
  VpnConfigParser parser,
  String raw, {
  String? fallbackTag,
}) {
  final Map<String, List<String>> interfaceFields = <String, List<String>>{};
  final List<Map<String, List<String>>> peerFields =
      <Map<String, List<String>>>[];
  final List<String> warnings = <String>[
    'wireguard outbound is deprecated in sing-box >= 1.11.0 and removed in 1.13.0.',
  ];

  String section = '';
  String? candidateTag;
  String? lastCommentText;

  for (final String line in const LineSplitter().convert(raw)) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final String? comment = _extractWireGuardCommentText(trimmed);
    if (comment != null) {
      if (comment.isNotEmpty) {
        lastCommentText = comment;
      }
      continue;
    }

    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final String header = trimmed.substring(1, trimmed.length - 1).trim();
      switch (header.toLowerCase()) {
        case 'interface':
          section = 'interface';
          break;
        case 'peer':
          section = 'peer';
          peerFields.add(<String, List<String>>{});
          candidateTag ??= lastCommentText;
          break;
        default:
          section = '';
          warnings.add('Ignoring unsupported wg-quick section [$header].');
          break;
      }
      lastCommentText = null;
      continue;
    }

    final int separator = trimmed.indexOf('=');
    if (separator <= 0 || separator >= trimmed.length - 1) {
      warnings.add('Ignoring malformed wg-quick line: "$trimmed".');
      continue;
    }

    final String key = _normalizeWireGuardFieldKey(
      trimmed.substring(0, separator),
    );
    final String value = _stripWireGuardInlineComment(
      trimmed.substring(separator + 1),
    ).trim();
    if (key.isEmpty || value.isEmpty) {
      continue;
    }

    if (section == 'interface') {
      _addWireGuardFieldValue(interfaceFields, key, value);
      continue;
    }
    if (section == 'peer') {
      if (peerFields.isEmpty) {
        peerFields.add(<String, List<String>>{});
      }
      _addWireGuardFieldValue(peerFields.last, key, value);
      continue;
    }

    warnings.add('Ignoring line outside [Interface]/[Peer]: "$trimmed".');
  }

  if (peerFields.isEmpty) {
    throw const FormatException(
      'wg-quick config must include a [Peer] section.',
    );
  }
  if (peerFields.length > 1) {
    warnings.add(
      'wg-quick has multiple [Peer] sections; using the first peer only.',
    );
  }

  if (_firstWireGuardField(interfaceFields, const <String>['dns']) != null) {
    warnings.add(
      'wg-quick DNS is ignored by this parser; configure DNS via feature settings/bypass policy.',
    );
  }

  final String privateKey = _requireWireGuardField(
    interfaceFields,
    const <String>['privatekey'],
    label: 'wg-quick Interface.PrivateKey',
  );
  final List<String> localAddress = _wireGuardFieldList(
    interfaceFields,
    const <String>['address'],
  );
  if (localAddress.isEmpty) {
    throw const FormatException('wg-quick Interface.Address is required.');
  }

  final Map<String, List<String>> peer = peerFields.first;
  final String peerPublicKey = _requireWireGuardField(peer, const <String>[
    'publickey',
  ], label: 'wg-quick Peer.PublicKey');
  final String endpointValue = _requireWireGuardField(peer, const <String>[
    'endpoint',
  ], label: 'wg-quick Peer.Endpoint');
  final _WireGuardEndpoint endpoint = _parseWireGuardEndpoint(endpointValue);

  final int? mtu = VpnConfigParser._parseInt(
    _firstWireGuardField(interfaceFields, const <String>['mtu']),
  );

  final String tag = parser._buildTag(
    scheme: 'wireguard',
    host: endpoint.host,
    explicitTag: candidateTag,
    fallbackTag: fallbackTag,
  );

  final VpnProfile profile = VpnProfile.wireguard(
    tag: tag,
    server: endpoint.host,
    serverPort: endpoint.port,
    privateKey: privateKey,
    peerPublicKey: peerPublicKey,
    localAddress: localAddress,
    preSharedKey: _firstWireGuardField(peer, const <String>[
      'presharedkey',
      'preshared',
    ]),
    mtu: mtu,
  );

  return _ParseOutput(profile, warnings: warnings);
}

void _addWireGuardFieldValue(
  Map<String, List<String>> fields,
  String key,
  String value,
) {
  final List<String> current = fields[key] ?? <String>[];
  current.add(value);
  fields[key] = current;
}

String _normalizeWireGuardFieldKey(String raw) {
  return raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
}

String? _extractWireGuardCommentText(String line) {
  if (line.startsWith('#') || line.startsWith(';')) {
    return line.substring(1).trim();
  }
  return null;
}

String _stripWireGuardInlineComment(String value) {
  final int hashIndex = value.indexOf(' #');
  final int semicolonIndex = value.indexOf(' ;');

  int index = -1;
  if (hashIndex >= 0) {
    index = hashIndex;
  }
  if (semicolonIndex >= 0) {
    index = index < 0
        ? semicolonIndex
        : semicolonIndex < index
        ? semicolonIndex
        : index;
  }
  if (index < 0) {
    return value;
  }
  return value.substring(0, index);
}

String? _firstWireGuardField(
  Map<String, List<String>> fields,
  List<String> keys,
) {
  for (final String rawKey in keys) {
    final String key = _normalizeWireGuardFieldKey(rawKey);
    final List<String>? values = fields[key];
    if (values == null || values.isEmpty) {
      continue;
    }
    final String? first = VpnConfigParser._firstNonEmpty(values);
    if (first != null) {
      return first;
    }
  }
  return null;
}

String _requireWireGuardField(
  Map<String, List<String>> fields,
  List<String> keys, {
  required String label,
}) {
  final String? value = _firstWireGuardField(fields, keys);
  if (value == null || value.isEmpty) {
    throw FormatException('$label is required.');
  }
  return value;
}

List<String> _wireGuardFieldList(
  Map<String, List<String>> fields,
  List<String> keys,
) {
  final List<String> output = <String>[];
  for (final String rawKey in keys) {
    final String key = _normalizeWireGuardFieldKey(rawKey);
    final List<String>? values = fields[key];
    if (values == null) {
      continue;
    }
    for (final String value in values) {
      output.addAll(VpnConfigParser._splitCsv(value));
    }
  }
  return output
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

_WireGuardEndpoint _parseWireGuardEndpoint(String value) {
  final String raw = value.trim();
  if (raw.isEmpty) {
    throw const FormatException('wg-quick Peer.Endpoint is empty.');
  }

  String host;
  String portRaw;
  if (raw.startsWith('[')) {
    final int closing = raw.indexOf(']');
    if (closing <= 1) {
      throw FormatException('Invalid wg-quick endpoint "$raw".');
    }
    host = raw.substring(1, closing).trim();
    final String rest = raw.substring(closing + 1).trim();
    if (!rest.startsWith(':')) {
      throw FormatException('Invalid wg-quick endpoint "$raw".');
    }
    portRaw = rest.substring(1).trim();
  } else {
    final int split = raw.lastIndexOf(':');
    if (split <= 0 || split >= raw.length - 1) {
      throw FormatException('Invalid wg-quick endpoint "$raw".');
    }
    host = raw.substring(0, split).trim();
    portRaw = raw.substring(split + 1).trim();
  }

  final int? port = int.tryParse(portRaw);
  if (host.isEmpty || port == null || port <= 0 || port > 65535) {
    throw FormatException('Invalid wg-quick endpoint "$raw".');
  }
  return _WireGuardEndpoint(host: host, port: port);
}

class _WireGuardEndpoint {
  const _WireGuardEndpoint({required this.host, required this.port});

  final String host;
  final int port;
}
