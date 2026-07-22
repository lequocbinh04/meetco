@preconcurrency import AVFoundation
import Foundation
import MeetcoCore

public struct AudioArchiveTrack: Codable, Equatable, Sendable {
    public var source: AudioSource
    public var fileName: String
    public var sampleRate: Double
    public var channelCount: Int
    public var startedAtMilliseconds: Int64
}

public struct AudioArchiveManifest: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var meetingID: UUID
    public var createdAt: Date
    public var tracks: [AudioArchiveTrack]
    public var completedAt: Date?
}

public actor AudioArchiveWriter {
    private struct OpenTrack {
        var file: AVAudioFile
        var signature: String
        var entryIndex: Int
    }

    public let directory: URL
    public let manifestURL: URL
    private var manifest: AudioArchiveManifest
    private var openTracks: [AudioSource: OpenTrack] = [:]

    public init(meetingID: UUID, directory: URL, now: Date = Date()) throws {
        self.directory = directory
        self.manifestURL = directory.appendingPathComponent("manifest.json")
        self.manifest = AudioArchiveManifest(
            meetingID: meetingID,
            createdAt: now,
            tracks: [],
            completedAt: nil
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func append(_ captured: CapturedAudioBuffer, atMilliseconds: Int64) throws {
        let format = captured.buffer.format
        let signature = "\(format.sampleRate)-\(format.channelCount)-\(format.commonFormat.rawValue)-\(format.isInterleaved)"
        var track = openTracks[captured.source]

        if track?.signature != signature {
            track = try openTrack(
                source: captured.source,
                format: format,
                signature: signature,
                atMilliseconds: atMilliseconds
            )
        }
        guard let track else {
            throw AudioCaptureError.archiveFailed("Could not open an audio track")
        }
        do {
            try track.file.write(from: captured.buffer)
            openTracks[captured.source] = track
        } catch {
            throw AudioCaptureError.archiveFailed(error.localizedDescription)
        }
    }

    public func finish(now: Date = Date()) throws -> URL {
        openTracks.removeAll()
        manifest.completedAt = now
        try AtomicFileWriter.write(manifest, to: manifestURL)
        return manifestURL
    }

    private func openTrack(
        source: AudioSource,
        format: AVAudioFormat,
        signature: String,
        atMilliseconds: Int64
    ) throws -> OpenTrack {
        let index = manifest.tracks.filter { $0.source == source }.count + 1
        let fileName = String(format: "%@-%02d.caf", source.rawValue, index)
        let url = directory.appendingPathComponent(fileName)
        let file: AVAudioFile
        do {
            var fileSettings = format.settings
            fileSettings.removeValue(forKey: AVLinearPCMIsNonInterleaved)
            file = try AVAudioFile(
                forWriting: url,
                settings: fileSettings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
        } catch {
            throw AudioCaptureError.archiveFailed(error.localizedDescription)
        }
        manifest.tracks.append(AudioArchiveTrack(
            source: source,
            fileName: fileName,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            startedAtMilliseconds: atMilliseconds
        ))
        try AtomicFileWriter.write(manifest, to: manifestURL)
        return OpenTrack(file: file, signature: signature, entryIndex: manifest.tracks.count - 1)
    }
}
