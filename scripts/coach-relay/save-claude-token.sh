#!/bin/bash
# Saves a long-lived Claude Code token (from `claude setup-token`) for the
# coach relay and restarts it. The same as `install.sh --claude-token`.
exec "$(cd "$(dirname "$0")" && pwd)/install.sh" --claude-token
