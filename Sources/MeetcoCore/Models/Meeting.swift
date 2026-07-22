import Foundation

public enum MeetingStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case recording
    case paused
    case finalizing
    case completed
    case failed
    case recoverable
}

public struct Meeting: Identifiable, Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let id: UUID
    public var schemaVersion: Int
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var startedAt: Date?
    public var endedAt: Date?
    public var durationMilliseconds: Int64
    public var status: MeetingStatus
    public var configuration: MeetingConfiguration
    public var hasLocalAudio: Bool
    public var failureMessage: String?

    public init(
        id: UUID = UUID(),
        title: String = "Untitled meeting",
        now: Date = Date(),
        status: MeetingStatus = .draft,
        configuration: MeetingConfiguration = .init()
    ) {
        self.id = id
        self.schemaVersion = Self.currentSchemaVersion
        self.title = title
        self.createdAt = now
        self.updatedAt = now
        self.startedAt = nil
        self.endedAt = nil
        self.durationMilliseconds = 0
        self.status = status
        self.configuration = configuration
        self.hasLocalAudio = false
        self.failureMessage = nil
    }
}
