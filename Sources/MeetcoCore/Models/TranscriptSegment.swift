import Foundation

public enum TranscriptVersion: String, Codable, Sendable {
    case provisional
    case final
}

public enum AudioSource: String, Codable, Sendable {
    case microphone
    case system
    case mixed
    case unknown
}

public struct TranscriptWord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var startMilliseconds: Int64
    public var endMilliseconds: Int64

    public init(
        id: UUID = UUID(),
        text: String,
        startMilliseconds: Int64,
        endMilliseconds: Int64
    ) {
        self.id = id
        self.text = text
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
    }
}

public struct TranscriptSegment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let meetingID: UUID
    public var startMilliseconds: Int64
    public var endMilliseconds: Int64
    public var text: String
    public var speakerID: String?
    public var speakerName: String?
    public var source: AudioSource
    public var version: TranscriptVersion
    public var isCommitted: Bool
    public var words: [TranscriptWord]
    public var provider: String?
    public var providerSessionID: String?
    public var languageCode: String?
    public var confidence: Double?

    public init(
        id: UUID = UUID(),
        meetingID: UUID,
        startMilliseconds: Int64,
        endMilliseconds: Int64,
        text: String,
        speakerID: String? = nil,
        speakerName: String? = nil,
        source: AudioSource = .unknown,
        version: TranscriptVersion = .provisional,
        isCommitted: Bool = true,
        words: [TranscriptWord] = [],
        provider: String? = nil,
        providerSessionID: String? = nil,
        languageCode: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.meetingID = meetingID
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.text = text
        self.speakerID = speakerID
        self.speakerName = speakerName
        self.source = source
        self.version = version
        self.isCommitted = isCommitted
        self.words = words
        self.provider = provider
        self.providerSessionID = providerSessionID
        self.languageCode = languageCode
        self.confidence = confidence
    }
}

public struct EvidenceReference: Codable, Equatable, Sendable {
    public var segmentIDs: [UUID]
    public var startMilliseconds: Int64?
    public var endMilliseconds: Int64?

    public init(
        segmentIDs: [UUID] = [],
        startMilliseconds: Int64? = nil,
        endMilliseconds: Int64? = nil
    ) {
        self.segmentIDs = segmentIDs
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
    }
}
