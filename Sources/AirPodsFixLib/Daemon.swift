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
