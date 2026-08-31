import Foundation

// MARK: - SectionMover

/// Moves a section (heading + content) within a Markdown document by extracting
/// its text range and reinserting it at the destination. Pure function — no
/// AppKit/UIKit dependency.
enum SectionMover {

    /// Result of a section move.
    struct MoveResult {
        /// The modified document text.
        let text: String
        /// The range where the moved section was inserted (for scroll-to).
        let insertedRange: NSRange
    }

    // MARK: - Public

    /// Move the section headed by `headings[sourceIndex]` so that it appears
    /// just before `headings[destinationIndex]` in the new heading order.
    /// If `destinationIndex == headings.count`, the section is moved to the
    /// end of the document.
    ///
    /// Returns nil when the move would be a no-op (source == destination or
    /// source == destination-1) or when the destination falls inside the
    /// source section's heading span (e.g. moving H1 to before H2 when H2
    /// is inside H1's section).
    static func move(
        text: String,
        headings: [OutlineHeading],
        sourceIndex: Int,
        destinationIndex: Int
    ) -> MoveResult? {
        guard !headings.isEmpty else { return nil }
        guard sourceIndex >= 0, sourceIndex < headings.count else { return nil }
        guard destinationIndex >= 0, destinationIndex <= headings.count else {
            return nil
        }

        // No-op checks
        if destinationIndex == sourceIndex { return nil }
        if destinationIndex == sourceIndex + 1 { return nil }

        let sourceHeading = headings[sourceIndex]

        // Reject: destination falls inside the source section's heading span.
        // Find the first heading after sourceIndex with equal or higher level;
        // the source section covers headings from sourceIndex through to (but
        // not including) that heading.
        if destinationIndex > sourceIndex {
            let sectionEndIdx = headings[sourceIndex...]
                .dropFirst()
                .firstIndex(where: { $0.level <= sourceHeading.level })
                ?? headings.count
            if destinationIndex < sectionEndIdx {
                return nil
            }
        }

        let nsText = text as NSString

        // Compute source section range
        let sourceStart = sourceHeading.range.location
        let sourceEnd: Int
        if let next = nextHeadingOfEqualOrHigherLevel(
            after: sourceIndex, in: headings
        ) {
            sourceEnd = next.range.location
        } else {
            sourceEnd = nsText.length
        }
        let sourceRange = NSRange(location: sourceStart, length: sourceEnd - sourceStart)

        // Compute destination insertion point
        let destInsertion: Int
        if destinationIndex >= headings.count {
            destInsertion = nsText.length
        } else {
            let destHeading = headings[destinationIndex]
            destInsertion = destHeading.range.location
        }

        // Extract the section text and normalise trailing newlines:
        // strip all but at most one trailing \n to avoid dragging blank
        // lines between sections into the new position.
        var sectionText = nsText.substring(with: sourceRange)
        while sectionText.hasSuffix("\n\n") {
            sectionText.removeLast()
        }

        // Build new text: remove the section, then insert at destination.
        let mutableText = NSMutableString(string: text)
        mutableText.deleteCharacters(in: sourceRange)

        let adjustedDest: Int
        if destInsertion > sourceRange.location {
            adjustedDest = destInsertion - sourceRange.length
        } else {
            adjustedDest = destInsertion
        }

        // Ensure the inserted section starts on its own line when the
        // insertion point is mid-text and not already at a line boundary.
        var actualInserted = adjustedDest
        if adjustedDest > 0 {
            let prev = mutableText.substring(
                with: NSRange(location: adjustedDest - 1, length: 1)
            )
            if prev != "\n" {
                sectionText = "\n" + sectionText
            }
        }

        mutableText.insert(sectionText, at: actualInserted)
        let insertedRange = NSRange(location: actualInserted,
                                     length: sectionText.utf16.count)

        return MoveResult(
            text: mutableText as String,
            insertedRange: insertedRange
        )
    }

    // MARK: - Private

    private static func nextHeadingOfEqualOrHigherLevel(
        after index: Int,
        in headings: [OutlineHeading]
    ) -> OutlineHeading? {
        let threshold = headings[index].level
        for i in (index + 1)..<headings.count {
            if headings[i].level <= threshold { return headings[i] }
        }
        return nil
    }
}
