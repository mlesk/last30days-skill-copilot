#!/usr/bin/env bash
set -euo pipefail

PORT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$PORT_DIR/.." && pwd)"
PLUGIN_DIR="$PORT_DIR/last30days-plugin"
TMP_DIR="$(mktemp -d /tmp/last30days-copilot-port.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$REPO_ROOT" "$TMP_DIR/last30days-plugin" <<'PY'
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
plugin_dir = Path(sys.argv[2])
skill_dir = plugin_dir / "skills" / "last30days"
skill_dir.mkdir(parents=True, exist_ok=True)

shutil.copytree(repo_root / "scripts", skill_dir / "scripts")
if (repo_root / "fixtures").exists():
    shutil.copytree(repo_root / "fixtures", skill_dir / "fixtures")
for filename in ("pyproject.toml", "README.md", "LICENSE"):
    shutil.copy2(repo_root / filename, skill_dir / filename)

source_plugin_manifest = json.loads((repo_root / ".claude-plugin" / "plugin.json").read_text())
plugin_manifest = {
    "name": "last30days-plugin",
    "description": source_plugin_manifest.get("description"),
    "version": source_plugin_manifest.get("version"),
    "author": source_plugin_manifest.get("author"),
    "homepage": source_plugin_manifest.get("homepage"),
    "repository": source_plugin_manifest.get("repository"),
    "license": source_plugin_manifest.get("license"),
    "keywords": source_plugin_manifest.get("keywords"),
    "skills": "skills/",
}
(plugin_dir / "plugin.json").write_text(json.dumps(plugin_manifest, indent=2) + "\n")

source_skill = repo_root / "skills" / "last30days" / "SKILL.md"
text = source_skill.read_text()
parts = text.split("---", 2)
if len(parts) != 3:
    raise SystemExit(f"Unexpected SKILL.md format: {source_skill}")
body = parts[2].lstrip()
setup_section = """## Setup: resolve the skill root

Before running any `last30days.py` command, resolve the Copilot skill root once and keep it in `SKILL_ROOT`:

```bash
SKILL_ROOT=""

for dir in \\
  "$HOME/.copilot/skills/last30days" \\
  "$HOME/.agents/skills/last30days" \\
  "$HOME/.claude/skills/last30days" \\
  "$HOME/.codex/skills/last30days"; do
  [ -n "$dir" ] && [ -f "$dir/scripts/last30days.py" ] && SKILL_ROOT="$dir" && break
done

if [ -z "$SKILL_ROOT" ] && [ -d "$HOME/.copilot/installed-plugins" ]; then
  while IFS= read -r dir; do
    if [ -f "$dir/scripts/last30days.py" ]; then
      SKILL_ROOT="$dir"
      break
    fi
  done < <(find "$HOME/.copilot/installed-plugins" -path '*/skills/last30days' -type d 2>/dev/null | sort)
fi

if [ -z "$SKILL_ROOT" ]; then
  echo "ERROR: Could not find the Copilot-installed last30days skill. Re-run copilot-port/install.sh." >&2
  exit 1
fi

for py in python3.14 python3.13 python3.12 python3; do
  command -v "$py" >/dev/null 2>&1 || continue
  "$py" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)' || continue
  LAST30DAYS_PYTHON="$py"
  break
done

if [ -z "${LAST30DAYS_PYTHON:-}" ]; then
  echo "ERROR: last30days v3 requires Python 3.12+. Install python3.12 or python3.13 and rerun." >&2
  exit 1
fi
```
"""
body = re.sub(
    r"## Setup: resolve the skill root\n.*?\n## Default command\n",
    setup_section + "\n## Default command\n",
    body,
    count=1,
    flags=re.S,
)
body = body.replace(
    "- For OpenClaw-specific watchlist, briefing, and history workflows, use `variants/open/SKILL.md`.\n",
    "- OpenClaw-specific variants are intentionally omitted from this Copilot port; use the original repository when you need those workflows.\n",
)
frontmatter = """---
name: last30days
description: Research any topic from the last 30 days across Reddit, X, YouTube, TikTok, Instagram, Hacker News, Polymarket, GitHub, and grounded web sources.
license: MIT
---
"""
(skill_dir / "SKILL.md").write_text(frontmatter + "\n" + body)
PY

rm -rf "$PLUGIN_DIR"
mv "$TMP_DIR/last30days-plugin" "$PLUGIN_DIR"

echo "Generated $PLUGIN_DIR"
