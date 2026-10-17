import Foundation

/// Per-field scoring of extraction output against hand-labelled expectations (used by `medlist-eval`).
public enum EvalScoring {
    /// What a labeller writes in `NNNN.expected.json`: plain strings, null/absent for "not on the label".
    public struct ExpectedFile: Codable, Sendable {
        public var medications: [[String: String?]]
        public init(medications: [[String: String?]]) { self.medications = medications }
    }

    public enum Outcome: String, Codable, CaseIterable, Sendable {
        case correct        // equal, or both empty
        case wrong          // both present, different
        case missed         // expected a value, got none
        case hallucinated   // expected none, got a value
    }

    public struct FieldTally: Codable, Equatable, Sendable {
        public var counts: [Outcome: Int] = [:]
        /// Errors (wrong/missed/hallucinated) that the Confirm screen would have highlighted.
        public var errorsHighlighted = 0
        /// Correct, non-empty values that were highlighted anyway (noise for the caregiver).
        public var correctHighlighted = 0
        public var correctNonEmpty = 0

        public init() {}

        public var total: Int { counts.values.reduce(0, +) }
        public var errors: Int { total - (counts[.correct] ?? 0) }
        public var accuracy: Double { total == 0 ? 0 : Double(counts[.correct] ?? 0) / Double(total) }
        /// Share of errors the highlight would have caught. The key safety number: aim for ~1.0.
        public var errorCatchRate: Double { errors == 0 ? 1 : Double(errorsHighlighted) / Double(errors) }
        public var falseAlarmRate: Double { correctNonEmpty == 0 ? 0 : Double(correctHighlighted) / Double(correctNonEmpty) }
    }

    public struct Report: Codable, Equatable, Sendable {
        public var samples = 0
        public var expectedMedications = 0
        public var matchedMedications = 0
        public var spuriousMedications = 0
        public var fields: [MedField: FieldTally] = Dictionary(uniqueKeysWithValues: MedField.allCases.map { ($0, FieldTally()) })

        public init() {}

        public var overallAccuracy: Double {
            let all = fields.values.reduce(into: (0, 0)) { $0.0 += $1.counts[.correct] ?? 0; $0.1 += $1.total }
            return all.1 == 0 ? 0 : Double(all.0) / Double(all.1)
        }
    }

    /// Lenient comparison: case, accents, spacing, "20mg" vs "20 mg", trailing punctuation and "Dr" vs "Dr." are ignored.
    public static func normalize(_ value: String?) -> String? {
        guard var s = value?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        s = IngredientKey.basic(s)
        s = s.replacingOccurrences(of: #"(\d)\s+([a-zµ%])"#, with: "$1$2", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[.,;:]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s*/\s*"#, with: "/", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }

    public static func outcome(expected: String?, predicted: String?) -> Outcome {
        switch (normalize(expected), normalize(predicted)) {
        case (nil, nil): .correct
        case (nil, _): .hallucinated
        case (_, nil): .missed
        case let (e?, p?): e == p ? .correct : .wrong
        }
    }

    /// Scores one sample and adds it to `report`. Medications are paired by drug-name similarity.
    public static func score(expected: [[String: String?]], predicted: [ExtractedMedication], into report: inout Report) {
        report.samples += 1
        report.expectedMedications += expected.count
        var remaining = Array(predicted.indices)

        for exp in expected {
            let expName = normalize(exp[MedField.drugName.rawValue] ?? nil) ?? ""
            let best = remaining.max { a, b in
                similarity(expName, normalize(predicted[a].drugName.value) ?? "") < similarity(expName, normalize(predicted[b].drugName.value) ?? "")
            }
            var pred: ExtractedMedication?
            if let best, similarity(expName, normalize(predicted[best].drugName.value) ?? "") >= 0.5 {
                pred = predicted[best]
                remaining.removeAll { $0 == best }
                report.matchedMedications += 1
            }
            for field in MedField.allCases {
                let predictedField = pred?[field] ?? .empty
                let result = outcome(expected: exp[field.rawValue] ?? nil, predicted: predictedField.value)
                let highlighted = ConfidencePolicy.needsAttention(predictedField)
                var tally = report.fields[field] ?? FieldTally()
                tally.counts[result, default: 0] += 1
                if result == .correct, predictedField.value != nil {
                    tally.correctNonEmpty += 1
                    if highlighted { tally.correctHighlighted += 1 }
                }
                if result != .correct, highlighted { tally.errorsHighlighted += 1 }
                report.fields[field] = tally
            }
        }
        report.spuriousMedications += remaining.count
    }

    /// 1 - normalized Levenshtein distance.
    static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var previous = row[0]
            row[0] = i
            for j in 1...b.count {
                let current = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
                previous = current
            }
        }
        return 1 - Double(row[b.count]) / Double(max(a.count, b.count))
    }
}

// Encode dictionaries keyed by these enums as JSON objects rather than arrays.
extension MedField: CodingKeyRepresentable {}
extension EvalScoring.Outcome: CodingKeyRepresentable {}
