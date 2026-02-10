# singbox_mm

A Flutter VPN plugin that drives a `sing-box` runtime with a high-level Dart API.

The package focuses on:
- GFW-resistant routing presets.
- Traffic-throttling countermeasures (uTLS, multiplex, optional TCP brutal).
- A typed profile/config builder instead of raw JSON strings.
- Runtime controls (`initialize`, `setConfig`, `start/stop/restart`) with state + stats streaming.

Supported protocols in the current model:
- `vless`
- `vmess`
- `trojan`
- `shadowsocks` (`ss://`)
- `hysteria2` (`hysteria://` / `hysteria2://` / `hy2://`)
- `tuic`
- `wireguard` (`wireguard://` / `wg://`)
- `ssh` (`ssh://`)

WireGuard outbound in sing-box is deprecated in `1.11.x` and removed in `1.13.x`; keep this in mind when choosing core versions.
Runtime capability guard is enabled: when core version is `>= 1.13.0`, WireGuard profiles are rejected (or filtered out from endpoint pools) before config apply.

You can inspect runtime capabilities directly:

```dart
final VpnCoreCapabilities core = await vpn.getCoreCapabilities();
print(core.displayVersion);
print(core.supportsProtocol(VpnProtocol.vless)); // true
print(core.supportsProtocol(VpnProtocol.wireguard)); // false on >= 1.13.0

final bool canUseWireGuard = await vpn.isProtocolSupportedByCore(
  VpnProtocol.wireguard,
);
final List<VpnProfile> supportedOnly = await vpn.filterProfilesByCoreSupport(
  profiles: subscriptionProfiles,
);
```

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  singbox_mm: ^0.1.0
```

For local development in a monorepo, you can still use a path dependency:

```yaml
dependencies:
  singbox_mm:
    path: ../singbox_mm
```

## Platform Support

- Android: fully supported runtime through bundled `libbox` JNI bridge.
- iOS: API surface is available, but production tunnel requires host-side `NetworkExtension` (`PacketTunnelProvider`) integration.

## Dart API

```dart
import 'package:singbox_mm/singbox_mm.dart';

final vpn = SignboxVpn();

await vpn.initialize(
  const SingboxRuntimeOptions(
    logLevel: 'info',
    tunInterfaceName: 'sb-tun',
    androidBinaryAssetByAbi: <String, String>{
      'arm64-v8a': 'assets/singbox/android/arm64-v8a/sing-box',
      'armeabi-v7a': 'assets/singbox/android/armeabi-v7a/sing-box',
      'x86_64': 'assets/singbox/android/x86_64/sing-box',
    },
  ),
);

final granted = await vpn.requestVpnPermission();
if (!granted) {
  throw Exception('VPN permission denied');
}

final notificationGranted = await vpn.requestNotificationPermission();
if (!notificationGranted) {
  throw Exception('Notification permission denied');
}

final profile = VpnProfile.vless(
  tag: 'proxy-main',
  server: 'example.com',
  serverPort: 443,
  uuid: '00000000-0000-0000-0000-000000000000',
  transport: VpnTransport.ws,
  websocketPath: '/ws',
  tls: const TlsOptions(
    enabled: true,
    serverName: 'example.com',
    utlsFingerprint: 'chrome',
  ),
);

await vpn.applyProfile(
  profile: profile,
  bypassPolicy: const BypassPolicy(
    preset: BypassPolicyPreset.aggressive,
    directDomains: <String>['lan', 'local'],
  ),
  throttlePolicy: const TrafficThrottlePolicy(
    enableMultiplex: true,
    enableTcpBrutal: true,
  ),
);

await vpn.start();
```

## Advanced Settings Surface (Dashboard-style)

The package now exposes a typed settings model that matches modern VPN
settings screens (advanced, route, DNS, inbound, TLS tricks, WARP, misc):

```dart
final settings = SingboxFeatureSettings(
  advanced: const AdvancedOptions(
    memoryLimit: true,
    debugMode: false,
    logLevel: 'warn',
  ),
  route: const RouteOptions(
    region: 'other',
    blockAdvertisements: true,
    bypassLan: true,
    resolveDestination: true,
    ipv6RouteMode: SingboxIpv6RouteMode.disable,
  ),
  dns: const DnsOptions(
    providerPreset: DnsProviderPreset.cloudflare,
    remoteDns: 'udp://1.1.1.1',
    directDns: '1.1.1.1',
    enableDnsRouting: true,
  ),
  inbound: const InboundOptions(
    serviceMode: SingboxServiceMode.vpn,
    strictRoute: true,
    tunImplementation: SingboxTunImplementation.gvisor,
    mixedPort: 12334,
    transparentProxyPort: 12335,
    shareVpnInLocalNetwork: false,
    includePackages: <String>['com.android.chrome'],
    excludePackages: <String>['com.example.bank'],
  ),
  tlsTricks: const TlsTricksOptions(
    enableTlsFragment: true,
    tlsFragmentSize: IntRange(10, 30),
    tlsFragmentSleep: IntRange(2, 8),
  ),
  warp: const WarpOptions(
    enableWarp: false,
    detourMode: WarpDetourMode.detourProxiesThroughWarp,
  ),
  misc: const MiscOptions(
    connectionTestUrl: 'http://cp.cloudflare.com',
    urlTestInterval: Duration(minutes: 10),
    clashApiPort: 16756,
  ),
);

await vpn.applyProfile(
  profile: profile,
  featureSettings: settings,
);
```

Custom DNS provider presets and fully custom DNS are both supported:

```dart
final googleDns = DnsOptions.fromProvider(
  preset: DnsProviderPreset.google,
);

const customDns = DnsOptions(
  providerPreset: DnsProviderPreset.custom,
  remoteDns: 'https://dns.nextdns.io/your-id',
  directDns: '45.90.28.0',
  enableDnsRouting: true,
);
```

`InboundOptions.includePackages` and `InboundOptions.excludePackages` map to
sing-box TUN `include_package` / `exclude_package`.

Use `InboundOptions.splitTunnelingEnabled` to explicitly control behavior:
- `true`: apply package filters.
- `false`: ignore package filters (full tunnel).
- `null` (default): backward-compatible mode, apply filters only when lists are non-empty.

## State + Traffic Stream

You can consume live stats directly instead of polling:

```dart
final stateSub = vpn.stateStream.listen((state) {
  print('state=${state.wireValue}');
});

final statsSub = vpn.statsStream.listen((stats) {
  print('downloadSpeed=${stats.downloadSpeed}');
  print('uploadSpeed=${stats.uploadSpeed}');
  print('totalDownloaded=${stats.totalDownloaded}');
  print('totalUploaded=${stats.totalUploaded}');
});
```

Detailed connection state (validation, private DNS status, interface, transport)
is also available:

```dart
final detailSub = vpn.stateDetailsStream.listen((snapshot) {
  print('state=${snapshot.state.wireValue} detail=${snapshot.detailCode}');
  print('validated=${snapshot.networkValidated} privateDns=${snapshot.privateDnsServerName}');
});

final current = await vpn.getStateDetails();
print(current.toMap());
```

If your fork/custom core needs non-standard experimental fields, use:
- `TlsTricksOptions.rawOutboundPatch`
- `SingboxFeatureSettings.rawConfigPatch`

This allows custom patching without losing typed settings for UI rendering.

Official core compatibility notes:
- `tls.fragment` is emitted in official-compatible form (boolean).
- Non-standard TLS keys like `mixed_sni_case` and `padding` are removed for official `SagerNet/sing-box` core compatibility.
- TLS tricks are applied only to TLS-capable outbound types (`vless`, `vmess`, `trojan`, `anytls`).

## Parse Share Links

You can parse common VPN links directly and apply them:

```dart
final parsed = vpn.parseConfigLink(
  'vless://uuid@host:443?type=ws&security=tls#node-1',
);

await vpn.applyConfigLink(
  configLink: 'ss://base64-userinfo@host:8388#ss-node',
  bypassPolicy: const BypassPolicy(
    preset: BypassPolicyPreset.aggressive,
  ),
  throttlePolicy: const TrafficThrottlePolicy(
    enableMultiplex: false,
  ),
);
```

Parser coverage includes:
- `sbmm://` (encrypted wrapper for a supported inner link)
- `vless://`
- `vmess://`
- `trojan://`
- `ss://` / `shadowsocks://`
- `hysteria://` / `hysteria2://` / `hy2://`
- `tuic://`
- `wireguard://` / `wg://`
- WireGuard `wg-quick` text blocks (`[Interface]` + `[Peer]`)
- `ssh://`

You can paste `wg-quick` text directly:

```dart
const String wgQuick = '''
[Interface]
PrivateKey = ...
Address = 10.0.0.2/32

[Peer]
PublicKey = ...
Endpoint = 203.0.113.20:31543
''';

final ParsedVpnConfig parsed = vpn.parseConfigLink(wgQuick);
await vpn.connectManualProfile(profile: parsed.profile);
```

For UI rendering, you can extract endpoint summaries directly from links or subscriptions:

```dart
final VpnProfileSummary summary = vpn.extractConfigLinkSummary(
  'vless://uuid@host:443?type=ws&security=tls#node-1',
);
print('remark=${summary.remark} host=${summary.host} port=${summary.port}');

final List<VpnProfileSummary> list = vpn.extractSubscriptionSummaries(
  subscriptionTextOrBase64,
);
```

## Auto + Manual Connect Methods

Use explicit UX-focused methods for common app flows:

```dart
// Manual: user pastes one link and taps Connect.
final manual = await vpn.connectManualConfigLink(
  configLink: 'vless://uuid@host:443?security=tls#my-node',
);
print(manual.profile.tag);

// Auto: import subscription, optionally pick lowest latency, then connect.
final auto = await vpn.connectAutoSubscription(
  rawSubscription: subscriptionTextOrBase64,
  preferLowestLatency: true,
  pingTimeout: const Duration(seconds: 2),
);
print(auto.selectedProfile?.tag);
```

If you expose endpoint list UI, you can combine manual and automatic switching:

```dart
await vpn.selectEndpoint(index: 2, reconnect: true); // manual select
await vpn.selectBestEndpointByPing(reconnect: true); // automatic select
```

## SBMM Secure Protocol Layer (`sbmm://`)

Use `sbmm://` to wrap any supported config link (`vless`, `vmess`, `trojan`, `ss`, `hysteria2`, `tuic`, `wireguard`, `ssh`) in an encrypted envelope:

```dart
const raw = 'vless://uuid@host:443?security=tls#edge-1';
const passphrase = 'your-strong-passphrase';

final sbmm = vpn.wrapSecureConfigLink(
  configLink: raw,
  passphrase: passphrase,
);

// Parse / connect directly using the same passphrase.
final parsed = vpn.parseConfigLink(
  sbmm,
  sbmmPassphrase: passphrase,
);

await vpn.connectManualConfigLink(
  configLink: sbmm,
  sbmmPassphrase: passphrase,
);
```

Crypto profile for `sbmm://` envelopes:
- `AES-256-GCM`
- `PBKDF2-HMAC-SHA256`
- random per-link salt + nonce

Security notes:
- Keep passphrases out of logs and analytics.
- Prefer device-secure storage (Keystore/Keychain) for passphrase persistence.
- `sbmm://` protects config confidentiality; it does not replace TLS/Reality transport security on the tunnel itself.

## GFW Hardened Preset Pack

The package now includes a ready-to-use hardened preset pack:
- `GfwPresetMode.compatibility`
- `GfwPresetMode.balanced` (recommended default)
- `GfwPresetMode.aggressive`
- `GfwPresetMode.extreme`

```dart
final preset = GfwPresetPack.balanced();

await vpn.connectManualConfigLinkWithPreset(
  configLink: 'vless://uuid@host:443?security=tls#edge-1',
  preset: preset,
);

await vpn.connectAutoWithPreset(
  rawSubscription: subscriptionTextOrBase64,
  preset: GfwPresetPack.aggressive(),
  preferLowestLatency: true,
);
```

You can list all preset packs for UI:

```dart
final presets = vpn.listGfwPresetPacks();
```

## Extract + Reconfigure From Config Files

When you already have a Sing-box JSON config file, parse it and extract
UI-friendly endpoint fields (`ip/server`, `port`, `remark`):

```dart
final document = vpn.parseConfigDocument(configJsonString);
final endpoints = document.endpointSummaries();

for (final endpoint in endpoints) {
  print(
    'remark=${endpoint.remark} server=${endpoint.server} port=${endpoint.serverPort}',
  );
}

document.updateEndpoint(
  outboundIndex: 0,
  server: '8.8.8.8',
  serverPort: 10443,
  remark: 'new-node',
  advancedPatch: {
    'transport': {'type': 'grpc', 'service_name': 'vpn'},
  },
);

document.applyAdvancedOverride({
  'experimental': {
    'clash_api': {'external_controller': '127.0.0.1:9090'},
  },
});

await vpn.applyConfigDocument(document);
```

## Multi-Endpoint Rotation + Auto Failover

Build an endpoint pool and let the SDK rotate/fail over automatically:

```dart
final endpoints = <VpnProfile>[
  vpn.parseConfigLink('vless://...#edge-a').profile,
  vpn.parseConfigLink('hysteria2://...#edge-b').profile,
  vpn.parseConfigLink('ss://...#edge-c').profile,
];

await vpn.applyEndpointPool(
  profiles: endpoints,
  options: const EndpointPoolOptions(
    autoFailover: true,
    rotationStrategy: EndpointRotationStrategy.healthiest,
    healthCheck: VpnHealthCheckOptions(
      checkInterval: Duration(seconds: 8),
      noTrafficTimeout: Duration(seconds: 45),
      maxConsecutiveFailures: 2,
      failoverOnNoTraffic: true,
      failoverOnError: true,
      failoverOnDisconnect: true,
    ),
  ),
);

await vpn.startManaged();
```

Manual rotation:

```dart
await vpn.rotateEndpoint(reconnect: true);
```

## Ping Check / URL Test Support

You can now run reachability-latency checks from Dart:

```dart
final ping = await vpn.pingProfile(profile: profile);
print('ok=${ping.success} latencyMs=${ping.latencyMs} error=${ping.error}');

final poolResults = await vpn.pingEndpointPool();
```

For managed failover, enable ping in health options:

```dart
await vpn.applyEndpointPool(
  profiles: endpoints,
  options: const EndpointPoolOptions(
    autoFailover: true,
    healthCheck: VpnHealthCheckOptions(
      pingEnabled: true,
      pingTimeout: Duration(seconds: 3),
      failoverOnPingFailure: true,
    ),
  ),
);
```

You can also fail over when HTTP connectivity probe fails (useful when tunnel is
"connected" but internet is blocked):

```dart
await vpn.applyEndpointPool(
  profiles: endpoints,
  options: const EndpointPoolOptions(
    autoFailover: true,
    healthCheck: VpnHealthCheckOptions(
      connectivityProbeEnabled: true,
      connectivityProbeUrl: 'http://cp.cloudflare.com',
      connectivityProbeTimeout: Duration(seconds: 8),
      failoverOnConnectivityFailure: true,
      maxConsecutiveFailures: 1,
    ),
  ),
);
```

## Subscription Import Pipeline

Import plain-text or base64-encoded subscription content:

```dart
final result = await vpn.importSubscription(
  rawSubscription: subscriptionTextOrBase64,
  source: 'my-provider',
  connect: true,
  options: const EndpointPoolOptions(
    autoFailover: true,
    rotationStrategy: EndpointRotationStrategy.healthiest,
  ),
);

print('Imported: ${result.importedCount}');
print('Invalid: ${result.invalidCount}');
print('Active: ${result.appliedProfile?.tag}');
```

## Android notes

- Android runtime uses embedded libbox JNI artifacts (`android/libs/libbox.jar` + `android/src/main/jniLibs/<abi>/libbox.so`).
- The `androidBinaryAssetByAbi` option remains available for compatibility, but Android VPN runtime is driven by libbox JNI lifecycle.
- Example assets still use `sing-box` filenames under `assets/singbox/android/<abi>/sing-box`.
- Call `requestVpnPermission()` before `start()`.
- On Android 13+, also call `requestNotificationPermission()` before `start()`.
- The VPN notification now uses a dedicated monochrome small icon (`ic_stat_singbox_mm`).
  - If you want a custom status-bar icon, provide your own `ic_stat_singbox_mm` drawable in the host app.
- While connected, Android foreground notification now shows:
  - live `Up/Down` speed only
  - session duration (chronometer)
- Android service recovery is sticky and stateful:
  - uses `START_REDELIVER_INTENT` for start/restart actions.
  - restores last config/state after process death (when possible).
- You can reduce Flutter-side stats overhead by increasing runtime stats interval:
  - `SingboxRuntimeOptions(statsEmitIntervalMs: 1500)` (range `250..10000`).
- Android excludes the VPN app package from TUN to avoid self-capture loops.
  - `probeConnectivity()` and UID-based `getStats()` can still show activity even when user-app traffic is failing.
  - For real tunnel health, prefer `stateDetailsStream` (`networkValidated`, `hasInternetCapability`, `detailCode`) plus a real external app test (browser/Telegram/etc).
- DNS requests to the TUN gateway (`172.19.0.2:53`) are explicitly routed to `dns-out` before private-network bypass rules.
- In strict-route VPN mode, the TUN inbound keeps an IPv6 address even when `ipv6RouteMode=disable` to prevent app-level IPv6 `No route to host` failures during mixed IPv4/IPv6 app traffic.
  - This prevents `ip_is_private -> direct` from blackholing app DNS on Android.
- The service applies a strict-Private-DNS compatibility patch on Android:
  - Detects active strict Private DNS hostname.
  - Adds a direct bootstrap DNS server (`1.1.1.1`) for that hostname lookup.
  - Adds direct route exceptions for the strict Private DNS host and TCP/853.
- If Android still shows `PRIVATE_DNS_BROKEN`, your strict DNS provider may block validation probe domains (`*.dnsotls-ds.metric.gstatic.com`). In that case, switch Private DNS to `Automatic/Off` or use a less filtering strict DNS provider.
- Ensure your final app architecture includes a compliant VPN service strategy for production distribution.
- Release builds must keep gomobile bridge classes (`go.Seq`, `go.*`) for libbox JNI.
  - This package now ships Android consumer keep rules (`android/consumer-rules.pro`) for host apps enabling shrink/obfuscation.

### Android Build Size Notes

Large release APK size is expected when shipping all native ABIs because each ABI includes its own `libbox.so`.

For pub.dev distribution, this package includes mobile ABIs only:
- `arm64-v8a`
- `armeabi-v7a`

Emulator ABIs (`x86`, `x86_64`) are excluded from the published tarball to stay under pub.dev extracted-size limits. If you need emulator ABI support, use a local/forked copy and include those JNI libs.

Recommended distribution strategy:
- Play Store: build `AAB` (`flutter build appbundle`) so users receive only their device ABI split.
- Direct APK distribution: build per-ABI artifacts (`flutter build apk --release --split-per-abi`).
- If your distribution never targets emulators, you can exclude `x86`/`x86_64` ABIs in the host app release config.

### Android Manifest Requirements

Your host app (or plugin merged manifest) must include:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<application>
  <service
    android:name=".SignboxLibboxVpnService"
    android:exported="false"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:foregroundServiceType="specialUse">
    <intent-filter>
      <action android:name="android.net.VpnService" />
    </intent-filter>
    <property
      android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
      android:value="vpn" />
  </service>
</application>
```

Runtime requirement (Android 13+):
- Request `POST_NOTIFICATIONS` at runtime (`vpn.requestNotificationPermission()`).

### PRIVATE_DNS_BROKEN Notes

When Android marks VPN as `PRIVATE_DNS_BROKEN`, the tunnel can still be connected.
Use detailed state diagnostics and logs together:

- `stateDetailsStream.detailCode == PRIVATE_DNS_BROKEN`
- `stateDetailsStream.networkValidated == false`
- logcat `PROBE_PRIVDNS ... dnsotls-ds.metric.gstatic.com ... No address associated`

If this happens:

1. Try Private DNS `Automatic` and retest.
2. Or switch strict provider to one that resolves Android validation probe domains.
3. Keep VPN DNS bootstrap (`1.1.1.1`) and direct TCP/853 exception enabled (already auto-patched by this package).

### Network Handover Stress Test

You can run a stress test that repeatedly toggles Wi-Fi/Data while the VPN stays connected:

```bash
./tool/run_android_handover_stress.sh \
  <device_id> \
  'vless://uuid@host:443?security=tls#edge-1' \
  120 \
  8
```

For `sbmm://` links:

```bash
./tool/run_android_handover_stress.sh \
  <device_id> \
  'sbmm://secure?data=...' \
  120 \
  8 \
  'your-strong-passphrase'
```

The script runs `example/integration_test/network_handover_stress_test.dart` and enforces handover signal detection (`NETWORK_HANDOVER`).

### Release Reliability Suite (App Reachability Matrix)

Run release-mode reliability checks with a probe matrix that targets browser + common app endpoints:

```bash
./tool/run_android_release_reliability_suite.sh \
  <device_id> \
  'vless://uuid@host:443?security=tls#edge-1' \
  balanced \
  75 \
  10
```

For `sbmm://` links:

```bash
./tool/run_android_release_reliability_suite.sh \
  <device_id> \
  'sbmm://secure?data=...' \
  balanced \
  90 \
  10 \
  'your-strong-passphrase'
```

Custom probe matrix and threshold:

```bash
./tool/run_android_release_reliability_suite.sh \
  <device_id> \
  'vless://uuid@host:443?security=tls#edge-1' \
  aggressive \
  120 \
  10 \
  '' \
  'http://cp.cloudflare.com||https://play.google.com/generate_204||https://www.facebook.com||https://telegram.org||https://www.viber.com' \
  0.75 \
  false
```

The suite performs:
- release APK build/install/launch smoke check (crash detection)
- profile-mode automated instrumentation (`flutter drive --profile`) for reliability sampling

Note: Flutter Driver does not support true non-web `--release` test execution.

It reports:
- VPN stability (`disconnected/error` transitions)
- ping success ratio
- URL probe success ratio
- traffic progression (`maxTotalBytes`)
- optional validated network requirement

## Quality Gate (9.5 Target)

Use the built-in quality gate before release:

```bash
./tool/quality_gate.sh
```

It enforces:
- `flutter analyze`
- `flutter test`
- direct dependency freshness (`flutter pub outdated`)

## Package Structure

```text
lib/src/config/
  singbox_config_builder.dart      # typed settings -> sing-box JSON
  internal/                        # builder + parser split modules
    singbox_*.dart                 # dns/inbound/route builders
    vpn_config_parser_*.dart       # protocol-specific link parsers
    vpn_subscription_parser_*.dart # subscription payload + entry parsing
  vpn_config_parser.dart           # sbmm + vmess/vless/ss/trojan/hysteria/tuic links
  sbmm_secure_link_codec.dart      # sbmm secure envelope codec
  vpn_subscription_parser.dart     # subscription decode + dedupe
  singbox_config_document.dart     # read/update raw sing-box JSON

lib/src/core/
  singbox_mm_client.dart           # core state holder + lightweight class shell
  internal/
    singbox_mm_client_api_*.dart   # public API wrappers (config/runtime/subscription/diagnostics)
    singbox_mm_client_orchestration_*.dart # apply/connect/import execution flows
    singbox_mm_client_diagnostics_*.dart   # profile validation + probe + report assembly
    singbox_mm_client_health_*.dart        # health tick/monitor/failover logic
    singbox_mm_client_lifecycle_*.dart     # init/cleanup/managed-state handlers
    singbox_mm_client_endpoint_*.dart      # endpoint rotation/selection/health scoring
    singbox_mm_client_{platform,network,document,utils,foundation}.dart
  singbox_mm_exception.dart

lib/src/models/
  vpn_profile.dart                 # protocol profile model
  singbox_feature_settings.dart    # advanced settings surface
  vpn_connection_snapshot.dart     # detailed state diagnostics
  vpn_runtime_stats.dart           # traffic stats model
  gfw_preset_pack.dart             # hardened presets
  ...

android/src/main/kotlin/com/signbox/singbox_mm/
  SingboxMmPlugin.kt               # Flutter method/event bridge
  SignboxLibboxVpnService.kt       # thin Android VpnService shell
  VpnServiceRuntimeGraph.kt        # top-level runtime composition root
  VpnServiceNotificationGraph.kt   # notification runtime + live ticker wiring
  VpnServicePlatformGraph.kt       # platform/tun/default-network monitor wiring
  VpnServiceControlGraph.kt        # runtime state/action/lifecycle orchestration
```

## Core Internals Map

- `singbox_mm_client_api_*.dart`: Public `SignboxVpn` API wrappers grouped by domain (config, runtime, subscription, diagnostics).
- `singbox_mm_client_orchestration_*.dart`: High-level connect/apply/import flows and shared orchestration helpers.
- `singbox_mm_client_diagnostics_*.dart`: Profile validation, connectivity probing, and diagnostics report collection/assembly.
- `singbox_mm_client_health_*.dart`: Health monitor scheduling, tick evaluation, and endpoint failover logic.
- `singbox_mm_client_lifecycle_*.dart`: Initialization, cleanup/reset, and managed state-stream handlers.
- `singbox_mm_client_endpoint_*.dart`: Endpoint selection/rotation strategy, health scoring, and throttle/MTU candidate policy.
- `singbox_mm_client_platform.dart`: Method-channel calls for config/control/permission operations.
- `singbox_mm_client_network.dart`: Ping implementations and endpoint pool latency checks.
- `singbox_mm_client_document.dart`: Raw sing-box JSON document parse/extract/apply helpers.
- `singbox_mm_client_utils.dart`: Shared stateless parsing/permission helpers.
- `singbox_mm_client_foundation.dart`: Small foundational types and guard wrappers used across modules.

## Performance Notes

- Keep `statsEmitIntervalMs` at `1000-2000` for UI updates without extra battery use.
- Default TUN stack is `gvisor` for better app compatibility on restrictive networks/devices.
- If your target devices are stable with `system`, switching to `system` can reduce overhead.
- Prefer `balanced` preset for long sessions; `aggressive/extreme` increase CPU/battery.
- Avoid excessive endpoint pool size on low-memory devices; keep health checks focused.

## Runtime Stats Formatting

`VpnRuntimeStats` includes built-in helpers for UI rendering:

```dart
final stats = await vpn.getStats();
print(stats.formattedDownloadSpeed);   // e.g. 52.10 KB/s
print(stats.formattedUploadSpeed);     // e.g. 4.22 KB/s
print(stats.formattedTotalDownloaded); // e.g. 390.10 MB
print(stats.formattedTotalUploaded);   // e.g. 12.45 MB
print(stats.formattedDuration); // e.g. 01:24:53
```

## Background/Resume Stability

Call `syncRuntimeState()` when the app returns to foreground so UI state and
stats baseline rehydrate even after process recreation:

```dart
class _MyState extends State<MyPage> with WidgetsBindingObserver {
  final SignboxVpn vpn = SignboxVpn();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(vpn.syncRuntimeState());
    }
  }
}
```

### Official libbox reference

This repository includes a helper script to sync official `SagerNet/sing-box` Android libbox artifacts:

```bash
./tool/fetch_singbox_libbox_android.sh
```

The script builds and syncs:
- `android/libs/libbox.jar`
- `android/src/main/jniLibs/<abi>/libbox.so`
- `example/assets/singbox/android/<abi>/sing-box`

Important:
- Official `sing-box` releases ship CLI binaries; Android `libbox` integration is built from source via `gomobile`.
- JNI Android integration requires matching Java package + native symbols (`io.nekohasekai.libbox` + `libbox.so`).
- Running only a standalone CLI via `ProcessBuilder` is not enough for a full VPN lifecycle on Android.
- Third-party attribution and license notes for bundled binaries are documented in `THIRD_PARTY_NOTICES.md`.

## iOS notes

iOS does not allow launching VPN binaries directly from app sandbox code.
You must integrate a **Packet Tunnel Network Extension** and bind it to a `sing-box` core strategy.

This plugin keeps the API consistent on iOS but returns `IOS_EXTENSION_REQUIRED` from `startVpn` until extension wiring is provided by the host app.

## What this package gives you

- Strongly typed config model and generator for `sing-box` JSON.
- Stable Flutter method/event channel contract.
- Android runtime libbox (JNI) bridge.
- iOS-compatible API surface with explicit extension requirement.

## Pub.dev Release Checklist

Run before publishing:

```bash
flutter analyze
flutter test
flutter pub publish --dry-run
```

## Support

Tron (TRC20): `TLbwVrZyaZujcTCXAb94t6k7BrvChVfxzi`

## License

Project license: MIT-style license in `LICENSE`.

Third-party runtime binaries and notices: `THIRD_PARTY_NOTICES.md`.
