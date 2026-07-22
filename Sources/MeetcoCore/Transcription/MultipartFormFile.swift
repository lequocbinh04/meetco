import Foundation

public struct MultipartFormFile: Sendable {
    public let url: URL
    public let boundary: String
    public let contentLength: Int64

    public static func create(
        fields: [(String, String)],
        fileField: String,
        fileURL: URL,
        mimeType: String,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) throws -> MultipartFormFile {
        let boundary = "Meetco-\(UUID().uuidString)"
        let outputURL = temporaryDirectory.appendingPathComponent("meetco-upload-\(UUID().uuidString).multipart")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw TranscriptionFailure(kind: .invalidInput, message: "Could not create upload body.")
        }
        let output = try FileHandle(forWritingTo: outputURL)
        do {
            for (name, value) in fields {
                try output.write(contentsOf: Data("--\(boundary)\r\n".utf8))
                try output.write(contentsOf: Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
                try output.write(contentsOf: Data("\(value)\r\n".utf8))
            }
            let fileName = fileURL.lastPathComponent.replacingOccurrences(of: "\"", with: "")
            try output.write(contentsOf: Data("--\(boundary)\r\n".utf8))
            try output.write(contentsOf: Data(
                "Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n".utf8
            ))
            try output.write(contentsOf: Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
            let input = try FileHandle(forReadingFrom: fileURL)
            defer { try? input.close() }
            while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
            try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
            try output.close()
        } catch {
            try? output.close()
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
        let values = try outputURL.resourceValues(forKeys: [.fileSizeKey])
        return MultipartFormFile(
            url: outputURL,
            boundary: boundary,
            contentLength: Int64(values.fileSize ?? 0)
        )
    }
}
