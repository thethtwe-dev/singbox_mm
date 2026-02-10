#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/signbox_singbox_libbox"
SRC_DIR="$TMP_DIR/sing-box"
REF="${SINGBOX_REF:-latest}" # e.g. v1.12.20

command -v go >/dev/null 2>&1 || {
  echo "Go is required but not found in PATH." >&2
  exit 1
}

command -v java >/dev/null 2>&1 || {
  echo "Java is required but not found in PATH." >&2
  exit 1
}

GO_BIN_DIR="$(go env GOPATH)/bin"
PATH="$GO_BIN_DIR:$PATH"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if [[ "$REF" == "latest" ]]; then
  RELEASE_JSON="$TMP_DIR/release.json"
  curl -sL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" > "$RELEASE_JSON"
  REF="$(grep -o '"tag_name":[[:space:]]*"[^"]*"' "$RELEASE_JSON" | head -n1 | cut -d'"' -f4)"
fi

if [[ -z "$REF" ]]; then
  echo "Unable to resolve sing-box release tag." >&2
  exit 1
fi

echo "Using sing-box ref: $REF"
echo "Installing gomobile tooling..."
go install -v github.com/sagernet/gomobile/cmd/gomobile@latest
go install -v github.com/sagernet/gomobile/cmd/gobind@latest
gomobile init

echo "Cloning sing-box source..."
git clone --depth 1 --branch "$REF" "https://github.com/SagerNet/sing-box" "$SRC_DIR"

TAGS="with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_conntrack,badlinkname,tfogo_checklinkname0,with_tailscale,ts_omit_logtail,ts_omit_ssh,ts_omit_drive,ts_omit_taildrop,ts_omit_webclient,ts_omit_doctor,ts_omit_capture,ts_omit_kube,ts_omit_aws,ts_omit_synology,ts_omit_bird"
LD_FLAGS="-X github.com/sagernet/sing-box/constant.Version=$REF -X internal/godebug.defaultGODEBUG=multipathtcp=0 -s -w -buildid= -checklinkname=0"
AAR_FILE="$TMP_DIR/libbox.aar"

echo "Building libbox.aar from official source..."
(
  cd "$SRC_DIR"
  gomobile bind \
    -v \
    -o "$AAR_FILE" \
    -target android \
    -androidapi 23 \
    -javapkg=io.nekohasekai \
    -libname=box \
    -trimpath \
    -buildvcs=false \
    -ldflags "$LD_FLAGS" \
    -tags "$TAGS" \
    ./experimental/libbox
)

if [[ ! -f "$AAR_FILE" ]]; then
  echo "libbox.aar was not produced." >&2
  exit 1
fi

echo "Syncing Android plugin artifacts..."
mkdir -p "$ROOT_DIR/android/libs"
unzip -p "$AAR_FILE" classes.jar > "$ROOT_DIR/android/libs/libbox.jar"
rm -f "$ROOT_DIR/android/libs/hiddify-core.jar"

copy_abi() {
  local abi="$1"
  local lib_path="jni/${abi}/libbox.so"
  local plugin_out="$ROOT_DIR/android/src/main/jniLibs/${abi}"
  local example_out="$ROOT_DIR/example/assets/singbox/android/${abi}"

  mkdir -p "$plugin_out" "$example_out"
  unzip -p "$AAR_FILE" "$lib_path" > "$plugin_out/libbox.so"
  unzip -p "$AAR_FILE" "$lib_path" > "$example_out/sing-box"
  rm -f "$plugin_out/libhiddify-core.so"

  echo "Synced ABI ${abi}"
}

copy_abi "arm64-v8a"
copy_abi "armeabi-v7a"
copy_abi "x86"
copy_abi "x86_64"

echo "Done."
echo "- Android core classes synced to android/libs/libbox.jar"
echo "- Plugin JNI libs updated under android/src/main/jniLibs/<abi>/libbox.so"
echo "- Example assets updated under example/assets/singbox/android/<abi>/sing-box"
