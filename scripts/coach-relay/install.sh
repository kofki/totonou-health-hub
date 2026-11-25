#!/bin/bash
# Installs the Totonou coach relay as a login item (a launchd agent), so it
# runs whenever you are logged in to this Mac.
#
# You need a Totonou link token: in the app, Connect → Claude → Make a link,
# then copy the part after "token=" (it starts with tt_). Each link has its own
# token, so this one does not disturb the connector you added to Claude.
#
#   scripts/coach-relay/install.sh             install or update
#   scripts/coach-relay/install.sh --claude-token   also save a `claude setup-token` token
#   scripts/coach-relay/install.sh --remove    stop and remove it

set -eu
LABEL="dev.totonou.coach-relay"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/coach-relay.sh"

if [ "${1:-}" = "--remove" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  security delete-generic-password -s totonou-coach-relay >/dev/null 2>&1 || true
  security delete-generic-password -s totonou-claude-oauth >/dev/null 2>&1 || true
  rm -f "$HOME/Library/Application Support/Totonou/coach-relay-mcp.json"
  echo "Removed the coach relay and its token."
  exit 0
fi

if ! security find-generic-password -s totonou-coach-relay >/dev/null 2>&1; then
  printf "Paste the Totonou token (starts with tt_), then press Return: "
  read -rs TOKEN || true; echo
  TOKEN=$(printf '%s' "$TOKEN" | tr -d '[:space:]')
  case "$TOKEN" in tt_*) ;; *) echo "That does not look like a Totonou token."; exit 1 ;; esac
  security add-generic-password -s totonou-coach-relay -a totonou -w "$TOKEN" -U
  echo "Token saved in your login keychain."
fi

if [ "${1:-}" = "--claude-token" ]; then
  printf "Paste the token from 'claude setup-token' (starts with sk-ant-), then press Return: "
  # `|| true`: a paste that ends without Return still counts.
  read -rs OAUTH || true; echo
  # The token is printed indented and wrapped; drop any spaces or line breaks.
  OAUTH=$(printf '%s' "$OAUTH" | tr -d '[:space:]')
  if [ -z "$OAUTH" ]; then echo "Nothing was pasted. Run it again and paste the token."; exit 1; fi
  case "$OAUTH" in sk-ant-*) ;; *) echo "That does not look like a Claude token (it should start with sk-ant-)."; exit 1 ;; esac
  security add-generic-password -s totonou-claude-oauth -a totonou -w "$OAUTH" -U
  echo "Claude token saved in your login keychain."
fi

chmod +x "$SCRIPT"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$SCRIPT</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/totonou-coach-relay.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/totonou-coach-relay.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Coach relay running. Log: ~/Library/Logs/totonou-coach-relay.log"
