#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deprecated: fetch_hiddify_core_android.sh now forwards to official sing-box libbox sync."
exec "$SCRIPT_DIR/fetch_singbox_libbox_android.sh" "$@"
