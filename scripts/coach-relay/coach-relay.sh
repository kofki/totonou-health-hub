#!/bin/bash
# Totonou coach relay: answers questions from the Coach tab with Claude Code,
# on your own Claude account, while this Mac is on.
#
# Every 15 seconds it asks the Totonou MCP server (supabase/functions/mcp)
# whether a question is waiting. That check is a plain HTTP call and uses no
# Claude usage. Only when a question is waiting does it run `claude -p`, with
# the Totonou tools and nothing else: no files, no shell, no other servers.
#
# Setup: scripts/coach-relay/install.sh. Logs: ~/Library/Logs/totonou-coach-relay.log

set -u

SERVER="https://xzxzkbpgcmwogwtkwbqp.supabase.co/functions/v1/mcp"
KEYCHAIN_SERVICE="totonou-coach-relay"
INTERVAL=15
SUPPORT="$HOME/Library/Application Support/Totonou"
CONFIG="$SUPPORT/coach-relay-mcp.json"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

TOKEN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)
if [ -z "$TOKEN" ]; then
  log "No token in the keychain. Run scripts/coach-relay/install.sh first."
  exit 1
fi

# A long-lived Claude Code token (from `claude setup-token`), if you saved one,
# so the relay keeps working after your normal sign-in expires.
OAUTH=$(security find-generic-password -s totonou-claude-oauth -w 2>/dev/null)
if [ -n "$OAUTH" ]; then
  export CLAUDE_CODE_OAUTH_TOKEN="$OAUTH"
fi

CLAUDE=$(command -v claude || echo "$HOME/.local/bin/claude")
if [ ! -x "$CLAUDE" ]; then
  log "Claude Code is not installed (no 'claude' on PATH)."
  exit 1
fi

# The MCP config holds the token, so only this user may read it.
mkdir -p "$SUPPORT"
umask 077
cat > "$CONFIG" <<JSON
{"mcpServers":{"totonou":{"type":"http","url":"$SERVER","headers":{"Authorization":"Bearer $TOKEN"}}}}
JSON

# Read tools, answering, and adding quests or objectives when asked. Creating,
# ending or removing things needs a conversation, so it is left to the Claude app.
ALLOWED="mcp__totonou__get_overview mcp__totonou__get_coach_questions mcp__totonou__answer_coach_question \
mcp__totonou__set_coach_message mcp__totonou__add_quests mcp__totonou__add_daily_quest mcp__totonou__add_objective"

PROMPT="You are the coach inside Totonou, the user's quest game. Questions typed on the Coach tab are waiting.
1. Call get_coach_questions, then get_overview.
2. Answer every waiting question with answer_coach_question: two to five sentences, plain text, no markdown.
   Start with the one thing to do. Use only what get_overview measured; never invent numbers.
3. Only if a question asks you to add or change quests or objectives, do it with the tools, then say what you added.
   Never create, end or remove arcs or quests here: suggest it in the answer instead.
Reply with one line saying how many questions you answered."

waiting_count() {
  curl -s --max-time 20 -X POST "$SERVER" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_coach_questions","arguments":{}}}' |
  /usr/bin/env python3 -c '
import json, sys
try:
    reply = json.load(sys.stdin)
    print(len(json.loads(reply["result"]["content"][0]["text"])["waiting"]))
except Exception:
    print(-1)
'
}

log "Relay started. Checking every ${INTERVAL}s.$( [ -n "$OAUTH" ] && echo ' Using the long-lived Claude token.')"
while true; do
  count=$(waiting_count)
  if [ "$count" = "-1" ]; then
    log "Could not reach the Totonou server (or the token was rejected)."
  elif [ "$count" -gt 0 ]; then
    log "$count question(s) waiting. Asking Claude Code."
    "$CLAUDE" -p "$PROMPT" \
      --mcp-config "$CONFIG" --strict-mcp-config \
      --allowedTools $ALLOWED \
      --no-session-persistence < /dev/null 2>&1 | tail -n 5 | while IFS= read -r line; do log "claude: $line"; done
  fi
  sleep "$INTERVAL"
done
