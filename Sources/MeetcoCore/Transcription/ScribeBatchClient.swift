import Foundation

public struct ScribeBatchWord: Decodable, Equatable, Sendable {
    public var text: String
    public var start: Double?
    public var end: Double?
    public var type: String?
    public var speakerID: String?

    enum CodingKeys: String, CodingKey {
        case text, start, end, type
        case speakerID = "speaker_id"
    }

    public init(
        text: String,
        start: Double? = nil,
        end: Double? = nil,
        type: String? = nil,
        speakerID: String? = nil
    ) {
        self.text = text
        self.start = start
        self.end = end
        self.type = type
        self.speakerID = speakerID
    }
}

public struct ScribeBatchResponse: Decodable, Equatable, Sendable {
    public var languageCode: String?
    public var languageProbability: Double?
    public var text: String
    public var words: [ScribeBatchWord]

    enum CodingKeys: String, CodingKey {
        case text, words
        case languageCode = "language_code"
        case languageProbability = "language_probability"
    }

    public init(
        languageCode: String? = nil,
        languageProbability: Double? = nil,
        text: String,
        words: [ScribeBatchWord]
    ) {
        self.languageCode = languageCode
        self.languageProbability = languageProbability
        self.text = text
        self.words = words
    }
}

public struct ScribeBatchUpload: Sendable {
    public var request: URLRequest
    public var body: MultipartFormFile
}

public actor ScribeBatchClient {
    private let session: URLSession

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    public func transcribe(
        meetingID: UUID,
        audioURL: URL,
        apiKey: String,
        languageCode: String? = nil,
        keyterms: [String] = [],
        numberOfSpeakers: Int? = nil
    ) async throws -> [TranscriptSegment] {
        let upload = try Self.makeUpload(
            audioURL: audioURL,
            apiKey: apiKey,
            languageCode: languageCode,
            keyterms: keyterms,
            numberOfSpeakers: numberOfSpeakers
        )
        defer { try? FileManager.default.removeItem(at: upload.body.url) }
        let (data, response) = try await session.upload(for: upload.request, fromFile: upload.body.url)
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionFailure(kind: .transient, message: "Scribe returned no HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.failure(statusCode: http.statusCode, data: data)
        }
        let decoded: ScribeBatchResponse
        do {
            decoded = try JSONDecoder().decode(ScribeBatchResponse.self, from: data)
        } catch {
            throw TranscriptionFailure(kind: .invalidInput, message: "Scribe returned an unreadable transcript.")
        }
        return Self.segments(from: decoded, meetingID: meetingID)
    }

    public static func makeUpload(
        audioURL: URL,
        apiKey: String,
        languageCode: String? = nil,
        keyterms: [String] = [],
        numberOfSpeakers: Int? = nil,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) throws -> ScribeBatchUpload {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionFailure(kind: .missingKey, message: "Add an ElevenLabs API key first.")
        }
        var fields = [
            ("model_id", "scribe_v2"),
            ("diarize", "true"),
            ("timestamps_granularity", "word"),
            ("tag_audio_events", "true"),
        ]
        if let languageCode, !languageCode.isEmpty { fields.append(("language_code", languageCode)) }
        if let count = numberOfSpeakers { fields.append(("num_speakers", String(min(max(count, 1), 32)))) }
        fields.append(contentsOf: ScribeKeyterms.batch(keyterms).map { ("keyterms", $0) })
        let body = try MultipartFormFile.create(
            fields: fields,
            fileField: "file",
            fileURL: audioURL,
            mimeType: mimeType(for: audioURL),
            temporaryDirectory: temporaryDirectory
        )
        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(body.boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(body.contentLength), forHTTPHeaderField: "Content-Length")
        return ScribeBatchUpload(request: request, body: body)
    }

    public static func segments(
        from response: ScribeBatchResponse,
        meetingID: UUID
    ) -> [TranscriptSegment] {
        let timedWords = response.words.filter { $0.start != nil && $0.end != nil }
        guard !timedWords.isEmpty else {
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? [] : [TranscriptSegment(
                meetingID: meetingID,
                startMilliseconds: 0,
                endMilliseconds: 0,
                text: text,
                version: .final,
                provider: "elevenlabs",
                languageCode: response.languageCode,
                confidence: response.languageProbability
            )]
        }

        var groups: [[ScribeBatchWord]] = []
        for word in timedWords {
            let previous = groups.last?.last
            let gap = (word.start ?? 0) - (previous?.end ?? 0)
            if groups.isEmpty || previous?.speakerID != word.speakerID || gap > 1.5 {
                groups.append([word])
            } else {
                groups[groups.count - 1].append(word)
            }
        }
        return groups.compactMap { group in
            guard let first = group.first, let last = group.last else { return nil }
            let text = joinedText(group).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TranscriptSegment(
                meetingID: meetingID,
                startMilliseconds: milliseconds(first.start ?? 0),
                endMilliseconds: milliseconds(last.end ?? first.start ?? 0),
                text: text,
                speakerID: first.speakerID,
                version: .final,
                isCommitted: true,
                words: group.compactMap { word in
                    guard let start = word.start, let end = word.end else { return nil }
                    return TranscriptWord(
                        text: word.text,
                        startMilliseconds: milliseconds(start),
                        endMilliseconds: milliseconds(end)
                    )
                },
                provider: "elevenlabs",
                languageCode: response.languageCode,
                confidence: response.languageProbability
            )
        }
    }

    private static func failure(statusCode: Int, data: Data) -> TranscriptionFailure {
        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { ($0["detail"] ?? $0["message"]) as? String }
            ?? "Scribe batch request failed (HTTP \(statusCode))."
        let kind: TranscriptionFailureKind = switch statusCode {
        case 401, 403: .authentication
        case 402: .quota
        case 408, 429: .rateLimited
        case 500...599: .transient
        default: .invalidInput
        }
        return TranscriptionFailure(kind: kind, message: message)
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav": "audio/wav"
        case "caf": "audio/x-caf"
        case "m4a": "audio/mp4"
        case "mp3": "audio/mpeg"
        default: "application/octet-stream"
        }
    }

    private static func joinedText(_ words: [ScribeBatchWord]) -> String {
        words.reduce(into: "") { result, word in
            guard !word.text.isEmpty else { return }
            let first = word.text.first
            let punctuation = first.map { ",.!?;:%)]}".contains($0) } ?? false
            if result.isEmpty || result.last?.isWhitespace == true || first?.isWhitespace == true || punctuation {
                result += word.text
            } else {
                result += " " + word.text
            }
        }
    }

    private static func milliseconds(_ seconds: Double) -> Int64 {
        Int64((seconds * 1_000).rounded())
    }
}
