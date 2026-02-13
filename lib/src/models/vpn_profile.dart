import 'traffic_throttle_policy.dart';

/// Supported outbound protocol types.
enum VpnProtocol {
  vless,
  vmess,
  trojan,
  shadowsocks,
  hysteria2,
  tuic,
  wireguard,
  ssh,
}

/// Wire-value helpers for [VpnProtocol].
extension VpnProtocolWire on VpnProtocol {
  /// Returns sing-box wire value for this protocol.
  String get wireValue {
    switch (this) {
      case VpnProtocol.vless:
        return 'vless';
      case VpnProtocol.vmess:
        return 'vmess';
      case VpnProtocol.trojan:
        return 'trojan';
      case VpnProtocol.shadowsocks:
        return 'shadowsocks';
      case VpnProtocol.hysteria2:
        return 'hysteria2';
      case VpnProtocol.tuic:
        return 'tuic';
      case VpnProtocol.wireguard:
        return 'wireguard';
      case VpnProtocol.ssh:
        return 'ssh';
    }
  }
}

/// Health/check helpers for [VpnProtocol].
extension VpnProtocolHealth on VpnProtocol {
  /// Whether this protocol is primarily UDP-based.
  bool get isUdpOriented {
    switch (this) {
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
      case VpnProtocol.wireguard:
        return true;
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
      case VpnProtocol.shadowsocks:
      case VpnProtocol.ssh:
        return false;
    }
  }
}

/// Transport options for supported TCP-based protocols.
enum VpnTransport { tcp, ws, grpc, quic, httpUpgrade }

/// Wire-value helpers for [VpnTransport].
extension VpnTransportWire on VpnTransport {
  /// Returns sing-box wire value for this transport.
  String get wireValue {
    switch (this) {
      case VpnTransport.tcp:
        return 'tcp';
      case VpnTransport.ws:
        return 'ws';
      case VpnTransport.grpc:
        return 'grpc';
      case VpnTransport.quic:
        return 'quic';
      case VpnTransport.httpUpgrade:
        return 'httpupgrade';
    }
  }
}

/// TLS and Reality options used by TLS-capable outbounds.
class TlsOptions {
  /// Creates TLS options.
  const TlsOptions({
    this.enabled = true,
    this.serverName,
    this.allowInsecure = false,
    this.utlsFingerprint = 'chrome',
    this.realityPublicKey,
    this.realityShortId,
    this.alpn = const <String>['h2', 'http/1.1'],
  });

  /// Whether TLS is enabled.
  final bool enabled;

  /// Optional TLS SNI.
  final String? serverName;

  /// Allows insecure certificate verification when `true`.
  final bool allowInsecure;

  /// Optional uTLS fingerprint name.
  final String? utlsFingerprint;

  /// Reality public key for VLESS-Reality.
  final String? realityPublicKey;

  /// Reality short ID.
  final String? realityShortId;

  /// ALPN list for TLS handshake.
  final List<String> alpn;

  /// Converts TLS options to sing-box outbound JSON format.
  Map<String, Object?> toMap() {
    if (!enabled) {
      return <String, Object?>{'enabled': false};
    }

    final Map<String, Object?> tls = <String, Object?>{
      'enabled': true,
      'insecure': allowInsecure,
    };

    if (serverName != null && serverName!.isNotEmpty) {
      tls['server_name'] = serverName;
    }

    if (utlsFingerprint != null && utlsFingerprint!.isNotEmpty) {
      tls['utls'] = <String, Object?>{
        'enabled': true,
        'fingerprint': utlsFingerprint,
      };
    }

    if (alpn.isNotEmpty) {
      tls['alpn'] = alpn;
    }

    if (realityPublicKey != null && realityPublicKey!.isNotEmpty) {
      tls['reality'] = <String, Object?>{
        'enabled': true,
        'public_key': realityPublicKey,
        if (realityShortId != null && realityShortId!.isNotEmpty)
          'short_id': realityShortId,
      };
    }

    return tls;
  }
}

/// Protocol-agnostic VPN profile model used by builders and runtime APIs.
class VpnProfile {
  /// Creates a protocol profile.
  const VpnProfile({
    required this.tag,
    required this.protocol,
    required this.server,
    required this.serverPort,
    this.uuid,
    this.password,
    this.method,
    this.flow,
    this.transport = VpnTransport.tcp,
    this.websocketPath,
    this.websocketHeaders = const <String, String>{},
    this.grpcServiceName,
    this.tls = const TlsOptions(),
    this.extra = const <String, Object?>{},
  }) : assert(tag != ''),
       assert(server != ''),
       assert(serverPort > 0);

  /// Creates a VLESS profile.
  factory VpnProfile.vless({
    required String tag,
    required String server,
    required int serverPort,
    required String uuid,
    String? flow,
    VpnTransport transport = VpnTransport.tcp,
    String? websocketPath,
    Map<String, String> websocketHeaders = const <String, String>{},
    String? grpcServiceName,
    TlsOptions tls = const TlsOptions(),
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.vless,
      server: server,
      serverPort: serverPort,
      uuid: uuid,
      flow: flow,
      transport: transport,
      websocketPath: websocketPath,
      websocketHeaders: websocketHeaders,
      grpcServiceName: grpcServiceName,
      tls: tls,
      extra: extra,
    );
  }

  /// Creates a VMess profile.
  factory VpnProfile.vmess({
    required String tag,
    required String server,
    required int serverPort,
    required String uuid,
    VpnTransport transport = VpnTransport.tcp,
    String? websocketPath,
    Map<String, String> websocketHeaders = const <String, String>{},
    String? grpcServiceName,
    TlsOptions tls = const TlsOptions(),
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.vmess,
      server: server,
      serverPort: serverPort,
      uuid: uuid,
      transport: transport,
      websocketPath: websocketPath,
      websocketHeaders: websocketHeaders,
      grpcServiceName: grpcServiceName,
      tls: tls,
      extra: extra,
    );
  }

  /// Creates a Trojan profile.
  factory VpnProfile.trojan({
    required String tag,
    required String server,
    required int serverPort,
    required String password,
    VpnTransport transport = VpnTransport.tcp,
    String? websocketPath,
    Map<String, String> websocketHeaders = const <String, String>{},
    String? grpcServiceName,
    TlsOptions tls = const TlsOptions(),
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.trojan,
      server: server,
      serverPort: serverPort,
      password: password,
      transport: transport,
      websocketPath: websocketPath,
      websocketHeaders: websocketHeaders,
      grpcServiceName: grpcServiceName,
      tls: tls,
      extra: extra,
    );
  }

  /// Creates a Shadowsocks profile.
  factory VpnProfile.shadowsocks({
    required String tag,
    required String server,
    required int serverPort,
    required String method,
    required String password,
    VpnTransport transport = VpnTransport.tcp,
    String? websocketPath,
    Map<String, String> websocketHeaders = const <String, String>{},
    String? grpcServiceName,
    TlsOptions tls = const TlsOptions(enabled: false),
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.shadowsocks,
      server: server,
      serverPort: serverPort,
      method: method,
      password: password,
      transport: transport,
      websocketPath: websocketPath,
      websocketHeaders: websocketHeaders,
      grpcServiceName: grpcServiceName,
      tls: tls,
      extra: extra,
    );
  }

  /// Creates a Hysteria2 profile.
  factory VpnProfile.hysteria2({
    required String tag,
    required String server,
    required int serverPort,
    required String password,
    TlsOptions tls = const TlsOptions(),
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.hysteria2,
      server: server,
      serverPort: serverPort,
      password: password,
      tls: tls,
      extra: extra,
    );
  }

  /// Creates a TUIC profile.
  factory VpnProfile.tuic({
    required String tag,
    required String server,
    required int serverPort,
    required String uuid,
    required String password,
    TlsOptions tls = const TlsOptions(),
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.tuic,
      server: server,
      serverPort: serverPort,
      uuid: uuid,
      password: password,
      tls: tls,
      extra: extra,
    );
  }

  /// Creates a WireGuard profile.
  factory VpnProfile.wireguard({
    required String tag,
    required String server,
    required int serverPort,
    required String privateKey,
    required String peerPublicKey,
    required List<String> localAddress,
    String? preSharedKey,
    List<int>? reserved,
    int? mtu,
    int? workers,
    bool? systemInterface,
    String? interfaceName,
    String? network,
    String? detour,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    final List<String> normalizedLocalAddress = localAddress
        .where((String item) => item.trim().isNotEmpty)
        .map((String item) => item.trim())
        .toList(growable: false);
    if (normalizedLocalAddress.isEmpty) {
      throw ArgumentError('localAddress is required for wireguard');
    }

    final Map<String, Object?> wireguardExtra = <String, Object?>{
      'private_key': privateKey,
      'peer_public_key': peerPublicKey,
      'local_address': normalizedLocalAddress,
      if (preSharedKey != null && preSharedKey.isNotEmpty)
        'pre_shared_key': preSharedKey,
      if (reserved != null && reserved.length == 3)
        'reserved': List<int>.unmodifiable(reserved),
      if (mtu != null && mtu > 0) 'mtu': mtu,
      if (workers != null && workers > 0) 'workers': workers,
      if (systemInterface case final bool value) 'system_interface': value,
      if (interfaceName != null && interfaceName.isNotEmpty)
        'interface_name': interfaceName,
      if (network != null && network.isNotEmpty) 'network': network,
      if (detour != null && detour.isNotEmpty) 'detour': detour,
      ...extra,
    };

    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.wireguard,
      server: server,
      serverPort: serverPort,
      tls: const TlsOptions(enabled: false),
      extra: wireguardExtra,
    );
  }

  /// Creates an SSH profile.
  factory VpnProfile.ssh({
    required String tag,
    required String server,
    int serverPort = 22,
    String user = 'root',
    String? password,
    String? privateKey,
    String? privateKeyPath,
    String? privateKeyPassphrase,
    List<String> hostKey = const <String>[],
    List<String> hostKeyAlgorithms = const <String>[],
    String? clientVersion,
    String? detour,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    final String normalizedUser = user.trim().isEmpty ? 'root' : user.trim();
    final List<String> normalizedHostKey = hostKey
        .where((String item) => item.trim().isNotEmpty)
        .map((String item) => item.trim())
        .toList(growable: false);
    final List<String> normalizedHostKeyAlgorithms = hostKeyAlgorithms
        .where((String item) => item.trim().isNotEmpty)
        .map((String item) => item.trim())
        .toList(growable: false);

    if ((password == null || password.isEmpty) &&
        (privateKey == null || privateKey.isEmpty) &&
        (privateKeyPath == null || privateKeyPath.isEmpty)) {
      throw ArgumentError(
        'ssh profile requires password or private key authentication',
      );
    }

    final Map<String, Object?> sshExtra = <String, Object?>{
      'user': normalizedUser,
      if (privateKey != null && privateKey.isNotEmpty)
        'private_key': privateKey,
      if (privateKeyPath != null && privateKeyPath.isNotEmpty)
        'private_key_path': privateKeyPath,
      if (privateKeyPassphrase != null && privateKeyPassphrase.isNotEmpty)
        'private_key_passphrase': privateKeyPassphrase,
      if (normalizedHostKey.isNotEmpty)
        'host_key': List<String>.unmodifiable(normalizedHostKey),
      if (normalizedHostKeyAlgorithms.isNotEmpty)
        'host_key_algorithms': List<String>.unmodifiable(
          normalizedHostKeyAlgorithms,
        ),
      if (clientVersion != null && clientVersion.isNotEmpty)
        'client_version': clientVersion,
      if (detour != null && detour.isNotEmpty) 'detour': detour,
      ...extra,
    };

    return VpnProfile(
      tag: tag,
      protocol: VpnProtocol.ssh,
      server: server,
      serverPort: serverPort,
      password: password,
      tls: const TlsOptions(enabled: false),
      extra: sshExtra,
    );
  }

  /// Friendly tag/remark for UI and outbound tagging.
  final String tag;

  /// Protocol type.
  final VpnProtocol protocol;

  /// Remote server host/IP.
  final String server;

  /// Remote server port.
  final int serverPort;

  /// UUID for protocols that require it.
  final String? uuid;

  /// Password/secret for protocols that require it.
  final String? password;

  /// Cipher method (for Shadowsocks).
  final String? method;

  /// Optional VLESS flow value.
  final String? flow;

  /// Selected transport mode.
  final VpnTransport transport;

  /// WebSocket/HTTP-upgrade path.
  final String? websocketPath;

  /// Optional WebSocket headers.
  final Map<String, String> websocketHeaders;

  /// gRPC service name.
  final String? grpcServiceName;

  /// TLS options.
  final TlsOptions tls;

  /// Extra protocol-specific attributes merged into outbound JSON.
  final Map<String, Object?> extra;

  /// Converts this profile into sing-box outbound JSON.
  Map<String, Object?> toOutboundJson({
    required TrafficThrottlePolicy throttle,
  }) {
    final Map<String, Object?> outbound = <String, Object?>{
      'tag': tag,
      'type': protocol.wireValue,
      'server': server,
      'server_port': serverPort,
      'domain_strategy': throttle.dnsStrategy,
      'tcp_fast_open': throttle.tcpFastOpen,
      'udp_fragment': throttle.udpFragment,
    };
    final Set<String> handledExtraKeys = <String>{};

    switch (protocol) {
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
        outbound['uuid'] = _requiredString(
          uuid,
          'uuid is required for ${protocol.wireValue}',
        );
        break;
      case VpnProtocol.tuic:
        outbound['uuid'] = _requiredString(uuid, 'uuid is required for tuic');
        outbound['password'] = _requiredString(
          password,
          'password is required for tuic',
        );
        break;
      case VpnProtocol.trojan:
      case VpnProtocol.hysteria2:
        outbound['password'] = _requiredString(
          password,
          'password is required for ${protocol.wireValue}',
        );
        if (protocol == VpnProtocol.hysteria2) {
          _applyHysteria2Obfs(
            source: extra,
            target: outbound,
            handledKeys: handledExtraKeys,
          );
          _putIfHasInt(extra, outbound, 'up_mbps');
          _putIfHasInt(extra, outbound, 'down_mbps');
          handledExtraKeys.addAll(const <String>{'up_mbps', 'down_mbps'});
        }
        break;
      case VpnProtocol.shadowsocks:
        outbound['method'] = _requiredString(
          method,
          'method is required for shadowsocks',
        );
        outbound['password'] = _requiredString(
          password,
          'password is required for shadowsocks',
        );
        break;
      case VpnProtocol.wireguard:
        outbound['private_key'] = _requiredExtraString(
          extra,
          'private_key',
          'private_key is required for wireguard',
        );
        outbound['peer_public_key'] = _requiredExtraString(
          extra,
          'peer_public_key',
          'peer_public_key is required for wireguard',
        );
        outbound['local_address'] = _requiredExtraStringList(
          extra,
          'local_address',
          'local_address is required for wireguard',
        );
        _putIfHasString(extra, outbound, 'pre_shared_key');
        _putIfHasInt(extra, outbound, 'mtu');
        _putIfHasInt(extra, outbound, 'workers');
        _putIfHasBool(extra, outbound, 'system_interface');
        _putIfHasString(extra, outbound, 'interface_name');
        _putIfHasString(extra, outbound, 'network');
        _putIfHasString(extra, outbound, 'detour');
        final List<int>? reserved = _extraIntList(extra['reserved']);
        if (reserved != null && reserved.length == 3) {
          outbound['reserved'] = reserved;
        }
        break;
      case VpnProtocol.ssh:
        outbound['user'] = _requiredExtraString(
          extra,
          'user',
          'user is required for ssh',
        );
        if (password != null && password!.isNotEmpty) {
          outbound['password'] = password;
        }
        _putIfHasString(extra, outbound, 'private_key');
        _putIfHasString(extra, outbound, 'private_key_path');
        _putIfHasString(extra, outbound, 'private_key_passphrase');
        _putIfHasStringList(extra, outbound, 'host_key');
        _putIfHasStringList(extra, outbound, 'host_key_algorithms');
        _putIfHasString(extra, outbound, 'client_version');
        _putIfHasString(extra, outbound, 'detour');

        final bool hasPassword = password != null && password!.isNotEmpty;
        final bool hasPrivateKey =
            (outbound['private_key'] as String?)?.isNotEmpty == true;
        final bool hasPrivateKeyPath =
            (outbound['private_key_path'] as String?)?.isNotEmpty == true;
        if (!hasPassword && !hasPrivateKey && !hasPrivateKeyPath) {
          throw ArgumentError(
            'ssh profile requires password or private key authentication',
          );
        }
        break;
    }

    if (flow != null && flow!.isNotEmpty) {
      outbound['flow'] = flow;
    }

    if (transport != VpnTransport.tcp && _supportsTransport()) {
      outbound['transport'] = _buildTransport();
    }

    final Map<String, Object?> tlsConfig = tls.toMap();
    _normalizeTlsForProtocol(tlsConfig);
    if (tlsConfig['enabled'] == true && _supportsTls()) {
      outbound['tls'] = tlsConfig;
    }

    if (throttle.enableMultiplex && _supportsMultiplex()) {
      outbound['multiplex'] = throttle.toMultiplexMap();
    }

    final Map<String, Object?>? tcpBrutal = throttle.toTcpBrutalMap();
    if (tcpBrutal != null && _supportsTcpBrutal()) {
      outbound['tcp_brutal'] = tcpBrutal;
    }

    if (extra.isNotEmpty) {
      if (handledExtraKeys.isEmpty) {
        outbound.addAll(extra);
      } else {
        extra.forEach((String key, Object? value) {
          if (handledExtraKeys.contains(key)) {
            return;
          }
          outbound[key] = value;
        });
      }
    }

    return outbound;
  }

  bool _supportsTransport() {
    switch (protocol) {
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
      case VpnProtocol.shadowsocks:
        return true;
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
      case VpnProtocol.wireguard:
      case VpnProtocol.ssh:
        return false;
    }
  }

  bool _supportsMultiplex() => _supportsTransport();

  bool _supportsTcpBrutal() => _supportsTransport();

  bool _supportsTls() {
    switch (protocol) {
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
        return true;
      case VpnProtocol.shadowsocks:
      case VpnProtocol.wireguard:
      case VpnProtocol.ssh:
        return false;
    }
  }

  void _normalizeTlsForProtocol(Map<String, Object?> tlsConfig) {
    if (tlsConfig.isEmpty || tlsConfig['enabled'] != true) {
      return;
    }

    switch (protocol) {
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
        // sing-box rejects uTLS on Hysteria2/TUIC (runtime error:
        // "unsupported usage for uTLS"), so keep native TLS fields only.
        tlsConfig.remove('utls');
        break;
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
      case VpnProtocol.shadowsocks:
      case VpnProtocol.wireguard:
      case VpnProtocol.ssh:
        break;
    }
  }

  Map<String, Object?> _buildTransport() {
    switch (transport) {
      case VpnTransport.tcp:
        return <String, Object?>{'type': 'tcp'};
      case VpnTransport.ws:
        return <String, Object?>{
          'type': 'ws',
          'path': websocketPath ?? '/',
          if (websocketHeaders.isNotEmpty) 'headers': websocketHeaders,
        };
      case VpnTransport.grpc:
        return <String, Object?>{
          'type': 'grpc',
          'service_name': grpcServiceName ?? 'grpc',
        };
      case VpnTransport.quic:
        return <String, Object?>{'type': 'quic'};
      case VpnTransport.httpUpgrade:
        return <String, Object?>{
          'type': 'httpupgrade',
          'path': websocketPath ?? '/',
        };
    }
  }

  static String _requiredString(String? value, String message) {
    if (value == null || value.isEmpty) {
      throw ArgumentError(message);
    }
    return value;
  }

  static String _requiredExtraString(
    Map<String, Object?> source,
    String key,
    String message,
  ) {
    final String? value = _extraString(source[key]);
    if (value == null || value.isEmpty) {
      throw ArgumentError(message);
    }
    return value;
  }

  static List<String> _requiredExtraStringList(
    Map<String, Object?> source,
    String key,
    String message,
  ) {
    final List<String>? value = _extraStringList(source[key]);
    if (value == null || value.isEmpty) {
      throw ArgumentError(message);
    }
    return value;
  }

  static String? _extraString(Object? value) {
    if (value is String) {
      final String normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    return null;
  }

  static int? _extraInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool? _extraBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  static List<String>? _extraStringList(Object? value) {
    if (value is List<dynamic>) {
      final List<String> items = value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
      if (items.isNotEmpty) {
        return items;
      }
    }
    if (value is String) {
      final String normalized = value.trim();
      if (normalized.isNotEmpty) {
        return <String>[normalized];
      }
    }
    return null;
  }

  static List<int>? _extraIntList(Object? value) {
    if (value is List<dynamic>) {
      final List<int> items = <int>[];
      for (final dynamic item in value) {
        final int? parsed = _extraInt(item);
        if (parsed == null) {
          continue;
        }
        items.add(parsed);
      }
      if (items.isNotEmpty) {
        return items;
      }
    }
    return null;
  }

  static void _applyHysteria2Obfs({
    required Map<String, Object?> source,
    required Map<String, Object?> target,
    required Set<String> handledKeys,
  }) {
    handledKeys.addAll(const <String>{
      'obfs',
      'obfs_password',
      'obfs-password',
      'obfspassword',
    });

    final Object? rawObfs = source['obfs'];
    String? obfsType;
    String? obfsPassword;
    Map<String, Object?>? obfsObject;

    if (rawObfs is String) {
      obfsType = _extraString(rawObfs);
    } else if (rawObfs is Map<Object?, Object?>) {
      obfsObject = <String, Object?>{};
      rawObfs.forEach((Object? key, Object? value) {
        if (key is String) {
          obfsObject![key] = value;
        }
      });
      obfsType = _extraString(obfsObject['type']);
      obfsPassword = _extraString(obfsObject['password']);
    }

    obfsPassword ??= _extraString(source['obfs_password']);
    obfsPassword ??= _extraString(source['obfs-password']);
    obfsPassword ??= _extraString(source['obfspassword']);

    if (obfsType == null || obfsType.isEmpty) {
      return;
    }

    final Map<String, Object?> normalizedObfs =
        obfsObject ?? <String, Object?>{};
    normalizedObfs['type'] = obfsType;
    if (obfsPassword != null && obfsPassword.isNotEmpty) {
      normalizedObfs['password'] = obfsPassword;
    } else {
      normalizedObfs.remove('password');
    }
    target['obfs'] = normalizedObfs;
  }

  static void _putIfHasString(
    Map<String, Object?> source,
    Map<String, Object?> target,
    String key,
  ) {
    final String? value = _extraString(source[key]);
    if (value != null) {
      target[key] = value;
    }
  }

  static void _putIfHasInt(
    Map<String, Object?> source,
    Map<String, Object?> target,
    String key,
  ) {
    final int? value = _extraInt(source[key]);
    if (value != null) {
      target[key] = value;
    }
  }

  static void _putIfHasBool(
    Map<String, Object?> source,
    Map<String, Object?> target,
    String key,
  ) {
    final bool? value = _extraBool(source[key]);
    if (value != null) {
      target[key] = value;
    }
  }

  static void _putIfHasStringList(
    Map<String, Object?> source,
    Map<String, Object?> target,
    String key,
  ) {
    final List<String>? value = _extraStringList(source[key]);
    if (value != null && value.isNotEmpty) {
      target[key] = value;
    }
  }
}
