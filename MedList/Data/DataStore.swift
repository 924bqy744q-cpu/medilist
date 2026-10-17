import Foundation
import SwiftData

/// Owns the on-device SwiftData store and the "Delete all data" action.
///
/// The store lives in Application Support with `NSFileProtectionComplete` (also the app-wide default via the
/// entitlement), is excluded from device backups, and is never synced anywhere.
enum DataStore {
    static let schema = Schema([CareRecipient.self, Medication.self])

    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "MedList", directoryHint: .isDirectory)
    }

    private static var storeURL: URL { directory.appending(path: "medlist.store") }
    private static var wipeMarker: URL { URL.documentsDirectory.appending(path: ".wipe-pending") }

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        if inMemory {
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: wipeMarker.path) {
            // A previous "Delete all data" could not remove the open store files; remove them before opening.
            try? fm.removeItem(at: directory)
            try? fm.removeItem(at: wipeMarker)
        }
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true,
                                attributes: [.protectionKey: FileProtectionType.complete])
        protect(directory)

        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            protectContents(of: directory)
            return container
        } catch {
            // An unreadable store (e.g. schema change during development) must not brick the app.
            PrivacyLog.event("store_open_failed_reset")
            try? fm.removeItem(at: directory)
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
            return try! ModelContainer(for: schema, configurations: configuration)
        }
    }

    /// Deletes every record, preferences, and temporary exports. Store files are removed on next launch.
    @MainActor
    static func deleteAllData(context: ModelContext) throws {
        try context.delete(model: Medication.self)
        try context.delete(model: CareRecipient.self)
        try context.save()

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        PDFExporter.removeTemporaryExports()
        FileManager.default.createFile(atPath: wipeMarker.path, contents: Data(),
                                       attributes: [.protectionKey: FileProtectionType.complete])
        PrivacyLog.event("delete_all_data")
    }

    private static func protect(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }

    private static func protectContents(of directory: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        files.forEach(protect)
    }
}
