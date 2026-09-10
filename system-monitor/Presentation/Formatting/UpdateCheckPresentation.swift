import Foundation

/// The words an update surface may use about when the app last looked (AU-6).
///
/// A value type over two dates, so the label is a pure function of its inputs
/// and nothing reads the clock behind the caller's back. `now` is injected for
/// exactly that reason: a relative phrase computed against `Date()` could only
/// ever be tested for its shape, and "the app never invents a date" is a claim
/// about the value.
nonisolated struct UpdateCheckPresentation: Sendable, Hashable {

    /// What a bundle that has never checked says.
    ///
    /// Words, deliberately, with no number in them. A placeholder date, a
    /// defaulted date and the Unix epoch all read as plausible sentences and all
    /// state something untrue.
    static let neverChecked = "Never checked"

    let lastCheck: Date?

    let now: Date

    init(lastCheck: Date?, now: Date) {
        self.lastCheck = lastCheck
        self.now = now
    }

    var label: String {
        guard let lastCheck else { return Self.neverChecked }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last checked \(formatter.localizedString(for: lastCheck, relativeTo: now))"
    }
}
