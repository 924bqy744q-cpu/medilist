import SwiftUI
import SwiftData
import MedListCore

/// Add a medication by hand, or edit/remove an existing one.
struct MedicationEditView: View {
    let medication: Medication?
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MedicationDraft
    @State private var confirmRemove = false
    @State private var isSaving = false

    init(medication: Medication?) {
        self.medication = medication
        _draft = State(initialValue: MedicationDraft(medication: medication))
    }

    var body: some View {
        Form {
            Section {
                MedicationFields(draft: $draft, idPrefix: "edit")
            }
            if let medication {
                Section {
                    Button("Remove from list", role: .destructive) { confirmRemove = true }
                } footer: {
                    Text("Added \(medication.createdAt.formatted(date: .abbreviated, time: .omitted))")
                }
            }
        }
        .navigationTitle(medication == nil ? "Add medication" : "Edit medication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!draft.isSavable || isSaving)
                    .accessibilityIdentifier("edit.save")
            }
        }
        .confirmationDialog("Remove this medication from the list?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let medication { context.delete(medication) }
                try? context.save()
                dismiss()
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let name = draft.value(.drugName) ?? ""
        if let medication {
            let nameChanged = medication.name != name
            medication.apply(draft)
            if nameChanged {
                let resolution = await env.normalizer.resolve(name)
                medication.ingredients = resolution.ingredients
                medication.ingredientSourceRaw = resolution.source.rawValue
            }
        } else {
            let resolution = await env.normalizer.resolve(name)
            context.insert(Medication(draft: draft, resolution: resolution))
            PrivacyLog.event("medication_added_manually")
        }
        try? context.save()
        dismiss()
    }
}
