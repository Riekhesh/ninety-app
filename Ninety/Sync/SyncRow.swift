import Foundation

/// One column's worth of value, in the small set Postgres actually receives.
///
/// An enum rather than `[String: Any]`, for two reasons that are both about the
/// photo route. `photo_estimates.model_output` is `jsonb` holding the model's
/// structured output **verbatim** — ADR 0010's whole point is that re-scoring a
/// stored estimate against a new prompt is only possible if the original
/// survived — so it has to reach the wire as JSON rather than as a string, and
/// it must not be parsed and re-emitted on the way. `.json` is that case, and
/// nothing else in the app needs it.
///
/// The second reason is that `Any` cannot be `Sendable` and this crosses an
/// `await`.
enum SyncValue: Equatable, Sendable {
    case text(String)
    case number(Double)
    case integer(Int)
    case flag(Bool)
    /// Already-encoded JSON, embedded exactly as it arrived.
    case json(Data)
    case null
}

/// A row, addressed and ready to send.
///
/// Built by `SyncPayload` from whatever the local store currently holds, never
/// from the outbox entry's own payload. `Outbox.enqueue` writes `{}` and its
/// doc comment says why: a row edited three times offline should sync once, in
/// its final state, rather than replaying three versions at the server for
/// last-write-wins to arbitrate afterwards.
struct SyncRow: Equatable, Sendable {
    let table: SyncTable
    let id: UUID
    /// Column name to value. Postgres column names, not Swift property names —
    /// this is the boundary where the two spellings meet.
    let columns: [String: SyncValue]
}

extension SyncRow {
    /// The row as a JSON object body.
    ///
    /// Written by hand rather than through `JSONSerialization`, and the reason
    /// is `.json`: serialising a parsed value would re-order keys and re-format
    /// numbers inside the model output, which is the one field in the schema
    /// that is specified to arrive unedited. Writing it out means the bytes in
    /// `model_output` are the bytes the model produced.
    ///
    /// Keys are emitted sorted, so a payload is the same twice and a test can
    /// compare against a literal.
    var body: Data {
        var out = "{"
        for (index, key) in columns.keys.sorted().enumerated() {
            if index > 0 { out += "," }
            out += SyncRow.quote(key)
            out += ":"
            out += SyncRow.literal(for: columns[key] ?? .null)
        }
        out += "}"
        return Data(out.utf8)
    }

    private static func literal(for value: SyncValue) -> String {
        switch value {
        case .text(let string):
            quote(string)
        case .number(let double):
            // A non-finite number has no JSON spelling, and emitting `nan`
            // would produce a body Postgres rejects with an error naming the
            // whole row rather than the column. Null is the honest answer: the
            // value was never a number.
            double.isFinite ? String(double) : "null"
        case .integer(let int):
            String(int)
        case .flag(let bool):
            bool ? "true" : "false"
        case .json(let data):
            // Verbatim. See the note above.
            //
            // Failable rather than `String(decoding:as:)`, and not only because
            // the linter says so: bytes that are not UTF-8 were never JSON, and
            // decoding them lossily would put replacement characters inside a
            // `jsonb` column. `{}` keeps the row — `model_output` is `not null`,
            // so a JSON `null` would have it refused five times and parked —
            // and what the benchmark actually scores is the correction delta
            // next to it, which is unaffected. The verbatim copy is on the
            // phone regardless; this column is the backup.
            String(bytes: data, encoding: .utf8) ?? "{}"
        case .null:
            "null"
        }
    }

    /// A JSON string literal, escaped to the letter of RFC 8259.
    ///
    /// The control-character branch is not theoretical: a food name pasted from
    /// a website can carry a line separator, and an unescaped one is a body the
    /// server rejects for a reason that looks nothing like its cause.
    private static func quote(_ string: String) -> String {
        var out = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

/// How the two Postgres time types are spelled on the wire.
///
/// Both are here rather than at the six call sites because they are not the
/// same question. A `timestamptz` is an instant and carries its offset; a
/// `date` is a day in the user's own calendar, and `dob` and
/// `health_samples.date` are both days — §10 S4 computes the age gate from an
/// actual date because someone turning 18 tomorrow is 17 today, and a day
/// re-derived in UTC from a local midnight is the wrong day for half the year.
enum SyncTime {
    /// A `timestamptz`, always in UTC.
    ///
    /// **Hand-rolled, and the formatter it replaces is why.**
    /// `ISO8601DateFormatter` is an `NSFormatter` subclass — a class, not
    /// `Sendable` — so a `static let` holding one is shared mutable state, and
    /// `SWIFT_STRICT_CONCURRENCY = complete` rejects it outright. The obvious
    /// repairs are both worse than this: an instance per call allocates a
    /// formatter to print six columns, and a lock around a shared one is a
    /// mutex protecting a date.
    ///
    /// So this file holds no shared state at all. Every value it emits is a
    /// pure function of its input, which is also what lets the payload tests
    /// compare against a literal.
    ///
    /// Microseconds rather than milliseconds because that is the precision
    /// `timestamptz` actually stores, and because `weight_logs` has a unique
    /// constraint on `(user_id, measured_at, source)` — truncating the value we
    /// resolve an upsert against is not somewhere to lose digits.
    static func instant(_ date: Date) -> String {
        let calendar = utc
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        return day(date, calendar: calendar)
            + "T" + padded(parts.hour ?? 0, to: 2)
            + ":" + padded(parts.minute ?? 0, to: 2)
            + ":" + padded(parts.second ?? 0, to: 2)
            + "." + padded((parts.nanosecond ?? 0) / 1_000, to: 6)
            + "Z"
    }

    /// `yyyy-MM-dd`, in the calendar the user chose it in.
    ///
    /// Padded by hand rather than with `String(format:)`, which takes `%d` as a
    /// 32-bit width and is handed a 64-bit `Int` — it happens to work for a year
    /// and is the wrong habit to leave in a file that formats data for a
    /// database.
    static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = padded(parts.year ?? 0, to: 4)
        let month = padded(parts.month ?? 0, to: 2)
        let day = padded(parts.day ?? 0, to: 2)
        return "\(year)-\(month)-\(day)"
    }

    private static func padded(_ value: Int, to width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }

    /// Computed, not stored. A `Calendar` is a `Sendable` value type, so a
    /// `static let` would be legal — but the whole point of the note above is
    /// that this file keeps no state, and one exception to that is how the next
    /// one gets in.
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }
}
