# singbox_mm_example

Example app for the `singbox_mm` plugin.

This sample demonstrates:
- Runtime initialization.
- VPN permission request flow.
- Applying a VLESS profile + anti-throttling policy.
- Connect/disconnect controls and state/stat rendering.

Before running Android VPN:
- Put `sing-box` binaries in `assets/singbox/android/<abi>/sing-box`.
- Current ABI map is configured in `lib/main.dart`.
- Sync official Sing-box libbox artifacts from project root with:
  `./tool/fetch_singbox_libbox_android.sh`

Run with:

```bash
flutter run
```
