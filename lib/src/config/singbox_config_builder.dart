import 'internal/singbox_dns_builder.dart';
import 'internal/singbox_inbound_builder.dart';
import 'internal/singbox_route_rules_builder.dart';
import '../models/bypass_policy.dart';
import '../models/singbox_feature_settings.dart';
import '../models/traffic_throttle_policy.dart';
import '../models/vpn_profile.dart';

class SingboxConfigBuilder {
  const SingboxConfigBuilder();

  static const SingboxInboundBuilder _inboundBuilder = SingboxInboundBuilder();
  static const SingboxDnsBuilder _dnsBuilder = SingboxDnsBuilder();
  static const SingboxRouteRulesBuilder _routeRulesBuilder =
      SingboxRouteRulesBuilder();

  Map<String, Object?> build({
    required VpnProfile profile,
    BypassPolicy bypassPolicy = const BypassPolicy(),
    TrafficThrottlePolicy throttlePolicy = const TrafficThrottlePolicy(),
    SingboxFeatureSettings settings = const SingboxFeatureSettings(),
    String logLevel = 'info',
    String tunInterfaceName = 'sb-tun',
    String tunInet4Address = '172.19.0.1/30',
  }) {
    final bool forceIpv4Only = _shouldForceIpv4Only(
      profile: profile,
      settings: settings,
    );
    final bool disableIpv6TunCapture = _shouldDisableIpv6TunCapture(
      profile: profile,
      settings: settings,
    );
    final Map<String, Object?> proxyOutbound = profile.toOutboundJson(
      throttle: throttlePolicy,
    );
    if (forceIpv4Only) {
      proxyOutbound['domain_strategy'] = 'ipv4_only';
    }
    _applyTransportCompatibility(proxyOutbound, profile);
    _applyTlsTricks(proxyOutbound, settings.tlsTricks);

    final List<Object?> outbounds = <Object?>[
      proxyOutbound,
      <String, Object?>{'type': 'direct', 'tag': 'direct'},
      <String, Object?>{'type': 'block', 'tag': 'block'},
      <String, Object?>{'type': 'dns', 'tag': 'dns-out'},
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
      throttlePolicy: throttlePolicy,
      tunInterfaceName: tunInterfaceName,
      tunInet4Address: tunInet4Address,
      disableIpv6Capture: disableIpv6TunCapture,
    );

    final Map<String, Object?> dns = _dnsBuilder.build(
      profile: profile,
      bypassPolicy: bypassPolicy,
      throttlePolicy: throttlePolicy,
      settings: settings,
      forceIpv4Only: forceIpv4Only,
    );

    final List<Object?> routeRules = _routeRulesBuilder.build(
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
      },
      'experimental': experimental,
    };

    if (settings.rawConfigPatch.isNotEmpty) {
      _deepMergeMap(config, settings.rawConfigPatch);
    }

    return config;
  }

  void _applyTransportCompatibility(
    Map<String, Object?> outbound,
    VpnProfile profile,
  ) {
    final bool streamTransport =
        profile.transport == VpnTransport.tcp ||
        profile.transport == VpnTransport.ws ||
        profile.transport == VpnTransport.grpc ||
        profile.transport == VpnTransport.httpUpgrade;
    if (!streamTransport) {
      return;
    }

    switch (profile.protocol) {
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
        outbound['udp_fragment'] = false;
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

  bool _shouldDisableIpv6TunCapture({
    required VpnProfile profile,
    required SingboxFeatureSettings settings,
  }) {
    if (settings.route.ipv6RouteMode != SingboxIpv6RouteMode.disable) {
      return false;
    }
    switch (profile.protocol) {
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
        return true;
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
      case VpnProtocol.shadowsocks:
      case VpnProtocol.wireguard:
      case VpnProtocol.ssh:
        return false;
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
