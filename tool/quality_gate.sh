#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[quality] flutter pub get"
flutter pub get >/dev/null

echo "[quality] flutter analyze"
flutter analyze

echo "[quality] flutter test"
flutter test

echo "[quality] flutter pub outdated"
OUTDATED_OUTPUT="$(flutter pub outdated)"
echo "$OUTDATED_OUTPUT"

if ! echo "$OUTDATED_OUTPUT" | grep -q "direct dependencies: all up-to-date."; then
  echo "[quality] FAIL: direct dependencies are not fully up-to-date."
  exit 1
fi

echo "[quality] PASS"
