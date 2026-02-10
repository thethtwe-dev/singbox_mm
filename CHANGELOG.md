## 0.1.1
- Linked with git project

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
