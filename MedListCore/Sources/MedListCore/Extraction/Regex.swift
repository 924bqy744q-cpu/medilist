import Foundation

/// Small NSRegularExpression wrapper (works on Linux, unlike `Regex` literals with all options).
struct Pattern {
    let regex: NSRegularExpression

    init(_ pattern: String, caseSensitive: Bool = false) {
        // Patterns are compile-time constants; a bad one is a programmer error caught by tests.
        regex = try! NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
    }

    struct Match {
        let range: Range<String.Index>
        let groups: [String?]
        var text: String
    }

    func matches(in string: String) -> [Match] {
        let ns = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: ns).compactMap { result in
            guard let range = Range(result.range, in: string) else { return nil }
            let groups: [String?] = (0..<result.numberOfRanges).map { i in
                Range(result.range(at: i), in: string).map { String(string[$0]) }
            }
            return Match(range: range, groups: groups, text: String(string[range]))
        }
    }

    func firstMatch(in string: String) -> Match? { matches(in: string).first }
}
