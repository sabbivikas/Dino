#!/usr/bin/env bash
# bump-version.sh — bump iOS build / marketing version for TestFlight uploads
#
# Usage:
#   ./scripts/bump-version.sh              # bump build number only (most common)
#   ./scripts/bump-version.sh 1.2          # also set marketing version to 1.2
#   ./scripts/bump-version.sh --show       # show current versions, no changes
#
# Reads/writes CURRENT_PROJECT_VERSION and MARKETING_VERSION in project.pbxproj.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$PROJECT_DIR/Dino.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "error: $PBXPROJ not found"
  exit 1
fi

current_build="$(grep -m 1 'CURRENT_PROJECT_VERSION = ' "$PBXPROJ" | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d ' ')"
current_marketing="$(grep -m 1 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d ' ')"

if [ "${1:-}" = "--show" ]; then
  echo "marketing version: $current_marketing"
  echo "build number:      $current_build"
  exit 0
fi

new_build=$((current_build + 1))
echo "build:      $current_build -> $new_build"

# Bump every CURRENT_PROJECT_VERSION occurrence (Debug + Release + extension targets)
# Use a portable sed: write to a temp file then move back.
tmp="$(mktemp)"
sed -E "s/(CURRENT_PROJECT_VERSION = )[^;]+;/\\1${new_build};/g" "$PBXPROJ" > "$tmp" && mv "$tmp" "$PBXPROJ"

if [ -n "${1:-}" ] && [ "${1:-}" != "--show" ]; then
  new_marketing="$1"
  echo "marketing:  $current_marketing -> $new_marketing"
  tmp="$(mktemp)"
  sed -E "s/(MARKETING_VERSION = )[^;]+;/\\1${new_marketing};/g" "$PBXPROJ" > "$tmp" && mv "$tmp" "$PBXPROJ"
fi

echo
echo "done. archive + upload now: Product -> Archive in Xcode"
