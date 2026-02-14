#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JNI_ROOT="$ROOT_DIR/android/src/main/jniLibs"

if ! command -v objdump >/dev/null 2>&1; then
  echo "[page-size] objdump is required but was not found in PATH." >&2
  exit 1
fi

required_align_pow2_for_abi() {
  case "$1" in
    arm64-v8a|x86_64)
      echo "14"
      ;;
    armeabi-v7a|x86)
      echo "12"
      ;;
    *)
      return 1
      ;;
  esac
}

extract_min_load_align_pow2() {
  local so_file="$1"
  local aligns
  aligns="$(objdump -p "$so_file" | awk '
    $1 == "LOAD" {
      for (i = 1; i <= NF; i++) {
        if ($i == "align" && (i + 1) <= NF) {
          token = $(i + 1)
          if (token ~ /^2\*\*[0-9]+$/) {
            gsub(/^2\*\*/, "", token)
            print token
          }
        }
      }
    }
  ')"

  if [[ -z "$aligns" ]]; then
    return 1
  fi

  echo "$aligns" | sort -n | head -n 1
}

fail_count=0
checked_count=0

for abi in "arm64-v8a" "armeabi-v7a" "x86_64" "x86"; do
  so_file="$JNI_ROOT/$abi/libbox.so"
  if [[ ! -f "$so_file" ]]; then
    echo "[page-size] $abi: skipped (missing $so_file)"
    continue
  fi

  checked_count=$((checked_count + 1))
  required="$(required_align_pow2_for_abi "$abi")"
  min_align_pow2="$(extract_min_load_align_pow2 "$so_file" || true)"
  if [[ -z "$min_align_pow2" ]]; then
    echo "[page-size] $abi: FAIL (unable to parse LOAD segment alignment)"
    fail_count=$((fail_count + 1))
    continue
  fi

  if (( min_align_pow2 >= required )); then
    echo "[page-size] $abi: PASS (min LOAD align 2**$min_align_pow2, required >= 2**$required)"
  else
    echo "[page-size] $abi: FAIL (min LOAD align 2**$min_align_pow2, required >= 2**$required)"
    fail_count=$((fail_count + 1))
  fi
done

if (( checked_count == 0 )); then
  echo "[page-size] No JNI libraries found under $JNI_ROOT" >&2
  exit 1
fi

if (( fail_count > 0 )); then
  echo "[page-size] FAIL ($fail_count ABI check(s) failed)." >&2
  exit 1
fi

echo "[page-size] PASS (all checked ABIs satisfy required alignment)."
