import SwiftUI
import MedListCore

@main
struct MedListApp: App {
    var body: some Scene {
        WindowGroup {
            Text(FlagCopy(language: "en").verifyWithPharmacist)
        }
    }
}
