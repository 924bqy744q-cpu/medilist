import Foundation

/// Data minimisation before OCR text leaves the device: removes identifiers extraction does not need
/// (the care recipient's name and birth date, phone numbers, prescription/patient numbers, addresses, e-mail).
///
/// This is best-effort, not a guarantee; the consent screen still says that label text is processed by the
/// extraction service.
public struct OCRRedactor: Sendable {
    public let recipientName: String?
    public let dateOfBirth: Date?

    public init(recipientName: String?, dateOfBirth: Date?) {
        self.recipientName = recipientName
        self.dateOfBirth = dateOfBirth
    }

    public static let placeholder = "[redacted]"

    private static let linePatterns: [Pattern] = [
        Pattern(#"^\s*(?:rx\s?(?:#|nr\b|no\b)|receptnr\b|recept\s?(?:#|nr\b)|(?:patient\s?(?:id|no|nr)|patiëntnummer|bsn|mrn|dob|geb(?:oorte)?(?:datum)?|date of birth|address|adres)\b).*$"#),
    ]
    private static let inlinePatterns: [Pattern] = [
        Pattern(#"[\w.+-]+@[\w-]+\.[\w.]+"#),                               // e-mail
        Pattern(#"(?:\+\d{1,3}[\s-]?)?\(?\d{2,4}\)?[\s-]?\d{3}[\s-]?\d{3,4}\b"#),  // phone numbers
        Pattern(#"\b[1-9]\d{3}\s?(?!MG|ML|IE|IU)[A-Z]{2}\b"#, caseSensitive: true),  // Dutch postcode
        Pattern(#"\b\d{6,}\b"#),                                            // long ID numbers (Rx, BSN, MRN)
    ]

    public func redact(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines).map { line -> String in
            Self.linePatterns.contains { $0.firstMatch(in: line) != nil } ? Self.placeholder : line
        }
        lines = lines.map { line in
            var result = line
            for pattern in Self.inlinePatterns {
                result = pattern.regex.stringByReplacingMatches(
                    in: result, range: NSRange(result.startIndex..., in: result), withTemplate: Self.placeholder)
            }
            for token in nameTokens() {
                result = Pattern(#"\b"# + NSRegularExpression.escapedPattern(for: token) + #"\b"#).regex
                    .stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: Self.placeholder)
            }
            for dateString in birthDateStrings() {
                result = result.replacingOccurrences(of: dateString, with: Self.placeholder)
            }
            return result
        }
        return lines.joined(separator: "\n")
    }

    /// Name parts of three or more letters, so initials and particles ("van", "de") alone are not stripped from drug text.
    private func nameTokens() -> [String] {
        guard let recipientName else { return [] }
        let particles: Set<String> = ["van", "der", "den", "de", "het", "ter", "ten"]
        return recipientName
            .split(whereSeparator: { !$0.isLetter && $0 != "-" && $0 != "'" })
            .map(String.init)
            .filter { $0.count >= 3 && !particles.contains($0.lowercased()) }
    }

    private func birthDateStrings() -> [String] {
        guard let dateOfBirth else { return [] }
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: dateOfBirth)
        guard let y = c.year, let m = c.month, let d = c.day else { return [] }
        let dd = String(format: "%02d", d), mm = String(format: "%02d", m)
        return [
            "\(dd)-\(mm)-\(y)", "\(dd)/\(mm)/\(y)", "\(dd).\(mm).\(y)",
            "\(mm)/\(dd)/\(y)", "\(m)/\(d)/\(y)", "\(d)-\(m)-\(y)", "\(y)-\(mm)-\(dd)",
        ]
    }
}
