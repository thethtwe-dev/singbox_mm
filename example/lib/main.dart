import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  runApp(const SignboxVpnDemoApp());
}

const String _defaultConfigLink =
    'vless://11111111-2222-3333-4444-555555555555@example.com:443?type=tcp&encryption=none&security=none#demo-node';
const String _defaultSubscription =
    'vless://11111111-2222-3333-4444-555555555555@edge-a.example.com:443?type=tcp&encryption=none&security=none#edge-a\n'
    'vless://11111111-2222-3333-4444-555555555556@edge-b.example.com:8443?type=tcp&encryption=none&security=none#edge-b';
const String _defaultPassphrase = 'sbmm-demo-passphrase';

class SignboxVpnDemoApp extends StatefulWidget {
  const SignboxVpnDemoApp({super.key});

  @override
  State<SignboxVpnDemoApp> createState() => _SignboxVpnDemoAppState();
}

class _SignboxVpnDemoAppState extends State<SignboxVpnDemoApp> {
  final SignboxVpn _vpn = SignboxVpn();
  final TextEditingController _configController = TextEditingController(
    text: _defaultConfigLink,
  );
  final TextEditingController _subscriptionController = TextEditingController(
    text: _defaultSubscription,
  );
  final TextEditingController _passphraseController = TextEditingController(
    text: _defaultPassphrase,
  );
  final TextEditingController _secureLinkController = TextEditingController();
  late final List<GfwPresetPack> _presetPacks = _vpn.listGfwPresetPacks();

  StreamSubscription<VpnConnectionState>? _stateSubscription;
  StreamSubscription<VpnConnectionSnapshot>? _stateDetailsSubscription;
  StreamSubscription<VpnRuntimeStats>? _statsSubscription;

  VpnConnectionState _state = VpnConnectionState.disconnected;
  VpnConnectionSnapshot _stateDetails = VpnConnectionSnapshot(
    state: VpnConnectionState.disconnected,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
  VpnRuntimeStats _stats = VpnRuntimeStats.empty();

  GfwPresetMode _selectedPresetMode = GfwPresetMode.balanced;
  bool _busy = false;
  String _message = 'Idle';
  final List<String> _activityLog = <String>[];

  Map<String, Object?>? _lastAppliedConfig;
  String? _lastAppliedConfigJson;
  VpnCoreCapabilities? _coreCapabilities;
  VpnProtocol? _currentConfigProtocol;
  bool? _currentConfigProtocolSupported;
  String? _currentConfigParseError;

  GfwPresetPack get _selectedPreset =>
      GfwPresetPack.fromMode(_selectedPresetMode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _stateSubscription = _vpn.stateStream.listen((
      VpnConnectionState nextState,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = nextState;
      });
    });

    _stateDetailsSubscription = _vpn.stateDetailsStream.listen((
      VpnConnectionSnapshot details,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stateDetails = details;
      });
    });

    _statsSubscription = _vpn.statsStream.listen((VpnRuntimeStats stats) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
      });
    });

    _configController.addListener(_onConfigInputsChanged);
    _passphraseController.addListener(_onConfigInputsChanged);

    _initializeRuntime();
  }

  late final WidgetsBindingObserver _lifecycleObserver = _DemoLifecycleObserver(
    onResume: _syncRuntimeOnResume,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _statsSubscription?.cancel();
    _stateSubscription?.cancel();
    _stateDetailsSubscription?.cancel();
    _configController.removeListener(_onConfigInputsChanged);
    _passphraseController.removeListener(_onConfigInputsChanged);
    _configController.dispose();
    _subscriptionController.dispose();
    _passphraseController.dispose();
    _secureLinkController.dispose();
    unawaited(_vpn.dispose());
    super.dispose();
  }

  Future<void> _initializeRuntime() async {
    await _runAction('Initialize Runtime', () async {
      await _vpn.initialize(
        const SingboxRuntimeOptions(
          logLevel: 'info',
          tunInterfaceName: 'sb-tun',
          tunInet4Address: '172.19.0.1/30',
          androidBinaryAssetByAbi: <String, String>{
            'arm64-v8a': 'assets/singbox/android/arm64-v8a/sing-box',
            'armeabi-v7a': 'assets/singbox/android/armeabi-v7a/sing-box',
            'x86_64': 'assets/singbox/android/x86_64/sing-box',
          },
        ),
      );
      await _ensureCoreCapabilitiesLoaded();
      await _refreshSnapshot();
      _setMessage('Runtime initialized.');
    });
  }

  void _onConfigInputsChanged() {
    _refreshConfigProtocolSupport();
  }

  Future<VpnCoreCapabilities> _ensureCoreCapabilitiesLoaded({
    bool refresh = false,
  }) async {
    if (!refresh && _coreCapabilities != null) {
      return _coreCapabilities!;
    }
    final VpnCoreCapabilities caps = await _vpn.getCoreCapabilities(
      refresh: refresh,
    );
    _coreCapabilities = caps;
    if (!mounted) {
      return caps;
    }
    setState(() {
      _coreCapabilities = caps;
    });
    _refreshConfigProtocolSupport();
    return caps;
  }

  void _refreshConfigProtocolSupport() {
    final String config = _configController.text.trim();
    VpnProtocol? protocol;
    bool? supported;
    String? parseError;

    if (config.isNotEmpty) {
      try {
        final ParsedVpnConfig parsed = _vpn.parseConfigLink(
          config,
          sbmmPassphrase: _optionalPassphrase(),
        );
        protocol = parsed.profile.protocol;
        final VpnCoreCapabilities? caps = _coreCapabilities;
        if (caps != null) {
          supported = caps.supportsProtocol(protocol);
        }
      } on Object catch (error) {
        parseError = error.toString();
      }
    }

    if (!mounted) {
      _currentConfigProtocol = protocol;
      _currentConfigProtocolSupported = supported;
      _currentConfigParseError = parseError;
      return;
    }

    setState(() {
      _currentConfigProtocol = protocol;
      _currentConfigProtocolSupported = supported;
      _currentConfigParseError = parseError;
    });
  }

  Future<void> _ensureCurrentConfigProtocolSupported() async {
    final VpnCoreCapabilities caps = await _ensureCoreCapabilitiesLoaded();
    final ParsedVpnConfig parsed = _vpn.parseConfigLink(
      _requireConfigLink(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    if (caps.supportsProtocol(parsed.profile.protocol)) {
      return;
    }
    throw SignboxVpnException(
      code: 'UNSUPPORTED_PROTOCOL_FOR_CORE',
      message:
          '${parsed.profile.protocol.wireValue} is not supported by current core '
          '(${caps.displayVersion}).',
    );
  }

  Future<void> _ensureSecureConfigProtocolSupported(String secureLink) async {
    final VpnCoreCapabilities caps = await _ensureCoreCapabilitiesLoaded();
    final ParsedVpnConfig parsed = _vpn.parseConfigLink(
      secureLink,
      sbmmPassphrase: _requirePassphrase(),
    );
    if (caps.supportsProtocol(parsed.profile.protocol)) {
      return;
    }
    throw SignboxVpnException(
      code: 'UNSUPPORTED_PROTOCOL_FOR_CORE',
      message:
          '${parsed.profile.protocol.wireValue} is not supported by current core '
          '(${caps.displayVersion}).',
    );
  }

  Future<void> _logSubscriptionCoreCompatibility(
    ParsedVpnSubscription parsed,
  ) async {
    final VpnCoreCapabilities caps = await _ensureCoreCapabilitiesLoaded();
    final Set<VpnProtocol> unsupported = parsed.profiles
        .map((VpnProfile profile) => profile.protocol)
        .where((VpnProtocol protocol) => !caps.supportsProtocol(protocol))
        .toSet();
    if (unsupported.isEmpty) {
      return;
    }
    _appendLog(
      'core unsupported in subscription (${caps.displayVersion}): '
      '${unsupported.map((VpnProtocol p) => p.wireValue).join(', ')}',
    );
  }

  Future<void> _syncRuntimeOnResume() async {
    try {
      await _vpn.syncRuntimeState();
      await _refreshSnapshot();
      _appendLog('Lifecycle resume -> runtime sync completed');
    } on Object {
      // Best effort during lifecycle resume.
    }
  }

  Future<void> _runAction(String label, Future<void> Function() action) async {
    if (_busy) {
      _setMessage('Busy, wait for current action to finish.');
      return;
    }

    setState(() {
      _busy = true;
    });
    _appendLog('$label: START');

    try {
      await action();
      _appendLog('$label: OK');
    } on SignboxVpnException catch (error) {
      _setMessage('${error.code}: ${error.message}');
      _appendLog('$label: FAIL ${error.code} ${error.message}');
    } on FormatException catch (error) {
      _setMessage('FORMAT_ERROR: ${error.message}');
      _appendLog('$label: FORMAT_ERROR ${error.message}');
    } on StateError catch (error) {
      _setMessage('STATE_ERROR: ${error.message}');
      _appendLog('$label: STATE_ERROR ${error.message}');
    } on Object catch (error) {
      _setMessage('UNEXPECTED: $error');
      _appendLog('$label: UNEXPECTED $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshSnapshot() async {
    final VpnConnectionState state = await _vpn.getState();
    final VpnConnectionSnapshot details = await _vpn.getStateDetails();
    final VpnRuntimeStats stats = await _vpn.getStats();
    if (!mounted) {
      return;
    }
    setState(() {
      _state = state;
      _stateDetails = details;
      _stats = stats;
    });
  }

  String _requireConfigLink() {
    final String config = _configController.text.trim();
    if (config.isEmpty) {
      throw const FormatException('Config link is empty.');
    }
    return config;
  }

  String _requireSubscription() {
    final String raw = _subscriptionController.text.trim();
    if (raw.isEmpty) {
      throw const FormatException('Subscription text is empty.');
    }
    return raw;
  }

  String _requirePassphrase() {
    final String passphrase = _passphraseController.text.trim();
    if (passphrase.isEmpty) {
      throw const FormatException('Passphrase is empty.');
    }
    return passphrase;
  }

  String? _optionalPassphrase() {
    final String passphrase = _passphraseController.text.trim();
    if (passphrase.isEmpty) {
      return null;
    }
    return passphrase;
  }

  void _rememberAppliedConfig(
    Map<String, Object?> config, {
    required String source,
  }) {
    final Map<String, Object?> copied = (jsonDecode(jsonEncode(config)) as Map)
        .cast<String, Object?>();
    final String pretty = const JsonEncoder.withIndent('  ').convert(copied);

    _lastAppliedConfig = copied;
    _lastAppliedConfigJson = pretty;

    int outboundCount = 0;
    final Object? outbounds = copied['outbounds'];
    if (outbounds is List<dynamic>) {
      outboundCount = outbounds.length;
    }

    _appendLog('$source: remembered config (outbounds=$outboundCount)');
  }

  void _appendLog(String message) {
    final String timestamp = DateTime.now().toIso8601String();
    final String line = '[$timestamp] $message';
    debugPrint('[singbox-demo] $line');

    if (!mounted) {
      return;
    }

    setState(() {
      _activityLog.add(line);
      if (_activityLog.length > 80) {
        _activityLog.removeRange(0, _activityLog.length - 80);
      }
    });
  }

  void _setMessage(String message) {
    _appendLog('MESSAGE: $message');
    if (!mounted) {
      return;
    }
    setState(() {
      _message = message;
    });
  }

  Future<void> _pasteConfigLink() async {
    final ClipboardData? clipboard = await Clipboard.getData(
      Clipboard.kTextPlain,
    );
    final String pasted = clipboard?.text?.trim() ?? '';
    if (pasted.isEmpty) {
      _setMessage('Clipboard is empty.');
      return;
    }
    _configController.text = pasted;
    _setMessage('Config pasted from clipboard.');
  }

  Future<void> _connectBasic() async {
    await _ensureCurrentConfigProtocolSupported();
    final ManualConnectResult result = await _vpn.connectManualConfigLink(
      configLink: _requireConfigLink(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    _rememberAppliedConfig(result.appliedConfig, source: 'connectBasic');
    await _refreshSnapshot();
    _setMessage('Connected (basic): ${result.profile.tag}');
  }

  Future<void> _connectHardened() async {
    await _ensureCurrentConfigProtocolSupported();
    final ManualConnectResult result = await _vpn
        .connectManualConfigLinkWithPreset(
          configLink: _requireConfigLink(),
          sbmmPassphrase: _optionalPassphrase(),
          preset: _selectedPreset,
        );
    _rememberAppliedConfig(result.appliedConfig, source: 'connectHardened');
    await _refreshSnapshot();
    _setMessage('Connected (${_selectedPreset.name}): ${result.profile.tag}');
  }

  Future<void> _connectManualProfileDirect() async {
    await _ensureCurrentConfigProtocolSupported();
    final ParsedVpnConfig parsed = _vpn.parseConfigLink(
      _requireConfigLink(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    final ManualConnectResult result = await _vpn.connectManualProfile(
      profile: parsed.profile,
      bypassPolicy: _selectedPreset.bypassPolicy,
      throttlePolicy: _selectedPreset.throttlePolicy,
      featureSettings: _selectedPreset.featureSettings,
    );
    _rememberAppliedConfig(
      result.appliedConfig,
      source: 'connectManualProfile',
    );
    await _refreshSnapshot();
    _setMessage('Connected (manual profile): ${result.profile.tag}');
    if (result.warnings.isNotEmpty) {
      _appendLog('manual profile warnings: ${result.warnings.join(' | ')}');
    }
  }

  Future<void> _connectManualPresetDirect() async {
    await _ensureCurrentConfigProtocolSupported();
    final ParsedVpnConfig parsed = _vpn.parseConfigLink(
      _requireConfigLink(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    final ManualConnectResult result = await _vpn.connectManualWithPreset(
      profile: parsed.profile,
      preset: _selectedPreset,
    );
    _rememberAppliedConfig(result.appliedConfig, source: 'connectManualPreset');
    await _refreshSnapshot();
    _setMessage(
      'Connected (manual preset ${_selectedPreset.name}): ${result.profile.tag}',
    );
    if (result.warnings.isNotEmpty) {
      _appendLog('manual preset warnings: ${result.warnings.join(' | ')}');
    }
  }

  Future<void> _connectWithSbmmLink() async {
    String secure = _secureLinkController.text.trim();
    if (secure.isEmpty) {
      secure = _vpn.wrapSecureConfigLink(
        configLink: _requireConfigLink(),
        passphrase: _requirePassphrase(),
      );
      _secureLinkController.text = secure;
    }

    await _ensureSecureConfigProtocolSupported(secure);

    final ManualConnectResult result = await _vpn.connectManualConfigLink(
      configLink: secure,
      sbmmPassphrase: _requirePassphrase(),
    );
    _rememberAppliedConfig(result.appliedConfig, source: 'connectSbmm');
    await _refreshSnapshot();
    _setMessage('Connected (sbmm): ${result.profile.tag}');
  }

  Future<void> _disconnect() async {
    await _vpn.stop();
    await _refreshSnapshot();
    _setMessage('VPN disconnected.');
  }

  Future<void> _restartVpn() async {
    await _vpn.restart();
    await _refreshSnapshot();
    _setMessage('VPN restarted.');
  }

  Future<void> _startVpn() async {
    await _vpn.start();
    await _refreshSnapshot();
    _setMessage('VPN start requested.');
  }

  Future<void> _startManaged() async {
    await _vpn.startManaged();
    await _refreshSnapshot();
    _setMessage('Managed mode started.');
  }

  Future<void> _resetProfile() async {
    await _vpn.resetProfile(stopVpn: true);
    _lastAppliedConfig = null;
    _lastAppliedConfigJson = null;
    await _refreshSnapshot();
    _setMessage('Profile reset complete.');
  }

  Future<void> _setPresetFeatureSettings() async {
    _vpn.setFeatureSettings(_selectedPreset.featureSettings);
    _setMessage('Feature settings set from preset: ${_selectedPreset.name}');
  }

  Future<void> _requestVpnPermission() async {
    final bool granted = await _vpn.requestVpnPermission();
    _setMessage('VPN permission: ${granted ? "granted" : "denied"}');
  }

  Future<void> _requestNotificationPermission() async {
    final bool granted = await _vpn.requestNotificationPermission();
    _setMessage(
      'Notification permission: ${granted ? "granted/available" : "denied"}',
    );
  }

  Future<void> _loadVersion() async {
    final String? version = await _vpn.getSingboxVersion();
    _setMessage(version ?? 'sing-box version unavailable');
  }

  Future<void> _loadCoreCapabilities() async {
    final VpnCoreCapabilities caps = await _ensureCoreCapabilitiesLoaded(
      refresh: true,
    );
    final String supported = caps.supportedProtocols
        .map((VpnProtocol protocol) => protocol.wireValue)
        .join(', ');
    _setMessage(
      'Core ${caps.displayVersion}: ${caps.supportedProtocols.length}/${VpnProtocol.values.length} protocols supported.',
    );
    _appendLog('core supported protocols: $supported');
  }

  Future<void> _loadLastError() async {
    final String? lastError = await _vpn.getLastError();
    _setMessage(lastError ?? 'No last error');
  }

  Future<void> _syncRuntime() async {
    await _vpn.syncRuntimeState();
    await _refreshSnapshot();
    _setMessage('Runtime synchronized.');
  }

  Future<void> _parseCurrentConfig() async {
    final String config = _requireConfigLink();
    final ParsedVpnConfig parsed = _vpn.parseConfigLink(
      config,
      sbmmPassphrase: _optionalPassphrase(),
    );
    final VpnProfileSummary summary = _vpn.extractConfigLinkSummary(
      config,
      sbmmPassphrase: _optionalPassphrase(),
    );
    final VpnProfileSummary profileSummary = _vpn.summarizeProfile(
      parsed.profile,
      warnings: parsed.warnings,
    );

    _setMessage(
      'Parsed ${parsed.scheme} -> ${summary.remark} @ ${summary.endpoint}',
    );
    _appendLog('summary.transport=${profileSummary.transport.wireValue}');
    if (parsed.warnings.isNotEmpty) {
      _appendLog('parse warnings: ${parsed.warnings.join(' | ')}');
    }
  }

  Future<void> _listPresetPacksFromApi() async {
    final List<GfwPresetPack> packs = _vpn.listGfwPresetPacks();
    _setMessage('Preset packs available: ${packs.length}');
    _appendLog(
      'preset names: ${packs.map((GfwPresetPack p) => p.name).join(', ')}',
    );
  }

  Future<void> _applyProfileDirect() async {
    await _ensureCurrentConfigProtocolSupported();
    final ParsedVpnConfig parsed = _vpn.parseConfigLink(
      _requireConfigLink(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    final Map<String, Object?> config = await _vpn.applyProfile(
      profile: parsed.profile,
    );
    _rememberAppliedConfig(config, source: 'applyProfileDirect');
    _setMessage('Profile applied only (not started): ${parsed.profile.tag}');
  }

  Future<void> _applyConfigLinkOnly() async {
    await _ensureCurrentConfigProtocolSupported();
    final Map<String, Object?> config = await _vpn.applyConfigLink(
      configLink: _requireConfigLink(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    _rememberAppliedConfig(config, source: 'applyConfigLink');
    _setMessage('Config link applied only (not started).');
  }

  Future<void> _wrapConfigLink() async {
    final String secure = _vpn.wrapSecureConfigLink(
      configLink: _requireConfigLink(),
      passphrase: _requirePassphrase(),
    );
    _secureLinkController.text = secure;
    _setMessage('Generated sbmm secure link.');
  }

  Future<void> _unwrapSecureLink() async {
    final String secure = _secureLinkController.text.trim();
    if (secure.isEmpty) {
      throw const FormatException('Secure link is empty.');
    }
    final String raw = _vpn.unwrapSecureConfigLink(
      sbmmLink: secure,
      passphrase: _requirePassphrase(),
    );
    _configController.text = raw;
    _setMessage('Secure link unwrapped into config field.');
  }

  Future<void> _validateActiveProfile() async {
    final VpnProfile? profile = _vpn.activeProfile;
    if (profile == null) {
      throw StateError('No active profile to validate.');
    }
    final List<VpnDiagnosticIssue> issues = _vpn.validateProfile(
      profile,
      strictTls: true,
    );
    _setMessage('Validation issues: ${issues.length}');
    if (issues.isNotEmpty) {
      _appendLog(
        'issue codes: ${issues.map((VpnDiagnosticIssue i) => i.code).join(', ')}',
      );
    }
  }

  Future<void> _probeConnectivity() async {
    final VpnConnectivityProbe probe = await _vpn.probeConnectivity();
    _setMessage(
      'Probe: success=${probe.success} status=${probe.statusCode ?? '-'} latency=${probe.latencyMs ?? '-'}ms',
    );
  }

  Future<void> _runDiagnostics() async {
    final VpnDiagnosticsReport report = await _vpn.runDiagnostics(
      strictTls: true,
      includeEndpointPoolPing: true,
      includeConnectivityProbe: true,
    );
    _setMessage(
      'Diagnostics: issues=${report.issues.length}, pings=${report.pingResults.length}, probe=${report.connectivityProbe?.success ?? false}',
    );
    if (report.issues.isNotEmpty) {
      _appendLog(
        'diagnostic codes: ${report.issues.map((VpnDiagnosticIssue i) => i.code).join(', ')}',
      );
    }
  }

  Future<void> _pingActiveProfile() async {
    final VpnProfile? profile = _vpn.activeProfile;
    if (profile == null) {
      throw StateError('No active profile available to ping.');
    }
    final VpnPingResult ping = await _vpn.pingProfile(profile: profile);
    _setMessage(
      'Ping active ${profile.tag}: success=${ping.success} latency=${ping.latencyMs ?? '-'}ms via ${ping.checkMethod}',
    );
  }

  Future<void> _pingEndpointPool() async {
    final List<VpnPingResult> results = await _vpn.pingEndpointPool();
    final int ok = results.where((VpnPingResult item) => item.success).length;
    final List<VpnPingResult> successful = results
        .where((VpnPingResult item) => item.success && item.latencyMs != null)
        .toList(growable: false);

    String latencySummary = '-';
    if (successful.isNotEmpty) {
      final int sum = successful.fold<int>(
        0,
        (int acc, VpnPingResult item) => acc + (item.latencyMs ?? 0),
      );
      final int avg = (sum / successful.length).round();
      latencySummary = '${avg}ms avg';
    }

    _setMessage(
      'Ping pool: $ok/${results.length} successful ($latencySummary)',
    );

    if (results.isNotEmpty) {
      final String lines = results
          .map(
            (VpnPingResult item) =>
                '${item.tag}: ${item.success ? '${item.latencyMs ?? '-'}ms (${item.checkMethod})' : 'fail (${item.checkMethod})'}',
          )
          .join(' | ');
      _appendLog('ping pool detail: $lines');
    }
  }

  Future<void> _parseSubscriptionText() async {
    final ParsedVpnSubscription parsed = _vpn.parseSubscription(
      _requireSubscription(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    await _logSubscriptionCoreCompatibility(parsed);
    final List<VpnProfileSummary> summaries = _vpn.extractSubscriptionSummaries(
      _requireSubscription(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    _setMessage(
      'Subscription parsed: profiles=${parsed.profiles.length}, failures=${parsed.failures.length}',
    );
    if (summaries.isNotEmpty) {
      _appendLog(
        'subscription tags: ${summaries.take(5).map((VpnProfileSummary s) => s.remark).join(', ')}',
      );
    }
  }

  Future<void> _extractSubscriptionSummariesOnly() async {
    final List<VpnProfileSummary> summaries = _vpn.extractSubscriptionSummaries(
      _requireSubscription(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    _setMessage('Subscription summaries: ${summaries.length}');
    if (summaries.isNotEmpty) {
      _appendLog(
        'top summaries: ${summaries.take(5).map((VpnProfileSummary s) => s.remark).join(', ')}',
      );
    }
  }

  Future<void> _applyEndpointPoolDirect() async {
    final ParsedVpnSubscription parsed = _vpn.parseSubscription(
      _requireSubscription(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    await _logSubscriptionCoreCompatibility(parsed);
    if (parsed.profiles.isEmpty) {
      throw StateError('No valid profiles to apply as endpoint pool.');
    }

    final Map<String, Object?> config = await _vpn.applyEndpointPool(
      profiles: parsed.profiles,
      options: _selectedPreset.endpointPoolOptions,
      bypassPolicy: _selectedPreset.bypassPolicy,
      throttlePolicy: _selectedPreset.throttlePolicy,
      featureSettings: _selectedPreset.featureSettings,
    );
    _rememberAppliedConfig(config, source: 'applyEndpointPool');
    _setMessage(
      'Endpoint pool applied (${parsed.profiles.length} profiles, not started).',
    );
  }

  Future<void> _importSubscription() async {
    final ParsedVpnSubscription parsed = _vpn.parseSubscription(
      _requireSubscription(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    await _logSubscriptionCoreCompatibility(parsed);
    final SubscriptionImportResult result = await _vpn.importSubscription(
      rawSubscription: _subscriptionController.text.trim(),
      source: 'example-ui',
      sbmmPassphrase: _optionalPassphrase(),
      connect: false,
      options: _selectedPreset.endpointPoolOptions,
      bypassPolicy: _selectedPreset.bypassPolicy,
      throttlePolicy: _selectedPreset.throttlePolicy,
      featureSettings: _selectedPreset.featureSettings,
    );
    if (result.appliedConfig != null) {
      _rememberAppliedConfig(
        result.appliedConfig!,
        source: 'importSubscription',
      );
    }
    _setMessage(
      'Imported ${result.importedCount} profiles, invalid=${result.invalidCount}, pool=${result.poolSize}',
    );
  }

  Future<void> _connectAutoSubscription() async {
    final ParsedVpnSubscription parsed = _vpn.parseSubscription(
      _requireSubscription(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    await _logSubscriptionCoreCompatibility(parsed);
    final AutoConnectResult result = await _vpn.connectAutoSubscription(
      rawSubscription: _subscriptionController.text.trim(),
      source: 'example-ui',
      sbmmPassphrase: _optionalPassphrase(),
      options: _selectedPreset.endpointPoolOptions,
      bypassPolicy: _selectedPreset.bypassPolicy,
      throttlePolicy: _selectedPreset.throttlePolicy,
      featureSettings: _selectedPreset.featureSettings,
      preferLowestLatency: true,
    );
    if (result.importResult.appliedConfig != null) {
      _rememberAppliedConfig(
        result.importResult.appliedConfig!,
        source: 'connectAutoSubscription',
      );
    }
    await _refreshSnapshot();
    _setMessage(
      'Auto connected: ${result.selectedProfile?.tag ?? '-'} (imported ${result.importResult.importedCount})',
    );
  }

  Future<void> _connectAutoWithPreset() async {
    final ParsedVpnSubscription parsed = _vpn.parseSubscription(
      _requireSubscription(),
      sbmmPassphrase: _optionalPassphrase(),
    );
    await _logSubscriptionCoreCompatibility(parsed);
    final AutoConnectResult result = await _vpn.connectAutoWithPreset(
      rawSubscription: _subscriptionController.text.trim(),
      source: 'example-ui',
      sbmmPassphrase: _optionalPassphrase(),
      preset: _selectedPreset,
      preferLowestLatency: true,
    );
    if (result.importResult.appliedConfig != null) {
      _rememberAppliedConfig(
        result.importResult.appliedConfig!,
        source: 'connectAutoWithPreset',
      );
    }
    await _refreshSnapshot();
    _setMessage('Auto preset connected: ${result.selectedProfile?.tag ?? '-'}');
  }

  Future<void> _rotateEndpoint() async {
    final VpnProfile? next = await _vpn.rotateEndpoint(reconnect: true);
    await _refreshSnapshot();
    _setMessage('Rotated endpoint: ${next?.tag ?? '-'}');
  }

  Future<void> _selectBestEndpoint() async {
    final VpnProfile? best = await _vpn.selectBestEndpointByPing(
      timeout: const Duration(seconds: 3),
      reconnect: false,
    );
    await _refreshSnapshot();
    _setMessage('Best endpoint selected: ${best?.tag ?? '-'}');
  }

  Future<void> _selectSecondEndpoint() async {
    if (_vpn.endpointPool.length < 2) {
      throw StateError('Need at least 2 endpoints in pool.');
    }
    final VpnProfile? selected = await _vpn.selectEndpoint(
      index: 1,
      reconnect: false,
    );
    await _refreshSnapshot();
    _setMessage('Selected endpoint index=1 -> ${selected?.tag ?? '-'}');
  }

  Future<void> _extractDocEndpoints() async {
    final String? configJson = _lastAppliedConfigJson;
    if (configJson == null || configJson.isEmpty) {
      throw StateError('No applied config in memory yet.');
    }
    final List<SingboxEndpointSummary> endpoints = _vpn.extractConfigEndpoints(
      configJson,
    );
    _setMessage('Document endpoints: ${endpoints.length}');
    if (endpoints.isNotEmpty) {
      final SingboxEndpointSummary first = endpoints.first;
      _appendLog(
        'first endpoint tag=${first.tag ?? '-'} server=${first.server ?? '-'}:${first.serverPort ?? '-'}',
      );
    }
  }

  Future<void> _applyDocPatch() async {
    final String? configJson = _lastAppliedConfigJson;
    if (configJson == null || configJson.isEmpty) {
      throw StateError('No applied config in memory yet.');
    }

    final SingboxConfigDocument document = _vpn.parseConfigDocument(configJson);
    final List<SingboxEndpointSummary> endpoints = document.endpointSummaries();
    if (endpoints.isEmpty) {
      throw StateError('No outbound endpoint found in document.');
    }

    final SingboxEndpointSummary first = endpoints.first;
    final String nextRemark = '${first.remark ?? first.tag ?? 'node'}-demo';
    document.updateEndpoint(
      outboundIndex: first.outboundIndex,
      remark: nextRemark,
    );
    await _vpn.applyConfigDocument(document);

    final String pretty = document.toJson(pretty: true);
    _lastAppliedConfigJson = pretty;
    _lastAppliedConfig = (jsonDecode(pretty) as Map).cast<String, Object?>();

    _setMessage(
      'Config document patch applied: ${first.tag ?? '-'} -> $nextRemark',
    );
  }

  Future<void> _reapplyRawConfig() async {
    final Map<String, Object?>? config = _lastAppliedConfig;
    if (config == null) {
      throw StateError('No applied config in memory yet.');
    }
    await _vpn.setRawConfig(config);
    _setMessage('Re-applied raw config from memory.');
  }

  Widget _actionButton(
    String label,
    Future<void> Function() action, {
    bool enabled = true,
  }) {
    return ElevatedButton(
      onPressed: _busy || !enabled ? null : () => _runAction(label, action),
      child: Text(label),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final VpnProfile? active = _vpn.activeProfile;
    final List<VpnEndpointHealth> endpointHealth = _vpn.endpointHealth;
    final String endpointHealthSummary = endpointHealth.isEmpty
        ? '-'
        : endpointHealth
              .take(3)
              .map((VpnEndpointHealth item) => '${item.tag}:${item.score}')
              .join(' | ');
    final String coreVersion = _coreCapabilities?.displayVersion ?? '-';
    final String currentProtocol = _currentConfigProtocol?.wireValue ?? '-';
    final String currentProtocolStatus =
        switch (_currentConfigProtocolSupported) {
          true => 'supported',
          false => 'unsupported',
          null => 'unknown',
        };
    final bool configProtocolAllowed = _currentConfigProtocolSupported != false;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Singbox MM Full API Demo')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('State: ${_state.wireValue}'),
                        Text(
                          'Detail: ${_stateDetails.detailCode ?? '-'} '
                          '/ validated=${_stateDetails.networkValidated?.toString() ?? 'unknown'}',
                        ),
                        if (_stateDetails.privateDnsServerName != null)
                          Text(
                            'Private DNS: ${_stateDetails.privateDnsServerName}',
                          ),
                        Text('Active Profile: ${active?.tag ?? '-'}'),
                        Text('Endpoint Pool: ${_vpn.endpointPool.length}'),
                        Text('Endpoint Health: $endpointHealthSummary'),
                        Text('Core: $coreVersion'),
                        Text(
                          'Config Protocol: $currentProtocol ($currentProtocolStatus)',
                        ),
                        if (_currentConfigParseError != null &&
                            _currentConfigParseError!.isNotEmpty)
                          Text(
                            'Config Parse: ${_currentConfigParseError!}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text('Down Speed: ${_stats.formattedDownloadSpeed}'),
                        Text('Up Speed: ${_stats.formattedUploadSpeed}'),
                        Text('Total Down: ${_stats.formattedTotalDownloaded}'),
                        Text('Total Up: ${_stats.formattedTotalUploaded}'),
                        Text('Duration: ${_stats.formattedDuration}'),
                        const SizedBox(height: 8),
                        Text(
                          'Message: $_message',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _configController,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Config Link',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passphraseController,
                  minLines: 1,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'SBMM Passphrase',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _secureLinkController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'SBMM Secure Link',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _subscriptionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Subscription (newline separated links)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GfwPresetMode>(
                  initialValue: _selectedPresetMode,
                  decoration: const InputDecoration(
                    labelText: 'Preset',
                    border: OutlineInputBorder(),
                  ),
                  items: _presetPacks
                      .map(
                        (GfwPresetPack preset) =>
                            DropdownMenuItem<GfwPresetMode>(
                              value: preset.mode,
                              child: Text(
                                '${preset.name} (${preset.mode.name})',
                              ),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: _busy
                      ? null
                      : (GfwPresetMode? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedPresetMode = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedPreset.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _buildSection('Connection', <Widget>[
                  _actionButton('Paste Config', _pasteConfigLink),
                  _actionButton(
                    'Connect Basic',
                    _connectBasic,
                    enabled: configProtocolAllowed,
                  ),
                  _actionButton(
                    'Connect Hardened',
                    _connectHardened,
                    enabled: configProtocolAllowed,
                  ),
                  _actionButton(
                    'Connect Manual Profile',
                    _connectManualProfileDirect,
                    enabled: configProtocolAllowed,
                  ),
                  _actionButton(
                    'Connect Manual Preset',
                    _connectManualPresetDirect,
                    enabled: configProtocolAllowed,
                  ),
                  _actionButton('Connect SBMM', _connectWithSbmmLink),
                  _actionButton('Start', _startVpn),
                  _actionButton('Start Managed', _startManaged),
                  _actionButton('Disconnect', _disconnect),
                  _actionButton('Restart', _restartVpn),
                  _actionButton('Reset Profile', _resetProfile),
                ]),
                const SizedBox(height: 16),
                _buildSection('Config / Profile APIs', <Widget>[
                  _actionButton(
                    'Set Preset Features',
                    _setPresetFeatureSettings,
                  ),
                  _actionButton('List Presets', _listPresetPacksFromApi),
                  _actionButton('Parse Config', _parseCurrentConfig),
                  _actionButton(
                    'Apply Profile',
                    _applyProfileDirect,
                    enabled: configProtocolAllowed,
                  ),
                  _actionButton(
                    'Apply Config Link',
                    _applyConfigLinkOnly,
                    enabled: configProtocolAllowed,
                  ),
                  _actionButton('Wrap SBMM', _wrapConfigLink),
                  _actionButton('Unwrap SBMM', _unwrapSecureLink),
                  _actionButton('Validate Active', _validateActiveProfile),
                  _actionButton('Doc Endpoints', _extractDocEndpoints),
                  _actionButton('Doc Patch Apply', _applyDocPatch),
                  _actionButton('Reapply Raw Config', _reapplyRawConfig),
                ]),
                const SizedBox(height: 16),
                _buildSection('Subscription / Endpoint Pool APIs', <Widget>[
                  _actionButton('Parse Subscription', _parseSubscriptionText),
                  _actionButton(
                    'Extract Summaries',
                    _extractSubscriptionSummariesOnly,
                  ),
                  _actionButton('Import Subscription', _importSubscription),
                  _actionButton(
                    'Apply Endpoint Pool',
                    _applyEndpointPoolDirect,
                  ),
                  _actionButton('Auto Connect', _connectAutoSubscription),
                  _actionButton('Auto Connect Preset', _connectAutoWithPreset),
                  _actionButton('Rotate Endpoint', _rotateEndpoint),
                  _actionButton('Select Best Endpoint', _selectBestEndpoint),
                  _actionButton('Select Endpoint #2', _selectSecondEndpoint),
                  _actionButton('Ping Pool', _pingEndpointPool),
                ]),
                const SizedBox(height: 16),
                _buildSection('Runtime / Diagnostics APIs', <Widget>[
                  _actionButton('Refresh Snapshot', _refreshSnapshot),
                  _actionButton('Request VPN Perm', _requestVpnPermission),
                  _actionButton(
                    'Request Noti Perm',
                    _requestNotificationPermission,
                  ),
                  _actionButton('Sync Runtime', _syncRuntime),
                  _actionButton('Ping Active', _pingActiveProfile),
                  _actionButton('Probe Connectivity', _probeConnectivity),
                  _actionButton('Run Diagnostics', _runDiagnostics),
                  _actionButton('Load Version', _loadVersion),
                  _actionButton('Core Capabilities', _loadCoreCapabilities),
                  _actionButton('Load Last Error', _loadLastError),
                ]),
                const SizedBox(height: 16),
                Text(
                  'Activity Log',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 120),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _activityLog.reversed.join('\n'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                if (_busy)
                  const Row(
                    children: <Widget>[
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Running action...'),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoLifecycleObserver with WidgetsBindingObserver {
  _DemoLifecycleObserver({required this.onResume});

  final Future<void> Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onResume());
    }
  }
}
