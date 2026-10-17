import SwiftUI
import SwiftData
import MedListCore

struct SettingsView: View {
    @Bindable var recipient: CareRecipient
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @State private var confirmDelete = false
    @State private var deleteFailed = false

    var body: some View {
        @Bindable var env = env
        Form {
            Section("Care recipient") {
                TextField("Name", text: $recipient.name)
                    .textInputAutocapitalization(.words)
                DatePicker("Date of birth", selection: $recipient.dateOfBirth, in: ...Date.now, displayedComponents: .date)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { env.lock.isEnabled },
                    set: { newValue in Task { await env.lock.setEnabled(newValue) } }
                )) {
                    Text("Lock with \(AppLock.biometryName)")
                }
                .disabled(!AppLock.canAuthenticate)
            } header: {
                Text("Security")
            } footer: {
                Text("Asks for Face ID or the device passcode each time MedList is opened.")
            }

            Section {
                Toggle("Online label reading", isOn: $env.useOnlineExtraction)
                    .disabled(!env.onlineExtractionAvailable)
            } header: {
                Text("Label reading")
            } footer: {
                if env.onlineExtractionAvailable {
                    Text("When on, recognized label text (not the photo) is sent to the MedList extraction service for better results. Names, dates of birth and ID numbers are removed first where possible.")
                } else {
                    Text("Labels are read on this device only. Online reading is not set up in this version.")
                }
            }

            Section {
                Text(FlagCopy.current.disclaimer)
                LabeledContent("Ingredient lookup", value: "RxNorm, U.S. National Library of Medicine")
                LabeledContent("Interaction data", value: env.interactionSourceName)
                LabeledContent("Consent given", value: recipient.consentGivenAt.formatted(date: .abbreviated, time: .omitted))
            } header: {
                Text("About")
            }

            Section {
                Button("Delete all data", role: .destructive) { confirmDelete = true }
                    .accessibilityIdentifier("settings.deleteAll")
            } footer: {
                Text("Removes the care recipient, every medication, and all settings from this device. This cannot be undone.")
            }
        }
        .navigationTitle("Settings")
        .onDisappear { try? context.save() }
        .confirmationDialog("Delete all data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                do {
                    try DataStore.deleteAllData(context: context)
                    env.lock.isEnabled = false
                    env.useOnlineExtraction = false
                } catch {
                    deleteFailed = true
                }
            }
        } message: {
            Text("The medication list and care recipient will be permanently removed from this device.")
        }
        .alert("Data could not be deleted. Please try again.", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        }
    }
}
