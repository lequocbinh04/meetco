import Foundation

public enum LocalAudioInspection {
    public static let pcmWAVHeaderByteCount = 44
    public static let maximumHeaderOnlyCAFByteCount = 4_096

    public static func hasUsableAudio(in directory: URL) -> Bool {
        if hasUsableFinalMix(at: directory.appendingPathComponent("final-mix.wav")) {
            return true
        }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return files.contains { url in
            guard url.pathExtension.lowercased() == "caf",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { return false }
            return (values.fileSize ?? 0) > maximumHeaderOnlyCAFByteCount
        }
    }

    public static func hasUsableFinalMix(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true else { return false }
        return (values.fileSize ?? 0) > pcmWAVHeaderByteCount
    }
}
