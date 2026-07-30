#!/usr/bin/env bash
# SessionStart hook: reports git submodule state so Claude knows lang/ and docs/
# are separate repositories before it starts editing or committing.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

status=$(git submodule status 2>/dev/null) || exit 0
[ -n "$status" ] || exit 0

context=$(printf 'Submodule state (each is a separate repository — commit inside it, then commit the pointer here).\nLeading "+" means the checkout differs from the pointer recorded in this repo, "-" means not initialized:\n%s\n' "$status")

jq -n --arg ctx "$context" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
