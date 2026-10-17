import SwiftUI
import SwiftData
import MedListCore

/// Every extracted field is editable; uncertain ones are highlighted. Nothing is stored until Save.
struct ConfirmView: View {
    @State private var drafts: [MedicationDraft]
    let recognizedText: String
    let usedFallback: Bool
    @Binding var path: [Route]

    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @State private var isSaving = false
    @State private var confirmDiscard = false

    init(result: ScanResult, path: Binding<[Route]>) {
        _drafts = State(initialValue: result.drafts)
        recognizedText = result.recognizedText
        usedFallback = result.usedFallback
        _path = path
    }

    private var included: [MedicationDraft] { drafts.filter(\.include) }
    private var canSave: Bool { !included.isEmpty && included.allSatisfy(\.isSavable) && !isSaving }

    var body: some View {
        Form {
            Section {
                Text("Check every field against the label. Fields marked Check may have been read incorrectly.")
                if usedFallback {
                    Label("Online reading was unavailable, so the text was read on this device only.", systemImage: "wifi.slash")
                        .font(.footnote)
                }
            }

            ForEach($drafts) { $draft in
                Section {
                    if drafts.count > 1 {
                        Toggle("Add this medication", isOn: $draft.include)
                    }
                    if draft.include {
                        MedicationFields(draft: $draft)
                        if !draft.isSavable {
                            Text("A medication name is needed.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color("AttentionForeground"))
                        }
                    }
                } header: {
                    if drafts.count > 1, let index = drafts.firstIndex(where: { $0.id == draft.id }) {
                        Text("Medication \(index + 1) of \(drafts.count)")
                    }
                }
            }

            if !recognizedText.isEmpty {
                Section {
                    DisclosureGroup("Show recognized text") {
                        Text(recognizedText)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                } footer: {
                    Text("The photo itself is not stored. This text is discarded when you leave this screen.")
                }
            }
        }
        .navigationTitle("Confirm details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Discard") { confirmDiscard = true }
                    .accessibilityIdentifier("confirm.discard")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await save() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(included.count > 1 ? "Save \(included.count) medications" : "Save to list")
                    }
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSave)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("confirm.save")
        }
        .confirmationDialog("Discard this scan?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { path.removeAll() }
        } message: {
            Text("Nothing from this scan will be saved.")
        }
    }

    private func save() async {
        isSaving = true
        for draft in included {
            let resolution = await env.normalizer.resolve(draft.value(.drugName) ?? "")
            context.insert(Medication(draft: draft, resolution: resolution))
        }
        try? context.save()
        PrivacyLog.event("scan_saved", count: included.count)
        isSaving = false
        path.removeAll()
    }
}
