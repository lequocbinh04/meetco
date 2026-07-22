import Foundation
import MeetcoCore

public struct HomeReadinessItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let isReady: Bool

    public init(id: String, title: String, detail: String, isReady: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isReady = isReady
    }
}

public struct RecentMeetingState: Identifiable, Equatable, Sendable {
    public let meeting: Meeting
    public let actionCount: Int
    public let transcriptVersion: TranscriptVersion?

    public var id: UUID { meeting.id }

    public init(meeting: Meeting, actionCount: Int, transcriptVersion: TranscriptVersion?) {
        self.meeting = meeting
        self.actionCount = actionCount
        self.transcriptVersion = transcriptVersion
    }
}

public struct HomeViewState: Equatable, Sendable {
    public let greeting: String
    public let readiness: [HomeReadinessItem]
    public let recentMeetings: [RecentMeetingState]
    public let activeMeeting: Meeting?

    public init(
        greeting: String,
        readiness: [HomeReadinessItem],
        recentMeetings: [RecentMeetingState],
        activeMeeting: Meeting?
    ) {
        self.greeting = greeting
        self.readiness = readiness
        self.recentMeetings = recentMeetings
        self.activeMeeting = activeMeeting
    }
}
