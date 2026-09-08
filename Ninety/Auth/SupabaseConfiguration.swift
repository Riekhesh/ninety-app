import Foundation

/// Which Supabase project this build talks to.
///
/// Both values are public by design — `docs/security/secrets.md` puts the
/// project URL and the publishable (anon) key in the "ships in the app bundle"
/// row, because RLS, not the key, is the security boundary. They are still not
/// committed: they identify one person's project, and this repository is read
/// by other people, which is exactly the reasoning `Config/Local.xcconfig`
/// already exists for.
///
/// So `Config/Ninety.xcconfig` declares both as empty, `Config/Info.plist`
/// substitutes them, and a clone without a `Local.xcconfig` gets `nil` here and
/// a sign-in screen that says what is missing — rather than a crash, which
/// would make a fresh checkout unrunnable for the sake of a developer's
/// configuration mistake.
struct SupabaseConfiguration: Equatable, Sendable {
    let url: URL
    let anonKey: String

    /// The host, without a scheme, is what the xcconfig carries.
    ///
    /// **xcconfig treats `//` as a comment**, so `https://x.supabase.co` in a
    /// build setting silently becomes `https:`. There is a `SLASH = /` trick
    /// people use to get round it; storing the bare host and putting the scheme
    /// back here is the version that cannot be mis-copied, and it also means
    /// the setting can never point the app at a plaintext endpoint.
    init?(host: String?, anonKey: String?) {
        let host = host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard Self.isAHost(host), !key.isEmpty, let url = URL(string: "https://\(host)") else {
            return nil
        }
        self.url = url
        self.anonKey = key
    }

    /// A host, and nothing that is not one.
    ///
    /// Checking only for `/` was not enough, and the test caught it: what an
    /// xcconfig leaves behind when a full URL is pasted is `https:` — no
    /// slashes at all, because the comment starts at the first one. That built
    /// a perfectly valid `URL` pointing at `https://https:`, and the app would
    /// have offered a sign-in button that could never work rather than saying
    /// it was not configured.
    ///
    /// So the rule is what a host *is*, not a list of what it must not be. It
    /// has a dot, and it has no scheme, port, path or space — which rejects
    /// `https:`, `abc.supabase.co:5432`, a surviving URL, and a bare word,
    /// while still allowing the custom domain the Data API settings offer.
    private static func isAHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.contains(".") else { return false }
        guard host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        return !host.contains(":") && !host.contains("/")
    }

    /// Reads the two keys out of the built bundle.
    ///
    /// Nil when either is blank, which is the fresh-clone state and the one
    /// `AuthFailure.notConfigured` exists for.
    static func fromBundle(_ bundle: Bundle = .main) -> SupabaseConfiguration? {
        SupabaseConfiguration(
            host: bundle.object(forInfoDictionaryKey: "NinetySupabaseHost") as? String,
            anonKey: bundle.object(forInfoDictionaryKey: "NinetySupabaseAnonKey") as? String
        )
    }
}
