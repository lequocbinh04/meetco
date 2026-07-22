import Foundation

public struct AudioFrame: Codable, Equatable, Sendable {
    public var source: AudioSource
    public var startMilliseconds: Int64
    public var sampleRate: Int
    public var channelCount: Int
    public var sampleCount: Int
    public var pcmData: Data

    public init(
        source: AudioSource,
        startMilliseconds: Int64,
        sampleRate: Int = 16_000,
        channelCount: Int = 1,
        sampleCount: Int,
        pcmData: Data
    ) {
        self.source = source
        self.startMilliseconds = startMilliseconds
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.sampleCount = sampleCount
        self.pcmData = pcmData
    }

    public var durationMilliseconds: Int64 {
        guard sampleRate > 0 else { return 0 }
        return Int64((Double(sampleCount) / Double(sampleRate) * 1_000).rounded())
    }
}

public struct AudioLevel: Equatable, Sendable {
    public var source: AudioSource
    public var linear: Float
    public var decibels: Float

    public init(source: AudioSource, linear: Float, decibels: Float) {
        self.source = source
        self.linear = min(max(linear, 0), 1)
        self.decibels = decibels
    }
}
