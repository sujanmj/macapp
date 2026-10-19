import AVFoundation
import Foundation

@main
struct MacNotchAudioRecordingChecks {
    static func main() throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchAudioOnly-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: output) }
        let writer = try AVAssetWriter(outputURL: output, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000
        ]
        let systemAudio = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        let microphone = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        systemAudio.expectsMediaDataInRealTime = true
        microphone.expectsMediaDataInRealTime = true
        precondition(writer.canAdd(systemAudio), "M4A writer should accept the system-audio track")
        writer.add(systemAudio)
        precondition(writer.canAdd(microphone), "M4A writer should accept a separate microphone track alongside system audio")
        writer.add(microphone)
        precondition(writer.inputs.count == 2, "Audio-only meeting files should preserve system audio and microphone as separate tracks")
        print("MacNotch audio-only writer checks passed")
    }
}
