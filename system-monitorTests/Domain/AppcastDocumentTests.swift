import Foundation
import Testing

@testable import system_monitor

/// A failure fixture and the exact typed error it must produce.
struct AppcastRejectionCase: Sendable, CustomStringConvertible {
    let fixture: String
    let failure: AppcastValidationFailure

    var description: String { fixture }
}

/// Reads the hand-authored appcast fixtures under `system-monitorTests/Fixtures/Appcast`.
///
/// Hand-authored rather than produced by running `scripts/appcast.sh` inside a
/// test: that would need the signing tool, a private key and network egress
/// inside `xcodebuild test`, three things this project forbids. The consequence
/// is stated rather than smoothed over — `AppcastScriptContractTests` pins the
/// script to the element and attribute names this validator requires, which
/// proves the emitter and the validator agree on **names**, not on bytes.
///
/// **How a fixture is found.** `system-monitorTests` is a
/// `PBXFileSystemSynchronizedRootGroup`, so a file Xcode does not recognise as a
/// source joins the test target's resources automatically; the copy is flattened,
/// so the subdirectory lookup is tried first and the flat one second. The
/// `#filePath` anchor is the last resort and is the idiom the App suites in this
/// target already use to read the repository off disk — it is what keeps this
/// suite from depending on how a future Xcode chooses to lay the bundle out.
enum AppcastFixtures {

    /// Swift Testing has no `XCTestCase`, so a class declared in this target is
    /// what names the test bundle to `Bundle(for:)`.
    private final class Anchor {}

    static let subdirectory = "Fixtures/Appcast"

    private static let bundle = Bundle(for: Anchor.self)

    /// The repository root, found relative to this file.
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Domain
            .deletingLastPathComponent()   // system-monitorTests
            .deletingLastPathComponent()   // repository root
    }

    static func url(_ name: String) -> URL? {
        let base = (name as NSString).deletingPathExtension
        if let bundled = bundle.url(forResource: base, withExtension: "xml", subdirectory: subdirectory) {
            return bundled
        }
        if let flattened = bundle.url(forResource: base, withExtension: "xml") {
            return flattened
        }
        let onDisk = repositoryRoot
            .appendingPathComponent("system-monitorTests")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: onDisk.path) ? onDisk : nil
    }

    static func text(_ name: String) throws -> String {
        let url = try #require(AppcastFixtures.url(name), "fixture \(name) is unreachable")
        return try String(contentsOf: url, encoding: .utf8)
    }
}

// release-distribution — the offline half of "A stable tag also publishes the
// update feed": what an appcast document must carry before System Monitor treats
// it as valid.
//
// Offline, with no network and without the updater framework, so a malformed
// feed is caught by a test before an installed copy of the app ever fetches it.
@Suite("Appcast document")
struct AppcastDocumentTests {

    // MARK: - A complete item validates

    /// Every field an update depends on, read back off a real document.
    ///
    /// Each field is asserted against its exact fixture value rather than
    /// against "is present": a validator that returned the right *shape* with the
    /// wrong enclosure URL would be worse than one that rejected the document,
    /// because the caller would download whatever it named.
    @Test("A complete item validates and carries every field an update depends on")
    func aCompleteItemValidates() throws {
        let document = try AppcastDocument.validate(AppcastFixtures.text("valid-single-item.xml"))

        #expect(document.items.count == 1)
        let item = try #require(document.items.first)

        #expect(item.version == "1")
        #expect(item.shortVersionString == "1.0.0")
        #expect(item.edSignature == "c2lnbmF0dXJlLWZpeHR1cmU=")
        #expect(item.length == 12_345_678)
        #expect(item.minimumSystemVersion == "26.5")
        #expect(item.enclosureURL.scheme == "https")
        #expect(item.enclosureURL.host() == "github.com")
        #expect(
            item.enclosureURL.absoluteString
                == "https://github.com/juancasanueva/SWIFTUI_system_monitor"
                + "/releases/download/v1.0.0/System-Monitor-1.0.0.zip"
        )
    }

    // MARK: - One fixture per failure case

    static let rejections: [AppcastRejectionCase] = [
        AppcastRejectionCase(fixture: "no-channel.xml", failure: .missingChannel),
        AppcastRejectionCase(fixture: "missing-signature.xml", failure: .missingSignature(item: 0)),
        AppcastRejectionCase(fixture: "missing-length.xml", failure: .nonNumericLength(item: 0)),
        AppcastRejectionCase(fixture: "non-numeric-length.xml", failure: .nonNumericLength(item: 0)),
        AppcastRejectionCase(fixture: "missing-version.xml", failure: .missingVersion(item: 0)),
        AppcastRejectionCase(
            fixture: "missing-short-version-string.xml",
            failure: .missingShortVersionString(item: 0)
        ),
        // Absent and unreadable are the same defect from the consumer's side:
        // there is no short version string to compare. Pinned explicitly so the
        // shared case is a decision rather than an accident.
        AppcastRejectionCase(
            fixture: "unreadable-short-version-string.xml",
            failure: .missingShortVersionString(item: 0)
        ),
        AppcastRejectionCase(fixture: "insecure-enclosure.xml", failure: .insecureEnclosure(item: 0)),
        AppcastRejectionCase(
            fixture: "unexpected-host.xml",
            failure: .unexpectedHost(item: 0, expected: "github.com")
        ),
        AppcastRejectionCase(
            fixture: "wrong-minimum-system-version.xml",
            failure: .wrongMinimumSystemVersion(item: 0, found: "26.0")
        ),
        AppcastRejectionCase(
            fixture: "missing-minimum-system-version.xml",
            failure: .wrongMinimumSystemVersion(item: 0, found: nil)
        ),
        AppcastRejectionCase(fixture: "hyphenated-version.xml", failure: .hyphenatedVersion(item: 0)),
        AppcastRejectionCase(fixture: "items-out-of-order.xml", failure: .itemsOutOfOrder)
    ]

    /// Every rejection names itself, and none is partially usable.
    ///
    /// The typed case carries the item's index because a feed grows: "the
    /// signature is missing" is not actionable on a document with eleven items.
    /// Nothing here returns a document with the bad item dropped — a feed that
    /// half-validates is a feed that offers whatever survived the filter.
    @Test("A malformed appcast is rejected with its own named failure", arguments: rejections)
    func aMalformedAppcastIsRejected(rejection: AppcastRejectionCase) throws {
        let xml = try AppcastFixtures.text(rejection.fixture)

        #expect(throws: rejection.failure) {
            try AppcastDocument.validate(xml)
        }
    }

    // MARK: - A merge keeps history

    /// Publishing a new version preserves every previously published item.
    ///
    /// This is the property the whole publication design rests on: the feed is
    /// fetched, one item is prepended, and the result is republished. A merge
    /// that dropped the oldest item would strand every user who skipped a
    /// version, and deleting a published item is never how a bad release is
    /// corrected.
    @Test("A merged document keeps every item, newest first")
    func aMergedDocumentKeepsEveryItem() throws {
        let document = try AppcastDocument.validate(AppcastFixtures.text("valid-merged-history.xml"))

        #expect(document.items.map(\.shortVersionString) == ["1.1.0", "1.0.1", "1.0.0"])
        #expect(document.items.map(\.version) == ["3", "2", "1"])
        #expect(Set(document.items.map(\.enclosureURL)).count == 3)
    }

    /// Every fixture this suite names is reachable.
    ///
    /// Non-vacuity for the two tables above: a loader that silently answered
    /// `nil` would turn "the document was rejected" into a statement about a
    /// missing file rather than about the validator.
    @Test("Every appcast fixture is reachable")
    func everyFixtureIsReachable() throws {
        var names = Self.rejections.map(\.fixture)
        names.append("valid-single-item.xml")
        names.append("valid-merged-history.xml")

        #expect(names.count == 15)
        for name in names {
            let text = try AppcastFixtures.text(name)
            #expect(text.contains("<rss"), "\(name) is not an appcast document")
        }
    }
}
