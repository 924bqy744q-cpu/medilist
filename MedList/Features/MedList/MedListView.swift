import SwiftUI
import SwiftData
import MedListCore

struct MedListView: View {
    let recipient: CareRecipient
    let medications: [Medication]
    @Binding var path: [Route]
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @State private var pendingDelete: Medication?

    var body: some View {
        List {
            FlagBanner(result: env.flags.result) { path.append(.flags) }

            Section {
                ForEach(medications) { med in
                    NavigationLink(value: Route.edit(med.id)) {
                        MedicationRow(medication: med, isFlagged: env.flags.flaggedIDs.contains(med.id))
                    }
                    .swipeActions {
                        Button(role: .destructive) { pendingDelete = med } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            } header: {
                if !medications.isEmpty {
                    Text("Medications (\(medications.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if medications.isEmpty {
                ContentUnavailableView {
                    Label("No medications yet", systemImage: "pills")
                } description: {
                    Text("Scan a pill bottle label or discharge papers, or add a medication by hand.")
                }
            }
        }
        .navigationTitle(recipient.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { path.append(.settings) } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("list.settings")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { path.append(.add) } label: {
                    Label("Add by hand", systemImage: "plus")
                }
                .accessibilityIdentifier("list.add")
                Button { path.append(.export) } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(medications.isEmpty)
                .accessibilityIdentifier("list.export")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { path.append(.scan) } label: {
                Label("Scan label", systemImage: "doc.viewfinder")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("list.scan")
        }
        .confirmationDialog(
            "Remove this medication from the list?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { med in
            Button("Remove", role: .destructive) {
                context.delete(med)
                try? context.save()
                PrivacyLog.event("medication_removed")
            }
        } message: { med in
            Text(med.name)
        }
    }
}

struct MedicationRow: View {
    let medication: Medication
    let isFlagged: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(titleLine)
                    .font(.headline)
                if isFlagged {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color("AttentionForeground"))
                        .accessibilityHidden(true)
                }
            }
            if let schedule = scheduleLine {
                Text(schedule)
                    .font(.body)
            }
            if let prescriber = medication.prescriber {
                Text("Prescriber: \(prescriber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let purpose = medication.purpose {
                Text("Purpose: \(purpose)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isFlagged ? Text("Has a flag") : Text(""))
    }

    private var titleLine: String {
        [medication.name, medication.strength, medication.form].compactMap { $0 }.joined(separator: " · ")
    }

    private var scheduleLine: String? {
        let parts = [medication.dose, medication.frequency].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
