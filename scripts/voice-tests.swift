import Foundation
import AVFoundation
import CoreMedia

@main struct VoiceTests {
    @MainActor static func main() async throws {
        let original = "Sujan, let's schedule a meeting tomorrow."
        let store = VoiceStore(answerRequest: { source, instruction, _ in
            precondition(source == original)
            precondition(instruction.contains("Never claim to have scheduled"))
            return "What time works for you tomorrow?"
        }, hasAnswerKey: { true })
        store.transcript = original
        store.askAI()
        precondition(!store.answerError.isEmpty && store.answer.isEmpty, "Consent is required before sending.")
        store.cloudConsent = true
        store.askAI()
        for _ in 0..<100 where store.answerBusy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(store.transcript == original, "Answer must not rewrite the transcript.")
        precondition(store.answer == "What time works for you tomorrow?" && store.answerSource == original)
        let delayed = VoiceStore(answerRequest: { _, _, _ in
            try? await Task.sleep(nanoseconds: 100_000_000)
            return "Late response"
        }, hasAnswerKey: { true })
        delayed.transcript = original; delayed.cloudConsent = true
        delayed.askAI(); delayed.cancelAnswer()
        try await Task.sleep(nanoseconds: 150_000_000)
        precondition(delayed.answer.isEmpty && !delayed.answerBusy, "Cancelled response must not reappear.")

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
        pcm.frameLength = 4800
        for c in 0..<2 { for i in 0..<4800 { pcm.floatChannelData![c][i] = Float(sin(Double(i) * 0.04) * 0.01) } }
        var sample: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48000), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        precondition(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: format.formatDescription,
            sampleCount: 4800, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample) == noErr)
        precondition(CMSampleBufferSetDataBufferFromAudioBufferList(sample!, blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: pcm.audioBufferList) == noErr)
        let writer = SystemAudioFile(url: url)
        try writer.append(sample!); writer.close()
        let decoded = try AVAudioFile(forReading: url)
        precondition(decoded.length > 0 && decoded.fileFormat.channelCount == 2, "Captured stereo PCM must produce readable compressed audio.")
        print("PASS: answer consent, transcript preservation, independent answer snapshot, cancellation, system-audio PCM → AAC round trip.")
    }
}
