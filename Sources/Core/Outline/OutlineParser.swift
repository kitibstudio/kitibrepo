import Foundation

// MARK: - OutlineHeading

/// A heading parsed from Markdown text.
struct OutlineHeading: Equatable {
    /// Heading level (1–6, corresponding to # through ######).
    let level: Int
    /// The heading text with the leading #s and trailing #s stripped,
    /// and whitespace trimmed.
    let text: String
    /// 1-indexed line number in the document.
    let lineNumber: Int
    /// Character range of the heading line in the document string (UTF-16).
    let range: NSRange
}

// MARK: - OutlineNode

/// A node in the heading hierarchy tree. Used by the outline UI for
/// indentation and parent-child disclosure.
final class OutlineNode: Identifiable {
    let id: String
    let heading: OutlineHeading
    /// Character range covering the heading line through to (but not including)
    /// the next heading of equal or higher level, or end of document.
    let sectionRange: NSRange
    weak var parent: OutlineNode?
    var children: [OutlineNode] = []

    init(heading: OutlineHeading, sectionRange: NSRange) {
        // ID includes line number so duplicate heading texts (e.g. two
        // "# Summary" sections) don't collide in SwiftUI ForEach. The
        // line number changes after a section move, but heading identity
        // is recomputed from scratch on every text change anyway.
        self.id = "L\(heading.level):\(heading.text):L\(heading.lineNumber)"
        self.heading = heading
        self.sectionRange = sectionRange
    }
}

// MARK: - OutlineParser

/// Parses ATX headings from Markdown text, builds a hierarchy, and computes
/// section boundaries. Pure function — no AppKit/UIKit dependency.
enum OutlineParser {

    // MARK: - Public

    /// Parse all ATX headings from `text`, ignoring any inside fenced code
    /// blocks (```). Returns headings in document order.
    static func parseHeadings(from text: String) -> [OutlineHeading] {
        var headings: [OutlineHeading] = []
        let nsText = text as NSString
        var inFence = false
        var lineNumber = 1
        var offset = 0

        while offset < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: offset, length: 0))
            let line = nsText.substring(with: lineRange)

            // Detect fenced code blocks
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
            } else if !inFence {
                if let heading = parseHeadingLine(line, lineNumber: lineNumber, range: lineRange) {
                    headings.append(heading)
                }
            }

            lineNumber += 1
            offset = NSMaxRange(lineRange)
        }

        return headings
    }

    /// Build a parent-child tree from pre-computed flat nodes (with section
    /// ranges already populated). A heading of level N is a child of the
    /// nearest preceding heading of level < N. Level-1 headings are roots.
    static func buildHierarchy(from flatNodes: [OutlineNode]) -> [OutlineNode] {
        var roots: [OutlineNode] = []
        // Stack of ancestors by level. Index = level (1-indexed, gaps filled by nil).
        var ancestors: [OutlineNode?] = Array(repeating: nil, count: 7)

        for node in flatNodes {
            let level = node.heading.level
            // Pop ancestors at this level or deeper
            for i in level...6 { ancestors[i] = nil }
            // Find nearest ancestor — walk down from level-1 to 1
            var parent: OutlineNode?
            for i in stride(from: level - 1, through: 1, by: -1) {
                if let candidate = ancestors[i] {
                    parent = candidate
                    break
                }
            }
            if let parent {
                node.parent = parent
                parent.children.append(node)
            } else {
                roots.append(node)
            }
            ancestors[level] = node
        }

        return roots
    }

    /// Compute section ranges for every heading and return a flat list of nodes
    /// (in document order) with `sectionRange` populated. The section spans
    /// from the heading line to just before the next heading of equal or higher
    /// level, or end of document.
    static func computeSectionRanges(
        text: String,
        headings: [OutlineHeading]
    ) -> [OutlineNode] {
        let nsText = text as NSString
        var nodes: [OutlineNode] = []

        for (i, heading) in headings.enumerated() {
            let start = heading.range.location
            let end: Int
            if let next = headings.nextHeadingOfEqualOrHigherLevel(from: i) {
                end = next.range.location
            } else {
                end = nsText.length
            }
            let sectionRange = NSRange(location: start, length: end - start)
            nodes.append(OutlineNode(heading: heading, sectionRange: sectionRange))
        }

        return nodes
    }

    /// Full parse: headings → nodes with hierarchy and section ranges.
    static func parse(text: String) -> [OutlineNode] {
        let headings = parseHeadings(from: text)
        let flatNodes = computeSectionRanges(text: text, headings: headings)
        return buildHierarchy(from: flatNodes)
    }

    // MARK: - Private

    /// Try to parse an ATX heading from a single line. Returns nil if the line
    /// is not a heading. Supports optional closing # characters.
    private static func parseHeadingLine(
        _ line: String,
        lineNumber: Int,
        range: NSRange
    ) -> OutlineHeading? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }

        // Count leading #s
        var level = 0
        for ch in trimmed {
            if ch == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        // Require a space after the #s (ATX spec)
        let afterHashes = trimmed.dropFirst(level)
        guard afterHashes.hasPrefix(" ") || afterHashes.hasPrefix("\t") else {
            return nil
        }

        // Extract text: remove leading #s, trailing #s, and trim
        var text = String(afterHashes).trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip trailing # sequences
        while let last = text.last, last == "#" {
            text.removeLast()
            text = text.trimmingCharacters(in: .whitespaces)
        }

        return OutlineHeading(
            level: level,
            text: text,
            lineNumber: lineNumber,
            range: range
        )
    }
}

// MARK: - Helpers

private extension Array where Element == OutlineHeading {
    /// Return the first heading after `index` whose level is ≤ `headings[index].level`.
    func nextHeadingOfEqualOrHigherLevel(from index: Int) -> OutlineHeading? {
        let threshold = self[index].level
        for i in (index + 1)..<count {
            if self[i].level <= threshold { return self[i] }
        }
        return nil
    }
}
