import Foundation

/// Heuristic, fully on-device parser for pharmacy labels and discharge medication lists (English and Dutch).
///
/// It is deliberately conservative: confidences stay below `ConfidencePolicy.lowThreshold` whenever a value
/// is a guess, so the Confirm screen asks the caregiver to check it. It backs `MockExtractionService` and is
/// the baseline the eval script compares the remote extractor against.
public struct LabelTextParser: Sendable {
    public init() {}

    public func parse(_ text: String) -> [ExtractedMedication] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        let anchors = lines.indices.filter { Self.isAnchor(lines[$0]) }
        let globalPrescriber = Self.prescriber(in: lines)

        if anchors.count <= 1 {
            let med = parseBlock(lines, anchorIndex: anchors.first, prescriber: globalPrescriber)
            return med.isEmpty ? [] : [med]
        }

        // Discharge-paper style: each strength line starts a new medication.
        return anchors.enumerated().map { offset, start in
            let end = offset + 1 < anchors.count ? anchors[offset + 1] : lines.count
            let block = Array(lines[start..<end])
            var fallback = globalPrescriber
            fallback.confidence = min(fallback.confidence, 0.5)
            return parseBlock(block, anchorIndex: 0, prescriber: Self.prescriber(in: block).value == nil ? fallback : Self.prescriber(in: block))
        }
    }

    // MARK: - Block

    private func parseBlock(_ lines: [String], anchorIndex: Int?, prescriber: ExtractedField) -> ExtractedMedication {
        var med = ExtractedMedication()
        let blockText = lines.joined(separator: "\n")
        let anchor = anchorIndex.map { lines[$0] }

        if let anchor, let strength = Self.strengthPattern.firstMatch(in: anchor) {
            med.strength = ExtractedField(value: Self.formatStrength(strength.text), confidence: 0.8)
            let name = Self.cleanName(String(anchor[..<strength.range.lowerBound]))
            if !name.isEmpty {
                med.drugName = ExtractedField(value: name, confidence: Self.looksGarbled(name) ? 0.45 : 0.75)
            } else if let anchorIndex, let previous = lines[..<anchorIndex].last(where: { !Self.isNoise($0) }) {
                med.drugName = ExtractedField(value: Self.cleanName(previous), confidence: 0.5)
            }
        } else if let candidate = lines.first(where: { !Self.isNoise($0) && Self.looksLikeName($0) }) {
            med.drugName = ExtractedField(value: Self.cleanName(candidate), confidence: 0.4)
        }

        med.form = Self.form(anchor: anchor, block: blockText)
        med.dose = Self.dose(in: lines, anchor: anchor)
        med.frequency = Self.frequency(in: lines)
        med.prescriber = prescriber
        med.purpose = Self.purpose(in: blockText)
        return med
    }

    // MARK: - Strength

    static let strengthUnit = #"(?:mg\s?/\s?\d*\s?ml|mcg|µg|microgram(?:s)?|mg|g|ml|iu|ie|units?|eenheden|%)"#
    static let strengthSingle = #"\d+(?:[.,]\d+)?\s?"# + strengthUnit
    static let strengthPattern = Pattern(
        #"(?<![\w.,])"# + strengthSingle + #"(?:\s?/\s?"# + strengthSingle + #")*(?![a-z])"#
    )

    static func formatStrength(_ raw: String) -> String {
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false).map { String($0) }
        // Re-join "mg/5ml"-style units, which contain a slash themselves.
        return Pattern(#"(\d+(?:[.,]\d+)?)\s?([a-zµ%]+(?:\s?/\s?\d*\s?ml)?)"#)
            .matches(in: parts.joined(separator: "/"))
            .map { m in
                let unit = (m.groups[2] ?? "").replacingOccurrences(of: " ", with: "")
                let normalizedUnit = ["IE", "IU"].contains(unit.uppercased()) ? unit.uppercased() : unit.lowercased()
                return "\(m.groups[1] ?? "") \(normalizedUnit)"
            }
            .joined(separator: " / ")
    }

    // MARK: - Name

    static func isAnchor(_ line: String) -> Bool {
        guard let m = strengthPattern.firstMatch(in: line) else { return false }
        // A strength on a line that is otherwise an instruction ("take 5 ml") is not an anchor.
        let before = line[..<m.range.lowerBound].lowercased()
        return !instructionStart.contains { before.trimmingCharacters(in: .whitespaces).hasPrefix($0) }
            && !isNoise(line)
    }

    private static let instructionStart = ["take", "neem", "use", "gebruik", "apply", "inhale", "give", "dosering"]

    static func cleanName(_ raw: String) -> String {
        var name = raw
        name = Pattern(#"^\s*(?:\d+[.)]|[-•*·])\s*"#).regex.stringByReplacingMatches(
            in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
        name = Pattern(#"^(?:rx|med(?:ication)?|medicijn|geneesmiddel)\s*[:#]\s*"#).regex.stringByReplacingMatches(
            in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " -–:,;.\t"))
        if name == name.uppercased() && name.count > 3 { name = name.capitalized }
        return name
    }

    /// Letters and digits mixed inside one word ("ALBUTER0L", "Metf0rmin") usually means an OCR error.
    static func looksGarbled(_ name: String) -> Bool {
        name.split(separator: " ").contains { word in
            word.count > 3 && word.contains(where: \.isLetter) && word.contains(where: \.isNumber)
        }
    }

    static func looksLikeName(_ line: String) -> Bool {
        let letters = line.filter(\.isLetter).count
        return letters >= 4 && Double(letters) / Double(max(line.count, 1)) > 0.6 && line.split(separator: " ").count <= 4
    }

    private static let noisePattern = Pattern(
        #"^(?:rx\s?#|rx\s?nr|qty|quantity|refills?|aantal|herhaal|date|datum|filled|exp|tel|phone|apotheek|pharmacy|patient|patiënt|dob|geb)|\b(?:pharmacy|apotheek|refills?|qty)\b|\d{2,}[-./]\d{2}[-./]\d{2,}|\(\d{3}\)|\d{3}-\d{3,4}"#
    )

    static func isNoise(_ line: String) -> Bool { noisePattern.firstMatch(in: line) != nil }

    // MARK: - Form

    private static let forms: [(Pattern, String)] = [
        (Pattern(#"\b(?:filmomhulde\s+)?tablet(?:ten)?\b"#), "tablet"),
        (Pattern(#"\b(?:tablets?|tabs?|tab\.)(?![a-z])"#), "tablet"),
        (Pattern(#"\b(?:capsules?|caps?)\b"#), "capsule"),
        (Pattern(#"\b(?:oral\s+)?(?:solution|suspension|syrup|liquid)\b"#), "liquid"),
        (Pattern(#"\b(?:drank|stroop)\b"#), "drank"),
        (Pattern(#"\b(?:inhaler|inhalation|aerosol)\b"#), "inhaler"),
        (Pattern(#"\b(?:inhalator|inhalatie)\b"#), "inhalator"),
        (Pattern(#"\b(?:patch(?:es)?)\b"#), "patch"),
        (Pattern(#"\b(?:pleisters?)\b"#), "pleister"),
        (Pattern(#"\b(?:cream|ointment)\b"#), "cream"),
        (Pattern(#"\b(?:crème|creme|zalf)\b"#), "zalf"),
        (Pattern(#"\b(?:eye\s+)?drops\b"#), "drops"),
        (Pattern(#"\b(?:druppels?|oogdruppels?)\b"#), "druppels"),
        (Pattern(#"\b(?:injection|injectievloeistof|pen)\b"#), "injection"),
        (Pattern(#"\b(?:suppositor(?:y|ies)|zetpil(?:len)?)\b"#), "suppository"),
    ]

    static func form(anchor: String?, block: String) -> ExtractedField {
        if let anchor, let hit = forms.first(where: { $0.0.firstMatch(in: anchor) != nil }) {
            return ExtractedField(value: hit.1, confidence: 0.8)
        }
        if let hit = forms.first(where: { $0.0.firstMatch(in: block) != nil }) {
            return ExtractedField(value: hit.1, confidence: 0.6)
        }
        return .empty
    }

    // MARK: - Dose

    private static let dosePattern = Pattern(
        #"(?<![\w.,/])((?:\d+(?:[.,/]\d+)?(?:\s?-\s?\d+)?|½|one|two|three|half|een|één|twee|drie|halve|1/2)\s+(?:tablets?|tabs?|capsules?|caps?|puffs?|drops?|sprays?|patch(?:es)?|sachets?|tabletten|druppels?|pufjes?|pufs?|stuks?|zakjes?|inhalaties?|ml))\b"#
    )

    static func dose(in lines: [String], anchor: String?) -> ExtractedField {
        // Instruction lines first; on the anchor line, "5 ml" inside "250 mg/5 ml" is strength, not dose.
        let ordered = lines.filter { $0 != anchor } + (anchor.map { [$0] } ?? [])
        for line in ordered {
            let strengthRanges = line == anchor ? strengthPattern.matches(in: line).map(\.range) : []
            if let m = dosePattern.matches(in: line).first(where: { d in !strengthRanges.contains { $0.overlaps(d.range) } }) {
                return ExtractedField(value: (m.groups[1] ?? m.text).lowercased(), confidence: 0.7)
            }
        }
        return .empty
    }

    // MARK: - Frequency

    private static let abbreviationFrequency = Pattern(#"\b(?:q\.?d|b\.?i\.?d|t\.?i\.?d|q\.?i\.?d|q\.?h\.?s|p\.?r\.?n)\b\.?"#)
    private static let frequencyPatterns: [Pattern] = [
        // English
        Pattern(#"\b(?:once|twice|(?:one|two|three|four|\d)\s+times)\s+(?:a\s+|per\s+|each\s+)?(?:day|daily|week)\b"#),
        Pattern(#"\bevery\s+(?:\d+(?:\s?(?:-|to)\s?\d+)?\s+hours?|morning|evening|night|day|other\s+day|week)\b"#),
        Pattern(#"\b(?:at\s+bedtime|in\s+the\s+(?:morning|evening)|before\s+(?:breakfast|meals|bed)|with\s+(?:meals|food|breakfast|dinner))\b"#),
        Pattern(#"\b(?:as|when)\s+needed\b"#),
        Pattern(#"\b(?:daily|weekly|nightly)\b"#),
        // Dutch
        Pattern(#"\b\d\s?(?:x|keer|maal)\s+(?:per\s+|p/\s?)?(?:dag|week)\b|\b\d\s?(?:x|keer|maal)\s+daags\b|\b\d\s?dd\b"#),
        Pattern(#"\b(?:een|één|twee|drie|vier)\s+(?:keer|maal)\s+(?:per\s+dag|daags|per\s+week)\b"#),
        Pattern(#"\b(?:dagelijks|wekelijks|elke\s+dag|zo\s+nodig|bij\s+pijn|om\s+de\s+\d+\s+uur|voor\s+het\s+slapen(?:gaan)?)\b|'s\s+(?:ochtends|avonds|morgens|middags)"#),
    ]

    static func frequency(in lines: [String]) -> ExtractedField {
        for line in lines {
            var hits = frequencyPatterns.flatMap { $0.matches(in: line) }.map(\.range)
            let isAbbreviation = hits.isEmpty
            if hits.isEmpty { hits = abbreviationFrequency.matches(in: line).map(\.range) }
            guard !hits.isEmpty else { continue }

            // Merge neighbouring phrases on the same line ("once daily at bedtime").
            hits.sort { $0.lowerBound < $1.lowerBound }
            var merged = hits[0]
            for range in hits.dropFirst() where range.lowerBound >= merged.lowerBound {
                let gap = line[merged.upperBound..<max(merged.upperBound, range.lowerBound)]
                if gap.count <= 4 && !gap.contains(where: { ",;.".contains($0) }) {
                    merged = merged.lowerBound..<max(merged.upperBound, range.upperBound)
                } else { break }
            }
            return ExtractedField(value: String(line[merged]).lowercased(), confidence: isAbbreviation ? 0.6 : 0.75)
        }
        return .empty
    }

    // MARK: - Prescriber

    private static let prescriberLabel = Pattern(
        #"^(?:prescriber|prescribed\s+by|voorschrijver|voorgeschreven\s+door|behandelend\s+arts|huisarts|arts|attending\s+physician|attending|physician)\s*[:\-]?\s*(.+)$"#
    )
    private static let doctorPrefix = Pattern(#"^(?:dr\.?|doctor|dokter)\s+([a-zà-ÿ][\w.\-' ]+)$"#)
    private static let credentialSuffix = Pattern(#"^([a-zà-ÿ][\w.\-' ]+?),\s*(?:md|m\.d\.|do|np|pa-c)\.?\s*$"#)

    static func prescriber(in lines: [String]) -> ExtractedField {
        for line in lines {
            if let m = prescriberLabel.firstMatch(in: line), let name = m.groups[1] {
                return ExtractedField(value: tidyPerson(name), confidence: 0.8)
            }
            if let m = doctorPrefix.firstMatch(in: line), let name = m.groups[1] {
                return ExtractedField(value: "Dr. " + tidyPerson(name), confidence: 0.75)
            }
            if let m = credentialSuffix.firstMatch(in: line), let name = m.groups[1], !isAnchor(line) {
                return ExtractedField(value: tidyPerson(name), confidence: 0.65)
            }
        }
        return .empty
    }

    private static func tidyPerson(_ raw: String) -> String {
        var name = Pattern(#",?\s*(?:md|m\.d\.|do|np|pa-c)\.?\s*$"#).regex.stringByReplacingMatches(
            in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: "")
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " .,:;"))
        if name == name.uppercased() { name = name.capitalized }
        return name
    }

    // MARK: - Purpose

    private static let purposePatterns: [Pattern] = [
        Pattern(#"\b(?:indication|reason|indicatie|reden|gebruikt\s+voor)\s*:\s*([a-zà-ÿ][a-zà-ÿ \-']{2,40})"#),
        Pattern(#"\b(?:for|voor|tegen)\s+([a-zà-ÿ][a-zà-ÿ \-']{2,40})"#),
        Pattern(#"\(([a-zà-ÿ][a-zà-ÿ \-']{2,40})\)"#),
    ]
    private static let notAPurpose = [
        "the next", "a ", "an ", "het slapen", "de maaltijd", "het eten", "het ontbijt", "bedtime",
        "meals", "breakfast", "dinner", "food", "days", "weeks", "dagen", "weken", "mouth", "oral",
    ]

    static func purpose(in block: String) -> ExtractedField {
        for pattern in purposePatterns {
            for m in pattern.matches(in: block) {
                guard var value = m.groups[1]?.lowercased() else { continue }
                // Stop at the next instruction or label word that the character class let through.
                for stop in [" take", " neem", " by mouth", " dr ", " qty", " refill"] {
                    if let r = value.range(of: stop) { value = String(value[..<r.lowerBound]) }
                }
                value = value.trimmingCharacters(in: .whitespaces)
                guard value.count >= 3, !notAPurpose.contains(where: { value.hasPrefix($0) }) else { continue }
                return ExtractedField(value: value, confidence: 0.55)
            }
        }
        return .empty
    }
}
