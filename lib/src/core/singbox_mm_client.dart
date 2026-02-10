import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../singbox_mm_platform_interface.dart';
export '../models/singbox_connect_results.dart';
import '../config/singbox_config_document.dart';
import '../config/singbox_config_builder.dart';
import '../config/sbmm_secure_link_codec.dart';
import '../config/vpn_config_parser.dart';
import '../config/vpn_subscription_parser.dart';
import '../models/bypass_policy.dart';
import '../models/gfw_preset_pack.dart';
import '../models/singbox_connect_results.dart';
import '../models/singbox_feature_settings.dart';
import '../models/singbox_runtime_options.dart';
import '../models/singbox_endpoint_summary.dart';
import '../models/traffic_throttle_policy.dart';
import '../models/vpn_connection_state.dart';
import '../models/vpn_connection_snapshot.dart';
import '../models/vpn_core_capabilities.dart';
import '../models/vpn_connectivity_probe.dart';
import '../models/vpn_diagnostics.dart';
import '../models/vpn_failover_options.dart';
import '../models/vpn_ping_result.dart';
import '../models/vpn_profile.dart';
import '../models/vpn_profile_summary.dart';
import '../models/vpn_runtime_stats.dart';
import 'singbox_mm_exception.dart';
part 'internal/singbox_mm_client_diagnostics_validation.dart';
part 'internal/singbox_mm_client_diagnostics_probe.dart';
part 'internal/singbox_mm_client_diagnostics_report_state.dart';
part 'internal/singbox_mm_client_diagnostics_report_checks.dart';
part 'internal/singbox_mm_client_diagnostics_report_builder.dart';
part 'internal/singbox_mm_client_endpoint_selection.dart';
part 'internal/singbox_mm_client_endpoint_health.dart';
part 'internal/singbox_mm_client_health_monitor.dart';
part 'internal/singbox_mm_client_health_tick.dart';
part 'internal/singbox_mm_client_health_tick_checks.dart';
part 'internal/singbox_mm_client_health_tick_traffic.dart';
part 'internal/singbox_mm_client_health_failover.dart';
part 'internal/singbox_mm_client_orchestration_shared.dart';
part 'internal/singbox_mm_client_orchestration_pool_apply.dart';
part 'internal/singbox_mm_client_orchestration_pool_switch.dart';
part 'internal/singbox_mm_client_orchestration_profile_apply.dart';
part 'internal/singbox_mm_client_orchestration_manual_connect.dart';
part 'internal/singbox_mm_client_orchestration_subscription_import.dart';
part 'internal/singbox_mm_client_orchestration_auto_connect.dart';
part 'internal/singbox_mm_client_platform.dart';
part 'internal/singbox_mm_client_network.dart';
part 'internal/singbox_mm_client_document.dart';
part 'internal/singbox_mm_client_lifecycle_core.dart';
part 'internal/singbox_mm_client_lifecycle_cleanup.dart';
part 'internal/singbox_mm_client_lifecycle_managed_state.dart';
part 'internal/singbox_mm_client_api_lifecycle.dart';
part 'internal/singbox_mm_client_api_endpoint.dart';
part 'internal/singbox_mm_client_api_config.dart';
part 'internal/singbox_mm_client_api_manual.dart';
part 'internal/singbox_mm_client_api_subscription.dart';
part 'internal/singbox_mm_client_api_runtime.dart';
part 'internal/singbox_mm_client_api_diagnostics.dart';
part 'internal/singbox_mm_client_core_capabilities.dart';
part 'internal/singbox_mm_client_utils.dart';
part 'internal/singbox_mm_client_foundation.dart';

class SignboxVpn {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  static const Set<VpnProtocol> _tlsRecommendedProtocols = <VpnProtocol>{
    VpnProtocol.vless,
    VpnProtocol.vmess,
    VpnProtocol.trojan,
    VpnProtocol.hysteria2,
    VpnProtocol.tuic,
  };

  SignboxVpn({
    SignboxVpnPlatform? platform,
    SingboxConfigBuilder configBuilder = const SingboxConfigBuilder(),
    VpnConfigParser configParser = const VpnConfigParser(),
    VpnSubscriptionParser subscriptionParser = const VpnSubscriptionParser(),
  }) : _platform = platform ?? SignboxVpnPlatform.instance,
       _configBuilder = configBuilder,
       _configParser = configParser,
       _subscriptionParser = subscriptionParser;

  final SignboxVpnPlatform _platform;
  final SingboxConfigBuilder _configBuilder;
  final VpnConfigParser _configParser;
  final VpnSubscriptionParser _subscriptionParser;
  SingboxRuntimeOptions _runtimeOptions = const SingboxRuntimeOptions();

  final List<VpnProfile> _endpointPool = <VpnProfile>[];
  final List<_EndpointHealthState> _endpointHealthStates =
      <_EndpointHealthState>[];
  final Map<String, int> _endpointMtuProbeCursorByTag = <String, int>{};
  VpnProfile? _standaloneProfile;

  int _activeEndpointIndex = -1;
  EndpointPoolOptions _endpointPoolOptions = const EndpointPoolOptions();
  BypassPolicy _endpointBypassPolicy = const BypassPolicy();
  TrafficThrottlePolicy _endpointThrottlePolicy = const TrafficThrottlePolicy();
  SingboxFeatureSettings _featureSettings = const SingboxFeatureSettings();
  SingboxFeatureSettings _endpointFeatureSettings =
      const SingboxFeatureSettings();
  _CoreCapabilityMatrix? _coreCapabilities;

  StreamSubscription<VpnConnectionState>? _managedStateSubscription;
  Timer? _healthTimer;
  VpnConnectionState _lastManagedState = VpnConnectionState.disconnected;
  bool _manualStopRequested = false;
  bool _failoverInProgress = false;

  int? _lastTotalBytes;
  DateTime? _lastTrafficProgressAt;
  bool _hasSeenTraffic = false;

  Stream<VpnConnectionState> get stateStream => _platform.stateStream;
  Stream<VpnConnectionSnapshot> get stateDetailsStream =>
      _platform.stateDetailsStream;
  Stream<VpnRuntimeStats> get statsStream => _platform.statsStream;
  SingboxFeatureSettings get featureSettings => _featureSettings;

  List<VpnProfile> get endpointPool =>
      List<VpnProfile>.unmodifiable(_endpointPool);

  VpnProfile? get activeEndpointProfile {
    if (_activeEndpointIndex < 0 ||
        _activeEndpointIndex >= _endpointPool.length) {
      return null;
    }
    return _endpointPool[_activeEndpointIndex];
  }

  VpnProfile? get activeProfile => activeEndpointProfile ?? _standaloneProfile;

  List<VpnEndpointHealth> get endpointHealth {
    final List<VpnEndpointHealth> output = <VpnEndpointHealth>[];
    for (int index = 0; index < _endpointPool.length; index++) {
      final _EndpointHealthState state = _endpointHealthStates[index];
      final VpnProfile profile = _endpointPool[index];
      output.add(
        VpnEndpointHealth(
          tag: profile.tag,
          score: state.score,
          consecutiveFailures: state.consecutiveFailures,
          lastSuccessAt: state.lastSuccessAt,
          lastFailureAt: state.lastFailureAt,
          lastProgressAt: state.lastProgressAt,
        ),
      );
    }
    return output;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    return _guardInternal(action);
  }
}
