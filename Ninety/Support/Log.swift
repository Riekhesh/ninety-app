import OSLog

/// Subsystem-scoped loggers.
///
/// `print()` does not survive into a shipped build and cannot be filtered by
/// subsystem, which is why `no_print` is a lint rule. Every category here maps
/// to an architectural seam, so Phase 3 crash triage can narrow to one of them
/// rather than reading the whole stream.
enum Log {
    private static let subsystem = "app.ninety"

    /// App lifecycle, navigation, and anything shell-shaped.
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Design system: token wiring, bundled font registration.
    static let design = Logger(subsystem: subsystem, category: "design")

    /// Sign in, sign out, session restore and refresh.
    ///
    /// Nothing logged under this category may carry a token, an identity token
    /// or an email — a log line is a copy of a credential that outlives the
    /// session it came from. User ids are fine and are the only identifier
    /// worth having here anyway, because they are what every RLS policy and
    /// every row in the local store is keyed on.
    static let auth = Logger(subsystem: subsystem, category: "auth")
}
