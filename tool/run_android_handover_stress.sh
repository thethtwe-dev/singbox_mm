#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <device_id> <vpn_config_or_sbmm_link> [stress_seconds] [toggle_seconds] [sbmm_passphrase]"
  exit 1
fi

DEVICE_ID="$1"
VPN_CONFIG="$2"
STRESS_SECONDS="${3:-120}"
TOGGLE_SECONDS="${4:-8}"
SBMM_PASSPHRASE="${5:-}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/example"

adb -s "$DEVICE_ID" wait-for-device

toggle_networks() {
  while true; do
    adb -s "$DEVICE_ID" shell svc data enable >/dev/null 2>&1 || true
    adb -s "$DEVICE_ID" shell svc wifi enable >/dev/null 2>&1 || true
    sleep "$TOGGLE_SECONDS"

    adb -s "$DEVICE_ID" shell svc wifi disable >/dev/null 2>&1 || true
    sleep "$TOGGLE_SECONDS"

    adb -s "$DEVICE_ID" shell svc wifi enable >/dev/null 2>&1 || true
    sleep "$TOGGLE_SECONDS"

    adb -s "$DEVICE_ID" shell svc data disable >/dev/null 2>&1 || true
    sleep "$TOGGLE_SECONDS"

    adb -s "$DEVICE_ID" shell svc data enable >/dev/null 2>&1 || true
    sleep "$TOGGLE_SECONDS"
  done
}

cleanup() {
  if [[ -n "${TOGGLER_PID:-}" ]]; then
    kill "$TOGGLER_PID" >/dev/null 2>&1 || true
    wait "$TOGGLER_PID" 2>/dev/null || true
  fi
  adb -s "$DEVICE_ID" shell svc data enable >/dev/null 2>&1 || true
  adb -s "$DEVICE_ID" shell svc wifi enable >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "[handover-stress] starting network toggler for device $DEVICE_ID"
toggle_networks &
TOGGLER_PID="$!"

cd "$EXAMPLE_DIR"

CMD=(
  flutter
  test
  integration_test/network_handover_stress_test.dart
  -d
  "$DEVICE_ID"
  "--dart-define=VPN_CONFIG=$VPN_CONFIG"
  "--dart-define=STRESS_SECONDS=$STRESS_SECONDS"
  "--dart-define=REQUIRE_HANDOVER_SIGNAL=true"
)

if [[ -n "$SBMM_PASSPHRASE" ]]; then
  CMD+=("--dart-define=SBMM_PASSPHRASE=$SBMM_PASSPHRASE")
fi

echo "[handover-stress] running Flutter integration test"
"${CMD[@]}"
echo "[handover-stress] completed"
