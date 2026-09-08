import Foundation

/// The 21 days, in the shape `spikes/vision-accuracy` scores.
///
/// ADR 0010 folded the photo benchmark into Phase 1 on one condition: that
/// Phase 1's logging keeps the photo alongside the confirmed values, so the
/// three weeks produce the dataset instead of a separate evening's collection.
/// This is the half of that condition that turns stored rows back into a file.
///
/// ## What this measures, and what it does not
///
/// **These are confirmed values, not weighed ones, and the difference matters
/// enough to be in the file.** `spikes/vision-accuracy/README.md` is emphatic:
/// *"actual_grams is WEIGHED on a scale, not estimated. If you estimated it, you
/// are measuring the model against a guess and the baseline is worthless."* A
/// user correcting a portion on Under Review is not weighing it, so a run over
/// this file is **not** the accuracy baseline and must never be reported as one.
///
/// What it does measure is **correction magnitude** — how far a human moved the
/// model, in which direction, and on which kinds of food — and that is a real
/// signal that the 20-meal weighed set cannot give at any scale: it is hundreds
/// of meals rather than twenty, and it is the actual distribution of what one
/// person eats rather than a set assembled to be photographed. The two answer
/// different questions and both are worth having.
///
/// Every row says which it is, in the `notes` column, so a file that escapes
/// this comment still cannot be mistaken for weighed truth.
enum PhotoBenchmarkExport {
    /// The header the spike's `load_truth` requires, in its order.
    static let header = "photo_id,item_name,actual_grams,actual_kcal,notes"

    /// The provenance stamp on every row.
    static let provenance = "user-confirmed on Under Review; NOT weighed"

    /// One CSV, one row per confirmed item.
    ///
    /// `photo_id` is the storage path's filename stem, which is what makes the
    /// rows join back to the objects in the `meal-photos` bucket — the spike
    /// pairs `meal-001.jpg` with `meal-001`, and this pairs
    /// `<uid>/<uuid>.jpg` with `<uuid>`.
    static func groundTruthCSV(from estimates: [PhotoEstimate]) -> String {
        let rows = estimates
            // Oldest first, so re-running the export appends rather than
            // reshuffling a file somebody may have opened in a spreadsheet.
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap(row(for:))
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// Nil for an estimate whose log has gone. The log is where the confirmed
    /// values live, so without one there is nothing to score against.
    static func row(for estimate: PhotoEstimate) -> String? {
        guard let log = estimate.log else { return nil }
        let corrected = estimate.wasCorrected ? "corrected" : "accepted as estimated"
        let delta = estimate.correctionDelta.map { " (\(Int($0.rounded())) kcal)" } ?? ""
        return [
            photoID(from: estimate.storagePath),
            log.nameSnapshot,
            "\(Int(log.grams.rounded()))",
            "\(Int(log.kcal.rounded()))",
            "\(Self.provenance); \(corrected)\(delta)",
        ]
        .map(escaped)
        .joined(separator: ",")
    }

    /// `<uid>/8f3e….jpg` → `8f3e…`.
    static func photoID(from storagePath: String) -> String {
        let file = storagePath.split(separator: "/").last.map(String.init) ?? storagePath
        guard let dot = file.lastIndex(of: ".") else { return file }
        return String(file[file.startIndex..<dot])
    }

    /// RFC 4180. Food names contain commas — "chicken, rice and naan" is one
    /// item — and an unescaped one shifts every column after it by one, which is
    /// the kind of corruption that produces a plausible wrong number rather than
    /// an error.
    static func escaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
