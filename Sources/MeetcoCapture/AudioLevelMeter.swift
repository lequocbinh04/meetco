import Foundation
import MeetcoCore

public enum AudioLevelMeter {
    public static func measure(source: AudioSource, samples: [Int16]) -> AudioLevel {
        guard !samples.isEmpty else {
            return AudioLevel(source: source, linear: 0, decibels: -80)
        }

        let sum = samples.reduce(0.0) { partial, sample in
            let normalized = Double(sample) / Double(Int16.max)
            return partial + normalized * normalized
        }
        let rms = sqrt(sum / Double(samples.count))
        let decibels = rms > 0 ? Float(20 * log10(rms)) : -80
        let normalizedLevel = max(0, min(1, (decibels + 60) / 60))
        return AudioLevel(source: source, linear: normalizedLevel, decibels: decibels)
    }
}
