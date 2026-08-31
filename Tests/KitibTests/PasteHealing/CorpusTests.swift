import XCTest

/// Tests that actually READ the fixture corpus from disk.
///
/// Spec: specs/paste-healing.md — Test plan, and criteria 3, 4, 8, 9.
/// The corpus is the acceptance criterion (build-plan Stage 0.5), so it has to
/// be loaded and compared, not described.
///
/// STAGE SCOPING (D25, D27): each pipeline stage has its own expected file and
/// its own comparison test. This file covers stage `.repairGlyphs` only. T2 adds
/// `expected-unwrapped.md` plus a new test beside these; T3 adds `expected.md`.
/// No stage rewrites an earlier stage's baseline or edits an earlier stage's
/// test — growing the pipeline is always additive.
final class CorpusTests: XCTestCase {

    // MARK: Corpus hygiene — applies at every stage

    /// The corpus directory must contain exactly the declared fixtures.
    /// Catches both a fixture that vanished and stray/abandoned directories —
    /// T1 left three empty ones (`ocr-output`, `standards-pdf`,
    /// `word-clipboard`) that git could not see, because git does not track
    /// empty directories.
    func testCorpusContainsExactlyTheDeclaredFixtures() throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: FixtureCorpus.corpusRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let onDisk = Set(
            contents
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .map { $0.lastPathComponent }
        )
        XCTAssertEqual(
            onDisk, Set(FixtureCorpus.names),
            "Fixture directories on disk do not match FixtureCorpus.names. "
                + "Stray empty directories are invisible to git — delete them."
        )
    }

    /// The corpus MUST be read from the copy inside the test bundle, not from
    /// the source tree. `FixtureCorpus.corpusRoot` falls back to the source tree
    /// if the bundled copy is missing, and without this assertion that fallback
    /// would silently mask a broken `resources` build phase — until the suite is
    /// run from a process lacking TCC access to ~/Documents, when every fixture
    /// read fails at once (D28). Fail here instead, with one clear message.
    func testFixturesAreBundledNotReadFromSourceTree() {
        XCTAssertNotNil(
            FixtureCorpus.bundledCorpusRoot,
            "Fixtures are not in the test bundle. The `resources` build phase for "
                + "Tests/Fixtures/paste-healing in project.yml is not copying them. "
                + "Run `xcodegen generate`. Until this passes, the suite is reading "
                + "the TCC-protected source tree and will fail under any runner that "
                + "lacks Documents access."
        )
    }

    func testEveryFixtureLoads() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .repairGlyphs) else { continue }
            XCTAssertFalse(fixture.input.isEmpty, "\(name): input.txt is empty")
            XCTAssertFalse(fixture.expected.isEmpty, "\(name): expected-repairglyphs.md is empty")
        }
    }

    /// A fixture whose expected output equals its input proves nothing.
    func testNoFixtureIsTautological() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .repairGlyphs) else { continue }
            XCTAssertNotEqual(
                fixture.input, fixture.expected,
                "\(name): input.txt and expected-repairglyphs.md are identical — this fixture tests nothing"
            )
        }
    }

    // MARK: Stage 1 contract — repairGlyphs

    /// Criterion 4, across the whole corpus.
    func testRepairGlyphsProducesExpectedOutputForEveryFixture() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .repairGlyphs) else { continue }
            XCTAssertEqual(
                repairGlyphs(fixture.input), fixture.expected,
                "\(name): repairGlyphs(input.txt) does not match expected-repairglyphs.md"
            )
        }
    }

    /// Criterion 8, across the whole corpus.
    func testRepairGlyphsIsDeterministicAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let input = FixtureCorpus.input(name) else { continue }
            XCTAssertEqual(
                repairGlyphs(input), repairGlyphs(input),
                "\(name): repairGlyphs is not deterministic"
            )
        }
    }

    /// Criterion 9, across the whole corpus.
    func testRepairGlyphsIsIdempotentAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let input = FixtureCorpus.input(name) else { continue }
            let once = repairGlyphs(input)
            XCTAssertEqual(
                repairGlyphs(once), once,
                "\(name): repairGlyphs is not idempotent"
            )
        }
    }

    /// Criterion 3 — the signature failure mode, checked against real fixtures
    /// rather than an inline string. Every protected compound present in a
    /// fixture's expected output must survive healing byte-identical.
    func testProtectedCompoundsSurviveAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .repairGlyphs) else { continue }
            let healed = repairGlyphs(fixture.input)
            for compound in ProtectedCompounds.compounds where fixture.expected.contains(compound) {
                XCTAssertTrue(
                    healed.contains(compound),
                    "\(name): protected compound '\(compound)' did not survive repairGlyphs"
                )
            }
        }
    }

    /// No mangled glyph may survive into the healed output.
    func testNoMangledGlyphResidueRemains() {
        // NBSP is deliberately absent: it is CONVERTED to a regular space (D23),
        // not removed, so it must not appear in this list.
        let mustNotSurvive: [(String, Character)] = [
            ("fi ligature", "\u{fb01}"),
            ("fl ligature", "\u{fb02}"),
            ("left double smart quote", "\u{201c}"),
            ("right double smart quote", "\u{201d}"),
            ("low double smart quote", "\u{201e}"),
            ("left single smart quote", "\u{2018}"),
            ("right single smart quote", "\u{2019}"),
            ("em dash", "\u{2014}"),
            ("en dash", "\u{2013}"),
            ("U+2010 hyphen", "\u{2010}"),
            ("U+2011 non-breaking hyphen", "\u{2011}"),
            ("zero-width space", "\u{200b}"),
        ]
        for name in FixtureCorpus.names {
            guard let input = FixtureCorpus.input(name) else { continue }
            let healed = repairGlyphs(input)
            for (label, scalar) in mustNotSurvive {
                XCTAssertFalse(
                    healed.contains(scalar),
                    "\(name): \(label) survived repairGlyphs"
                )
            }
        }
    }

    /// D23 — NBSP is a value/unit separator in this corpus. Deleting it yields
    /// `1000kVA`, `50Hz`, `300A`: output that reads as correct and is not.
    func testNonBreakingSpaceBecomesASpaceNotNothing() {
        let input = "1000\u{00a0}kVA at 50\u{00a0}Hz drawing 300\u{00a0}A"
        XCTAssertEqual(repairGlyphs(input), "1000 kVA at 50 Hz drawing 300 A")
    }
}
