import AVFoundation
import Foundation

@main
struct MacNotchAudioActionsTests {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchAudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let source = folder.appendingPathComponent("voice.wav")
        try makePCMRecording(at: source)
        let sourceSize = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard AudioFileActions.isSupportedAudio(source),
              AudioFileActions.isSupportedAudio(folder.appendingPathComponent("speech.AIFF")),
              !AudioFileActions.isSupportedAudio(folder.appendingPathComponent("song.m4a")),
              !AudioFileActions.isSupportedAudio(folder.appendingPathComponent("notes.txt")) else {
            fatalError("Audio format filtering should accept WAV/AIFF/CAF and reject unrelated formats")
        }

        let expectedDestination = AudioFileActions.convertedDestination(for: source, in: folder)
        guard expectedDestination.lastPathComponent == "voice-converted.m4a" else { fatalError("Unexpected M4A destination name") }
        try Data("existing file".utf8).write(to: expectedDestination)
        let numberedDestination = AudioFileActions.convertedDestination(for: source, in: folder)
        guard numberedDestination.lastPathComponent == "voice-converted-2.m4a",
              try Data(contentsOf: expectedDestination) == Data("existing file".utf8) else {
            fatalError("Audio conversion must not overwrite an existing file")
        }
        try FileManager.default.removeItem(at: expectedDestination)

        let invalidFile = folder.appendingPathComponent("notes.txt")
        try Data("not audio".utf8).write(to: invalidFile)
        let invalid = await AudioFileActions.convertToM4A([invalidFile, invalidFile], into: folder)
        guard invalid.outputs.isEmpty, invalid.failures.count == 1,
              FileManager.default.fileExists(atPath: invalidFile.path) else {
            fatalError("Invalid and duplicate audio inputs should be reported once without changing the source")
        }

        let result = await AudioFileActions.convertToM4A([source, source], into: folder)
        guard result.outputs.count == 1, result.failures.isEmpty,
              FileManager.default.fileExists(atPath: source.path),
              let output = result.outputs.first,
              let outputSize = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              outputSize < sourceSize,
              try await AVURLAsset(url: output).load(.isPlayable),
              !(try await AVURLAsset(url: output).loadTracks(withMediaType: .audio)).isEmpty else {
            fatalError("Audio conversion should create one playable, smaller M4A with an audio track and preserve the original")
        }
        print("MacNotch audio action checks passed")
    }

    private static func makePCMRecording(at url: URL) throws {
        let sampleRate: UInt32 = 48_000
        let frames = Int(sampleRate) * 3
        let channels: UInt16 = 2
        let bytesPerSample: UInt16 = 2
        let payloadSize = UInt32(frames * Int(channels * bytesPerSample))
        var data = Data("RIFF".utf8)
        data.appendLE(36 + payloadSize)
        data.append(Data("WAVEfmt ".utf8))
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(channels)
        data.appendLE(sampleRate)
        data.appendLE(sampleRate * UInt32(channels * bytesPerSample))
        data.appendLE(channels * bytesPerSample)
        data.appendLE(bytesPerSample * 8)
        data.append(Data("data".utf8))
        data.appendLE(payloadSize)
        for frame in 0..<frames {
            for frequency in [440.0, 523.25] {
                let phase = 2.0 * Double.pi * frequency * Double(frame) / Double(sampleRate)
                data.appendLE(UInt16(bitPattern: Int16(sin(phase) * 12_000)))
            }
        }
        try data.write(to: url, options: .atomic)
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
