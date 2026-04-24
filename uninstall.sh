#!/bin/bash
set -euo pipefail

PLIST_LABEL="com.$(whoami).airpods-format-fix"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
BINARY_PATH="$HOME/.local/bin/airpods-fix"

if [ -f "$PLIST_PATH" ]; then
    if launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null; then
        echo "Daemon stopped and unregistered"
    else
        echo "Daemon was not loaded (already stopped or never registered)"
    fi
    rm "$PLIST_PATH" && echo "Removed $PLIST_PATH"
fi

[ -f "$BINARY_PATH" ] && rm "$BINARY_PATH" && echo "Removed $BINARY_PATH"

echo "Uninstalled."
