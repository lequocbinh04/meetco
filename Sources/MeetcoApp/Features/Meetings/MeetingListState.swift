import Foundation
import MeetcoCore

public struct MeetingListItemState: Identifiable, Equatable, Sendable {
    public let meeting: Meeting
    public let transcriptVersion: TranscriptVersion?
    public let actionCount: Int

    public var id: UUID { meeting.id }

    public init(meeting: Meeting, transcriptVersion: TranscriptVersion?, actionCount: Int) {
        self.meeting = meeting
        self.transcriptVersion = transcriptVersion
        self.actionCount = actionCount
    }
}

public struct MeetingListState: Equatable, Sendable {
    public let meetings: [MeetingListItemState]
    public let selectedMeetingID: UUID?

    public init(meetings: [MeetingListItemState], selectedMeetingID: UUID?) {
        self.meetings = meetings
        self.selectedMeetingID = selectedMeetingID
    }
}
