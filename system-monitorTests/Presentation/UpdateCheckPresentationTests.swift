import Foundation
import Testing
@testable import system_monitor

// app-updates — AU-6 "No update surface states something untrue".
//
// Deterministic because `now` is injected: a label that read the clock could
// only ever be tested for its shape, and "the app never invents a date" is a
// claim about the value.
@Suite("Update check presentation", .timeLimit(.minutes(1)))
struct UpdateCheckPresentationTests {

    private static let now = Date(timeIntervalSince1970: 1_787_000_000)

    // app-updates — AU-6 "A never-checked app says so". The wording carries no
    // digits at all, which is the assertion that actually forbids the failure
    // mode: a fabricated date, a placeholder and the Unix epoch all read as
    // plausible sentences, and only "there is no number in it" rules out all
    // three at once without enumerating them.
    @Test func aNeverCheckedAppSaysSoWithNoDateInTheText() {
        let presentation = UpdateCheckPresentation(lastCheck: nil, now: Self.now)

        let carriesADigit = presentation.label.rangeOfCharacter(from: .decimalDigits) != nil

        #expect(presentation.label == "Never checked")
        #expect(carriesADigit == false)
    }

    // app-updates — AU-6 "A checked app reports the date it checked". Wording
    // beyond the prefix belongs to the formatter and the user's locale, so it is
    // not pinned. What is pinned is that the label is *derived from the date*:
    // three offsets, three distinct labels. A hardcoded "Last checked recently"
    // would satisfy the prefix and fail this.
    @Test func aCheckedAppReportsItsCheckAndTheLabelFollowsTheDate() {
        let offsets: [TimeInterval] = [-3600, -3 * 86_400, -21 * 86_400]

        let labels = offsets.map { offset in
            UpdateCheckPresentation(lastCheck: Self.now.addingTimeInterval(offset), now: Self.now).label
        }

        for label in labels {
            #expect(label.hasPrefix("Last checked "))
            #expect(label.count > "Last checked ".count)
        }
        #expect(Set(labels).count == 3)
    }

    // app-updates — AU-6: the same inputs produce the same label every time,
    // which is the whole reason `now` is a parameter rather than `Date()`.
    @Test func theLabelIsAPureFunctionOfTheTwoDates() {
        let checked = Self.now.addingTimeInterval(-7200)

        let first = UpdateCheckPresentation(lastCheck: checked, now: Self.now)
        let second = UpdateCheckPresentation(lastCheck: checked, now: Self.now)

        #expect(first == second)
        #expect(first.label == second.label)
    }

    // app-updates — AU-6 "The label follows the updater's recorded date": an app
    // that has just checked must stop saying it never has.
    @Test func theLabelChangesWhenTheRecordedDateArrives() {
        let before = UpdateCheckPresentation(lastCheck: nil, now: Self.now)
        let after = UpdateCheckPresentation(lastCheck: Self.now.addingTimeInterval(-60), now: Self.now)

        #expect(before.label == "Never checked")
        #expect(after.label != before.label)
        #expect(after.label.hasPrefix("Last checked "))
    }
}
