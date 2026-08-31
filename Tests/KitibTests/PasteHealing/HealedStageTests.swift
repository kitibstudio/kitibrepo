import XCTest

/// Stage 3 — the full six-transform pipeline, `PasteHealer.heal`, read from the
/// corpus on disk.
///
/// A NEW file beside `CorpusTests` and `UnwrappedStageTests` rather than an edit
/// to either (D27): each stage adds its own expected file and its own test, so
/// every finished stage stays permanently regression-tested and no passing test
/// is ever weakened.
///
/// **Every `expected.md` here is byte-identical to its stage-2 baseline, and
/// that is the assertion, not an omission.** No fixture in the corpus contains a
/// word split by hyphenation, a column-aligned table, or a clause header — so
/// `dehyphenate`, `detectTables` and `preserveClauseNumbers` are correctly
/// identity across all six. What this file proves is that the three new
/// transforms do not DAMAGE anything the first three produced: the protected
/// compounds, the em-dash spans (`Model-T-1000-K-rated`, `spec-XLPE/SWA/PVC-must`)
/// and the unit values are all shapes a careless dehyphenator destroys.
/// Criteria 2, 6 and 7 are exercised positively by `DehyphenateTests`,
/// `PreserveClauseNumbersTests`, `DetectTablesTests` and `PasteHealerTests` —
/// see PARKED.md for the fixture class that would put them under the golden
/// corpus too.
final class HealedStageTests: XCTestCase {

    func testEveryFixtureHasAHealedBaseline() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .healed) else { continue }
            XCTAssertFalse(fixture.input.isEmpty, "\(name): input.txt is empty")
            XCTAssertFalse(fixture.expected.isEmpty, "\(name): expected.md is empty")
        }
    }

    /// The whole pipeline, across the whole corpus.
    func testHealProducesExpectedOutputForEveryFixture() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .healed) else { continue }
            XCTAssertEqual(
                PasteHealer.heal(fixture.input), fixture.expected,
                "\(name): PasteHealer.heal does not match expected.md"
            )
        }
    }

    /// Criterion 8.
    func testHealIsDeterministicAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let input = FixtureCorpus.input(name) else { continue }
            XCTAssertEqual(
                PasteHealer.heal(input), PasteHealer.heal(input),
                "\(name): heal is not deterministic"
            )
        }
    }

    /// Criterion 9 — the guard against failure mode 7, non-idempotence.
    func testHealIsIdempotentAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let input = FixtureCorpus.input(name) else { continue }
            let once = PasteHealer.heal(input)
            XCTAssertEqual(
                PasteHealer.heal(once), once,
                "\(name): heal(heal(x)) != heal(x)"
            )
        }
    }

    /// Criterion 3 and failure mode 1, after all six transforms have run. This
    /// is the last place a protected compound can be destroyed.
    func testProtectedCompoundsSurviveHealAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .healed) else { continue }
            let healed = PasteHealer.heal(fixture.input)
            for compound in ProtectedCompounds.compounds where fixture.expected.contains(compound) {
                XCTAssertTrue(
                    healed.contains(compound),
                    "\(name): protected compound '\(compound)' did not survive heal"
                )
            }
        }
    }

    /// The stage-3 baseline is the output of a pipeline, never a copy of its
    /// input — a fixture whose expected output equals its input tests nothing.
    func testNoHealedBaselineIsTautological() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .healed) else { continue }
            XCTAssertNotEqual(
                fixture.input, fixture.expected,
                "\(name): input.txt and expected.md are identical — this fixture "
                    + "tests nothing"
            )
        }
    }

    /// Every stage-3 baseline must be present in the corpus as its own file.
    /// The stage files are equal in content here, so a missing `expected.md`
    /// would otherwise be indistinguishable from a passing test.
    func testEveryFixtureHasAllThreeStageFilesOnDisk() {
        for name in FixtureCorpus.names {
            for stage in FixtureCorpus.Stage.allCases {
                let url = FixtureCorpus.directory(name).appendingPathComponent(stage.rawValue)
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: url.path),
                    "\(name): \(stage.rawValue) is missing from the corpus"
                )
            }
        }
    }
}
