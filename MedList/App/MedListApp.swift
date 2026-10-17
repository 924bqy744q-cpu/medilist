import SwiftUI
import SwiftData
import MedListCore

@main
struct MedListApp: App {
    @State private var environment = AppEnvironment()
    private let container: ModelContainer

    init() {
        let launch = LaunchOptions.current
        container = DataStore.makeContainer(inMemory: launch.resetState)
        #if DEBUG
        if launch.seedSampleData {
            SampleData.seed(into: container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Query private var recipients: [CareRecipient]

    var body: some View {
        ZStack {
            if let recipient = recipients.first, recipient.consentVersion >= CareRecipient.currentConsentVersion {
                MainView(recipient: recipient)
            } else {
                OnboardingView(existing: recipients.first)
            }

            if env.lock.isLocked {
                LockView()
            } else if env.lock.isEnabled && scenePhase != .active {
                PrivacyCover() // hides content in the app switcher
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { env.lock.lockIfEnabled() }
            if phase == .active, env.lock.isLocked { Task { await env.lock.unlock() } }
        }
    }
}

struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Image(systemName: "cross.case")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
    }
}

struct LockView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("MedList is locked")
                    .font(.title2.bold())
                Button {
                    Task { await env.lock.unlock() }
                } label: {
                    Text("Unlock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
            }
        }
        .task { await env.lock.unlock() }
    }
}
