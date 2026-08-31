import Foundation

// MARK: - BrokenWikiLinkRule

/// Flags a `[[wiki-link]]` that the LinkIndex cannot resolve
/// (specs/rules-engine.md criterion 9). The only error-severity rule in the
/// spec (failure mode 9).
///
/// Failure mode 6: with NO index supplied the rule emits nothing. "Index says
/// no" (an index exists but resolution fails) and "no index supplied" (nil)
/// are different states, carried by the projection's Optional linkIndex.
///
/// Fence and backtick exclusion is inherited from extractWikiLinks, the sole
/// authority: this rule reads projection.wikiLinks and never re-scans the
/// text for link syntax.
struct BrokenWikiLinkRule: Rule {

    var ruleID: String { "broken-wiki-link" }
    var defaultSeverity: DiagnosticSeverity { .error }

    func evaluate(_ projection: DocumentProjection) -> [Diagnostic] {
        guard let index = projection.linkIndex else { return [] }
        return projection.wikiLinks.compactMap { link in
            guard index.resolve(link.target) == nil else { return nil }
            return Diagnostic(
                ruleID: ruleID,
                severity: defaultSeverity,
                message: "Broken wiki-link: [[\(link.target)]]",
                range: link.range
            )
        }
    }
}
