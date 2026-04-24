# AirPodsOnMac

A silent macOS daemon that locks your AirPods Pro audio format to 24 kHz, eliminating crackling and audio breakup that makes AirPods unusable as a serious listening device on a Mac.

## The trigger: Apple Music sounded broken

This project exists because **listening to Apple Music on a Mac through AirPods Pro produced constant, severe crackling** — to the point where the AirPods were practically useless as a music device. Music playback was the symptom that made the problem impossible to ignore. Calls and short clips were tolerable; sustained music exposed it on every track.

After replacing both the MacBook and the AirPods (twice), the problem persisted across every combination — proving it wasn't a hardware defect on either side. The crackling was reproducible on demand: connect AirPods, open Apple Music, hit play, hear the noise within seconds.

## What's actually happening

AirPods Pro process audio internally at **24 kHz** when connected to a Mac via Apple's H-chip Bluetooth protocol. macOS, however, defaults the Core Audio format for any newly-connected audio device to **48 kHz** — its generic fallback for "standard" devices.

The mismatch forces Core Audio to perform continuous **2× sample rate conversion** before the audio reaches the Bluetooth layer. The Bluetooth packet scheduler runs on a fixed clock tuned to the AirPods' native 24 kHz processing rate. When the SRC output and the Bluetooth packet timing fall even slightly out of phase — which they will, because they're driven by independent clocks — Core Audio's buffer underruns and overruns become audible as clicks and crackles. Sustained material like music exposes this constantly. Short audio (notification sounds, voice calls) often masks it.

Setting the format manually to 24 kHz in **Audio MIDI Setup** eliminates the crackling immediately. The Bluetooth clock and the Core Audio clock now agree, no SRC happens, and music plays cleanly.

The catch: macOS resets the format to 48 kHz on **every reconnect** — when you take the AirPods off your ears, when iPhone borrows them for a call and gives them back, when the system renegotiates the Bluetooth profile for any reason. The manual fix doesn't survive a single off-ear cycle.

## Why this isn't widely known

The problem is real and reproducible, but stays under the radar because:

- Most users never open Audio MIDI Setup — it's a pro audio utility, not part of the normal Mac surface
- Crackling gets blamed on "Bluetooth interference" or "distance from the Mac"
- Users who hit the problem at full intensity tend to switch to wired headphones rather than dig three layers deep into Core Audio
- Apple Community threads about this exist but close without resolution
- The JUCE audio framework (used by Logic Pro and many other pro audio apps) had to add explicit 24 kHz support after a specific AirPods Pro firmware update — confirming at the framework level that 24 kHz is the correct rate

References:
- [AirPods 4 — audio switches to 24kHz (Apple Community)](https://discussions.apple.com/thread/255875912)
- [AirPods Pro Sample Rate (Apple Community)](https://discussions.apple.com/thread/253367026)
- [Latest AirPod Pro requires 24kHz sample rate support (JUCE Forum)](https://forum.juce.com/t/latest-airpod-pro-requires-24khz-sample-rate-support/49609)
- [Crackling sound on every AirPods on MacBook Pro (Apple Community)](https://discussions.apple.com/thread/253806465)

## What this daemon does

A small Swift binary registers two Core Audio property listeners:

1. **Device-list listener** (`kAudioHardwarePropertyDevices`) — fires whenever any audio device connects or disconnects. When AirPods appear, the daemon resets their format to 24 kHz and attaches a per-device listener.
2. **Per-device format listener** (`kAudioDevicePropertyNominalSampleRate`) — fires when anything changes the AirPods sample rate mid-session. After a 500 ms delay (to let macOS finish Bluetooth profile negotiation), the daemon resets the format back to 24 kHz.

The daemon also performs an immediate scan at startup, so AirPods that are already connected when you log in get fixed before the first track plays.

It runs silently, consumes effectively zero CPU at idle (event-driven, not polling), and starts automatically at login via a LaunchAgent. There is no UI. The only feedback is a log file that records each format reset.

## Installation

Requires **Xcode Command Line Tools** for the Swift compiler:

```bash
xcode-select --install
```

Then clone, build, and install:

```bash
git clone https://github.com/yoelf22/AirPodsOnMac.git
cd AirPodsOnMac
./install.sh
```

`install.sh` does the following:

1. Compiles the release binary with `swift build -c release`
2. Copies the binary to `~/.local/bin/airpods-fix`
3. Writes a LaunchAgent plist to `~/Library/LaunchAgents/com.<username>.airpods-format-fix.plist`
4. Registers the LaunchAgent with `launchctl bootstrap` so it starts immediately and at every login

No `sudo` is required. Nothing is written to `/usr/local`, `/Library`, or any other system location.

After install, the daemon is running. Verify with:

```bash
launchctl list | grep airpods-format-fix
```

You should see a line with a non-zero PID in the first column.

## Verifying it works

Start tailing the log in one terminal:

```bash
tail -f ~/Library/Logs/airpods-fix.log
```

Then trigger a reconnect — pop the AirPods out of your ears, wait ~5 seconds for the off-ear sensor to disconnect them, then put them back in. Within a second, the log should show:

```
[2026-04-24 12:44:29 +0000] Fixed Yoel's AirPods Pro3: 48000.0 Hz → 24000.0 Hz
```

You can also open **Audio MIDI Setup** (`/Applications/Utilities/Audio MIDI Setup.app`), click on your AirPods in the device list, and watch the Format dropdown snap back to `24,000 Hz` after a reconnect.

The real proof: open Apple Music, play any track, and reconnect the AirPods mid-playback. Music resumes without crackling.

## Architecture

```
Sources/
  AirPodsFixLib/              # library — all logic, testable units
    NameMatcher.swift         # pure: does a device name refer to AirPods?
    AudioDevice.swift         # CoreAudio wrappers (enumerate, get/set sample rate)
    Daemon.swift              # listener registration, format reset, thread safety
  airpods-fix/
    main.swift                # entry point — Daemon().start() + RunLoop
Tests/
  AirPodsFixLibTests/         # Swift Testing unit tests for NameMatcher
  NameMatcherRunner/          # standalone runner for environments without full Xcode
install.sh                    # build + deploy + launchctl bootstrap
uninstall.sh                  # tear everything down
docs/superpowers/
  specs/                      # design spec
  plans/                      # implementation plan
```

The library is split into three single-responsibility files. `NameMatcher` is a pure function (one line) that decides whether a Core Audio device name belongs to AirPods — case-insensitive substring match on `"airpods"`. `AudioDevice` is a thin wrapper around the four Core Audio HAL calls the daemon needs. `Daemon` is the only stateful component: it owns a serial dispatch queue, a set of known AirPods device IDs, and a dictionary of pending fix work items used to coalesce rapid callbacks during Bluetooth profile negotiation.

The daemon uses `AudioObjectAddPropertyListenerBlock` rather than the older C-callback API so the dispatch queue can be specified directly, simplifying thread safety. All `knownAirPods` access happens on the daemon's serial queue. Multiple property-change callbacks during a single profile negotiation are coalesced via `DispatchWorkItem` cancellation, so the daemon doesn't fight macOS while it's setting up.

## Uninstallation

```bash
cd AirPodsOnMac
./uninstall.sh
```

This stops the daemon, removes the LaunchAgent, and deletes the binary. The log file at `~/Library/Logs/airpods-fix.log` is left in place; delete it manually if you want.

## Limitations

- **Hard-coded target rate.** 24 kHz is correct for current AirPods Pro firmware on Apple Silicon Macs. Future firmware may require a different value, in which case `Daemon.targetRate` needs updating.
- **Name matching is permissive.** Any audio device whose name contains "airpods" (case-insensitive) gets reset to 24 kHz. This includes EarPods bridged through some adapters and aggregate devices that include AirPods. In practice this hasn't caused problems, but it's worth knowing.
- **Listener cleanup is bounded but not perfect.** When AirPods disconnect, the per-device format listener is not explicitly removed from Core Audio. The Core Audio HAL eventually destroys the device object and the listener with it, but the timing is not guaranteed. This is a small, bounded leak — not a correctness issue.
- **Not the AirPods auto-switch fix.** This daemon controls audio format only. It does not influence whether AirPods automatically reconnect to your Mac after an iPhone call ends — that's Apple's "Automatic Switching" feature, which is unreliable for unrelated reasons. If AirPods don't come back to the Mac on their own, switch them via Control Center → Sound.

## License

MIT — see `LICENSE` (TODO: add).

## Acknowledgments

Built with [Claude Code](https://claude.com/claude-code) using the [Superpowers](https://github.com/anthropics/superpowers) brainstorming, planning, and subagent-driven development skills. Spec and implementation plan are committed in `docs/superpowers/`.
