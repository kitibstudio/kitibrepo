import Foundation

// MARK: - DocumentProjection

/// The spine of the rules engine (specs/rules-engine.md "Intent, stated as an
/// architecture"). Built ONCE from the four authorised sources; every rule
/// reads this one structure and never re-scans the raw text (criterion 6).
///
/// The projection may be assembled ONLY from (spec "The tripwire"):
///   - OutlineParser: headings and section ranges
///   - extractWikiLinks: wiki-links, already fence- and backtick-aware
///   - MarkdownTableParser: table ranges
///   - ExclusionSpans: fenced code, inline backticks, frontmatter
/// A need for any other syntax is the signal that the swift-markdown AST is
/// required: park the rule, raise the Open RED, do not grow a scanner.
struct DocumentProjection {

    /// The raw document text. Diagnostics range into it.
    let text: String
    /// The caller-supplied link index. Nil means "no index supplied", which
    /// is NOT the same as "the index says no"; rules must distinguish them
    /// (failure mode 6). The distinction is carried here as an Optional.
    let linkIndex: LinkIndex?
    /// ATX headings in document order, fence-aware (OutlineParser).
    let headings: [OutlineHeading]
    /// Flat heading nodes with section ranges, in document order
    /// (OutlineParser.computeSectionRanges).
    let sections: [OutlineNode]
    /// Every `[[target]]` span outside fences and inline backticks, in
    /// document order (extractWikiLinks).
    let wikiLinks: [(range: Range<String.Index>, target: String)]
    /// Every Markdown pipe table range, in document order
    /// (MarkdownTableParser.findTableRange, probed per line).
    let tableRanges: [Range<String.Index>]
    /// Every fenced code block, including both fence lines.
    let fencedCodeSpans: [Range<String.Index>]
    /// Every inline code span, including both backtick runs.
    let inlineCodeSpans: [Range<String.Index>]
    /// The frontmatter block, or nil when the document has none.
    let frontmatterRange: Range<String.Index>?

    /// Runs every authorised parser once and assembles the projection.
    static func build(from text: String, linkIndex: LinkIndex?) -> DocumentProjection {
        let headings = OutlineParser.parseHeadings(from: text)
        let sections = OutlineParser.computeSectionRanges(text: text, headings: headings)
        let exclusion = ExclusionSpans.scan(text)

        return DocumentProjection(
            text: text,
            linkIndex: linkIndex,
            headings: headings,
            sections: sections,
            wikiLinks: extractWikiLinks(text),
            tableRanges: Self.enumerateTableRanges(in: text),
            fencedCodeSpans: exclusion.fencedCodeSpans,
            inlineCodeSpans: exclusion.inlineCodeSpans,
            frontmatterRange: exclusion.frontmatterRange
        )
    }

    /// Converts an NSRange (UTF-16 coordinates, as used by OutlineParser and
    /// MarkdownTableParser) to a character range into `text`. Returns nil
    /// when the range is not fully within the text. Rules use this to build
    /// diagnostic ranges from the projection's heading and section ranges.
    func range(fromNSRange ns: NSRange) -> Range<String.Index>? {
        Self.range(fromNSRange: ns, in: text)
    }

    /// Whether `range` lies entirely inside a fenced code block.
    func isInsideFence(_ range: Range<String.Index>) -> Bool {
        fencedCodeSpans.contains { span in
            span.lowerBound <= range.lowerBound && range.upperBound <= span.upperBound
        }
    }

    /// Whether `range` lies entirely inside an inline code span.
    func isInsideInlineCode(_ range: Range<String.Index>) -> Bool {
        inlineCodeSpans.contains { span in
            span.lowerBound <= range.lowerBound && range.upperBound <= span.upperBound
        }
    }

    /// Whether `range` lies entirely inside the frontmatter block.
    func isInsideFrontmatter(_ range: Range<String.Index>) -> Bool {
        guard let frontmatter = frontmatterRange else { return false }
        return frontmatter.lowerBound <= range.lowerBound && range.upperBound <= frontmatter.upperBound
    }

    // MARK: - Assembly helpers

    /// Enumerates every table range via MarkdownTableParser.findTableRange,
    /// probing at each pipe-bearing line start.
    ///
    /// The containment re-check exists because findTableRange walks UP to the
    /// nearest delimiter row and can return a table that sits ABOVE the probe
    /// line when the probe line is separated from it by a blank line; for
    /// example the header line of a second table probing back into the first.
    /// A candidate that does not contain the probe line is a table already
    /// reported, so it is skipped rather than trusted.
    private static func enumerateTableRanges(in text: String) -> [Range<String.Index>] {
        let nsText = text as NSString
        var ranges: [NSRange] = []
        var offset = 0
        while offset < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: offset, length: 0))
            let line = nsText.substring(with: lineRange)
            if line.contains("|"),
               let candidate = MarkdownTableParser.findTableRange(in: text, cursorPosition: offset),
               NSLocationInRange(offset, candidate),
               !ranges.contains(candidate) {
                ranges.append(candidate)
            }
            offset = NSMaxRange(lineRange)
        }
        return ranges.compactMap { range(fromNSRange: $0, in: text) }
    }

    static func range(fromNSRange ns: NSRange, in text: String) -> Range<String.Index>? {
        let utf16Count = text.utf16.count
        guard ns.location != NSNotFound,
              ns.location >= 0, ns.length >= 0,
              ns.location <= utf16Count,
              ns.location + ns.length <= utf16Count else { return nil }
        let start = String.Index(utf16Offset: ns.location, in: text)
        let end = String.Index(utf16Offset: ns.location + ns.length, in: text)
        return start..<end
    }
}
