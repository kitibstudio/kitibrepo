import XCTest

/// Locates and loads the golden-document corpus from the test bundle.
///
/// The golden documents are COPIED INTO THE TEST BUNDLE as a folder reference
/// (project.yml, KitibTests resources build phase) — same treatment as the
/// paste-healing fixtures (D28, D29). The repo lives under ~/Documents, which
/// macOS TCC gates against the xctest runner; the bundled copy in DerivedData
/// is not subject to that.
///
/// Every document here was written by hand and was never produced by running
/// the implementation. They exist to prove acceptance criterion 10: clean input
/// is a no-op. `PasteHealer.heal(document)` must return `document` unchanged,
/// byte for byte.
enum Goldens {

    /// Every golden document in the corpus, by filename.
    /// The README.md is documentation, not a golden document — it is not listed
    /// here, but it is caught by golden-roundtrip.sh's .md scan.
    static let names = [
        "01-design-note.md",
        "02-specification-extract.md",
        "03-test-report.md",
        "04-minimal.md",
        "05-edge-cases.md",
    ]

    /// Prefers the bundled copy over the TCC-protected source tree.
    static var corpusRoot: URL {
        if let bundled = bundledCorpusRoot { return bundled }
        return sourceTreeCorpusRoot
    }

    /// The corpus as copied into the test bundle by the `resources` build phase.
    /// `nil` if absent — `testGoldenDocumentsAreBundledNotReadFromSourceTree`
    /// treats that as a failure.
    static var bundledCorpusRoot: URL? {
        let bundle = Bundle(for: BundleMarker.self)
        guard let resources = bundle.resourceURL else { return nil }
        let candidate = resources.appendingPathComponent("golden-documents")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    static var sourceTreeCorpusRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // KitibTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Tests")
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("golden-documents")
    }

    /// Anchor class used only to locate the test bundle.
    private final class BundleMarker {}

    static func document(_ name: String) -> URL {
        corpusRoot.appendingPathComponent(name)
    }

    /// Loads one golden document. Fails the calling test if the file is
    /// missing or unreadable, so a corpus that quietly stops existing cannot
    /// pass vacuously.
    static func load(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        let url = document(name)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            XCTFail(
                "Golden document '\(name)' could not be loaded from \(url.path): "
                    + "\(error)\(Self.permissionHint(error))",
                file: file, line: line
            )
            return nil
        }
    }

    /// Turns a macOS privacy denial into an actionable message (D28).
    static func permissionHint(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == NSCocoaErrorDomain,
              ns.code == NSFileReadNoPermissionError else { return "" }
        return """

            ^^ THIS IS A PERMISSIONS PROBLEM, NOT A TEST FAILURE.
            The fixture exists and is readable — this process is not allowed to \
            read it. Grant your terminal Full Disk Access (System Settings > \
            Privacy & Security > Full Disk Access), then QUIT and reopen it. \
            Or move the repo out of ~/Documents.
            """
    }
}

/// Criterion 10: clean input is a no-op.
///
/// Every golden document was written by hand and was never tuned to pass a
/// test. `PasteHealer.heal(document)` must return `document` unchanged, byte
/// for byte — a healing pass over well-formed, glyph-normalised Markdown must
/// be identity.
///
/// If any of these assertions fails, it is a FINDING, not a test to weaken:
/// the transform damaged a correctly written document. Park the result in
/// PARKED.md, commit only the green parts, and stop.
final class GoldenDocumentTests: XCTestCase {

    /// The corpus must be readable. This catches the case where the resources
    /// build phase is broken AND the source tree is TCC-blocked.
    func testGoldenCorpusIsNotEmpty() {
        XCTAssertFalse(
            Goldens.names.isEmpty,
            "Goldens.names is empty — the corpus declares no documents"
        )
    }

    /// Every golden document must be present and loaded.
    func testEveryGoldenDocumentLoads() {
        for name in Goldens.names {
            guard let doc = Goldens.load(name) else { continue }
            XCTAssertFalse(doc.isEmpty, "\(name): document is empty")
        }
    }

    /// ACCEPTANCE CRITERION 10 — the gate itself.
    /// PasteHealer.heal must be identity over every golden document.
    func testGoldenDocumentsRoundTripByteForByte() {
        for name in Goldens.names {
            guard let doc = Goldens.load(name) else { continue }
            let healed = PasteHealer.heal(doc)
            XCTAssertEqual(
                healed, doc,
                "\(name): PasteHealer.heal changed a golden document — "
                    + "criterion 10 failure. Do NOT edit the document to pass. "
                    + "Park this as a finding."
            )
        }
    }

    /// Golden documents must be read from the bundled copy, not from the
    /// TCC-protected source tree (D28/D29).
    func testGoldenDocumentsAreBundledNotReadFromSourceTree() {
        XCTAssertNotNil(
            Goldens.bundledCorpusRoot,
            "Golden documents are not in the test bundle. The `resources` build "
                + "phase for Tests/Fixtures/golden-documents in project.yml is not "
                + "copying them. Run `xcodegen generate`. Until this passes, the "
                + "suite is reading the TCC-protected source tree and will fail "
                + "under any runner that lacks Documents access."
        )
    }
}
