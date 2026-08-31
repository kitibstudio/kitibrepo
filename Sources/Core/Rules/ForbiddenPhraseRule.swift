import Foundation

// MARK: - ForbiddenPhraseRule

/// Flags caller-supplied phrases when they appear in prose
/// (specs/rules-engine.md criterion 10). A phrase never fires inside a
/// fenced code block, inline code, a table's delimiter row, or frontmatter.
///
/// Matching is a literal, case-insensitive substring search (Foundation
/// `range(of:options:)`, no regular expressions). Severity is per phrase,
/// from the caller's tuple; the engine preserves it unless a
/// RuleConfiguration override applies (D81).
///
/// Delimiter rows are computed HERE, not in the projection: the tripwire
/// authorises table RANGES from MarkdownTableParser only, and the delimiter
/// predicate is that parser's private detail. This rule mirrors
/// isDelimiterRow (D82); the fixture corpus keeps the two in sync.
struct ForbiddenPhraseRule: Rule {

    /// One banned phrase with the message and severity attached to it.
    struct Phrase {
        let pattern: String
        let message: String
        let severity: DiagnosticSeverity
    }

    let phrases: [Phrase]

    var ruleID: String { "forbidden-phrase" }
    var defaultSeverity: DiagnosticSeverity { .warning }

    init(phrases: [Phrase]) {
        self.phrases = phrases
    }

    func evaluate(_ projection: DocumentProjection) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        for phrase in phrases where !phrase.pattern.isEmpty {
            var searchRange = projection.text.startIndex..<projection.text.endIndex
            while let found = projection.text.range(of: phrase.pattern,
                                                    options: [.caseInsensitive],
                                                    range: searchRange) {
                if !isExcluded(found, in: projection) {
                    diagnostics.append(Diagnostic(
                        ruleID: ruleID,
                        severity: phrase.severity,
                        message: phrase.message,
                        range: found
                    ))
                }
                searchRange = found.upperBound..<projection.text.endIndex
            }
        }
        return diagnostics
    }

    /// The four exclusion zones of criterion 10. Delimiter rows are the only
    /// one the projection does not carry directly; the others are its spans.
    private func isExcluded(_ range: Range<String.Index>, in projection: DocumentProjection) -> Bool {
        if projection.isInsideFence(range) { return true }
        if projection.isInsideInlineCode(range) { return true }
        if projection.isInsideFrontmatter(range) { return true }
        return isInDelimiterRow(range, in: projection)
    }

    /// A table's delimiter row is structure, not prose. Mirrors
    /// MarkdownTableParser.isDelimiterRow, which is private (D82).
    private func isInDelimiterRow(_ range: Range<String.Index>, in projection: DocumentProjection) -> Bool {
        for table in projection.tableRanges {
            guard table.contains(range.lowerBound), table.contains(range.upperBound) else { continue }
            let line = projection.text.lineRange(for: range.lowerBound..<range.lowerBound)
            if isDelimiterRow(String(projection.text[line])) { return true }
        }
        return false
    }

    private func isDelimiterRow(_ line: String) -> Bool {
        // The line arrives with its trailing newline; trim before pipe
        // stripping, or the trailing-pipe strip never fires.
        var cells = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if cells.hasPrefix("|") { cells.removeFirst() }
        if cells.hasSuffix("|") { cells.removeLast() }
        let parts = cells.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 1 else { return false }
        return parts.allSatisfy { cell in
            guard cell.contains("-") else { return false }
            return cell.allSatisfy { "-: \t".contains($0) }
        }
    }
}
