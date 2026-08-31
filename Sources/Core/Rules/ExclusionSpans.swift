import Foundation

// MARK: - ExclusionSpans

/// Scans the three exclusion zones the rules engine is authorised to know
/// about (specs/rules-engine.md "The tripwire"): fenced code blocks, inline
/// code spans, and the frontmatter block. This is the ONLY new scanning the
/// engine performs. Everything else comes from the existing Core parsers:
/// OutlineParser (headings, sections), extractWikiLinks (wiki-links),
/// MarkdownTableParser (table ranges).
///
/// Reviewer's test: if a function here starts matching Markdown punctuation
/// outside this list (emphasis, link destinations, list nesting, block quote
/// structure, inline HTML), the tripwire has been crossed. Park the rule and
/// re-raise the swift-markdown RED instead.
enum ExclusionSpans {

    struct Result: Equatable {
        /// Each fenced block, including both fence lines. Unterminated fences
        /// extend to the end of the document (matches OutlineParser's toggle
        /// behaviour).
        var fencedCodeSpans: [Range<String.Index>] = []
        /// Each inline code span, including both backtick runs. A span is
        /// delimited by matching backtick runs of equal length (CommonMark
        /// 6.1), may span lines, and if unclosed runs to the end of its
        /// paragraph.
        var inlineCodeSpans: [Range<String.Index>] = []
        /// The frontmatter block from the document start through the closing
        /// fence line. Nil when the document has no frontmatter.
        var frontmatterRange: Range<String.Index>? = nil
    }

    static func scan(_ text: String) -> Result {
        var result = Result()
        let nsText = text as NSString
        guard nsText.length > 0 else { return result }

        // --- Frontmatter --------------------------------------------------
        // Opens with a "---" line at the very start of the document and
        // closes at the next "---" or "..." line. No closing line means no
        // frontmatter: a lone "---" is a horizontal rule, not metadata.
        var scanFrom = 0
        let firstLineRange = nsText.lineRange(for: NSRange(location: 0, length: 0))
        let firstLine = nsText.substring(with: firstLineRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if firstLine == "---" {
            var offset = NSMaxRange(firstLineRange)
            while offset < nsText.length {
                let lineRange = nsText.lineRange(for: NSRange(location: offset, length: 0))
                let line = nsText.substring(with: lineRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if line == "---" || line == "..." {
                    let end = NSMaxRange(lineRange)
                    result.frontmatterRange = range(fromNSRange: NSRange(location: 0, length: end), in: text)
                    scanFrom = end
                    break
                }
                offset = NSMaxRange(lineRange)
            }
        }

        // --- Fences and inline code spans --------------------------------
        // One pass, three states. Fences take precedence over backticks: a
        // backtick run inside a fence is code content, not a span opener.
        var inFence = false
        var fenceStart = 0
        var codeSpanOpen: Int? = nil   // UTF-16 offset of the opening backtick
        var openRunLength = 0

        var offset = scanFrom
        while offset < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: offset, length: 0))
            let line = nsText.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let runs = backtickRuns(in: line)

            if inFence {
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    if let span = range(fromNSRange:
                            NSRange(location: fenceStart, length: NSMaxRange(lineRange) - fenceStart),
                            in: text) {
                        result.fencedCodeSpans.append(span)
                    }
                    inFence = false
                }
                offset = NSMaxRange(lineRange)
                continue
            }

            if let spanOpen = codeSpanOpen {
                // Looking for the closing run: the first run of exactly
                // `openRunLength` backticks. Runs of other lengths inside
                // the span are literal content.
                var closeIdx: Int? = nil
                for (i, run) in runs.enumerated() where run.length == openRunLength {
                    closeIdx = i
                    break
                }
                if let idx = closeIdx {
                    let end = lineRange.location + runs[idx].end
                    if let span = range(fromNSRange:
                            NSRange(location: spanOpen, length: end - spanOpen), in: text) {
                        result.inlineCodeSpans.append(span)
                    }
                    codeSpanOpen = nil
                    // The span closed mid-line; the remainder of the line is
                    // scanned in normal mode (there may be more spans).
                    scanRuns(Array(runs[(idx + 1)...]),
                             lineLocation: lineRange.location,
                             text: text,
                             result: &result,
                             codeSpanOpen: &codeSpanOpen,
                             openRunLength: &openRunLength)
                } else {
                    if trimmed.isEmpty {
                        // Paragraph boundary: an unclosed code span ends with
                        // its paragraph (CommonMark 6.1).
                        if let span = range(fromNSRange:
                                NSRange(location: spanOpen, length: lineRange.location - spanOpen),
                                in: text) {
                            result.inlineCodeSpans.append(span)
                        }
                        codeSpanOpen = nil
                    }
                }
                offset = NSMaxRange(lineRange)
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence = true
                fenceStart = lineRange.location
                offset = NSMaxRange(lineRange)
                continue
            }

            scanRuns(runs,
                     lineLocation: lineRange.location,
                     text: text,
                     result: &result,
                     codeSpanOpen: &codeSpanOpen,
                     openRunLength: &openRunLength)
            offset = NSMaxRange(lineRange)
        }

        if inFence {
            if let span = range(fromNSRange:
                    NSRange(location: fenceStart, length: nsText.length - fenceStart), in: text) {
                result.fencedCodeSpans.append(span)
            }
        }
        if let spanOpen = codeSpanOpen {
            if let span = range(fromNSRange:
                    NSRange(location: spanOpen, length: nsText.length - spanOpen), in: text) {
                result.inlineCodeSpans.append(span)
            }
        }

        return result
    }

    // MARK: - Line scanning

    /// Scans a line's backtick runs in normal mode: pairs each run with the
    /// next run of equal length (span = both runs plus content between); a
    /// run with no matching close on the line opens a span that continues on
    /// following lines.
    private static func scanRuns(_ runs: [(start: Int, end: Int, length: Int)],
                                 lineLocation: Int,
                                 text: String,
                                 result: inout Result,
                                 codeSpanOpen: inout Int?,
                                 openRunLength: inout Int) {
        var pos = 0
        while pos < runs.count {
            let run = runs[pos]
            var closeIdx = pos + 1
            while closeIdx < runs.count && runs[closeIdx].length != run.length {
                closeIdx += 1
            }
            if closeIdx < runs.count {
                let start = lineLocation + run.start
                let end = lineLocation + runs[closeIdx].end
                if let span = range(fromNSRange: NSRange(location: start, length: end - start), in: text) {
                    result.inlineCodeSpans.append(span)
                }
                pos = closeIdx + 1
            } else {
                codeSpanOpen = lineLocation + run.start
                openRunLength = run.length
                break
            }
        }
    }

    /// Returns every run of one or more backticks in `line`, as UTF-16
    /// offsets relative to the line start. A backtick is U+0060, a single
    /// UTF-16 unit, so code-unit scanning is exact.
    private static func backtickRuns(in line: String) -> [(start: Int, end: Int, length: Int)] {
        var runs: [(start: Int, end: Int, length: Int)] = []
        let units = Array(line.utf16)
        var i = 0
        while i < units.count {
            if units[i] == 0x60 {
                let start = i
                while i < units.count && units[i] == 0x60 { i += 1 }
                runs.append((start, i, i - start))
            } else {
                i += 1
            }
        }
        return runs
    }

    // MARK: - Coordinate conversion

    /// Converts an NSRange (UTF-16 coordinates, the convention of
    /// NSString.lineRange) to a character range into `text`. Returns nil when
    /// the range is not fully within the text.
    private static func range(fromNSRange ns: NSRange, in text: String) -> Range<String.Index>? {
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
