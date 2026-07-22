import Foundation
import Testing
@testable import MeetcoCore

@Suite("Model round trips")
struct ModelRoundTripTests {
    @Test
    func meetingSnapshotRoundTripPreservesEvidenceAndConfiguration() throws {
        let now = Date(timeIntervalSince1970: 1_725_000_000)
        let configuration = MeetingConfiguration(
            captureMode: .onSite,
            transcriptionMode: .realtime,
            audioRetention: .keepAudio,
            agentProvider: .codexCLI,
            artifactRecipe: ArtifactRecipe(risks: true, followUpDraft: true),
            mcpEnabled: true,
            languageCode: "vi",
            keyterms: ["Meetco"]
        )
        let meeting = Meeting(title: "Planning", now: now, configuration: configuration)
        let segment = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 1_000,
            endMilliseconds: 2_500,
            text: "Ship the native app.",
            speakerName: "Cris",
            source: .microphone,
            version: .final
        )
        let decision = EvidenceLinkedText(
            text: "Ship native macOS first.",
            evidence: EvidenceReference(segmentIDs: [segment.id], startMilliseconds: 1_000, endMilliseconds: 2_500)
        )
        let snapshot = MeetingContextSnapshot(
            meeting: meeting,
            transcript: [segment],
            artifacts: MeetingArtifacts(decisions: [decision]),
            updatedAt: now
        )

        let data = try JSONCoding.encoder().encode(snapshot)
        let decoded = try JSONCoding.decoder().decode(MeetingContextSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.artifacts.decisions.first?.evidence.segmentIDs == [segment.id])
    }

    @Test
    func keytermsAreBoundedForRealtimeContract() {
        let configuration = MeetingConfiguration(keyterms: (0..<75).map(String.init))
        #expect(configuration.keyterms.count == 50)

        let realtime = ScribeRealtimeConfiguration(
            keyterms: ["  Meetco  ", "MEETCO", "a very long keyterm that exceeds realtime"]
        )
        #expect(realtime.keyterms == ["Meetco", "a very long keyterm"])
        #expect(ScribeKeyterms.batch(["one two three four five six"]) == ["one two three four five"])
    }

    @Test
    func audioOnlySessionCannotAccidentallyRequestTranscription() {
        let configuration = MeetingConfiguration(
            transcriptionMode: .realtime,
            audioRetention: .audioOnly,
            polishWithBatchAfterRealtime: true
        ).normalizedForSession()
        #expect(configuration.transcriptionMode == .recordOnly)
        #expect(configuration.audioRetention == .audioOnly)
        #expect(!configuration.polishWithBatchAfterRealtime)
    }

    @Test
    func audioFrameDurationUsesSampleRate() {
        let frame = AudioFrame(
            source: .mixed,
            startMilliseconds: 0,
            sampleCount: 4_000,
            pcmData: Data(count: 8_000)
        )
        #expect(frame.durationMilliseconds == 250)
    }
}
