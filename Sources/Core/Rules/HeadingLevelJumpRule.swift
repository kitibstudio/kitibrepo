import Foundation

// MARK: - HeadingLevelJumpRule

/// Flags a heading that descends more than one level from the previous
/// heading (`##` then `####`), per specs/rules-engine.md criterion 7.
///
/// The comparison is pairwise against the PREVIOUS heading's level, never a
/// running expectation, so SectionMover-shaped documents are read correctly
/// (failure mode 5). The range covers the offending heading marker only
/// (criterion 5): the `#` run, not the line.
struct HeadingLevelJumpRule: Rule {

    var ruleID: String { "heading-level-jump" }
    var defaultSeverity: DiagnosticSeverity { .warning }

    func evaluate(_ projection: DocumentProjection) -> [Diagnostic] {
        let headings = projection.headings
        guard headings.count >= 2 else { return [] }

        var diagnostics: [Diagnostic] = []
        for i in 1..<headings.count {
            let previousLevel = headings[i - 1].level
            let current = headings[i]
            guard current.level > previousLevel + 1 else { continue }
            // The marker is the heading's own `#` run: `level` characters
            // from the line start, all ASCII.
            guard let marker = projection.range(fromNSRange:
                NSRange(location: current.range.location, length: current.level)) else { continue }
            diagnostics.append(Diagnostic(
                ruleID: ruleID,
                severity: defaultSeverity,
                message: "Heading jumps from level \(previousLevel) to level \(current.level)",
                range: marker
            ))
        }
        return diagnostics
    }
}
