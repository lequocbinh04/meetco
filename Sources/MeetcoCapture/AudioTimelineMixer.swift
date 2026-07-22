import Foundation
import MeetcoCore

public actor AudioTimelineMixer {
    private struct SampleQueue {
        var storage: [Int16] = []
        var readIndex = 0

        var available: Int { storage.count - readIndex }

        mutating func append(contentsOf samples: [Int16]) {
            storage.append(contentsOf: samples)
        }

        mutating func appendSilence(count: Int) {
            guard count > 0 else { return }
            storage.append(contentsOf: repeatElement(0, count: count))
        }

        mutating func take(_ count: Int) -> ArraySlice<Int16> {
            let end = min(storage.count, readIndex + count)
            let result = storage[readIndex..<end]
            readIndex = end
            if readIndex > 16_000, readIndex * 2 > storage.count {
                storage.removeFirst(readIndex)
                readIndex = 0
            }
            return result
        }
    }

    public static let frameSampleCount = 4_000
    public static let maximumSourceSkewSampleCount = 16_000
    private let expectedSources: [AudioSource]
    private var queues: [AudioSource: SampleQueue]
    private var writtenSampleCounts: [AudioSource: Int64]
    private var emittedSampleCount: Int64 = 0

    public init(expectedSources: Set<AudioSource>) {
        self.expectedSources = expectedSources.sorted { $0.rawValue < $1.rawValue }
        self.queues = Dictionary(uniqueKeysWithValues: expectedSources.map { ($0, SampleQueue()) })
        self.writtenSampleCounts = Dictionary(uniqueKeysWithValues: expectedSources.map { ($0, 0) })
    }

    public func append(_ chunk: ConvertedAudioChunk) -> [AudioFrame] {
        guard expectedSources.contains(chunk.source), var queue = queues[chunk.source] else {
            return []
        }

        let requestedStart = Int64((Double(chunk.startMilliseconds) / 1_000 * 16_000).rounded())
        let written = writtenSampleCounts[chunk.source, default: 0]
        var samples = chunk.samples

        if requestedStart > written {
            queue.appendSilence(count: Int(requestedStart - written))
            writtenSampleCounts[chunk.source] = requestedStart
        } else if requestedStart < written {
            let overlap = min(Int(written - requestedStart), samples.count)
            samples.removeFirst(overlap)
        }

        queue.append(contentsOf: samples)
        writtenSampleCounts[chunk.source, default: 0] += Int64(samples.count)
        queues[chunk.source] = queue
        padSourcesBehindWatermark()
        return emitReadyFrames()
    }

    public func finish() -> [AudioFrame] {
        let maximumAvailable = expectedSources.map { queues[$0]?.available ?? 0 }.max() ?? 0
        guard maximumAvailable > 0 else { return [] }
        for source in expectedSources {
            var queue = queues[source] ?? SampleQueue()
            queue.appendSilence(count: maximumAvailable - queue.available)
            queues[source] = queue
        }

        var output = emitReadyFrames()
        let remainder = expectedSources.map { queues[$0]?.available ?? 0 }.max() ?? 0
        if remainder > 0 {
            for source in expectedSources {
                var queue = queues[source] ?? SampleQueue()
                queue.appendSilence(count: Self.frameSampleCount - queue.available)
                queues[source] = queue
            }
            output.append(contentsOf: emitReadyFrames())
        }
        return output
    }

    private func emitReadyFrames() -> [AudioFrame] {
        var frames: [AudioFrame] = []
        while expectedSources.allSatisfy({ queues[$0, default: SampleQueue()].available >= Self.frameSampleCount }) {
            let channels = expectedSources.map { source -> [Int16] in
                var queue = queues[source] ?? SampleQueue()
                let samples = Array(queue.take(Self.frameSampleCount))
                queues[source] = queue
                return samples
            }
            let mixed = mix(channels)
            let startMilliseconds = Int64(Double(emittedSampleCount) / 16_000 * 1_000)
            emittedSampleCount += Int64(Self.frameSampleCount)
            let data = mixed.withUnsafeBytes { Data($0) }
            frames.append(AudioFrame(
                source: expectedSources.count == 1 ? expectedSources[0] : .mixed,
                startMilliseconds: startMilliseconds,
                sampleCount: mixed.count,
                pcmData: data
            ))
        }
        return frames
    }

    private func padSourcesBehindWatermark() {
        let furthestWritten = writtenSampleCounts.values.max() ?? 0
        let watermark = max(0, furthestWritten - Int64(Self.maximumSourceSkewSampleCount))
        guard watermark > 0 else { return }

        for source in expectedSources {
            let written = writtenSampleCounts[source, default: 0]
            guard written < watermark else { continue }
            var queue = queues[source] ?? SampleQueue()
            queue.appendSilence(count: Int(watermark - written))
            queues[source] = queue
            writtenSampleCounts[source] = watermark
        }
    }

    private func mix(_ channels: [[Int16]]) -> [Int16] {
        guard let first = channels.first else { return [] }
        if channels.count == 1 { return first }
        return first.indices.map { index in
            let total = channels.reduce(Int64(0)) { $0 + Int64($1[index]) }
            let averaged = total / Int64(channels.count)
            return Int16(clamping: averaged)
        }
    }
}
