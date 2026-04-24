import CoreAudio

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
    let actualCount = Int(size) / MemoryLayout<DeviceID>.size
    return Array(ids.prefix(actualCount))
}

public func deviceName(_ id: DeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var name: CFString? = nil
    var size = UInt32(MemoryLayout<CFString?>.size)
    let status = withUnsafeMutablePointer(to: &name) { ptr in
        AudioObjectGetPropertyData(id, &address, 0, nil, &size,
                                   UnsafeMutableRawPointer(ptr))
    }
    guard status == noErr, let result = name else { return nil }
    return result as String
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
