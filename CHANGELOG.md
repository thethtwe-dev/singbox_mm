## 0.1.9
- **Global Support**: Optimized presets and routing for international network environments.
- **Myanmar Optimization**: Added a dedicated `Myanmar Optimized` preset for local ISP/Bank bypass.
- **Sing-box v1.14 Alignment**:
  - Added `RuleSet` support for modern routing.
  - Added `dns.timeout` support.
  - Hardened SSH outbound with `cipher`, `mac`, and `key_exchange` extensions.
- **Sing-box 1.13 runtime compatibility:** migrated generated TUN and DNS
  route configuration away from removed legacy fields and `dns-out` outbounds.
- **Android libbox bridge update:** aligned service startup/reload calls with
  the current `CommandServer`/`OverrideOptions` API and pinned the fetch script
  to the tested sing-box release line.
- **Parser Hardening**:
  - Improved `xhttp` transport detection (Split-HTTP compatibility).
  - Added unknown field diagnostics to common protocol parsers.
  - Parse Reality `spx`/`spider_x` links while omitting unsupported
    `tls.reality.spider_x` from sing-box JSON.
- **Android DNS fix:** stop hijacking TCP/853 into the plain DNS handler while
  preserving strict Private DNS direct-route exceptions.
- **Android hardening:** constrain runtime config writes to app-private storage,
  write configs atomically, protect state broadcasts on older Android, and honor
  TLS/SNI options in native ping checks.
- **Package size:** publish only `arm64-v8a` native artifacts to satisfy
  pub.dev's expanded archive limit; local checkouts can regenerate additional
  ABIs with `tool/fetch_singbox_libbox_android.sh`.
- **Tests:** updated preset expectations for the Myanmar preset and added
  regression coverage for sing-box 1.13 config output.

## 0.1.8

- **Fixed:** `net=xhttp` share links are now remapped to sing-box
  `httpupgrade` transport consistently for compatibility with the current
  runtime behavior.
- **Fixed:** remapped xHTTP/httpupgrade TLS handshake normalization is hardened:
  ALPN is enforced to `http/1.1` and `tls.utls` is removed to reduce
  framing/protocol mismatch failures.
- **Fixed:** xHTTP transport host/path/method normalization is strengthened to
  avoid malformed requests and strict-CDN `404`/protocol edge cases.
- **Added:** `VpnCoreCapabilities.supportsTransport(VpnTransport)` — query whether a
  transport is natively supported by the current sing-box build.
  Also exposes `supportsAllTransports()`, `unsupportedTransports`, and a
  `supportedTransports` list (defaults to tcp, ws, grpc, http, httpUpgrade).
- **Added:** `VpnSubscriptionParser.parse()` now accepts optional `allowedTransports`
  and `allowedProtocols` filter sets. Profiles outside the allowed sets are silently
  skipped, enabling callers to exclude unsupported transports at parse time.
- **Chore:** Removed verbose generated-config runtime prints to avoid leaking
  sensitive profile fields in device logs.
- **Chore:** Added `libbox_backup/` to `.pubignore` to keep publish artifacts minimal.
- **Compatibility note:** xHTTP behavior can still vary across server panels and
  cores. If a server is provisioned for Xray-only split-http semantics and
  rejects remapped sing-box xHTTP/httpupgrade behavior, use an explicitly
  compatible transport profile (`ws` or `grpc`) on that endpoint.

## 0.1.7


- Deep parser hardening release across `vless`, `vmess`, `trojan`, and `shadowsocks`.
- Added robust `xhttp`/`httpupgrade` handling for TLS and non-TLS links (including port 80 plain HTTP cases).
- Improved host/header alias extraction and precedence:
  `host`, `ws_host`, `ws-host`, `authority`, `:authority`, header-map forms, with `sni` fallback when host is absent.
- Added gRPC parser normalization helpers:
  broader service-name aliases and path fallback; authority propagated to transport JSON.
- Expanded modern TLS parsing:
  `fp`/`fingerprint` aliases and Reality aliases (`pbk`, `sid`, `spx`/`spider_x`) into outbound TLS block.
- Tightened path normalization to avoid malformed/double-encoded WS/xHTTP paths while stripping parser-only hints (`ed`, `eh`).
- Kept safe default for WebSocket early-data (`max_early_data: 0`), with explicit override support when provided in links.
- Extended ALPN/uTLS guard for both WS and HTTP-upgrade to reduce strict CDN handshake failures.
- Added and updated regression tests for xHTTP, gRPC aliases, Reality fields, host fallback behavior, and early-data mapping.

## 0.1.6

- Hardened WebSocket parser/config generation to reduce strict CDN `404` handshake failures.
- Disabled WebSocket Early Data by default in generated transport:
  now emits `max_early_data: 0` and omits `early_data_header_name`.
- Added WS path sanitization for parser+builder:
  strips control characters, normalizes leading `//` to `/`, and removes `ed/eh` query hints.
- Expanded WS host extraction aliases across parsers (`host`, `ws_host`, `ws-host`, `authority`, `:authority`, and header-map forms).
- Added optional explicit empty ALPN parsing support (`alpn=none|empty|off|false|0` -> `tls.alpn=[]`) for strict WS/TLS endpoints.
- Added/updated regression tests for WS path/host normalization and early-data-disabled transport output.

## 0.1.5

- Fixed domain-bootstrap DNS handling for strict FakeIP mode by extracting
  bootstrap hosts from more config fields (transport headers and extra host
  hints), preventing outbound server-domain resolution loops.
- Made QUIC/UDP route blocking protocol-aware:
  UDP-native profiles (`hysteria2`, `tuic`, `wireguard`, and QUIC transport)
  are no longer blocked by generic UDP/443 + QUIC deny rules.
- Added a hardened silent-packet-loss resilience path in managed mode with
  new health-check options:
  `silentPacketLossTimeout` and `failoverOnSilentPacketLoss`.
- Increased health monitor responsiveness by evaluating health checks on each
  configured tick interval (instead of skipping stable ticks).
- Kept WS `alpn=http/1.1` compatibility strict by stripping `tls.utls` to avoid
  accidental HTTP/2 negotiation on CDN WebSocket links.
- Added regression tests for:
  DNS bootstrap ordering and extra-host extraction,
  protocol-aware QUIC blocking behavior,
  and WS ALPN compatibility.

## 0.1.4

- Maintenance release to refresh package metadata and publication pipeline.
- Updated README install snippet to the latest published version line.

## 0.1.3

- Improved Android native ping reliability by adding a hard timeout wrapper,
  preventing occasional long stalls during DNS/socket connect checks.
- Refined Android foreground notification text:
  title now shows profile label directly and traffic content uses compact
  `↑ / ↓` speed indicators.
- Added Android native page-size verification script
  (`tool/check_android_page_size.sh`) and integrated it into
  `tool/quality_gate.sh` and `tool/fetch_singbox_libbox_android.sh`.

## 0.1.2

- Improved endpoint-pool ping throughput with bounded parallel probing
  (up to 4 concurrent workers) while preserving deterministic result order.
- Reduced Android stats stream overhead with payload de-duplication plus
  heartbeat emission (every 5s) for UI freshness.
- Fixed disconnected stats semantics so totals/speeds reset to `0` while VPN
  is not connected.
- Clarified `Extreme` preset compatibility in docs:
  only `VLESS-Reality`, `Hysteria2`, and `TUIC` are allowed; incompatible
  profiles are blocked with `EXTREME_PRESET_PROTOCOL_BLOCKED`.
- Updated example app connect UX:
  when `Extreme` is selected with an incompatible manual link, users are
  prompted to switch to `Aggressive` before connect.
- Fixed Android strict-Private-DNS compatibility priority:
  private DNS host rules are now prepended so they win over global DNS
  interception rules (prevents `PRIVATE_DNS_BROKEN` regressions with custom
  providers like AdGuard).
- Fixed Android TUN DNS behavior under strict Private DNS:
  keep core-provided TUN DNS when present, and use bootstrap DNS only as
  fallback.
- Expanded dartdoc coverage for public API surfaces and top-level exports to
  improve pub.dev documentation scoring.

## 0.1.1

- Updated package links to the correct GitHub repository (`homepage`,
  `repository`, `issue_tracker`, `documentation`).
- Fixed pub.dev publish size-limit issue by excluding emulator JNI ABIs
  (`x86`, `x86_64`) from published package contents.
- Added/clarified release docs:
  Android size/distribution notes, support section, and publish checklist.
- Added complete MIT `LICENSE` text and third-party attribution file
  (`THIRD_PARTY_NOTICES.md`).

## 0.1.0

- Replaced template plugin with full `sign-box` focused VPN API.
- Added typed profile, routing, throttle, runtime, and stats models.
- Added `SingboxFeatureSettings` to support dashboard-style advanced settings:
  route, DNS, inbound, TLS tricks, WARP, misc, and raw config patch hooks.
- Added ping check support (`pingProfile`, `pingEndpointPool`) and optional
  ping-driven auto-failover (`VpnHealthCheckOptions.pingEnabled`).
- Added UI-friendly endpoint summary extraction APIs:
  `extractConfigLinkSummary` and `extractSubscriptionSummaries`.
- Added explicit UX connection APIs:
  `connectManualProfile`, `connectManualConfigLink`, and
  `connectAutoSubscription`.
- Added GFW hardened preset pack (`GfwPresetPack`) with four modes:
  `compatibility`, `balanced`, `aggressive`, and `extreme`.
- Added preset-aware connect helpers:
  `connectManualWithPreset`, `connectManualConfigLinkWithPreset`,
  `connectAutoWithPreset`, and `listGfwPresetPacks`.
- Tuned GFW preset defaults for wider core compatibility by disabling
  `tcp_brutal` in built-in presets.
- Added endpoint switching helpers:
  `selectEndpoint` (manual) and `selectBestEndpointByPing` (auto).
- Added connectivity-probe driven health checks and failover controls:
  `connectivityProbeEnabled`, `connectivityProbeUrl`,
  `connectivityProbeTimeout`, and `failoverOnConnectivityFailure`.
- Improved diagnostics for standalone profiles (without endpoint pool).
- Added `SingboxConfigBuilder` for tun inbound, DNS, route, and anti-throttling options.
- Implemented Android method/event bridge with VPN permission flow and process lifecycle.
- Implemented iOS method/event bridge with explicit Network Extension requirement signaling.
- Updated example app and tests for the new API.
- Added Android ABI-aware asset extraction options for `sing-box` binary bootstrapping.
- Added parser support for additional share-link formats and profiles:
  `hysteria2`, `tuic`, `wireguard` (`wireguard://`, `wg://`, `wg-quick`),
  and `ssh`.
- Added encrypted `sbmm://` secure-link wrapper codec.
- Added runtime capability guard helpers (including WireGuard checks for
  newer core versions).
- Added split-tunneling controls and richer detailed connection state snapshots.
- Improved Android notification/status UX with live `Up/Down` speeds and
  session duration display.
- Improved Android service resilience for background/process restart scenarios.
