#!/bin/bash
# Saves a long-lived Claude Code token for the coach relay, from the clipboard.
#
#   1. In a terminal, run `claude setup-token` and copy the whole token
#      (every line of it; it is printed wrapped).
#   2. Run this script. It reads the clipboard, removes the line breaks,
#      checks the token with Claude, saves it in your keychain, clears the
#      clipboard and restarts the relay.

set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"

TOKEN=$(pbpaste | tr -d '[:space:]')
case "$TOKEN" in
  sk-ant-*) ;;
  *) echo "The clipboard does not hold a Claude token (it should start with sk-ant-). Copy it and try again."; exit 1 ;;
esac

echo "Checking the token with Claude…"
if ! CLAUDE_CODE_OAUTH_TOKEN="$TOKEN" claude -p "Reply with the single word OK" \
     --no-session-persistence --strict-mcp-config < /dev/null >/dev/null 2>&1; then
  echo "Claude did not accept that token. It may be cut off or revoked; make a new one with 'claude setup-token'."
  exit 1
fi

security add-generic-password -s totonou-claude-oauth -a totonou -w "$TOKEN" -U
printf '' | pbcopy
echo "Token works and is saved in your keychain. Clipboard cleared."
"$HERE/install.sh"
