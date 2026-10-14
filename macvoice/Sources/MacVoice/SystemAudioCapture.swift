import AVFoundation
import ScreenCaptureKit
import Speech

/// Only audio output is registered. No screen images are saved or delivered.
final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var cancelled = false
    private let queue = DispatchQueue(label: "MacVoice.system-audio")
    private var receive: ((CMSampleBuffer) -> Void)?
    var failure: ((Error) -> Void)?

    @MainActor func start(receive: @escaping (CMSampleBuffer) -> Void) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !cancelled else { throw CancellationError() }
        guard let display = content.displays.first else { throw UtilityError(message: "No display is available for system audio capture.") }
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48000
        configuration.channelCount = 2
        configuration.width = 2; configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        queue.sync { self.receive = receive }
        self.stream = stream
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        do {
            try await stream.startCapture()
            if self.stream !== stream { try? await stream.stopCapture() }
        }
        catch { stop(); throw error }
    }
    @MainActor func stop() {
        cancelled = true
        queue.sync { receive = nil }
        if let stream { Task { try? await stream.stopCapture() } }
        stream = nil
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        receive?(sampleBuffer)
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { failure?(error) }
}

/// Accessed only on the serial capture queue; closed after that queue drains.
final class SystemAudioFile {
    private var file: AVAudioFile?
    let url: URL
    init(url: URL) { self.url = url }
    func append(_ sample: CMSampleBuffer) throws {
        guard let description = sample.formatDescription,
              let format = AVAudioFormat(cmAudioFormatDescription: description) as AVAudioFormat?,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sample.numSamples)) else { return }
        buffer.frameLength = buffer.frameCapacity
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(sample.numSamples), into: buffer.mutableAudioBufferList)
        guard status == noErr else { throw UtilityError(message: "Could not read system audio (\(status)).") }
        if file == nil {
            file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate,
                                                            AVNumberOfChannelsKey: format.channelCount, AVEncoderBitRateKey: 128000],
                                   commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        }
        try file?.write(from: buffer)
    }
    func close() { file = nil }
}
