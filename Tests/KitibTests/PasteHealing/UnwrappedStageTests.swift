import XCTest

/// Stage 2 of the pipeline, read from the corpus on disk:
/// `repairGlyphs` → `stripArtefacts` → `unwrapLines` (D20 order).
///
/// A NEW file beside `CorpusTests` rather than an edit to it (D27): each stage
/// adds its own expected file and its own test, so every finished stage stays
/// permanently regression-tested and no passing test is ever weakened.
///
/// `expected-unwrapped.md` is hand-authored. Two fixtures — `protected-compounds`
/// and `web` — are byte-identical to their stage-1 baseline, and that is the
/// assertion, not an omission: every line of `protected-compounds` ends a
/// sentence, and `web` has no consistent wrap column, so in both cases the
/// correct stage-2 output is "unchanged". A transform that rejoined them would
/// fail here.
final class UnwrappedStageTests: XCTestCase {

    /// The stage-2 pipeline, in the locked order. Composed here rather than via
    /// `PasteHealer.heal` because that entry point is T3 and does not exist yet.
    private func stageTwo(_ raw: String) -> String {
        unwrapLines(stripArtefacts(repairGlyphs(raw)))
    }

    func testEveryFixtureHasAnUnwrappedBaseline() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .unwrapped) else { continue }
            XCTAssertFalse(fixture.input.isEmpty, "\(name): input.txt is empty")
            XCTAssertFalse(fixture.expected.isEmpty, "\(name): expected-unwrapped.md is empty")
        }
    }

    /// Criteria 1 and 5, across the whole corpus.
    func testStageTwoProducesExpectedOutputForEveryFixture() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .unwrapped) else { continue }
            XCTAssertEqual(
                stageTwo(fixture.input), fixture.expected,
                "\(name): repairGlyphs → stripArtefacts → unwrapLines does not match "
                    + "expected-unwrapped.md"
            )
        }
    }

    /// Criterion 8.
    func testStageTwoIsDeterministicAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let input = FixtureCorpus.input(name) else { continue }
            XCTAssertEqual(
                stageTwo(input), stageTwo(input),
                "\(name): the stage-2 pipeline is not deterministic"
            )
        }
    }

    /// Criterion 9 — the guard against failure mode 7, non-idempotence.
    func testStageTwoIsIdempotentAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let input = FixtureCorpus.input(name) else { continue }
            let once = stageTwo(input)
            XCTAssertEqual(
                stageTwo(once), once,
                "\(name): the stage-2 pipeline is not idempotent"
            )
        }
    }

    /// Criterion 3 — the signature failure mode, re-checked after two more
    /// transforms have run. A compound that survived `repairGlyphs` can still be
    /// destroyed by a rejoin.
    func testProtectedCompoundsSurviveStageTwoAcrossCorpus() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .unwrapped) else { continue }
            let healed = stageTwo(fixture.input)
            for compound in ProtectedCompounds.compounds where fixture.expected.contains(compound) {
                XCTAssertTrue(
                    healed.contains(compound),
                    "\(name): protected compound '\(compound)' did not survive stage 2"
                )
            }
        }
    }

    /// No stage-2 baseline may be a copy of `input.txt` — that would prove
    /// nothing at all.
    func testNoUnwrappedBaselineIsTautological() {
        for name in FixtureCorpus.names {
            guard let fixture = FixtureCorpus.load(name, stage: .unwrapped) else { continue }
            XCTAssertNotEqual(
                fixture.input, fixture.expected,
                "\(name): input.txt and expected-unwrapped.md are identical — this "
                    + "fixture tests nothing"
            )
        }
    }
}
