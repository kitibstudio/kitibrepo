import Foundation

// MARK: - DiagnosticSeverity

/// The severity a rule attaches to a finding.
enum DiagnosticSeverity: Equatable {
    case error
    case warning
    case info
}

// MARK: - Diagnostic

/// One finding from one rule: a single shape every rule returns
/// (specs/rules-engine.md criterion 1). Nothing else; no fix, no rule
/// metadata, no UI. Adding a field is a spec change, not a GREEN deviation.
struct Diagnostic: Equatable {
    let ruleID: String
    let severity: DiagnosticSeverity
    let message: String
    /// The offending text in the original document. Rules must narrow this
    /// to the defect itself; not the whole line, not the whole section
    /// (criterion 5).
    let range: Range<String.Index>
}
