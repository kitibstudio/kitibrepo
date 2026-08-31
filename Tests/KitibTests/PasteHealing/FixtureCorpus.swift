import XCTest

/// Locates and loads the paste-healing fixture corpus from disk.
///
/// The fixtures are NOT bundle resources — the test target compiles
/// `Sources/Core` directly and copies no resources — so they are found relative
/// to this source file via `#filePath`.
///
/// Before this existed the corpus was written to disk and never read by any
/// test: the only test named "…FixtureRoundTrips" hardcoded its input inline.
/// Twelve fixture files were dead weight and nothing verified them.
enum FixtureCorpus {

    /// Every fixture directory name in the corpus. Add new ones here — both
    /// `CorpusTests` and `scripts/validate.sh` assert that the directories on
    /// disk match this list exactly, so a stray or missing fixture fails.
    static let names = [
        "clause-lead-in-standards-pdf",
        "data-sheet",
        "definitions-with-list-standards-pdf",
        "definitions-with-notes-standards-pdf",
        "lettered-list-standards-pdf",
        "multi-column-standards-pdf",
        "paginated-standards-pdf",
        "protected-compounds",
        "scanned-ocr-output",
        "unlined-word-paste",
        "web",
        "word-to-clipboard",
    ]

    /// One expected-output file PER PIPELINE STAGE (D25, D27).
    ///
    /// Each stage ADDS a file; no stage rewrites an earlier one. That keeps
    /// every completed stage permanently regression-tested, and means growing
    /// the pipeline never requires weakening or deleting an existing test —
    /// which the unattended-agent contract forbids outright.
    ///
    /// Transform order is locked by D20:
    ///   repairGlyphs → stripArtefacts → unwrapLines → dehyphenate
    ///   → detectTables → preserveClauseNumbers
    enum Stage: String, CaseIterable {
        /// T1 — after `repairGlyphs` alone.
        case repairGlyphs = "expected-repairglyphs.md"
        /// T2 — after `repairGlyphs` → `stripArtefacts` → `unwrapLines`.
        case unwrapped = "expected-unwrapped.md"
        /// T3 — after the full six-transform pipeline, i.e. `PasteHealer.heal`.
        case healed = "expected.md"
    }

    /// Repo root, derived from this file's location:
    /// Tests/KitibTests/PasteHealing/FixtureCorpus.swift → up 4 → repo root.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PasteHealing
            .deletingLastPathComponent()   // KitibTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    /// Where the corpus is read from at runtime.
    ///
    /// PREFERS the copy inside the test bundle (DerivedData, under ~/Library),
    /// falling back to the source tree only if that copy is missing.
    ///
    /// This ordering is deliberate and is not a style choice. The repo lives
    /// under `~/Documents`, which macOS protects with TCC, and the `xctest`
    /// runner does NOT inherit the launching terminal's permission — so reading
    /// the corpus from the source tree fails with `NSCocoaErrorDomain` 257 for
    /// every file, producing dozens of assertion failures that look like code
    /// defects (D28). The bundled copy is not subject to that.
    static var corpusRoot: URL {
        if let bundled = bundledCorpusRoot { return bundled }
        return sourceTreeCorpusRoot
    }

    /// The corpus as copied into the test bundle by the `resources` build phase.
    /// `nil` if the copy is absent, which `testFixturesAreBundled` treats as a
    /// failure so the resource phase cannot silently stop working.
    static var bundledCorpusRoot: URL? {
        let bundle = Bundle(for: BundleMarker.self)
        guard let resources = bundle.resourceURL else { return nil }
        let candidate = resources.appendingPathComponent("paste-healing")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    static var sourceTreeCorpusRoot: URL {
        repoRoot
            .appendingPathComponent("Tests")
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("paste-healing")
    }

    /// Anchor class used only to locate the test bundle.
    private final class BundleMarker {}

    static func directory(_ name: String) -> URL {
        corpusRoot.appendingPathComponent(name)
    }

    /// Loads one fixture's `input.txt` and the expected output for `stage`.
    ///
    /// Fails the calling test — rather than returning nil silently — if either
    /// file is missing, so a corpus that quietly stops existing cannot pass.
    static func load(
        _ name: String,
        stage: Stage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (input: String, expected: String)? {
        let dir = directory(name)
        let inputURL = dir.appendingPathComponent("input.txt")
        let expectedURL = dir.appendingPathComponent(stage.rawValue)
        do {
            return (
                try String(contentsOf: inputURL, encoding: .utf8),
                try String(contentsOf: expectedURL, encoding: .utf8)
            )
        } catch {
            XCTFail(
                "Fixture '\(name)' stage '\(stage.rawValue)' could not be loaded "
                    + "from \(dir.path): \(error)\(Self.permissionHint(error))",
                file: file, line: line
            )
            return nil
        }
    }

    /// Turns a macOS privacy denial into an actionable sentence.
    ///
    /// This repo sits under `~/Documents`, which macOS protects with TCC. The
    /// xctest runner inherits the privacy permissions of whatever launched it,
    /// so running the suite from a terminal without Documents/Full Disk Access
    /// makes every fixture read fail with `NSCocoaErrorDomain` 257 — producing
    /// dozens of assertion failures that read exactly like code defects and are
    /// not one. That happened on 2026-08-10 and cost a full diagnosis.
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

    /// Loads only `input.txt`, for checks that apply at every stage.
    static func input(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        let url = directory(name).appendingPathComponent("input.txt")
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            XCTFail("Fixture '\(name)': input.txt unreadable at \(url.path): "
                        + "\(error)\(Self.permissionHint(error))",
                    file: file, line: line)
            return nil
        }
    }
}
