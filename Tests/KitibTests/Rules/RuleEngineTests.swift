import XCTest

/// Failure-mode tests for RuleEngine: pluggability (criterion 2),
/// deterministic order (criterion 3 + failure mode 7), disabled rules that
/// cost nothing (criterion 4 + failure mode 9), and pass-through of the one
/// diagnostic shape (criterion 1).
final class RuleEngineTests: XCTestCase {

    private let text = "abcdefgh"
    private var projection: DocumentProjection { makeProjection(text) }

    // MARK: - Pluggability

    func testEmptyRuleListProducesNoDiagnostics() {
        let result = RuleEngine.run(rules: [], on: projection)
        XCTAssertEqual(result, [])
    }

    func testEmptyDocumentProducesNoDiagnostics() {
        let p = makeProjection("")
        let result = RuleEngine.run(rules: [StubRule(ruleID: "a", diagnostics: [])], on: p)
        XCTAssertEqual(result, [])
    }

    func testDiagnosticsFromDifferentRulesConcatenate() {
        let ruleA = StubRule(ruleID: "a", diagnostics: [makeDiagnostic("a", at: 0, in: text)])
        let ruleB = StubRule(ruleID: "b", diagnostics: [makeDiagnostic("b", at: 6, in: text)])
        let result = RuleEngine.run(rules: [ruleA, ruleB], on: projection)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.ruleID), ["a", "b"])
    }

    func testDiagnosticsCarryOriginalRangesAndMessages() {
        let d = makeDiagnostic("x", at: 2, message: "hello", in: text)
        let result = RuleEngine.run(rules: [StubRule(ruleID: "x", diagnostics: [d])], on: projection)
        XCTAssertEqual(result.first?.message, "hello")
        XCTAssertEqual(result.first?.range, d.range)
        XCTAssertEqual(result.first?.severity, .warning)
    }

    // MARK: - Deterministic order (criterion 3, failure mode 7)

    func testDiagnosticsAreSortedByRangeStartRegardlessOfRuleOrder() {
        let ruleA = StubRule(ruleID: "a", diagnostics: [makeDiagnostic("a", at: 5, in: text)])
        let ruleB = StubRule(ruleID: "b", diagnostics: [makeDiagnostic("b", at: 1, in: text)])
        let result = RuleEngine.run(rules: [ruleA, ruleB], on: projection)
        XCTAssertEqual(result.map(\.ruleID), ["b", "a"])
        let starts = result.map { $0.range.lowerBound }
        XCTAssertEqual(starts, starts.sorted())
    }

    func testSameOffsetSortedByRuleID() {
        let ruleB = StubRule(ruleID: "beta", diagnostics: [makeDiagnostic("beta", at: 2, in: text)])
        let ruleA = StubRule(ruleID: "alpha", diagnostics: [makeDiagnostic("alpha", at: 2, in: text)])
        let result = RuleEngine.run(rules: [ruleB, ruleA], on: projection)
        XCTAssertEqual(result.map(\.ruleID), ["alpha", "beta"])
    }

    func testSameRuleSameOffsetKeepsEmitOrder() {
        let rule = StubRule(ruleID: "one", diagnostics: [
            makeDiagnostic("one", at: 3, message: "first", in: text),
            makeDiagnostic("one", at: 3, message: "second", in: text),
        ])
        let result = RuleEngine.run(rules: [rule], on: projection)
        XCTAssertEqual(result.map(\.message), ["first", "second"])
    }

    func testDeterministicOrderAcrossRuns() {
        let rules: [Rule] = [
            StubRule(ruleID: "c", diagnostics: [
                makeDiagnostic("c", at: 4, in: text),
                makeDiagnostic("c", at: 0, in: text),
            ]),
            StubRule(ruleID: "a", diagnostics: [makeDiagnostic("a", at: 4, in: text)]),
        ]
        let first = RuleEngine.run(rules: rules, on: projection)
        let second = RuleEngine.run(rules: rules, on: projection)
        XCTAssertEqual(first, second)
        // Offsets: c@0, then at offset 4 ruleID order wins: a before c.
        XCTAssertEqual(first.map(\.ruleID), ["c", "a", "c"])
    }

    // MARK: - Disabled rules (criterion 4)

    func testDisabledRuleProducesNothing() {
        let rule = StubRule(ruleID: "disabled", diagnostics: [makeDiagnostic("disabled", at: 1, in: text)])
        var config = RuleConfiguration()
        config.disable("disabled")
        let result = RuleEngine.run(rules: [rule], on: projection, configuration: config)
        XCTAssertEqual(result, [])
    }

    func testDisabledRuleIsNotEvaluated() {
        let rule = CountingRule(ruleID: "counted", diagnostics: [makeDiagnostic("counted", at: 1, in: text)])
        var config = RuleConfiguration()
        config.disable("counted")
        _ = RuleEngine.run(rules: [rule], on: projection, configuration: config)
        XCTAssertEqual(rule.evaluationCount, 0, "a disabled rule must not be evaluated at all")
    }

    func testEnabledRuleIsEvaluated() {
        let rule = CountingRule(ruleID: "counted", diagnostics: [])
        _ = RuleEngine.run(rules: [rule], on: projection)
        XCTAssertEqual(rule.evaluationCount, 1)
    }

    func testDisablingOneRuleLeavesOthersEvaluated() {
        let disabled = CountingRule(ruleID: "off", diagnostics: [])
        let enabled = CountingRule(ruleID: "on", diagnostics: [])
        var config = RuleConfiguration()
        config.disable("off")
        _ = RuleEngine.run(rules: [disabled, enabled], on: projection, configuration: config)
        XCTAssertEqual(disabled.evaluationCount, 0)
        XCTAssertEqual(enabled.evaluationCount, 1)
    }

    // MARK: - Severity override (criterion 4, failure mode 9)

    func testSeverityOverrideAppliesToAllDiagnostics() {
        let rule = StubRule(ruleID: "mixed", diagnostics: [
            makeDiagnostic("mixed", at: 1, severity: .warning, in: text),
            makeDiagnostic("mixed", at: 3, severity: .error, in: text),
        ])
        var config = RuleConfiguration()
        config.setSeverity(.info, for: "mixed")
        let result = RuleEngine.run(rules: [rule], on: projection, configuration: config)
        XCTAssertEqual(result.map(\.severity), [.info, .info])
    }

    func testNoOverrideKeepsRuleSeverity() {
        let rule = StubRule(ruleID: "warn", diagnostics: [
            makeDiagnostic("warn", at: 1, severity: .warning, in: text),
        ])
        let result = RuleEngine.run(rules: [rule], on: projection)
        XCTAssertEqual(result.map(\.severity), [.warning])
    }

    func testDefaultConfigurationUsedWhenOmitted() {
        let rule = StubRule(ruleID: "r", diagnostics: [makeDiagnostic("r", at: 1, in: text)])
        let result = RuleEngine.run(rules: [rule], on: projection)
        XCTAssertEqual(result.count, 1)
    }

    /// D81: without a configuration override, a rule's own per-diagnostic
    /// severities stand. ForbiddenPhraseRule depends on this (criterion 10
    /// pairs severity with each phrase). The engine replaces severity ONLY
    /// when an override exists.
    func testNoOverrideKeepsMixedSeverities() {
        let rule = StubRule(ruleID: "mixed", defaultSeverity: .warning, diagnostics: [
            makeDiagnostic("mixed", at: 1, severity: .warning, in: text),
            makeDiagnostic("mixed", at: 3, severity: .error, in: text),
        ])
        let result = RuleEngine.run(rules: [rule], on: projection)
        XCTAssertEqual(result.map(\.severity), [.warning, .error])
    }
}
