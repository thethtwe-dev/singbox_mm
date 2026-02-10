# Third-Party Notices

This package bundles third-party runtime artifacts for Android VPN support.

## SagerNet sing-box (libbox)

- Component: `libbox` Android JNI bridge (`classes.jar` + `libbox.so`)
- Upstream project: <https://github.com/SagerNet/sing-box>
- Build/sync script in this repository: `tool/fetch_singbox_libbox_android.sh`
- Bundled paths:
  - `android/libs/libbox.jar`
  - `android/src/main/jniLibs/arm64-v8a/libbox.so`
  - `android/src/main/jniLibs/armeabi-v7a/libbox.so`
  - `android/src/main/jniLibs/x86/libbox.so`
  - `android/src/main/jniLibs/x86_64/libbox.so`

License and attribution for `sing-box` and its transitive components are
governed by the upstream project. Review the upstream repository and release
tag license files before distribution:

- <https://github.com/SagerNet/sing-box/blob/main/LICENSE>

If you ship this package in a production app, ensure your distribution,
attribution, and source-offer obligations are satisfied for all bundled
components.
