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
}
