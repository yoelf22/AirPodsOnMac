#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_DEST="$HOME/.local/bin/airpods-fix"
PLIST_LABEL="com.$(whoami).airpods-format-fix"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_PATH="$HOME/Library/Logs/airpods-fix.log"

if ! command -v swiftc &> /dev/null; then
    echo "Error: swiftc not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

echo "Building..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

mkdir -p "$HOME/.local/bin"
cp ".build/release/airpods-fix" "$BINARY_DEST"
chmod +x "$BINARY_DEST"
echo "Binary installed at $BINARY_DEST"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY_DEST</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_PATH</string>
    <key>StandardErrorPath</key>
    <string>$LOG_PATH</string>
</dict>
</plist>
PLIST
echo "LaunchAgent installed at $PLIST_PATH"

launchctl bootstrap gui/$(id -u) "$PLIST_PATH"
echo ""
echo "Done. Daemon is running. Logs: $LOG_PATH"
