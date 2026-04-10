#!/usr/bin/env bash
set -euo pipefail

PORT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$PORT_DIR/last30days-plugin"
SKILL_SOURCE_DIR="$PLUGIN_DIR/skills/last30days"
PERSONAL_SKILL_DIR="$HOME/.copilot/skills/last30days"

if ! command -v copilot >/dev/null 2>&1; then
  echo "ERROR: GitHub Copilot CLI ('copilot') is not installed or not on PATH." >&2
  exit 1
fi

bash "$PORT_DIR/upgrade.sh"

copilot plugin install "$PLUGIN_DIR"

mkdir -p "$(dirname "$PERSONAL_SKILL_DIR")"
rm -rf "$PERSONAL_SKILL_DIR"
cp -R "$SKILL_SOURCE_DIR" "$PERSONAL_SKILL_DIR"

echo "Installed Copilot plugin from $PLUGIN_DIR"
echo "Synced personal skill to $PERSONAL_SKILL_DIR for Copilot Chat discovery"
