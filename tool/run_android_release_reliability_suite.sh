#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <device_id> <vpn_config_or_sbmm_link> [preset_mode] [duration_seconds] [sample_interval_seconds] [sbmm_passphrase] [check_urls] [min_success_ratio] [require_validated_network]"
  echo "check_urls format: url1||url2||url3"
  exit 1
fi

DEVICE_ID="$1"
VPN_CONFIG="$2"
PRESET_MODE="${3:-balanced}"
DURATION_SECONDS="${4:-75}"
SAMPLE_INTERVAL_SECONDS="${5:-10}"
SBMM_PASSPHRASE="${6:-}"
CHECK_URLS="${7:-}"
MIN_SUCCESS_RATIO="${8:-0.70}"
REQUIRE_VALIDATED_NETWORK="${9:-false}"
APP_PACKAGE="com.signbox.singbox_mm_example"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/example"

adb -s "$DEVICE_ID" wait-for-device

cd "$EXAMPLE_DIR"

echo "[release-reliability] building release APK for smoke validation"
flutter build apk --release

echo "[release-reliability] installing release APK"
adb -s "$DEVICE_ID" install -r build/app/outputs/flutter-apk/app-release.apk >/dev/null

echo "[release-reliability] launching release APK smoke"
adb -s "$DEVICE_ID" logcat -c >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" shell monkey -p "$APP_PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
sleep 6

RELEASE_PID="$(adb -s "$DEVICE_ID" shell pidof "$APP_PACKAGE" | tr -d '\r')"
if [[ -z "$RELEASE_PID" ]]; then
  echo "[release-reliability] FAIL: release app is not running after launch smoke."
  adb -s "$DEVICE_ID" logcat -d | tail -n 120
  exit 1
fi

LOG_DUMP="$(adb -s "$DEVICE_ID" logcat -d)"
if echo "$LOG_DUMP" | grep -q "FATAL EXCEPTION" &&
  echo "$LOG_DUMP" | grep -Fq "Process: $APP_PACKAGE"; then
  echo "[release-reliability] FAIL: potential release crash detected in logcat."
  echo "$LOG_DUMP" | tail -n 120
  exit 1
fi

echo "[release-reliability] release smoke passed (pid=$RELEASE_PID)"

CMD=(
  flutter
  drive
  --driver=test_driver/integration_test.dart
  --target=integration_test/release_reliability_suite_test.dart
  --profile
  -d
  "$DEVICE_ID"
  "--dart-define=VPN_CONFIG=$VPN_CONFIG"
  "--dart-define=PRESET_MODE=$PRESET_MODE"
  "--dart-define=DURATION_SECONDS=$DURATION_SECONDS"
  "--dart-define=SAMPLE_INTERVAL_SECONDS=$SAMPLE_INTERVAL_SECONDS"
  "--dart-define=MIN_SUCCESS_RATIO=$MIN_SUCCESS_RATIO"
  "--dart-define=REQUIRE_VALIDATED_NETWORK=$REQUIRE_VALIDATED_NETWORK"
)

if [[ -n "$SBMM_PASSPHRASE" ]]; then
  CMD+=("--dart-define=SBMM_PASSPHRASE=$SBMM_PASSPHRASE")
fi

if [[ -n "$CHECK_URLS" ]]; then
  CMD+=("--dart-define=CHECK_URLS=$CHECK_URLS")
fi

echo "[release-reliability] running release suite on $DEVICE_ID"
"${CMD[@]}"
echo "[release-reliability] completed"
