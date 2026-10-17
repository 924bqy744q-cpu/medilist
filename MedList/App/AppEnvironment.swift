import Foundation
import Observation
import os
import MedListCore

/// Build-time configuration. Set `extractionEndpoint` to your deployed proxy (see backend/README.md).
/// No LLM API key ever lives in the app.
enum AppConfig {
    static let extractionEndpoint: URL? = nil // e.g. URL(string: "https://medlist-proxy.example.com/extract")
    /// Coarse gate only; extractable from the binary. Replace with App Attest before a pilot (TODO.md).
    static let extractionClientToken: String? = nil
}

/// Launch arguments used by UI tests and CI screenshots. Ignored in Release builds.
struct LaunchOptions {
    var resetState = false
    var seedSampleData = false
    var showSampleScanInput = false
    var open: String?

    static let current: LaunchOptions = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        var options = LaunchOptions()
        options.resetState = args.contains("-uitest-reset")
        options.seedSampleData = args.contains("-uitest-seed")
        options.showSampleScanInput = args.contains { $0.hasPrefix("-uitest") }
        if let i = args.firstIndex(of: "-uitest-open"), i + 1 < args.count { options.open = args[i + 1] }
        return options
        #else
        return LaunchOptions()
        #endif
    }()

    var isUITest: Bool { resetState || seedSampleData || showSampleScanInput }
}

/// Wires services together. Swap `interactionProvider` here for a licensed source (TODO.md).
@MainActor
@Observable
final class AppEnvironment {
    let launch: LaunchOptions
    let normalizer: IngredientNormalizer
    let flagEngine: FlagEngine
    let interactionSourceName: String
    let flags = FlagsModel()
    let lock: AppLock

    var useOnlineExtraction: Bool {
        didSet { UserDefaults.standard.set(useOnlineExtraction, forKey: Keys.onlineExtraction) }
    }

    var onlineExtractionAvailable: Bool { AppConfig.extractionEndpoint != nil }

    init(launch: LaunchOptions = .current) {
        self.launch = launch
        // UI tests run offline and deterministic: no RxNorm calls.
        normalizer = IngredientNormalizer(rxNorm: launch.isUITest ? nil : RxNormClient())
        let interactions: InteractionProvider = SampleInteractionProvider.bundled() // TODO(licensed-data)
        interactionSourceName = interactions.sourceName
        flagEngine = FlagEngine(interactions: interactions)
        lock = AppLock(enabledByDefault: false, bypass: launch.isUITest)
        useOnlineExtraction = UserDefaults.standard.bool(forKey: Keys.onlineExtraction)
    }

    /// The extractor to use right now. Falls back to on-device parsing when no proxy is configured.
    var extractionService: ExtractionService {
        if useOnlineExtraction, !launch.isUITest, let endpoint = AppConfig.extractionEndpoint {
            return RemoteExtractionService(endpoint: endpoint, clientToken: AppConfig.extractionClientToken)
        }
        return MockExtractionService()
    }

    var languageCode: String {
        Locale.current.language.languageCode?.identifier == "nl" ? "nl" : "en"
    }

    private enum Keys {
        static let onlineExtraction = "onlineExtraction"
    }
}

/// Logging that never contains medication content, names or free text: event names and counts only.
enum PrivacyLog {
    private static let logger = Logger(subsystem: "app.medlist", category: "app")

    static func event(_ name: StaticString, count: Int? = nil) {
        if let count {
            logger.info("\(name, privacy: .public) count=\(count, privacy: .public)")
        } else {
            logger.info("\(name, privacy: .public)")
        }
    }
}
