import Foundation
import MeetcoCore

public actor PCM16WAVWriter {
    public let url: URL
    private let file: FileHandle
    private var dataByteCount: UInt32 = 0
    private var isFinalized = false

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let file = FileHandle(forWritingAtPath: url.path) else {
            throw AudioCaptureError.archiveFailed("Could not create final mix")
        }
        self.file = file
        try file.write(contentsOf: Self.header(dataByteCount: 0))
    }

    public func append(_ frame: AudioFrame) throws {
        guard !isFinalized else { return }
        try file.write(contentsOf: frame.pcmData)
        dataByteCount = dataByteCount.addingReportingOverflow(UInt32(frame.pcmData.count)).partialValue
    }

    public func finish() throws -> URL {
        guard !isFinalized else { return url }
        try file.seek(toOffset: 0)
        try file.write(contentsOf: Self.header(dataByteCount: dataByteCount))
        try file.synchronize()
        try file.close()
        isFinalized = true
        return url
    }

    private static func header(dataByteCount: UInt32) -> Data {
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(littleEndian: 36 &+ dataByteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: UInt16(1))
        data.append(littleEndian: UInt16(1))
        data.append(littleEndian: UInt32(16_000))
        data.append(littleEndian: UInt32(32_000))
        data.append(littleEndian: UInt16(2))
        data.append(littleEndian: UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.append(littleEndian: dataByteCount)
        return data
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
