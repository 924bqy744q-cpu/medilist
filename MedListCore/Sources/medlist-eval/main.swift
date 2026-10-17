import Foundation
import MedListCore

// medlist-eval: per-field extraction accuracy over a folder of labelled samples.
//
//   swift run --package-path MedListCore medlist-eval <samples-dir> [--endpoint URL] [--token T] [--json report.json] [--verbose]
//
// Each sample is NNNN.txt (OCR text) or NNNN.jpg/.jpeg/.png/.heic (photo, OCR'd with Vision; macOS only),
// next to NNNN.expected.json. See Eval/README.md.

struct Options {
    var samples: URL
    var endpoint: URL?
    var token: String?
    var jsonOut: URL?
    var verbose = false
    var language = "nl"
}

func parseOptions() -> Options {
    var args = Array(CommandLine.arguments.dropFirst())
    guard let first = args.first, !first.hasPrefix("-") else {
        print("usage: medlist-eval <samples-dir> [--endpoint URL] [--token T] [--json report.json] [--language nl|en] [--verbose]")
        exit(2)
    }
    var options = Options(samples: URL(fileURLWithPath: first))
    args.removeFirst()
    while !args.isEmpty {
        let flag = args.removeFirst()
        switch flag {
        case "--endpoint": options.endpoint = URL(string: args.removeFirst())
        case "--token": options.token = args.removeFirst()
        case "--json": options.jsonOut = URL(fileURLWithPath: args.removeFirst())
        case "--verbose": options.verbose = true
        case "--language": options.language = args.removeFirst()
        default: print("unknown option \(flag)"); exit(2)
        }
    }
    return options
}

func ocrText(for url: URL) async throws -> String? {
    if url.pathExtension.lowercased() == "txt" { return try String(contentsOf: url, encoding: .utf8) }
    #if canImport(Vision)
    return try await TextRecognizer.recognizeText(contentsOf: url)
    #else
    return nil
    #endif
}

let options = parseOptions()
let service: ExtractionService = options.endpoint.map { RemoteExtractionService(endpoint: $0, clientToken: options.token) } ?? MockExtractionService()
let inputExtensions: Set<String> = ["txt", "jpg", "jpeg", "png", "heic"]

let files = (try? FileManager.default.contentsOfDirectory(at: options.samples, includingPropertiesForKeys: nil)) ?? []
let inputs = files
    .filter { inputExtensions.contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var report = EvalScoring.Report()
var skipped: [String] = []
let redactor = OCRRedactor(recipientName: nil, dateOfBirth: nil) // same minimisation as the app

for input in inputs {
    let id = input.deletingPathExtension().lastPathComponent
    let expectedURL = input.deletingLastPathComponent().appendingPathComponent("\(id).expected.json")
    guard let data = try? Data(contentsOf: expectedURL),
          let expected = try? JSONDecoder().decode(EvalScoring.ExpectedFile.self, from: data) else {
        skipped.append("\(input.lastPathComponent) (no valid \(id).expected.json)")
        continue
    }
    guard let text = try? await ocrText(for: input) else {
        skipped.append("\(input.lastPathComponent) (photos need macOS for Vision OCR)")
        continue
    }
    let predicted: [ExtractedMedication]
    do {
        predicted = try await service.extract(from: redactor.redact(text), languageCode: options.language)
    } catch {
        predicted = []
        print("! \(id): extraction failed (\(error))")
    }
    var sampleReport = EvalScoring.Report()
    EvalScoring.score(expected: expected.medications, predicted: predicted, into: &sampleReport)
    EvalScoring.score(expected: expected.medications, predicted: predicted, into: &report)
    if options.verbose {
        let errors = sampleReport.fields.filter { $0.value.errors > 0 }.map(\.key.rawValue).sorted()
        print("\(id): \(errors.isEmpty ? "all fields correct" : "errors in " + errors.joined(separator: ", "))")
    }
}

func pct(_ x: Double) -> String { String(format: "%5.1f%%", x * 100) }
func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: n, withPad: " ", startingAt: 0) }

print("")
print("Extractor: \(options.endpoint == nil ? "on-device parser (mock)" : options.endpoint!.absoluteString)")
print("Samples: \(report.samples)   medications expected: \(report.expectedMedications)   matched: \(report.matchedMedications)   spurious: \(report.spuriousMedications)")
print("")
print(pad("field", 12) + pad("accuracy", 10) + pad("wrong", 7) + pad("missed", 8) + pad("halluc.", 9) + pad("errors caught", 15) + "false alarms")
for field in MedField.allCases {
    let t = report.fields[field] ?? .init()
    print(pad(field.rawValue, 12) + pad(pct(t.accuracy), 10) + pad("\(t.counts[.wrong] ?? 0)", 7) + pad("\(t.counts[.missed] ?? 0)", 8)
          + pad("\(t.counts[.hallucinated] ?? 0)", 9) + pad(pct(t.errorCatchRate), 15) + pct(t.falseAlarmRate))
}
print("")
print("Overall field accuracy: \(pct(report.overallAccuracy))")
print("'errors caught' = share of wrong/missed/hallucinated fields that the Confirm screen highlights (confidence < \(ConfidencePolicy.lowThreshold)).")
if !skipped.isEmpty {
    print("\nSkipped:")
    skipped.forEach { print("  - \($0)") }
}

if let out = options.jsonOut {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(to: out)
    print("\nWrote \(out.path)")
}
