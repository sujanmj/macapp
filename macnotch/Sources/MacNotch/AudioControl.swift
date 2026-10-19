import AppKit
import CoreAudio
import Foundation
import SwiftUI

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    var isDefault: Bool
}

enum AudioControlMath {
    static func normalizedVolume(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

@MainActor
final class AudioControlStore: ObservableObject {
    @Published private(set) var devices: [AudioOutputDevice] = []
    @Published private(set) var currentDeviceID: AudioDeviceID?
    @Published private(set) var volume = 0.5
    @Published private(set) var volumeAvailable = false
    @Published private(set) var isMuted = false
    @Published private(set) var muteAvailable = false
    @Published private(set) var message = "Choose an output device."

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defaultID = AudioDeviceID(kAudioObjectUnknown)
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let defaultStatus = AudioObjectGetPropertyData(system, &defaultAddress, 0, nil, &defaultSize, &defaultID)
        guard defaultStatus == noErr, defaultID != kAudioObjectUnknown else {
            devices = []
            currentDeviceID = nil
            volumeAvailable = false
            muteAvailable = false
            message = "macOS has no default sound output device."
            return
        }

        currentDeviceID = defaultID
        devices = Self.outputDevices(defaultID: defaultID)
        if let value = Self.readScalar(device: defaultID, selector: kAudioDevicePropertyVolumeScalar) {
            volume = Double(value)
            volumeAvailable = Self.isSettable(device: defaultID, selector: kAudioDevicePropertyVolumeScalar)
        } else {
            volumeAvailable = false
        }
        if let value = Self.readUInt32(device: defaultID, selector: kAudioDevicePropertyMute) {
            isMuted = value != 0
            muteAvailable = Self.isSettable(device: defaultID, selector: kAudioDevicePropertyMute)
        } else {
            isMuted = false
            muteAvailable = false
        }
        let name = devices.first(where: { $0.id == defaultID })?.name ?? "Current output"
        if !volumeAvailable && !muteAvailable {
            message = "\(name) manages volume in its own controls; this device does not expose software volume."
        } else {
            message = "\(name) · changes apply to the current macOS output only."
        }
    }

    func setVolume(_ value: Double) {
        guard let currentDeviceID, volumeAvailable else { return }
        let newValue = Float(AudioControlMath.normalizedVolume(value))
        guard Self.writeScalar(device: currentDeviceID, selector: kAudioDevicePropertyVolumeScalar, value: newValue) else {
            message = "macOS could not set this device’s output volume."
            refresh()
            return
        }
        volume = Double(newValue)
        isMuted = false
        message = "Output volume set to \(Int(newValue * 100))%."
    }

    func toggleMute() {
        guard let currentDeviceID, muteAvailable else { return }
        let next: UInt32 = isMuted ? 0 : 1
        guard Self.writeUInt32(device: currentDeviceID, selector: kAudioDevicePropertyMute, value: next) else {
            message = "macOS could not mute this device."
            refresh()
            return
        }
        isMuted = next != 0
        message = isMuted ? "Output muted." : "Output unmuted."
    }

    func selectOutput(_ deviceID: AudioDeviceID) {
        guard devices.contains(where: { $0.id == deviceID }) else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var settable = DarwinBoolean(false)
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectIsPropertySettable(system, &address, &settable) == noErr, settable.boolValue else {
            message = "macOS does not allow MacNotch to change the default output device."
            return
        }
        var requestedID = deviceID
        let status = AudioObjectSetPropertyData(system, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &requestedID)
        if status == noErr { refresh() }
        else { message = "Could not switch sound output (Core Audio error \(status))." }
    }

    private static func outputDevices(defaultID: AudioDeviceID) -> [AudioOutputDevice] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &byteCount) == noErr,
              byteCount > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(byteCount) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &byteCount, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard hasOutputStream(id), let name = deviceName(id) else { return nil }
            return AudioOutputDevice(id: id, name: name, isDefault: id == defaultID)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func hasOutputStream(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &byteCount) == noErr && byteCount > 0
    }

    private static func deviceName(_ device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString?
        var byteCount = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutableBytes(of: &name) { storage in
            guard let baseAddress = storage.baseAddress else { return kAudio_ParamError }
            return AudioObjectGetPropertyData(device, &address, 0, nil, &byteCount, baseAddress)
        }
        guard status == noErr, let name else { return nil }
        return (name as String).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readScalar(device: AudioDeviceID, selector: AudioObjectPropertySelector) -> Float32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var value: Float32 = 0
        var byteCount = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &byteCount, &value) == noErr else { return nil }
        return min(1, max(0, value))
    }

    private static func readUInt32(device: AudioDeviceID, selector: AudioObjectPropertySelector) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var byteCount = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &byteCount, &value) == noErr else { return nil }
        return value
    }

    private static func isSettable(device: AudioDeviceID, selector: AudioObjectPropertySelector) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    @discardableResult
    private static func writeScalar(device: AudioDeviceID, selector: AudioObjectPropertySelector, value: Float32) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var newValue = value
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &newValue) == noErr
    }

    @discardableResult
    private static func writeUInt32(device: AudioDeviceID, selector: AudioObjectPropertySelector, value: UInt32) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var newValue = value
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &newValue) == noErr
    }
}
