import Foundation

public enum ScribeKeyterms {
    public static func realtime(_ values: [String]) -> [String] {
        normalize(values, limit: 50, maximumCharacters: 20, maximumWords: nil)
    }

    public static func batch(_ values: [String]) -> [String] {
        normalize(values, limit: 1_000, maximumCharacters: 49, maximumWords: 5)
    }

    private static func normalize(
        _ values: [String],
        limit: Int,
        maximumCharacters: Int,
        maximumWords: Int?
    ) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        let unsupported = CharacterSet(charactersIn: "<>{}[]\\")

        for value in values {
            let words = value.components(separatedBy: unsupported).joined()
                .split(whereSeparator: \Character.isWhitespace)
            let sanitized = (maximumWords.map { words.prefix($0) } ?? words[...])
                .joined(separator: " ")
            let bounded = String(sanitized.prefix(maximumCharacters))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bounded.isEmpty else { continue }
            let identity = bounded.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(identity).inserted else { continue }
            result.append(bounded)
            if result.count == limit { break }
        }
        return result
    }
}
