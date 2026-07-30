#!/usr/bin/env bash
# PostToolUse hook: formats a single C# file after Claude writes or edits it.
# Silent no-op for anything that is not a .cs file inside a project.
set -uo pipefail

file=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

case "$file" in
    *.cs) ;;
    *) exit 0 ;;
esac
case "$file" in
    */bin/* | */obj/*) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# Walk up from the file to the nearest enclosing .csproj.
dir=$(cd "$(dirname "$file")" 2>/dev/null && pwd) || exit 0
project=""
while [ "$dir" != "/" ]; do
    for candidate in "$dir"/*.csproj; do
        [ -f "$candidate" ] && project="$candidate" && break
    done
    [ -n "$project" ] && break
    dir=$(dirname "$dir")
done
[ -n "$project" ] || exit 0

dotnet format whitespace "$project" --no-restore --include "$file" >/dev/null 2>&1 || true
exit 0
