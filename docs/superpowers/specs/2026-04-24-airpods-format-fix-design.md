# AirPods Format Fix — Design Spec

**Date:** 2026-04-24  
**Status:** Approved  

## Problem

AirPods Pro (gen 3) connected to a Mac default to 48kHz in Core Audio whenever they reconnect — after coming off-ear, after handling a call on iPhone, or after any Bluetooth profile renegotiation. At 48kHz, Core Audio performs a 2× sample rate conversion against the AirPods' native 24kHz processing rate. The mismatch causes constant crackling that makes the AirPods unusable for Apple Music playback. Setting the format to 24kHz in Audio MIDI Setup eliminates the crackling, but macOS resets it on every reconnect.

## Goal

A silent background daemon that keeps the AirPods Core Audio format locked to 24kHz at all times, requiring no user interaction after installation.

## Non-Goals

- No menu bar UI or notifications
- No management of default audio device selection
- No support for non-AirPods Bluetooth devices
- No microphone mode detection or HFP/A2DP awareness

## Components

```
airpods-fix.swift                           # daemon source
install.sh                                  # compile + deploy
uninstall.sh                                # tear down cleanly
com.yoel.airpods-format-fix.plist           # LaunchAgent template
```

### Installed locations

| File | Path |
|------|------|
| Binary | `~/.local/bin/airpods-fix` |
| LaunchAgent | `~/Library/LaunchAgents/com.yoel.airpods-format-fix.plist` |
| Log | `~/Library/Logs/airpods-fix.log` |

The source repo is not required for day-to-day operation after install.

## CoreAudio Event Flow

### On launch

1. Scan all current audio devices for any whose name contains "AirPods" (case-insensitive)
2. For each match: if nominal sample rate ≠ 24000 Hz, set it to 24000 Hz
3. Attach a per-device format listener to each AirPods device found
4. Register a global device-list listener
5. Enter `RunLoop` — idle until next event

### On device-list change (`kAudioHardwarePropertyDevices`)

1. Diff the current device list against the known set
2. For any newly appeared device whose name contains "AirPods":
   - Set nominal sample rate to 24000 Hz
   - Attach per-device format listener
3. For any disappeared device, remove it from the known set (listener is auto-invalidated by CoreAudio)

### On per-device format change (`kAudioDevicePropertyNominalSampleRate`)

1. Wait 500ms — allows macOS to finish Bluetooth profile negotiation
2. Read current sample rate
3. If ≠ 24000 Hz, set to 24000 Hz

The 500ms delay prevents the daemon from fighting macOS during the brief window when the system legitimately holds an intermediate format while switching profiles.

## Device Identification

Match on partial name `"AirPods"` (case-insensitive) against `kAudioObjectPropertyName`. This handles:
- Renamed devices ("Yoel's AirPods Pro3 1" or any future name)
- New hardware replacements
- Both the output and input CoreAudio devices that AirPods expose

Both output and input devices are reset to 24kHz, since macOS can reset either independently. The output device is what matters for Apple Music playback; covering both costs nothing.

## Deployment

Uses macOS LaunchAgents — the standard mechanism for user-space background processes. No sudo required.

The LaunchAgent plist configures:
- Run binary at login
- Restart on crash (`KeepAlive = true`)
- Stdout/stderr to `~/Library/Logs/airpods-fix.log`

### install.sh steps

1. Check for `swiftc` (ships with Xcode Command Line Tools)
2. Compile `airpods-fix.swift` → `~/.local/bin/airpods-fix`
3. Expand plist template → `~/Library/LaunchAgents/com.yoel.airpods-format-fix.plist`
4. `launchctl bootstrap gui/$(id -u)` to register and start immediately (no reboot needed)

### uninstall.sh steps

1. `launchctl bootout` to stop and unregister
2. Remove plist from `~/Library/LaunchAgents/`
3. Remove binary from `~/.local/bin/`

## Error Handling

- If `swiftc` is missing at install time: print instructions to install Xcode CLT (`xcode-select --install`) and exit
- If format set fails (e.g., device busy): log the error, retry on the next event
- If the daemon crashes: LaunchAgent restarts it automatically

## Testing

- Connect AirPods → verify format is 24kHz within 1 second
- Disconnect and reconnect → verify format resets to 24kHz
- Make and end an iPhone call → verify format resets to 24kHz after call
- Open Apple Music, play audio → verify no crackling
- Reboot Mac → verify daemon starts at login and fixes format on first connect
