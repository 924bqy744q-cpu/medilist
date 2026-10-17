import Foundation
import LocalAuthentication
import Observation

/// Optional Face ID / passcode lock. When enabled, the app locks whenever it leaves the foreground and the
/// app-switcher snapshot is covered.
@MainActor
@Observable
final class AppLock {
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.key) }
    }
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private let bypass: Bool

    private static let key = "appLockEnabled"

    init(enabledByDefault: Bool, bypass: Bool) {
        self.bypass = bypass
        let stored = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? enabledByDefault
        isEnabled = stored && !bypass
        isLocked = stored && !bypass
    }

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return String(localized: "device passcode")
        }
    }

    static var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lockIfEnabled() {
        if isEnabled && !bypass { isLocked = true }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        let reason = String(localized: "Unlock the medication list")
        // .deviceOwnerAuthentication falls back to the device passcode if biometrics fail.
        if (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true {
            isLocked = false
        }
    }

    /// Turning the lock on requires a successful authentication first, so users cannot lock themselves out.
    func setEnabled(_ enabled: Bool) async {
        guard enabled else { isEnabled = false; return }
        let context = LAContext()
        let reason = String(localized: "Turn on the app lock")
        if (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true {
            isEnabled = true
        }
    }
}
