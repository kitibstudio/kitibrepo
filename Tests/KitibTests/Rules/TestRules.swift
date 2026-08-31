import Foundation

// MARK: - Test support: rule doubles for engine tests.
//
// The engine tests need rules whose output, severity, and evaluation count
// are fully controlled. These doubles are deliberately dumb; the behaviour
// they assert on lives in RuleEngine, not in the doubles.

/// A rule that emits a fixed diagnostic list, unchanged, every evaluation.
struct StubRule: Rule {
    let ruleID: String
    let defaultSeverity: DiagnosticSeverity
    let diagnostics: [Diagnostic]

    init(ruleID: String,
         defaultSeverity: DiagnosticSeverity = .warning,
         diagnostics: [Diagnostic] = []) {
        self.ruleID = ruleID
        self.defaultSeverity = defaultSeverity
        self.diagnostics = diagnostics
    }

    func evaluate(_ projection: DocumentProjection) -> [Diagnostic] {
        diagnostics
    }
}

/// A rule that counts how many times it was evaluated, so the spec's "a
/// disabled rule ... costs nothing" (criterion 4) is asserted by call count,
/// not by inference from the empty result.
final class CountingRule: Rule {
    let ruleID: String
    let defaultSeverity: DiagnosticSeverity
    let diagnostics: [Diagnostic]
    private(set) var evaluationCount = 0

    init(ruleID: String,
         defaultSeverity: DiagnosticSeverity = .warning,
         diagnostics: [Diagnostic] = []) {
        self.ruleID = ruleID
        self.defaultSeverity = defaultSeverity
        self.diagnostics = diagnostics
    }

    func evaluate(_ projection: DocumentProjection) -> [Diagnostic] {
        evaluationCount += 1
        return diagnostics
    }
}

// MARK: - Builders

/// Builds a diagnostic spanning one character at a UTF-16 offset into `text`.
/// Test documents are ASCII, so UTF-16 offsets equal character offsets.
func makeDiagnostic(_ ruleID: String,
                    at offset: Int,
                    severity: DiagnosticSeverity = .warning,
                    message: String = "diagnostic",
                    in text: String) -> Diagnostic {
    let start = String.Index(utf16Offset: offset, in: text)
    let end = String.Index(utf16Offset: offset + 1, in: text)
    return Diagnostic(ruleID: ruleID, severity: severity,
                      message: message, range: start..<end)
}

/// Builds a projection for a text with no link index.
func makeProjection(_ text: String, linkIndex: LinkIndex? = nil) -> DocumentProjection {
    DocumentProjection.build(from: text, linkIndex: linkIndex)
}
