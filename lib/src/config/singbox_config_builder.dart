import 'internal/singbox_dns_builder.dart';
import 'internal/singbox_inbound_builder.dart';
import 'internal/singbox_route_rules_builder.dart';
import '../models/bypass_policy.dart';
import '../models/singbox_feature_settings.dart';
import '../models/singbox_rule_set.dart';
import '../models/traffic_throttle_policy.dart';
import '../models/vpn_profile.dart';

/// Transport normalization strategy used during config generation.
enum SingboxTransportBuildMode {
  /// Prefer official sing-box native transport mapping.
  singboxNative,

  /// Prefer Xray-compatible legacy transport mapping for problematic links.
  xrayCompat,
}

class SingboxConfigBuilder {
  const SingboxConfigBuilder();

  static const SingboxInboundBuilder _inboundBuilder = SingboxInboundBuilder();
  static const SingboxDnsBuilder _dnsBuilder = SingboxDnsBuilder();
  static const SingboxRouteRulesBuilder _routeRulesBuilder =
      SingboxRouteRulesBuilder();
  static const String _httpUpgradeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  static const String _transportAliasExtraKey = '_sbmm_transport_alias';
  static const String _grpcAuthorityExtraKey = '_sbmm_grpc_authority';
  static const String _grpcModeExtraKey = '_sbmm_grpc_mode';

  Map<String, Object?> build({
    required VpnProfile profile,
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings settings = const SingboxFeatureSettings(),
    SingboxTransportBuildMode transportBuildMode =
        SingboxTransportBuildMode.singboxNative,
    String logLevel = 'info',
    String tunInterfaceName = 'sb-tun',
    String tunInet4Address = '172.19.0.1/30',
  }) {
    final bool forceIpv4Only = _shouldForceIpv4Only(
      profile: profile,
      settings: settings,
    );
    final Map<String, Object?> proxyOutbound = profile.toOutboundJson(
      throttle: throttlePolicy,
    );
    final String normalizedTransportType = _resolveNormalizedTransportType(
      profile: profile,
      outbound: proxyOutbound,
      transportBuildMode: transportBuildMode,
    );
    _applyEarlyTransportNormalization(
      outbound: proxyOutbound,
      normalizedTransportType: normalizedTransportType,
      transportBuildMode: transportBuildMode,
    );
    final String postNormalizedTransportType = _resolveNormalizedTransportType(
      profile: profile,
      outbound: proxyOutbound,
      transportBuildMode: transportBuildMode,
    );
    _enforceVlessMultiplexStability(outbound: proxyOutbound, profile: profile);
    if (forceIpv4Only) {
      proxyOutbound['domain_strategy'] = 'ipv4_only';
    }
    _applyTransportCompatibility(
      proxyOutbound,
      profile,
      normalizedTransportType: postNormalizedTransportType,
    );
    _applyTlsTricks(proxyOutbound, settings.tlsTricks);

    final List<Object?> outbounds = <Object?>[
      proxyOutbound,
      <String, Object?>{'type': 'direct', 'tag': 'direct'},
      <String, Object?>{'type': 'block', 'tag': 'block'},
    ];

    String finalOutboundTag = profile.tag;
    _applyWarp(
      outbounds: outbounds,
      proxyOutbound: proxyOutbound,
      settings: settings.warp,
      onFinalOutboundChanged: (String nextTag) {
        finalOutboundTag = nextTag;
      },
    );

    final List<Object?> inbounds = _inboundBuilder.build(
      settings: settings,
      tunInterfaceName: tunInterfaceName,
      tunInet4Address: tunInet4Address,
    );

    final Map<String, Object?> dns = _dnsBuilder.build(
      profile: profile,
      bypassPolicy: bypassPolicy,
      settings: settings,
    );

    final List<Object?> routeRules = _routeRulesBuilder.build(
      profile: profile,
      bypassPolicy: bypassPolicy,
      settings: settings,
      includeDnsRoutingRule: settings.dns.enableDnsRouting,
    );

    final Map<String, Object?> experimental = <String, Object?>{
      'cache_file': <String, Object?>{
        'enabled': !settings.advanced.memoryLimit,
        'store_fakeip': !settings.advanced.memoryLimit,
      },
    };

    final int? clashApiPort = settings.misc.clashApiPort;
    if (clashApiPort != null && clashApiPort > 0) {
      experimental['clash_api'] = <String, Object?>{
        'external_controller': '127.0.0.1:$clashApiPort',
      };
    }

    final Map<String, Object?> config = <String, Object?>{
      'log': <String, Object?>{
        'level': _resolveLogLevel(
          runtimeLogLevel: logLevel,
          settings: settings.advanced,
        ),
        'timestamp': true,
      },
      'dns': dns,
      'inbounds': inbounds,
      'outbounds': outbounds,
      'route': <String, Object?>{
        'auto_detect_interface': true,
        'override_android_vpn': false,
        'final': finalOutboundTag,
        'rules': routeRules,
        if (settings.route.ruleSets.isNotEmpty)
          'rule_set': settings.route.ruleSets
              .map((SingboxRuleSet e) => e.toMap())
              .toList(),
      },
      'experimental': experimental,
    };

    if (settings.rawConfigPatch.isNotEmpty) {
      _deepMergeMap(config, settings.rawConfigPatch);
    }

    _migrateLegacyDnsRouteRules(config);
    _sanitizeFinalOutbounds(
      config,
      profile,
      transportBuildMode: transportBuildMode,
    );
    _forceHttpUpgradeHttp11Alpn(config, transportBuildMode: transportBuildMode);

    return config;
  }

  void _applyTransportCompatibility(
    Map<String, Object?> outbound,
    VpnProfile profile, {
    required String normalizedTransportType,
  }) {
    final bool streamTransport =
        normalizedTransportType == 'tcp' ||
        normalizedTransportType == 'ws' ||
        normalizedTransportType == 'grpc' ||
        normalizedTransportType == 'http' ||
        normalizedTransportType == 'httpupgrade';
    if (!streamTransport) {
      return;
    }

    switch (profile.protocol) {
      case VpnProtocol.vless:
        outbound['multiplex'] = const <String, Object?>{'enabled': false};
        outbound['udp_fragment'] = false;
        break;
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
        outbound['udp_fragment'] = false;
        if (normalizedTransportType == 'http' ||
            normalizedTransportType == 'httpupgrade') {
          outbound['multiplex'] = const <String, Object?>{'enabled': false};
        }
        break;
      case VpnProtocol.shadowsocks:
        outbound['udp_fragment'] = false;
        break;
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
      case VpnProtocol.wireguard:
        break;
      case VpnProtocol.ssh:
        outbound['udp_fragment'] = false;
        break;
    }

    // For WS/HTTP upgrade, uTLS fingerprints can force HTTP/2 ALPN (e.g.
    // "chrome"), which breaks HTTP/1.1 upgrade flows. Strip uTLS when the
    // profile explicitly pins ALPN to http/1.1-only.
    if (normalizedTransportType == 'ws' ||
        normalizedTransportType == 'httpupgrade') {
      final bool http11Only =
          profile.tls.alpn.length == 1 &&
          profile.tls.alpn.first.toLowerCase() == 'http/1.1';
      if (http11Only) {
        final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
        if (tls.isNotEmpty) {
          tls.remove('utls');
          outbound['tls'] = tls;
        }
      }
    }

    if (normalizedTransportType == 'httpupgrade') {
      // Hard override: never allow profile/link ALPN preferences to force
      // HTTP/2 for HTTP upgrade transport.
      final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
      if (tls.isNotEmpty) {
        tls.remove('utls');
        tls['alpn'] = const <String>['http/1.1'];
        outbound['tls'] = tls;
      }
    }
  }

  String _resolveNormalizedTransportType({
    required VpnProfile profile,
    required Map<String, Object?> outbound,
    required SingboxTransportBuildMode transportBuildMode,
  }) {
    final String? transportAlias = _readTransportAlias(outbound);
    if (transportAlias == 'xhttp') {
      return transportBuildMode == SingboxTransportBuildMode.xrayCompat
          ? 'httpupgrade'
          : 'http';
    }
    if (transportAlias == 'httpupgrade') {
      return 'httpupgrade';
    }

    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    final String? rawFromOutbound = _normalizedNonEmptyString(
      transport['type'],
    );
    if (rawFromOutbound != null) {
      return _normalizeTransportTypeValue(
        rawFromOutbound,
        transportBuildMode: transportBuildMode,
      );
    }
    return _normalizeTransportTypeValue(
      profile.transport.wireValue,
      transportBuildMode: transportBuildMode,
    );
  }

  void _applyEarlyTransportNormalization({
    required Map<String, Object?> outbound,
    required String normalizedTransportType,
    required SingboxTransportBuildMode transportBuildMode,
  }) {
    if (normalizedTransportType == 'httpupgrade') {
      final Map<String, Object?> transport = _asObjectMap(
        outbound['transport'],
      );
      if (transport.isNotEmpty) {
        transport['type'] = 'httpupgrade';
        outbound['transport'] = transport;
      }
      _normalizeTransportType(outbound, transportBuildMode: transportBuildMode);
      _normalizeHttpUpgradeTransport(outbound);
      _applyHttpUpgradeAlpnDefaults(outbound);
      return;
    }

    if (normalizedTransportType == 'http') {
      final Map<String, Object?> transport = _asObjectMap(
        outbound['transport'],
      );
      if (transport.isNotEmpty) {
        transport['type'] = 'http';
        outbound['transport'] = transport;
      }
      _normalizeTransportType(outbound, transportBuildMode: transportBuildMode);
      _normalizeHttpTransport(outbound);
      _applyHttpTransportAlpnDefaults(outbound);
      return;
    }

    if (normalizedTransportType == 'grpc') {
      _normalizeGrpcTransport(outbound);
      _applyGrpcAlpnDefaults(outbound);
    }
  }

  String _normalizeTransportTypeValue(
    String rawType, {
    SingboxTransportBuildMode transportBuildMode =
        SingboxTransportBuildMode.singboxNative,
  }) {
    final String normalized = rawType.trim().toLowerCase();
    if (normalized == 'xhttp') {
      return transportBuildMode == SingboxTransportBuildMode.xrayCompat
          ? 'httpupgrade'
          : 'http';
    }
    if (normalized == 'httpupgrade' || normalized == 'http-upgrade') {
      return 'httpupgrade';
    }
    if (normalized == 'h2' || normalized == 'http2') {
      return 'http';
    }
    return normalized;
  }

  void _enforceVlessMultiplexStability({
    required Map<String, Object?> outbound,
    required VpnProfile profile,
  }) {
    if (profile.protocol != VpnProtocol.vless) {
      return;
    }
    // Some servers exhibit intermittent stalls under smux on VLESS.
    outbound['multiplex'] = const <String, Object?>{'enabled': false};
  }

  bool _shouldForceIpv4Only({
    required VpnProfile profile,
    required SingboxFeatureSettings settings,
  }) {
    switch (profile.protocol) {
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
        return settings.route.ipv6RouteMode == SingboxIpv6RouteMode.disable;
      case VpnProtocol.wireguard:
        return false;
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
      case VpnProtocol.shadowsocks:
      case VpnProtocol.ssh:
        return profile.transport != VpnTransport.quic;
    }
  }

  void _applyTlsTricks(
    Map<String, Object?> outbound,
    TlsTricksOptions settings,
  ) {
    if (settings.rawOutboundPatch.isNotEmpty) {
      _deepMergeMap(outbound, settings.rawOutboundPatch);
    }

    _normalizeUdpFragmentSchema(outbound);

    final bool supportsTls = _supportsTlsTricks(outbound);
    if (supportsTls && settings.enableTlsFragment) {
      final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
      // Do not force-enable TLS for non-TLS profiles (for example
      // VLESS links with `security=none`). Only attach fragment on
      // already-enabled TLS outbounds.
      if (tls['enabled'] == true) {
        // Official sing-box libbox expects bool `tls.fragment`.
        tls['fragment'] = true;
        outbound['tls'] = tls;
      }
    }

    if (!supportsTls) {
      if (!_requiresNativeTls(outbound)) {
        outbound.remove('tls');
        return;
      }

      final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
      if (tls.isNotEmpty) {
        // Keep mandatory TLS block for protocols like Hysteria2/TUIC, but strip
        // tricks that are only valid for VLESS/VMess/Trojan.
        tls.remove('mixed_sni_case');
        tls.remove('padding');
        tls.remove('fragment');
        tls.remove('utls');
        outbound['tls'] = tls;
      }
      return;
    }

    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    if (tls.isNotEmpty) {
      _normalizeTlsFragmentSchema(tls);
      outbound['tls'] = tls;
    }
  }

  void _normalizeUdpFragmentSchema(Map<String, Object?> outbound) {
    final Object? raw = outbound['udp_fragment'];
    bool? normalized;

    if (raw is bool) {
      normalized = raw;
    } else if (raw is num) {
      normalized = raw != 0;
    } else if (raw is String) {
      final String value = raw.trim().toLowerCase();
      if (value == 'true' || value == '1' || value == 'yes') {
        normalized = true;
      } else if (value == 'false' || value == '0' || value == 'no') {
        normalized = false;
      }
    } else if (raw is Map<Object?, Object?>) {
      final Map<String, Object?> fragment = _asObjectMap(raw);
      final Object? enabled = fragment['enabled'];
      if (enabled is bool) {
        normalized = enabled;
      } else if (enabled is num) {
        normalized = enabled != 0;
      } else if (enabled is String) {
        normalized = enabled.toLowerCase() == 'true' || enabled == '1';
      } else {
        normalized = true;
      }
    }

    if (normalized != null) {
      outbound['udp_fragment'] = normalized;
    } else {
      final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
      final bool tlsEnabled = tls['enabled'] == true;
      if (tlsEnabled && _isTlsCapableOutboundType(outbound)) {
        outbound['udp_fragment'] = true;
      }
    }
  }

  void _normalizeTlsFragmentSchema(Map<String, Object?> tls) {
    // These keys are not supported by official sing-box TLS options.
    tls.remove('mixed_sni_case');
    tls.remove('padding');

    final Object? fragment = tls['fragment'];
    if (fragment is Map<Object?, Object?>) {
      final Map<String, Object?> fragmentObject = _asObjectMap(fragment);
      final Object? enabledRaw = fragmentObject['enabled'];
      final bool enabled = enabledRaw is bool ? enabledRaw : true;
      if (enabled) {
        tls['fragment'] = true;
      } else {
        tls.remove('fragment');
      }
    }
  }

  bool _supportsTlsTricks(Map<String, Object?> outbound) {
    final bool tlsCapableType = _isTlsCapableOutboundType(outbound);
    if (!tlsCapableType) {
      return false;
    }
    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    return tls['enabled'] == true;
  }

  bool _isTlsCapableOutboundType(Map<String, Object?> outbound) {
    final String type = (outbound['type'] as String?)?.toLowerCase() ?? '';
    return type == 'vless' ||
        type == 'vmess' ||
        type == 'trojan' ||
        type == 'anytls';
  }

  bool _requiresNativeTls(Map<String, Object?> outbound) {
    final String type = (outbound['type'] as String?)?.toLowerCase() ?? '';
    return type == 'hysteria2' || type == 'tuic';
  }

  void _sanitizeFinalOutbounds(
    Map<String, Object?> config,
    VpnProfile profile, {
    required SingboxTransportBuildMode transportBuildMode,
  }) {
    final Object? rawOutbounds = config['outbounds'];
    if (rawOutbounds is! List<Object?>) {
      return;
    }

    for (int i = rawOutbounds.length - 1; i >= 0; i--) {
      final Object? item = rawOutbounds[i];
      if (item is! Map<Object?, Object?>) {
        continue;
      }

      final Map<String, Object?> outbound = _asObjectMap(item);
      final String type =
          (outbound['type'] as String?)?.trim().toLowerCase() ?? '';
      if (type == 'dns') {
        rawOutbounds.removeAt(i);
        continue;
      }

      _normalizeTransportType(outbound, transportBuildMode: transportBuildMode);
      _normalizeHttpUpgradeTransport(outbound);
      _normalizeHttpTransport(outbound);
      _applyHttpUpgradeAlpnDefaults(outbound);
      _applyHttpTransportAlpnDefaults(outbound);

      final bool securityNone = _isSecurityNone(outbound);
      final bool requiresNativeTls = _requiresNativeTls(outbound);
      final bool profileTlsDisabled =
          outbound['tag'] == profile.tag && profile.tls.enabled == false;
      final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
      _sanitizeTlsReality(tls);
      final bool tlsEnabled = tls['enabled'] == true;

      if (profileTlsDisabled || securityNone) {
        outbound.remove('tls');
      } else if (!requiresNativeTls && !tlsEnabled) {
        // Strict guard for plain transports (`security=none`): non-native
        // TLS outbounds must not carry any `tls` key at all.
        outbound.remove('tls');
      } else if (requiresNativeTls && tls.isNotEmpty && !tlsEnabled) {
        // Prevent invalid partially-patched native TLS blocks.
        outbound.remove('tls');
      } else if (tls.isNotEmpty) {
        outbound['tls'] = tls;
      }

      rawOutbounds[i] = outbound;
    }
  }

  void _sanitizeTlsReality(Map<String, Object?> tls) {
    final Map<String, Object?> reality = _asObjectMap(tls['reality']);
    if (reality.isEmpty) {
      return;
    }

    reality.remove('spider_x');
    tls['reality'] = reality;
  }

  void _migrateLegacyDnsRouteRules(Map<String, Object?> config) {
    final Map<String, Object?> route = _asObjectMap(config['route']);
    final Object? rawRules = route['rules'];
    if (rawRules is! List<Object?>) {
      return;
    }

    for (int i = 0; i < rawRules.length; i++) {
      final Object? item = rawRules[i];
      if (item is! Map<Object?, Object?>) {
        continue;
      }

      final Map<String, Object?> rule = _asObjectMap(item);
      final String outbound =
          (rule['outbound'] as String?)?.trim().toLowerCase() ?? '';
      if (outbound != 'dns-out') {
        continue;
      }

      rule.remove('outbound');
      rule['action'] = 'hijack-dns';
      rawRules[i] = rule;
    }
  }

  void _normalizeTransportType(
    Map<String, Object?> outbound, {
    required SingboxTransportBuildMode transportBuildMode,
  }) {
    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    if (transport.isEmpty) {
      return;
    }

    final String rawType =
        (transport['type'] as String?)?.trim().toLowerCase() ?? '';
    final String? transportAlias = _readTransportAlias(outbound);
    if (transportAlias == 'xhttp' &&
        (rawType == 'httpupgrade' || rawType == 'http-upgrade')) {
      transport['type'] =
          transportBuildMode == SingboxTransportBuildMode.xrayCompat
          ? 'httpupgrade'
          : 'http';
      outbound['transport'] = transport;
      return;
    }
    if (rawType == 'xhttp') {
      transport['type'] =
          transportBuildMode == SingboxTransportBuildMode.xrayCompat
          ? 'httpupgrade'
          : 'http';
      outbound['transport'] = transport;
      return;
    }
    if (rawType == 'httpupgrade' || rawType == 'http-upgrade') {
      transport['type'] = 'httpupgrade';
      outbound['transport'] = transport;
      return;
    }
    if (rawType == 'h2' || rawType == 'http2') {
      transport['type'] = 'http';
      outbound['transport'] = transport;
    }
  }

  void _normalizeHttpUpgradeTransport(Map<String, Object?> outbound) {
    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    if (transport.isEmpty) {
      return;
    }

    final String transportType =
        (transport['type'] as String?)?.trim().toLowerCase() ?? '';
    if (transportType != 'httpupgrade') {
      return;
    }

    transport['path'] = _normalizeHttpUpgradePath(transport['path']);

    final String? host = _resolveHttpUpgradeHost(
      outbound: outbound,
      transport: transport,
    );
    if (host != null) {
      transport['host'] = host;
      final Map<String, Object?> headers = _asObjectMap(transport['headers']);
      headers['Host'] = host;
      headers.remove('host');
      headers.remove(':authority');
      headers.remove('authority');
      headers['User-Agent'] = _httpUpgradeUserAgent;
      transport['headers'] = headers;
    } else {
      final Map<String, Object?> headers = _asObjectMap(transport['headers']);
      headers.remove('Host');
      headers.remove('host');
      headers.remove(':authority');
      headers.remove('authority');
      headers['User-Agent'] = _httpUpgradeUserAgent;
      transport['headers'] = headers;
    }

    outbound['transport'] = transport;
  }

  void _normalizeHttpTransport(Map<String, Object?> outbound) {
    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    if (transport.isEmpty) {
      return;
    }

    final String transportType =
        (transport['type'] as String?)?.trim().toLowerCase() ?? '';
    if (transportType != 'http' &&
        transportType != 'h2' &&
        transportType != 'http2') {
      return;
    }

    final bool xhttpAlias = _readTransportAlias(outbound) == 'xhttp';
    transport['type'] = 'http';
    transport['path'] = xhttpAlias
        ? _normalizeXhttpPath(transport['path'])
        : _normalizeHttpUpgradePath(transport['path']);

    final String? host = _resolveHttpTransportHost(
      outbound: outbound,
      transport: transport,
    );
    if (host != null) {
      transport['host'] = <String>[host];
    } else {
      transport.remove('host');
    }

    final Map<String, Object?> headers = _asObjectMap(transport['headers']);
    // sing-box `http` transport already has dedicated `host`, so avoid
    // duplicate authority headers that can cause CDN request rejection.
    headers.remove('Host');
    headers.remove('host');
    headers.remove(':authority');
    headers.remove('authority');
    if (xhttpAlias) {
      bool hasUserAgent = false;
      for (final Object? key in headers.keys) {
        if (key is! String) {
          continue;
        }
        if (key.trim().toLowerCase() == 'user-agent') {
          hasUserAgent = true;
          break;
        }
      }
      if (!hasUserAgent) {
        headers['User-Agent'] = _httpUpgradeUserAgent;
      }
    }
    if (headers.isEmpty) {
      transport.remove('headers');
    } else {
      transport['headers'] = headers;
    }

    final String? method = _normalizedNonEmptyString(transport['method']);
    if (method != null) {
      transport['method'] = method.toUpperCase();
    } else if (xhttpAlias) {
      // xray/v2ray xhttp servers expect POST requests.
      // sing-box's http transport defaults to PUT when method is absent,
      // which causes xray xhttp servers to return 404 Not Found.
      // Explicitly set POST so the server accepts the vmess tunnel request.
      transport['method'] = 'POST';
    }

    if (xhttpAlias) {
      // Disable H2 PING health-check for xhttp. The default 15-second
      // idle_timeout causes sing-box to send H2 PING frames; if the xhttp
      // CDN server (a plain reverse proxy) replies with PROTOCOL_ERROR.
      // Setting to '0s' disables pings so connections stay alive.
      transport['idle_timeout'] = '0s';
    }

    outbound['transport'] = transport;
  }

  void _normalizeGrpcTransport(Map<String, Object?> outbound) {
    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    if (transport.isEmpty) {
      return;
    }

    final String transportType =
        (transport['type'] as String?)?.trim().toLowerCase() ?? '';
    if (transportType != 'grpc') {
      return;
    }

    transport['service_name'] = _normalizeGrpcServiceName(
      transport['service_name'],
    );

    final String? mode = _normalizedNonEmptyString(
      outbound[_grpcModeExtraKey],
    )?.toLowerCase();
    if (mode == 'multi') {
      // Best-effort compatibility with Xray-style grpc "multi" mode.
      transport['permit_without_stream'] = true;
    }

    final String? authority = _normalizedNonEmptyString(
      outbound[_grpcAuthorityExtraKey],
    );
    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    final String? tlsServerName = _normalizedNonEmptyString(tls['server_name']);
    final String? outboundSni = _normalizedNonEmptyString(outbound['sni']);
    final String? desiredAuthority = _firstNonEmptyString(<String?>[
      authority,
      tlsServerName,
      outboundSni,
    ]);

    if (desiredAuthority != null && !_looksLikeIpLiteral(desiredAuthority)) {
      // sing-box gRPC does not expose explicit :authority override.
      // Align dial host with authority/SNI to mimic Xray behavior and reduce
      // CDN 403 responses when origin routing depends on :authority.
      outbound['server'] = desiredAuthority;
      if (tls.isNotEmpty) {
        tls['server_name'] = desiredAuthority;
        outbound['tls'] = tls;
      }
    }

    outbound['transport'] = transport;
  }

  String _normalizeXhttpPath(Object? rawPath) {
    // Keep xHTTP path stable with a single leading slash only.
    // Do not force trailing slash because some servers validate exact path.
    return _normalizeHttpUpgradePath(rawPath);
  }

  String _normalizeHttpUpgradePath(Object? rawPath) {
    final String raw = (rawPath as String?)?.trim() ?? '';
    final String body = raw.replaceAll(RegExp(r'^/+'), '');
    return '/$body';
  }

  String _normalizeGrpcServiceName(Object? rawServiceName) {
    final String raw = (rawServiceName as String?)?.trim() ?? '';
    if (raw.isEmpty) {
      return 'grpc';
    }

    String normalized = raw.replaceFirst(RegExp(r'^/+'), '');
    if (normalized.toLowerCase().endsWith('/tun')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }

    final List<String> encodedSegments = <String>[];
    for (final String segment in normalized.split('/')) {
      final String token = segment.trim();
      if (token.isEmpty) {
        continue;
      }
      encodedSegments.add(Uri.encodeComponent(token));
    }
    if (encodedSegments.isEmpty) {
      return 'grpc';
    }
    return encodedSegments.join('/');
  }

  bool _looksLikeIpLiteral(String host) {
    if (host.contains(':')) {
      return true;
    }
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  }

  String? _firstNonEmptyString(List<String?> values) {
    for (final String? value in values) {
      if (value == null) {
        continue;
      }
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String? _resolveHttpUpgradeHost({
    required Map<String, Object?> outbound,
    required Map<String, Object?> transport,
  }) {
    final String? transportHost = _normalizedNonEmptyString(transport['host']);
    if (transportHost != null) {
      return transportHost;
    }

    final Map<String, Object?> headers = _asObjectMap(transport['headers']);
    final String? headerHost =
        _normalizedNonEmptyString(headers['Host']) ??
        _normalizedNonEmptyString(headers['host']) ??
        _normalizedNonEmptyString(headers[':authority']) ??
        _normalizedNonEmptyString(headers['authority']);
    if (headerHost != null) {
      return headerHost;
    }

    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    final String? tlsServerName = _normalizedNonEmptyString(tls['server_name']);
    if (tlsServerName != null) {
      return tlsServerName;
    }

    final String? outboundSni = _normalizedNonEmptyString(outbound['sni']);
    if (outboundSni != null) {
      return outboundSni;
    }

    return _normalizedNonEmptyString(outbound['server']);
  }

  String? _normalizedNonEmptyString(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final String normalized = raw.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _readTransportAlias(Map<String, Object?> outbound) {
    return _normalizedNonEmptyString(
      outbound[_transportAliasExtraKey],
    )?.toLowerCase();
  }

  void _applyHttpUpgradeAlpnDefaults(Map<String, Object?> outbound) {
    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    final String transportType =
        (transport['type'] as String?)?.trim().toLowerCase() ?? '';
    if (transportType != 'httpupgrade' && transportType != 'http-upgrade') {
      return;
    }

    if (_isSecurityNone(outbound)) {
      return;
    }

    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    final bool shouldAssumeTls =
        tls.isNotEmpty ||
        _isTlsSecurityEnabled(outbound) ||
        _isHttpsPort(outbound);
    if (!shouldAssumeTls) {
      return;
    }

    tls['enabled'] = true;
    if (_normalizedNonEmptyString(tls['server_name']) == null) {
      final String? serverName = _resolveHttpUpgradeHost(
        outbound: outbound,
        transport: transport,
      );
      if (serverName != null) {
        tls['server_name'] = serverName;
      }
    }
    // HTTP upgrade expects HTTP/1.1 semantics. Force ALPN strictly to
    // HTTP/1.1 to avoid receiving HTTP/2 SETTINGS frames.
    tls.remove('utls');
    tls['alpn'] = const <String>['http/1.1'];
    outbound['tls'] = tls;
  }

  void _applyHttpTransportAlpnDefaults(Map<String, Object?> outbound) {
    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    final String transportType =
        (transport['type'] as String?)?.trim().toLowerCase() ?? '';
    if (transportType != 'http' &&
        transportType != 'h2' &&
        transportType != 'http2') {
      return;
    }

    if (_isSecurityNone(outbound)) {
      return;
    }

    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    final bool shouldAssumeTls =
        tls.isNotEmpty ||
        _isTlsSecurityEnabled(outbound) ||
        _isHttpsPort(outbound);
    if (!shouldAssumeTls) {
      return;
    }

    final bool xhttpAlias = _readTransportAlias(outbound) == 'xhttp';
    tls['enabled'] = true;
    if (_normalizedNonEmptyString(tls['server_name']) == null) {
      final String? serverName = _resolveHttpTransportHost(
        outbound: outbound,
        transport: transport,
      );
      if (serverName != null) {
        tls['server_name'] = serverName;
      }
    }

    final List<String> alpn = _coerceTlsAlpnList(tls['alpn']);
    final List<String> normalizedAlpn = <String>[];
    for (final String value in alpn) {
      final String token = value.trim().toLowerCase();
      if (token.isEmpty ||
          token == 'none' ||
          token == 'off' ||
          token == 'false' ||
          token == '0') {
        continue;
      }
      String normalized = token;
      if (normalized == 'http/2' ||
          normalized == 'http2' ||
          normalized == 'h2-14' ||
          normalized == 'h2-16') {
        normalized = 'h2';
      } else if (normalized == 'http1.1') {
        normalized = 'http/1.1';
      } else if (normalized.startsWith('h3-')) {
        normalized = 'h3';
      }
      if (normalized != 'h3' &&
          normalized != 'h2' &&
          normalized != 'http/1.1') {
        continue;
      }
      if (!normalizedAlpn.contains(normalized)) {
        normalizedAlpn.add(normalized);
      }
    }

    if (xhttpAlias) {
      // Preserve explicit link ALPN order for xHTTP. Some CDN deployments
      // require HTTP/1.1-only or custom H2/H3 preference to avoid 400/404.
      if (normalizedAlpn.isEmpty) {
        tls['alpn'] = const <String>['h2', 'http/1.1'];
      } else {
        tls['alpn'] = normalizedAlpn;
      }
      // Prevent uTLS presets from silently reordering ALPN.
      tls.remove('utls');
    } else if (normalizedAlpn.isEmpty) {
      tls['alpn'] = const <String>['h2', 'http/1.1'];
    } else {
      tls['alpn'] = normalizedAlpn;
    }
    outbound['tls'] = tls;
  }

  void _applyGrpcAlpnDefaults(Map<String, Object?> outbound) {
    final Map<String, Object?> transport = _asObjectMap(outbound['transport']);
    final String transportType =
        (transport['type'] as String?)?.trim().toLowerCase() ?? '';
    if (transportType != 'grpc') {
      return;
    }
    if (_isSecurityNone(outbound)) {
      return;
    }

    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    final bool shouldAssumeTls =
        tls.isNotEmpty ||
        _isTlsSecurityEnabled(outbound) ||
        _isHttpsPort(outbound);
    if (!shouldAssumeTls) {
      return;
    }

    tls['enabled'] = true;
    // gRPC over v2ray transport must negotiate HTTP/2.
    tls['alpn'] = const <String>['h2'];
    outbound['tls'] = tls;
  }

  List<String> _coerceTlsAlpnList(Object? raw) {
    if (raw is List<Object?>) {
      return raw
          .map((Object? item) => item?.toString().trim() ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  String? _resolveHttpTransportHost({
    required Map<String, Object?> outbound,
    required Map<String, Object?> transport,
  }) {
    final Object? rawHost = transport['host'];
    if (rawHost is List<Object?>) {
      for (final Object? item in rawHost) {
        final String? value = _normalizedNonEmptyString(item);
        if (value != null) {
          return value;
        }
      }
    }
    final String? singleHost = _normalizedNonEmptyString(rawHost);
    if (singleHost != null) {
      return singleHost;
    }
    final Map<String, Object?> tls = _asObjectMap(outbound['tls']);
    final String? tlsServerName = _normalizedNonEmptyString(tls['server_name']);
    if (tlsServerName != null) {
      return tlsServerName;
    }
    return _normalizedNonEmptyString(outbound['server']);
  }

  bool _isSecurityNone(Map<String, Object?> outbound) {
    if (!_usesSecurityFieldForTls(outbound)) {
      return false;
    }
    final String? security = (outbound['security'] as String?)
        ?.trim()
        .toLowerCase();
    if (security == null) {
      return false;
    }
    return security.isEmpty ||
        security == 'none' ||
        security == 'false' ||
        security == '0';
  }

  bool _isTlsSecurityEnabled(Map<String, Object?> outbound) {
    if (!_usesSecurityFieldForTls(outbound)) {
      return false;
    }
    final String? security = (outbound['security'] as String?)
        ?.trim()
        .toLowerCase();
    if (security == null) {
      return false;
    }
    return security == 'tls' ||
        security == 'reality' ||
        security == 'true' ||
        security == '1';
  }

  bool _usesSecurityFieldForTls(Map<String, Object?> outbound) {
    final String type =
        (outbound['type'] as String?)?.trim().toLowerCase() ?? '';
    // In sing-box, `security` on VMess is cipher selection (auto/aes-128-gcm),
    // not TLS state.
    return type == 'vless' || type == 'trojan';
  }

  bool _isHttpsPort(Map<String, Object?> outbound) {
    final Object? rawPort = outbound['server_port'];
    if (rawPort is int) {
      return rawPort == 443;
    }
    if (rawPort is num) {
      return rawPort.toInt() == 443;
    }
    if (rawPort is String) {
      return int.tryParse(rawPort.trim()) == 443;
    }
    return false;
  }

  void _forceHttpUpgradeHttp11Alpn(
    Map<String, Object?> config, {
    required SingboxTransportBuildMode transportBuildMode,
  }) {
    final Object? rawOutbounds = config['outbounds'];
    if (rawOutbounds is! List<Object?>) {
      return;
    }

    for (int i = 0; i < rawOutbounds.length; i++) {
      final Object? item = rawOutbounds[i];
      if (item is! Map<Object?, Object?>) {
        continue;
      }

      final Map<String, Object?> outbound = _asObjectMap(item);
      _normalizeTransportType(outbound, transportBuildMode: transportBuildMode);
      _normalizeHttpUpgradeTransport(outbound);
      _normalizeHttpTransport(outbound);
      _normalizeGrpcTransport(outbound);
      _applyHttpUpgradeAlpnDefaults(outbound);
      _applyHttpTransportAlpnDefaults(outbound);
      _applyGrpcAlpnDefaults(outbound);
      outbound.remove(_transportAliasExtraKey);
      outbound.remove(_grpcAuthorityExtraKey);
      outbound.remove(_grpcModeExtraKey);
      rawOutbounds[i] = outbound;
    }
  }

  void _applyWarp({
    required List<Object?> outbounds,
    required Map<String, Object?> proxyOutbound,
    required WarpOptions settings,
    required void Function(String nextTag) onFinalOutboundChanged,
  }) {
    if (!settings.enableWarp || settings.outboundTemplate.isEmpty) {
      return;
    }

    final Map<String, Object?> warpOutbound = _cloneMap(
      settings.outboundTemplate,
    );
    final String warpTag =
        (warpOutbound['tag'] as String?)?.trim().isNotEmpty == true
        ? warpOutbound['tag'] as String
        : 'warp-out';
    warpOutbound['tag'] = warpTag;
    outbounds.insert(1, warpOutbound);

    switch (settings.detourMode) {
      case WarpDetourMode.detourProxiesThroughWarp:
        proxyOutbound['detour'] = warpTag;
        break;
      case WarpDetourMode.routeAllThroughWarp:
        onFinalOutboundChanged(warpTag);
        break;
    }
  }

  String _resolveLogLevel({
    required String runtimeLogLevel,
    required AdvancedOptions settings,
  }) {
    if (settings.logLevel != null && settings.logLevel!.isNotEmpty) {
      return settings.logLevel!.toLowerCase();
    }
    if (settings.debugMode) {
      return 'debug';
    }
    return runtimeLogLevel.toLowerCase();
  }

  Map<String, Object?> _asObjectMap(Object? value) {
    if (value is Map<Object?, Object?>) {
      final Map<String, Object?> output = <String, Object?>{};
      value.forEach((Object? key, Object? item) {
        if (key is String) {
          output[key] = item;
        }
      });
      return output;
    }
    return <String, Object?>{};
  }

  void _deepMergeMap(Map<String, Object?> target, Map<String, Object?> source) {
    source.forEach((String key, Object? value) {
      final Object? current = target[key];
      if (current is Map<Object?, Object?> && value is Map<Object?, Object?>) {
        final Map<String, Object?> mergedCurrent = _asObjectMap(current);
        _deepMergeMap(mergedCurrent, _asObjectMap(value));
        target[key] = mergedCurrent;
        return;
      }

      if (value is Map<Object?, Object?>) {
        target[key] = _cloneMap(_asObjectMap(value));
        return;
      }

      if (value is List<Object?>) {
        target[key] = _cloneList(value);
        return;
      }

      target[key] = value;
    });
  }

  Map<String, Object?> _cloneMap(Map<String, Object?> input) {
    final Map<String, Object?> output = <String, Object?>{};
    input.forEach((String key, Object? value) {
      if (value is Map<Object?, Object?>) {
        output[key] = _cloneMap(_asObjectMap(value));
      } else if (value is List<Object?>) {
        output[key] = _cloneList(value);
      } else {
        output[key] = value;
      }
    });
    return output;
  }

  List<Object?> _cloneList(List<Object?> input) {
    return input
        .map<Object?>((Object? value) {
          if (value is Map<Object?, Object?>) {
            return _cloneMap(_asObjectMap(value));
          }
          if (value is List<Object?>) {
            return _cloneList(value);
          }
          return value;
        })
        .toList(growable: false);
  }
}
