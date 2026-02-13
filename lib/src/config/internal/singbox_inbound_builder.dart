import '../../models/singbox_feature_settings.dart';
import '../../models/traffic_throttle_policy.dart';

class SingboxInboundBuilder {
  const SingboxInboundBuilder();

  List<Object?> build({
    required SingboxFeatureSettings settings,
    required TrafficThrottlePolicy throttlePolicy,
    required String tunInterfaceName,
    required String tunInet4Address,
    required bool disableIpv6Capture,
  }) {
    final List<Object?> inbounds = <Object?>[];
    final bool sniff = settings.route.resolveDestination;
    final bool shareLan = settings.inbound.shareVpnInLocalNetwork;

    if (settings.inbound.serviceMode == SingboxServiceMode.vpn) {
      final List<String> includePackages = _dedupeStrings(
        settings.inbound.includePackages,
      );
      final List<String> excludePackages = _dedupeStrings(
        settings.inbound.excludePackages,
      );
      final bool splitTunnelingEnabled =
          settings.inbound.splitTunnelingEnabled ??
          (includePackages.isNotEmpty || excludePackages.isNotEmpty);
      // Keep IPv6 TUN capture for strict-route VPN mode to avoid
      // app-level IPv6 "No route to host" failures on stacks that prefer AAAA.
      final bool captureIpv6InTun =
          settings.route.ipv6RouteMode != SingboxIpv6RouteMode.disable
          ? true
          : !disableIpv6Capture && settings.inbound.strictRoute;
      final Map<String, Object?> tunInbound = <String, Object?>{
        'type': 'tun',
        'tag': 'tun-in',
        'interface_name': tunInterfaceName,
        'inet4_address': tunInet4Address,
        'auto_route': true,
        'strict_route': settings.inbound.strictRoute,
        'stack': _toTunStack(settings.inbound.tunImplementation),
        'mtu': throttlePolicy.tunMtu,
        'sniff': sniff,
      };

      if (captureIpv6InTun) {
        tunInbound['inet6_address'] = 'fdfe:dcba:9876::1/126';
      }
      if (splitTunnelingEnabled && includePackages.isNotEmpty) {
        tunInbound['include_package'] = includePackages;
      }
      if (splitTunnelingEnabled && excludePackages.isNotEmpty) {
        tunInbound['exclude_package'] = excludePackages;
      }

      inbounds.add(tunInbound);
    }

    final int? mixedPort = settings.inbound.mixedPort;
    if (mixedPort != null ||
        settings.inbound.serviceMode == SingboxServiceMode.proxyOnly) {
      inbounds.add(<String, Object?>{
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': shareLan ? '0.0.0.0' : '127.0.0.1',
        'listen_port': mixedPort ?? 10808,
        'sniff': sniff,
      });
    }

    final int? transparentProxyPort = settings.inbound.transparentProxyPort;
    if (transparentProxyPort != null) {
      inbounds.add(<String, Object?>{
        'type': 'redirect',
        'tag': 'redirect-in',
        'listen': shareLan ? '0.0.0.0' : '127.0.0.1',
        'listen_port': transparentProxyPort,
        'sniff': sniff,
      });
    }

    return inbounds;
  }

  String _toTunStack(SingboxTunImplementation implementation) {
    switch (implementation) {
      case SingboxTunImplementation.system:
        return 'system';
      case SingboxTunImplementation.gvisor:
        return 'gvisor';
    }
  }

  List<String> _dedupeStrings(List<String> input) {
    final Set<String> output = <String>{};
    for (final String raw in input) {
      final String value = raw.trim();
      if (value.isNotEmpty) {
        output.add(value);
      }
    }
    return output.toList(growable: false);
  }
}
