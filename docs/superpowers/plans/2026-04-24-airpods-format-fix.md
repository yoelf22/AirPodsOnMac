# AirPods Format Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a silent macOS daemon that locks AirPods Pro Core Audio format to 24kHz on every reconnect, eliminating crackling in Apple Music.

**Architecture:** A Swift binary structured as a Swift Package with a testable library target (`AirPodsFixLib`) and a thin executable entry point. The library registers CoreAudio property listeners for device-list changes and per-device format changes, then resets the sample rate to 24kHz whenever it drifts. Deployed via a LaunchAgent so it starts at login and restarts on crash.

**Tech Stack:** Swift 5.9+, CoreAudio framework, Foundation, Swift Package Manager, macOS LaunchAgents (`launchctl`)

---

## File Map

| Path | Role |
|------|------|
| `Package.swift` | SPM package definition |
| `Sources/AirPodsFixLib/NameMatcher.swift` | Pure function: does a device name refer to AirPods? |
| `Sources/AirPodsFixLib/AudioDevice.swift` | CoreAudio wrappers: enumerate devices, get/set sample rate |
| `Sources/AirPodsFixLib/Daemon.swift` | Listener registration, known-device tracking, format fix |
| `Sources/airpods-fix/main.swift` | Entry point: start daemon, run RunLoop |
| `Tests/AirPodsFixLibTests/NameMatcherTests.swift` | Unit tests for name matching logic |
| `install.sh` | Compile release binary, write LaunchAgent plist, bootstrap |
| `uninstall.sh` | Stop daemon, remove plist and binary |
| `.gitignore` | Exclude `.build/` |

---

## Task 1: Package scaffold, NameMatcher, and tests

**Files:**
- Create: `Package.swift`
- Create: `Sources/AirPodsFixLib/NameMatcher.swift`
- Create: `Sources/airpods-fix/main.swift` (stub)
- Create: `Tests/AirPodsFixLibTests/NameMatcherTests.swift`
- Create: `.gitignore`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AirPodsFixLibTests/NameMatcherTests.swift`:

```swift
import XCTest
@testable import AirPodsFixLib

final class NameMatcherTests: XCTestCase {
    func testExactName() {
        XCTAssertTrue(isAirPodsName("AirPods"))
    }

    func testFullProductName() {
        XCTAssertTrue(isAirPodsName("Yoel's AirPods Pro3 1"))
    }

    func testCaseInsensitive() {
        XCTAssertTrue(isAirPodsName("airpods pro"))
        XCTAssertTrue(isAirPodsName("AIRPODS"))
    }

    func testNonAirPods() {
        XCTAssertFalse(isAirPodsName("Sony WH-1000XM5"))
        XCTAssertFalse(isAirPodsName("MacBook Pro Speakers"))
        XCTAssertFalse(isAirPodsName(""))
    }
}
```

- [ ] **Step 2: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "airpods-fix",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "AirPodsFixLib",
            path: "Sources/AirPodsFixLib",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("Foundation")
            ]
        ),
        .executableTarget(
            name: "airpods-fix",
            dependencies: ["AirPodsFixLib"],
            path: "Sources/airpods-fix"
        ),
        .testTarget(
            name: "AirPodsFixLibTests",
            dependencies: ["AirPodsFixLib"],
            path: "Tests/AirPodsFixLibTests"
        )
    ]
)
```

- [ ] **Step 3: Create stub NameMatcher (just enough to compile)**

Create `Sources/AirPodsFixLib/NameMatcher.swift`:

```swift
public func isAirPodsName(_ name: String) -> Bool {
    return false
}
```

- [ ] **Step 4: Create stub entry point**

Create `Sources/airpods-fix/main.swift`:

```swift
import AirPodsFixLib
import Foundation

// entry point — wired in Task 4
```

- [ ] **Step 5: Run tests — verify they fail**

```bash
swift test
```

Expected: `XCTAssertTrue` failures for `testExactName`, `testFullProductName`, `testCaseInsensitive`.

- [ ] **Step 6: Implement NameMatcher**

Replace `Sources/AirPodsFixLib/NameMatcher.swift`:

```swift
public func isAirPodsName(_ name: String) -> Bool {
    name.lowercased().contains("airpods")
}
```

- [ ] **Step 7: Run tests — verify they pass**

```bash
swift test
```

Expected: `Test Suite 'All tests' passed`

- [ ] **Step 8: Create .gitignore**

```
.build/
*.o
*.d
```

- [ ] **Step 9: Commit**

```bash
git add Package.swift Sources/AirPodsFixLib/NameMatcher.swift \
    Sources/airpods-fix/main.swift \
    Tests/AirPodsFixLibTests/NameMatcherTests.swift \
    .gitignore
git commit -m "feat: add package scaffold, NameMatcher, and unit tests"
```

---

## Task 2: CoreAudio device enumeration and format control

**Files:**
- Create: `Sources/AirPodsFixLib/AudioDevice.swift`

- [ ] **Step 1: Create AudioDevice.swift**

```swift
import CoreAudio
import Foundation

public typealias DeviceID = AudioDeviceID

public func allAudioDevices() -> [DeviceID] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
    ) == noErr else { return [] }
    let count = Int(size) / MemoryLayout<DeviceID>.size
    var ids = [DeviceID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
    ) == noErr else { return [] }
    return ids
}

public func deviceName(_ id: DeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var name = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr else { return nil }
    return name as String
}

public func getNominalSampleRate(_ id: DeviceID) -> Float64? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyNominalSampleRate,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var rate: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &rate) == noErr else { return nil }
    return rate
}

public func setNominalSampleRate(_ id: DeviceID, rate: Float64) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyNominalSampleRate,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var r = rate
    let size = UInt32(MemoryLayout<Float64>.size)
    return AudioObjectSetPropertyData(id, &address, 0, nil, size, &r) == noErr
}
```

- [ ] **Step 2: Verify it compiles**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/AirPodsFixLib/AudioDevice.swift
git commit -m "feat: add CoreAudio device enumeration and format control"
```

---

## Task 3: Daemon — listener logic

**Files:**
- Create: `Sources/AirPodsFixLib/Daemon.swift`

- [ ] **Step 1: Create Daemon.swift**

```swift
import CoreAudio
import Foundation

public final class Daemon {
    public static let targetRate: Float64 = 24000.0

    private let queue = DispatchQueue(label: "com.airpods-fix.daemon")
    private var knownAirPods = Set<DeviceID>()

    public init() {}

    public func start() {
        queue.sync {
            for id in allAudioDevices() where isAirPodsDevice(id) {
                fixFormat(id)
                attachFormatListener(to: id)
            }
        }
        registerDeviceListListener()
        log("Monitoring for AirPods connections...")
    }

    // MARK: - Private

    private func isAirPodsDevice(_ id: DeviceID) -> Bool {
        guard let name = deviceName(id) else { return false }
        return isAirPodsName(name)
    }

    private func fixFormat(_ id: DeviceID) {
        guard let rate = getNominalSampleRate(id), rate != Self.targetRate else { return }
        let name = deviceName(id) ?? "device \(id)"
        if setNominalSampleRate(id, rate: Self.targetRate) {
            log("Fixed \(name): \(rate) Hz → \(Self.targetRate) Hz")
        } else {
            log("Failed to fix \(name) (still at \(rate) Hz)")
        }
    }

    private func attachFormatListener(to id: DeviceID) {
        guard !knownAirPods.contains(id) else { return }
        knownAirPods.insert(id)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(id, &address, queue) { [weak self] _, _ in
            self?.queue.asyncAfter(deadline: .now() + 0.5) {
                self?.fixFormat(id)
            }
        }
    }

    private func registerDeviceListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, queue
        ) { [weak self] _, _ in
            self?.handleDeviceListChange()
        }
    }

    private func handleDeviceListChange() {
        let current = Set(allAudioDevices().filter { isAirPodsDevice($0) })
        for id in current.subtracting(knownAirPods) {
            fixFormat(id)
            attachFormatListener(to: id)
        }
        knownAirPods.subtract(knownAirPods.subtracting(current))
    }

    private func log(_ message: String) {
        print("[\(Date())] \(message)")
        fflush(stdout)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/AirPodsFixLib/Daemon.swift
git commit -m "feat: add Daemon with CoreAudio listeners and format reset"
```

---

## Task 4: Entry point and smoke test

**Files:**
- Modify: `Sources/airpods-fix/main.swift`

- [ ] **Step 1: Wire entry point**

Replace `Sources/airpods-fix/main.swift`:

```swift
import AirPodsFixLib
import Foundation

let daemon = Daemon()
daemon.start()
RunLoop.main.run()
```

- [ ] **Step 2: Build release binary**

```bash
swift build -c release
```

Expected: `Build complete!` — binary at `.build/release/airpods-fix`

- [ ] **Step 3: Run smoke test**

Make sure AirPods are connected to the Mac. Run:

```bash
.build/release/airpods-fix
```

Expected output (within 2 seconds):
```
[2026-04-24 ...] Fixed Yoel's AirPods Pro3 1: 48000.0 Hz → 24000.0 Hz
[2026-04-24 ...] Monitoring for AirPods connections...
```

If AirPods are already at 24kHz, the fix line won't appear — only the "Monitoring" line. That's correct behaviour.

Kill with `Ctrl+C`.

- [ ] **Step 4: Test reconnect response**

With the binary still running in one terminal:

1. Remove AirPods from ears and wait ~5 seconds (triggers off-ear disconnect)
2. Put AirPods back in ears

Expected: within 1 second of reconnect, terminal prints:
```
[...] Fixed Yoel's AirPods Pro3 1: 48000.0 Hz → 24000.0 Hz
```

Kill with `Ctrl+C`.

- [ ] **Step 5: Commit**

```bash
git add Sources/airpods-fix/main.swift
git commit -m "feat: wire entry point, connect daemon to RunLoop"
```

---

## Task 5: install.sh

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Create install.sh**

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Run it**

```bash
./install.sh
```

Expected:
```
Building...
Build complete!
Binary installed at /Users/yoel/.local/bin/airpods-fix
LaunchAgent installed at /Users/yoel/Library/LaunchAgents/com.yoel.airpods-format-fix.plist

Done. Daemon is running. Logs: /Users/yoel/Library/Logs/airpods-fix.log
```

- [ ] **Step 4: Verify daemon is running**

```bash
launchctl list | grep airpods-format-fix
```

Expected: a line with `com.yoel.airpods-format-fix` and a PID (non-zero number in first column).

- [ ] **Step 5: Check logs**

```bash
tail -f ~/Library/Logs/airpods-fix.log
```

Expected: "Monitoring for AirPods connections..." line. Kill tail with `Ctrl+C`.

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh — compile, deploy binary, register LaunchAgent"
```

---

## Task 6: uninstall.sh

**Files:**
- Create: `uninstall.sh`

- [ ] **Step 1: Create uninstall.sh**

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x uninstall.sh
```

- [ ] **Step 3: Test it (then reinstall)**

```bash
./uninstall.sh
```

Expected:
```
Daemon stopped and unregistered
Removed /Users/yoel/Library/LaunchAgents/com.yoel.airpods-format-fix.plist
Removed /Users/yoel/.local/bin/airpods-fix
Uninstalled.
```

Verify it's gone:
```bash
launchctl list | grep airpods-format-fix
```

Expected: no output.

Reinstall for ongoing use:
```bash
./install.sh
```

- [ ] **Step 4: Commit**

```bash
git add uninstall.sh
git commit -m "feat: add uninstall.sh"
```

---

## Task 7: End-to-end deployment test

No new files. Verify the full lifecycle with real hardware.

- [ ] **Step 1: Confirm daemon survives reboot**

Restart the Mac. After login:

```bash
launchctl list | grep airpods-format-fix
```

Expected: entry with non-zero PID.

- [ ] **Step 2: Verify format is fixed on connect**

With AirPods disconnected, open Audio MIDI Setup (`/Applications/Utilities/Audio MIDI Setup.app`). Connect AirPods. Within 1 second, verify Format shows `24,000 Hz`.

- [ ] **Step 3: Simulate iPhone call handoff**

Make a call on iPhone with AirPods active. End the call. Within 2 seconds, verify Audio MIDI Setup shows `24,000 Hz` (not 48,000 Hz).

- [ ] **Step 4: Verify Apple Music plays without crackling**

Open Apple Music, play any track. Confirm no crackling.

- [ ] **Step 5: Push to GitHub**

```bash
git push
```

---

## Self-Review Notes

- **Spec coverage:** All spec requirements covered — startup scan (Task 4), device-list listener (Task 3), per-device format listener (Task 3), 500ms delay (Task 3 `asyncAfter`), both input/output devices handled (CoreAudio returns both as separate `DeviceID`s that both contain "AirPods" in name), install/uninstall (Tasks 5–6), deployment (Task 5).
- **No placeholders:** Confirmed — all steps contain exact code and expected output.
- **Type consistency:** `DeviceID` defined in `AudioDevice.swift`, used consistently across `Daemon.swift`. `isAirPodsName` defined in `NameMatcher.swift`, called in `Daemon.swift`. No naming drift.
