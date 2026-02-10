import 'traffic_throttle_policy.dart';

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

extension VpnProtocolWire on VpnProtocol {
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

extension VpnProtocolHealth on VpnProtocol {
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

enum VpnTransport { tcp, ws, grpc, quic, httpUpgrade }

extension VpnTransportWire on VpnTransport {
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

class TlsOptions {
  const TlsOptions({
    this.enabled = true,
    this.serverName,
    this.allowInsecure = false,
    this.utlsFingerprint = 'chrome',
    this.realityPublicKey,
    this.realityShortId,
    this.alpn = const <String>['h2', 'http/1.1'],
  });

  final bool enabled;
  final String? serverName;
  final bool allowInsecure;
  final String? utlsFingerprint;
  final String? realityPublicKey;
  final String? realityShortId;
  final List<String> alpn;

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

class VpnProfile {
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

  final String tag;
  final VpnProtocol protocol;
  final String server;
  final int serverPort;
  final String? uuid;
  final String? password;
  final String? method;
  final String? flow;
  final VpnTransport transport;
  final String? websocketPath;
  final Map<String, String> websocketHeaders;
  final String? grpcServiceName;
  final TlsOptions tls;
  final Map<String, Object?> extra;

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
      outbound.addAll(extra);
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
