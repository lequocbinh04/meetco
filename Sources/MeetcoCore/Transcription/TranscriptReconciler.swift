import Foundation

public struct TranscriptReconciliation: Equatable, Sendable {
    public var provisional: [TranscriptSegment]
    public var final: [TranscriptSegment]
    public var evidenceMapping: [UUID: [UUID]]

    public init(
        provisional: [TranscriptSegment],
        final: [TranscriptSegment],
        evidenceMapping: [UUID: [UUID]]
    ) {
        self.provisional = provisional
        self.final = final
        self.evidenceMapping = evidenceMapping
    }
}

public enum TranscriptReconciler {
    public static func reconcile(
        provisional: [TranscriptSegment],
        final: [TranscriptSegment]
    ) -> TranscriptReconciliation {
        let normalizedFinal = final.map { segment in
            var copy = segment
            copy.version = .final
            copy.isCommitted = true
            return copy
        }
        var mapping: [UUID: [UUID]] = [:]
        for old in provisional {
            let overlaps = normalizedFinal.filter { candidate in
                overlap(
                    old.startMilliseconds...max(old.endMilliseconds, old.startMilliseconds),
                    candidate.startMilliseconds...max(candidate.endMilliseconds, candidate.startMilliseconds)
                ) > 0
            }
            if !overlaps.isEmpty { mapping[old.id] = overlaps.map(\.id) }
        }
        return TranscriptReconciliation(
            provisional: provisional,
            final: normalizedFinal,
            evidenceMapping: mapping
        )
    }

    public static func remap(
        _ evidence: EvidenceReference,
        using reconciliation: TranscriptReconciliation
    ) -> EvidenceReference {
        let finalIDs = Set(reconciliation.final.map(\.id))
        let remapped = evidence.segmentIDs.flatMap { id in
            reconciliation.evidenceMapping[id] ?? (finalIDs.contains(id) ? [id] : [])
        }
        var seen: Set<UUID> = []
        return EvidenceReference(
            segmentIDs: remapped.filter { seen.insert($0).inserted },
            startMilliseconds: evidence.startMilliseconds,
            endMilliseconds: evidence.endMilliseconds
        )
    }

    private static func overlap(_ left: ClosedRange<Int64>, _ right: ClosedRange<Int64>) -> Int64 {
        max(0, min(left.upperBound, right.upperBound) - max(left.lowerBound, right.lowerBound) + 1)
    }
}
