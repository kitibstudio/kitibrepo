import Foundation

// MARK: - EmptySectionRule

/// Flags a heading whose section contains no non-blank content before the
/// next heading of equal or higher level (specs/rules-engine.md criterion 8).
///
/// Content is ANY non-whitespace character. A section holding only
/// subheadings, only a table, only an image, or only a code fence is NOT
/// empty (failure mode 4); a heading followed immediately by another heading
/// IS empty. The range covers the heading line (criterion 5).
struct EmptySectionRule: Rule {

    var ruleID: String { "empty-section" }
    var defaultSeverity: DiagnosticSeverity { .warning }

    func evaluate(_ projection: DocumentProjection) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        for node in projection.sections {
            guard let section = projection.range(fromNSRange: node.sectionRange),
                  let headingLine = projection.range(fromNSRange: node.heading.range),
                  headingLine.upperBound <= section.upperBound else { continue }
            let content = projection.text[headingLine.upperBound..<section.upperBound]
            if !content.contains(where: { !$0.isWhitespace }) {
                diagnostics.append(Diagnostic(
                    ruleID: ruleID,
                    severity: defaultSeverity,
                    message: "Section is empty",
                    range: headingLine
                ))
            }
        }
        return diagnostics
    }
}
