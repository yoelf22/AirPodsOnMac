#!/bin/bash
set -euo pipefail

PLIST_LABEL="com.$(whoami).airpods-format-fix"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
BINARY_PATH="$HOME/.local/bin/airpods-fix"

if launchctl list 2>/dev/null | grep -q "$PLIST_LABEL"; then
    launchctl bootout gui/$(id -u) "$PLIST_PATH" && echo "Daemon stopped and unregistered"
fi

[ -f "$PLIST_PATH" ] && rm "$PLIST_PATH" && echo "Removed $PLIST_PATH"
[ -f "$BINARY_PATH" ] && rm "$BINARY_PATH" && echo "Removed $BINARY_PATH"

echo "Uninstalled."
