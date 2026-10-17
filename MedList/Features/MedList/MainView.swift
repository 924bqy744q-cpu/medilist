import SwiftUI
import SwiftData
import MedListCore

enum Route: Hashable {
    case scan
    case confirm(ScanResult)
    case add
    case edit(UUID)
    case flags
    case export
    case settings
}

/// Result of a scan, held in memory only. Hashed by identity so it can travel in the navigation path.
struct ScanResult: Hashable {
    let id = UUID()
    var drafts: [MedicationDraft]
    var recognizedText: String
    var usedFallback: Bool

    static func == (a: ScanResult, b: ScanResult) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MainView: View {
    let recipient: CareRecipient
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            MedListView(recipient: recipient, medications: medications, path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .scan:
                        ScanView(recipient: recipient, path: $path)
                    case .confirm(let result):
                        ConfirmView(result: result, path: $path)
                    case .add:
                        MedicationEditView(medication: nil)
                    case .edit(let id):
                        MedicationEditView(medication: medications.first { $0.id == id })
                    case .flags:
                        FlagsView(medications: medications)
                    case .export:
                        ExportView(recipient: recipient, medications: medications)
                    case .settings:
                        SettingsView(recipient: recipient)
                    }
                }
        }
        .task(id: medications.map(\.snapshot)) {
            await env.flags.refresh(medications.map(\.snapshot), engine: env.flagEngine)
        }
        .onAppear {
            switch env.launch.open {
            case "flags": path = [.flags]
            case "export": path = [.export]
            case "settings": path = [.settings]
            case "confirm":
                let drafts = LabelTextParser().parse(SampleData.scanText).map(MedicationDraft.init(extracted:))
                path = [.confirm(ScanResult(drafts: drafts, recognizedText: SampleData.scanText, usedFallback: false))]
            default: break
            }
        }
    }
}
