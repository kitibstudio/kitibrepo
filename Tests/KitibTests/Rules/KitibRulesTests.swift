import XCTest

/// Tests for the default ruleset the Problems panel runs (specs/problems-panel.md
/// criteria 1 and 6): exactly the four spec rules in spec order, unique
/// ruleIDs, the engine-spec severity pin (exactly one error rule, failure
/// mode 9), the inert empty-phrase ForbiddenPhraseRule (failure mode 7), and
/// a ruleset that still fires on real defects.
final class KitibRulesTests: XCTestCase {

    /// Criterion 6: the panel's ruleset is the four spec rules. The order is
    /// pinned because the engine's deterministic sort uses the rule's index
    /// in the array as a tie-breaker for same-range diagnostics
    /// (specs/rules-engine.md criterion 3).
    func testRulesetHoldsExactlyTheFourSpecRules() {
        XCTAssertEqual(
            KitibRules.all.map(\.ruleID),
            ["heading-level-jump", "empty-section", "broken-wiki-link", "forbidden-phrase"],
            "KitibRules.all must be the four spec rules in spec order"
        )
    }

    func testRuleIDsAreUnique() {
        let ids = KitibRules.all.map(\.ruleID)
        XCTAssertEqual(Set(ids).count, ids.count, "ruleIDs must be unique")
    }

    /// Engine-spec failure mode 9: exactly one error-severity rule, and it
    /// is the broken-link rule. A panel ruleset that errors on style
    /// opinions is the QA-gate failure this pin exists to catch.
    func testExactlyOneErrorRule() {
        let errorRules = KitibRules.all.filter { $0.defaultSeverity == .error }
        XCTAssertEqual(errorRules.count, 1, "exactly one rule may default to .error")
        XCTAssertEqual(errorRules.first?.ruleID, "broken-wiki-link",
                       "the one error rule must be broken-wiki-link")
    }

    /// Failure mode 7: the empty phrase list must be inert, not a crash.
    /// The panel ships with no phrase configuration, so this is the panel's
    /// default behaviour until a settings surface exists.
    func testEmptyPhraseForbiddenRuleIsInert() {
        let text = "This draft contains a TODO and a fixme."
        let diagnostics = RuleEngine.run(
            rules: KitibRules.all,
            on: makeProjection(text, linkIndex: nil),
            configuration: RuleConfiguration()
        )
        let phraseHits = diagnostics.filter { $0.ruleID == "forbidden-phrase" }
        XCTAssertEqual(phraseHits, [],
                       "an empty phrase list must never fire, and must not crash")
    }

    /// A clean document produces zero diagnostics under the panel's ruleset:
    /// no heading jumps, no empty sections, no links; the nil index makes
    /// the link rule emit nothing (engine-spec failure mode 6).
    func testCleanDocumentProducesZeroDiagnostics() {
        let text = """
        # Title

        Introduction text.

        ## Section

        Body text.

        ### Subsection

        More text.
        """
        let diagnostics = RuleEngine.run(
            rules: KitibRules.all,
            on: makeProjection(text, linkIndex: nil),
            configuration: RuleConfiguration()
        )
        XCTAssertEqual(diagnostics, [])
    }

    /// The ruleset must actually fire: a document holding one of each
    /// structural defect produces exactly one diagnostic of each kind. This
    /// catches a future edit that empties or miswires KitibRules.all.
    func testRulesetDetectsAllThreeStructuralDefects() {
        let text = """
        # Title

        Intro.

        ### Deep jump

        Some body text.

        ## Empty

        ## Next

        [[missing-target]]
        """
        // # -> ### is a two-level jump (3 > 1 + 1). "## Empty" is followed
        // directly by "## Next", so its section holds only whitespace. The
        // [[missing-target]] link cannot resolve against the empty index.
        let diagnostics = RuleEngine.run(
            rules: KitibRules.all,
            on: makeProjection(text, linkIndex: LinkIndex(entries: [])),
            configuration: RuleConfiguration()
        )
        let byRule = Dictionary(grouping: diagnostics, by: \.ruleID)
        XCTAssertEqual(byRule["heading-level-jump"]?.count, 1)
        XCTAssertEqual(byRule["empty-section"]?.count, 1)
        XCTAssertEqual(byRule["broken-wiki-link"]?.count, 1)
        XCTAssertEqual(diagnostics.count, 3, "no unexpected diagnostics")
    }

    /// Engine-spec criterion 3: the ruleset's output is deterministic. The
    /// panel relies on this and must never re-sort.
    func testRulesetOutputIsDeterministic() {
        let text = """
        # Title

        ### Deep

        Some text.

        ## Empty

        ## Next

        [[a]] [[b]]
        """
        let first = RuleEngine.run(
            rules: KitibRules.all,
            on: makeProjection(text, linkIndex: LinkIndex(entries: [])),
            configuration: RuleConfiguration()
        )
        let second = RuleEngine.run(
            rules: KitibRules.all,
            on: makeProjection(text, linkIndex: LinkIndex(entries: [])),
            configuration: RuleConfiguration()
        )
        XCTAssertEqual(first, second)
    }
}
