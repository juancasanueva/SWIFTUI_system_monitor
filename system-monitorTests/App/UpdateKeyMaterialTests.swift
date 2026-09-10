import Foundation
import Testing

/// Walks the repository looking for Ed25519-shaped key material.
///
/// Self-contained, like the other update suites, so the whole slice rolls back
/// by deleting its own files.
nonisolated enum UpdateKeyMaterialSources {

    /// Directories that are not "the repository": version-control internals,
    /// build output, local tool state and binary reference material.
    static let uncheckedDirectories: Set<String> = [
        ".git", ".build", "build", ".swiftpm", "DerivedData", ".codegraph", ".atl", ".pi",
    ]

    /// File extensions whose bytes are not text. Decoding a PNG as UTF-8 yields
    /// a string in which any 43-byte run can happen to look like base64, which
    /// would make this a guard that fires on noise and therefore on nothing.
    static let uncheckedExtensions: Set<String> = ["png", "jpg", "jpeg", "pdf", "icns", "zip"]

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // system-monitorTests
            .deletingLastPathComponent()   // repository root
    }

    static func repositoryFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: repositoryRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        var files: [URL] = []
        while let candidate = enumerator.nextObject() as? URL {
            let isDirectory = (try? candidate.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                if uncheckedDirectories.contains(candidate.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard !uncheckedExtensions.contains(candidate.pathExtension.lowercased()) else { continue }
            files.append(candidate)
        }
        return files
    }

    /// A found literal, with the file that carried it.
    nonisolated struct Sighting: Sendable, Hashable {
        let path: String
        let literal: String
    }

    /// A raw Ed25519 key is 32 bytes, which base64-encodes to 43 characters plus
    /// one `=` of padding. The lookarounds stop the pattern firing on a
    /// 43-character window inside a longer base64 or hexadecimal blob — a
    /// resolved-package checksum, for instance — which would otherwise make this
    /// a guard that fires on everything.
    static let ed25519Shape = "(?<![A-Za-z0-9+/=])[A-Za-z0-9+/]{43}=(?![A-Za-z0-9+/=])"

    static func sightings() throws -> (found: [Sighting], scanned: Int) {
        let expression = try NSRegularExpression(pattern: ed25519Shape)
        let rootPath = repositoryRoot.standardizedFileURL.path

        var found: [Sighting] = []
        var scanned = 0

        for file in repositoryFiles() {
            guard let data = try? Data(contentsOf: file) else { continue }
            scanned += 1
            let text = String(decoding: data, as: UTF8.self)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in expression.matches(in: text, range: range) {
                guard let matched = Range(match.range, in: text) else { continue }
                let path = file.standardizedFileURL.path
                    .replacingOccurrences(of: rootPath + "/", with: "")
                found.append(Sighting(path: path, literal: String(text[matched])))
            }
        }
        return (found, scanned)
    }
}

// app-updates — AU-3 "the private key must not exist anywhere in the repository".
//
// A raw Ed25519 **private** key is also 44 base64 characters with no header, so
// it is byte-shape-identical to the **public** key this change commits on
// purpose. Any pattern broad enough to catch one catches the other, and a
// filename allow-list is a guard that passes because it was told to.
//
// The exact-count form is false-positive-free and strictly stronger: a second
// key appearing anywhere — in a fixture, a document, a script, a committed
// export — fails it, whatever the file is called.
//
// Residual gap, recorded rather than smoothed: a private key committed in a
// format that is *not* 44-character base64 evades this sweep.
@Suite("Update key material", .timeLimit(.minutes(2)))
struct UpdateKeyMaterialTests {

    @Test func theOnlyKeyShapedLiteralInTheRepositoryIsTheBundledPublicKey() throws {
        let (found, scanned) = try UpdateKeyMaterialSources.sightings()

        #expect(found.map(\.path) == [UpdateBundleSources.partialInfoPlist])

        let contents = try UpdateBundleSources.partialInfoPlistContents()
        let publicKey = try #require(contents["SUPublicEDKey"] as? String)
        #expect(found.map(\.literal) == [publicKey])

        // An absence is only proof if something counted the presences.
        #expect(scanned > 100)
    }
}
