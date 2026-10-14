import AppKit
import CoreAudio

struct HardwareChange {
    let symbol: String
    let label: String
    let level: Double?
    static func key(_ code: Int) -> HardwareChange? {
        switch code {
        case 0: return .init(symbol: "speaker.wave.3.fill", label: "Volume up", level: outputLevel())
        case 1: return .init(symbol: "speaker.wave.1.fill", label: "Volume down", level: outputLevel())
        case 7: return .init(symbol: "speaker.slash.fill", label: "Mute toggled", level: outputLevel())
        case 2: return .init(symbol: "sun.max.fill", label: "Brightness up", level: nil)
        case 3: return .init(symbol: "sun.min.fill", label: "Brightness down", level: nil)
        default: return nil
        }
    }
    static func outputLevel() -> Double? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var property = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size, &device) == noErr else { return nil }
        var value: Float32 = 0
        size = UInt32(MemoryLayout<Float32>.size)
        property = .init(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr else { return nil }
        return Double(min(1, max(0, value)))
    }
}

/// Observes only system media-key events; never consumes keys or reads typing.
@MainActor final class HardwareFeedback {
    private var global: Any?
    private var local: Any?
    private var timer: Timer?
    private var lastVolume: Double?
    var changed: ((HardwareChange) -> Void)?
    func start() {
        stop()
        global = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in self?.handle(event) }
        local = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in self?.handle(event); return event }
        lastVolume = HardwareChange.outputLevel()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let value = HardwareChange.outputLevel()
                if let value, let old = self.lastVolume, abs(value - old) > 0.005 {
                    self.changed?(.init(symbol: "speaker.wave.2.fill", label: "Volume", level: value))
                }
                self.lastVolume = value
            }
        }
    }
    private func handle(_ event: NSEvent) {
        guard event.subtype.rawValue == 8, (event.data1 >> 8) & 0xff == 0x0a else { return }
        let code = (event.data1 >> 16) & 0xffff
        guard [0, 1, 2, 3, 7].contains(code) else { return }
        // Read volume after macOS has applied the key; brightness levels are
        // intentionally omitted where no portable public readback is available.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            if let change = HardwareChange.key(code) { self?.changed?(change) }
        }
    }
    func stop() {
        if let global { NSEvent.removeMonitor(global) }; global = nil
        if let local { NSEvent.removeMonitor(local) }; local = nil
        timer?.invalidate(); timer = nil
    }
}
