import SwiftUI
import SwiftData
import MedListCore

/// Three steps: what MedList is (and is not), who the list is for, and explicit consent.
struct OnboardingView: View {
    /// Set when consent text changed since the user last agreed.
    let existing: CareRecipient?
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(from: DateComponents(year: 1945, month: 1, day: 1)) ?? .now
    @State private var consentHealthData = false
    @State private var consentSharing = false

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: welcome
                case 1: recipient
                default: consent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if let existing {
                name = existing.name
                dateOfBirth = existing.dateOfBirth
                step = 2
            }
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("One accurate medication list")
                    .font(.largeTitle.bold())
                Text("MedList helps you keep a single, up-to-date list of medications for the person you care for, and bring it to appointments.")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Scan labels and discharge papers", systemImage: "doc.viewfinder")
                    Label("Check and correct every detail", systemImage: "checkmark.circle")
                    Label("See items to verify with the pharmacist", systemImage: "exclamationmark.triangle")
                    Label("Share a one-page PDF", systemImage: "doc.richtext")
                }
                .font(.body)
                DisclaimerBox()
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue", identifier: "onboarding.continue") { step = 1 }
        }
    }

    private var recipient: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("onboarding.name")
                DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date.now, displayedComponents: .date)
            } header: {
                Text("Who is this list for?")
            } footer: {
                Text("Shown on the PDF so the doctor knows whose list it is. Stored only on this device.")
            }
        }
        .navigationTitle("Care recipient")
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue", identifier: "onboarding.continue") { step = 2 }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var consent: some View {
        Form {
            Section {
                Text("Medication information is health data. Before you continue, please read how MedList handles it.")
            }
            Section("What stays on this device") {
                Label("The medication list, the name and date of birth. Encrypted by iOS and not included in backups.", systemImage: "iphone")
                Label("Photos. They are read on this device and never stored or uploaded.", systemImage: "camera")
            }
            Section("What leaves this device") {
                Label("Medication names are looked up in RxNorm (US National Library of Medicine) to find active ingredients. No personal details are sent.", systemImage: "network")
                Label("If online reading is turned on in Settings: the text read from a label, with names, dates of birth and ID numbers removed where possible, is sent to the MedList extraction service and processed by an AI provider. It is not stored there.", systemImage: "text.viewfinder")
            }
            Section {
                Toggle("I agree that MedList processes health information about the person I care for, as described above, and I am allowed to do so for them.", isOn: $consentHealthData)
                    .accessibilityIdentifier("onboarding.consent")
                Toggle("I understand MedList is an organizer and does not give medical advice.", isOn: $consentSharing)
                    .accessibilityIdentifier("onboarding.disclaimer")
            } footer: {
                Text("You can delete all data at any time in Settings.")
            }
        }
        .navigationTitle("Privacy and consent")
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Start", identifier: "onboarding.start") { finish() }
                .disabled(!(consentHealthData && consentSharing))
        }
    }

    private func finish() {
        if let existing {
            existing.consentGivenAt = .now
            existing.consentVersion = CareRecipient.currentConsentVersion
        } else {
            context.insert(CareRecipient(name: name.trimmingCharacters(in: .whitespaces), dateOfBirth: dateOfBirth))
        }
        try? context.save()
        PrivacyLog.event("onboarding_completed")
    }
}

struct DisclaimerBox: View {
    var body: some View {
        Text(FlagCopy.current.disclaimer)
            .font(.body)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.separator)))
    }
}

struct PrimaryButton: View {
    let title: LocalizedStringKey
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .background(.bar)
        .accessibilityIdentifier(identifier)
    }
}
