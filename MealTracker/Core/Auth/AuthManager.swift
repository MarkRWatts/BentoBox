import Foundation
import Observation
import UIKit
import GoogleSignIn

/// Account identity, kept deliberately separate from `UserProfile`/SwiftData — sign-in state has
/// a different lifecycle than local meal-tracking data (see `LocalDataStore` for what happens to
/// that data when the signed-in Google account changes).
@Observable
@MainActor
final class AuthManager {
    private(set) var isSignedIn = false
    private(set) var displayName: String?
    private(set) var email: String?
    private(set) var googlePhotoURL: URL?
    /// A locally-chosen override photo, when set — takes precedence over `googlePhotoURL`
    /// wherever the avatar is shown. Kept as raw JPEG data (not a `UIImage`) so this type stays
    /// trivially `Sendable`.
    private(set) var customPhotoData: Data?
    /// Set by `continueWithoutAccount()` — lets someone past the splash screen without a Google
    /// account at all (there's no backend here, so an account was never a hard requirement for
    /// the app to work; this also covers Simulator runs where passkey-based Google sign-in
    /// isn't available). Persisted the same way `lastSignedInGoogleUserID` is, so it survives a
    /// relaunch.
    private(set) var isLocalOnly: Bool

    /// What `RootView` actually gates on — either a real Google session or local-only mode.
    var isAuthenticated: Bool { isSignedIn || isLocalOnly }

    init() {
        customPhotoData = try? Data(contentsOf: Self.customPhotoFileURL)
        isLocalOnly = UserDefaults.standard.bool(forKey: "isLocalOnly")
    }

    /// Only ever "different account than last time" vs. "no account yet" matters here, so this
    /// stays a plain UserDefaults string rather than anything richer — it must outlive sign-out
    /// (unlike `GIDSignIn`'s own session state) so a later sign-in can still compare against it.
    @ObservationIgnored
    private var lastSignedInGoogleUserID: String? {
        get { UserDefaults.standard.string(forKey: "lastSignedInGoogleUserID") }
        set { UserDefaults.standard.set(newValue, forKey: "lastSignedInGoogleUserID") }
    }

    /// Re-hydrates a still-valid Google session on launch, without prompting the user.
    func restorePreviousSignIn() async {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            apply(user)
        } catch {
            isSignedIn = false
        }
    }

    /// Returns whether this sign-in is for a *different* Google account than the last one seen on
    /// this device — the caller is responsible for wiping local data when that happens.
    @discardableResult
    func signInWithGoogle() async throws -> Bool {
        guard let presenting = Self.topViewController() else {
            throw AuthError.noPresentingViewController
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        let user = result.user
        let didSwitchAccount = lastSignedInGoogleUserID != nil && lastSignedInGoogleUserID != user.userID
        apply(user)
        lastSignedInGoogleUserID = user.userID
        isLocalOnly = false
        UserDefaults.standard.set(false, forKey: "isLocalOnly")
        if didSwitchAccount {
            clearCustomPhoto()
        }
        return didSwitchAccount
    }

    /// Bypasses Google entirely and drops straight into onboarding/home, same as a real sign-in.
    func continueWithoutAccount() {
        isLocalOnly = true
        UserDefaults.standard.set(true, forKey: "isLocalOnly")
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        displayName = nil
        email = nil
        googlePhotoURL = nil
        isLocalOnly = false
        UserDefaults.standard.set(false, forKey: "isLocalOnly")
    }

    func setCustomPhoto(_ data: Data) {
        try? FileManager.default.createDirectory(
            at: Self.customPhotoFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: Self.customPhotoFileURL)
        customPhotoData = data
    }

    func clearCustomPhoto() {
        try? FileManager.default.removeItem(at: Self.customPhotoFileURL)
        customPhotoData = nil
    }

    private func apply(_ user: GIDGoogleUser) {
        isSignedIn = true
        displayName = user.profile?.name
        email = user.profile?.email
        googlePhotoURL = user.profile?.imageURL(withDimension: 200)
    }

    private static var customPhotoFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile-photo.jpg")
    }

    private static func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    enum AuthError: Error {
        case noPresentingViewController
    }
}
