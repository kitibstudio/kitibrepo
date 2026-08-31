import XCTest

/// The golden corpus under the four rules (specs/rules-engine.md test plan):
/// zero errors, warning counts pinned per document. A count drift is a rule
/// over-firing or under-firing, caught by a diff rather than by a human
/// reading a panel (failure mode 10).
final class GoldenDocumentRuleTests: XCTestCase {

    /// Pinned counts of non-error diagnostics per golden document, read by
    /// hand from the documents before the rules were implemented. All zero:
    /// every heading in the corpus has real content. Note the subtlety that
    /// makes the level-1 titles in 01 and 03 NOT empty: a level-1 heading
    /// followed only by level-2 headings has its section run to end of
    /// document (no equal-or-higher heading after it), and that section holds
    /// content.
    private let pinnedWarningCounts = [
        "01-design-note.md": 0,
        "02-specification-extract.md": 0,
        "03-test-report.md": 0,
        "04-minimal.md": 0,
        "05-edge-cases.md": 0,
    ]

    private func run(_ doc: String) -> [Diagnostic] {
        // An empty index: any wiki-link in a golden document would resolve to
        // nil and error, so "zero errors" is a real claim, not a vacuous one.
        runAllFourRules(on: doc, linkIndex: LinkIndex(entries: []))
    }

    func testGoldenDocumentsProduceZeroErrors() {
        for name in Goldens.names {
            guard let doc = Goldens.load(name) else { continue }
            let errors = run(doc).filter { $0.severity == .error }
            XCTAssertEqual(errors, [],
                           "\\(name): golden documents must produce zero errors")
        }
    }

    func testGoldenDocumentWarningCountsArePinned() {
        for name in Goldens.names {
            guard let doc = Goldens.load(name) else { continue }
            let warnings = run(doc).filter { $0.severity != .error }
            XCTAssertEqual(
                warnings.count, pinnedWarningCounts[name] ?? 0,
                "\\(name): pinned warning count drifted. Update the pin ONLY "
                    + "if the rule behaviour change is deliberate and "
                    + "spec-compliant, and record it in DECISIONS.md."
            )
        }
    }

    func testGoldenDeterminism() {
        for name in Goldens.names {
            guard let doc = Goldens.load(name) else { continue }
            XCTAssertEqual(run(doc), run(doc), "\\(name): diagnostics must be deterministic")
        }
    }
}
