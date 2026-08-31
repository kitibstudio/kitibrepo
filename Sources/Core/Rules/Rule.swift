import Foundation

// MARK: - Rule

/// One check over the projection. A new rule is a new file that conforms to
/// this protocol; the engine never changes to accommodate one
/// (specs/rules-engine.md criterion 2).
///
/// A rule reads ONLY the projection, never the raw text, so the engine
/// cannot drift into re-parsing Markdown (spec "The tripwire"). A rule that
/// needs inline structure the projection does not carry is parked and the
/// swift-markdown RED is re-raised; it is not grown as a new scanner.
protocol Rule {
    /// Stable identifier, unique per rule. Used by RuleConfiguration to
    /// disable and re-severity a rule, and by the engine's deterministic
    /// ordering.
    var ruleID: String { get }
    /// The severity this rule attaches when the caller has not overridden it.
    /// The spec pins exactly one error rule: BrokenWikiLinkRule. Everything
    /// else is warning or info (failure mode 9).
    var defaultSeverity: DiagnosticSeverity { get }
    func evaluate(_ projection: DocumentProjection) -> [Diagnostic]
}
