#!/usr/bin/env bash
# Sync the top-level skills/ folder into the OpenAI plugin bundle.
# Skills are identical in format between Claude and the agent-plugins.org
# standard, so we keep one source of truth at ./skills/ and copy into the
# OpenAI bundle before packaging.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rsync -a --delete "$REPO_ROOT/skills/" "$REPO_ROOT/providers/openai/skills/"
echo "Synced skills/ into providers/openai/skills/"
