import Foundation

// MARK: - RuleEngine

/// Runs any list of rules over one projection and returns the concatenated
/// diagnostics in a deterministic total order (specs/rules-engine.md
/// criterion 3, failure mode 7).
///
/// Order: range start, then ruleID, then the rule's position in the rules
/// array, then the diagnostic's position within its rule's result. The last
/// two tie-breakers exist because Swift's `sorted` is not stable: without
/// them two diagnostics that are equal on (range start, ruleID) could swap
/// between runs and make a golden test flake.
enum RuleEngine {

    static func run(rules: [Rule],
                    on projection: DocumentProjection,
                    configuration: RuleConfiguration = RuleConfiguration()) -> [Diagnostic] {
        var collected: [(ruleIndex: Int, diagnostic: Diagnostic)] = []

        for (ruleIndex, rule) in rules.enumerated() {
            // Disabled rules are skipped BEFORE evaluate: they must cost
            // nothing, not merely contribute nothing (criterion 4).
            guard configuration.isEnabled(rule.ruleID) else { continue }

            let severity = configuration.severity(for: rule.ruleID,
                                                  default: rule.defaultSeverity)
            for diagnostic in rule.evaluate(projection) {
                collected.append((ruleIndex, Diagnostic(
                    ruleID: diagnostic.ruleID,
                    severity: severity,
                    message: diagnostic.message,
                    range: diagnostic.range
                )))
            }
        }

        return collected.enumerated().sorted { lhs, rhs in
            let (emitIndexA, a) = lhs
            let (emitIndexB, b) = rhs
            if a.diagnostic.range.lowerBound != b.diagnostic.range.lowerBound {
                return a.diagnostic.range.lowerBound < b.diagnostic.range.lowerBound
            }
            if a.diagnostic.ruleID != b.diagnostic.ruleID {
                return a.diagnostic.ruleID < b.diagnostic.ruleID
            }
            if a.ruleIndex != b.ruleIndex {
                return a.ruleIndex < b.ruleIndex
            }
            return emitIndexA < emitIndexB
        }.map { $0.element.diagnostic }
    }
}
