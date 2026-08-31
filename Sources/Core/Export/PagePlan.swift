import Foundation

// MARK: - PageBlock

/// A top-level block of rendered content, measured in the web view's own
/// coordinate space (CSS pixels, top-down, origin at the top of the document).
struct PageBlock: Equatable {
    let top: Double
    let bottom: Double

    init(top: Double, bottom: Double) {
        self.top = top
        self.bottom = bottom
    }
}

// MARK: - PageSlice

/// One printed page, expressed as a window onto the continuous render.
struct PageSlice: Equatable {
    /// Offset of the page's first pixel from the top of the document.
    let top: Double
    /// How much of the document this page shows. Never zero or negative.
    let height: Double
}

// MARK: - PagePlan

/// Decides where a continuously-rendered document is cut into printed pages.
///
/// WebKit's own paginating print view does not terminate on macOS 26 (D71), so
/// Kitib renders the document as one tall page and cuts it here instead. The
/// cuts are chosen so that no top-level block is split across a page boundary —
/// the same intent as the `break-inside: avoid` rules in the print CSS, which
/// only WebKit's pagination honoured.
///
/// Pure arithmetic on measurements taken elsewhere: no WebKit, no AppKit.
enum PagePlan {

    /// Hard ceiling on page count. The defect this file exists to fix produced
    /// an unbounded number of pages, so refusing to plan more than this is a
    /// guard against ever shipping that failure again, in any form.
    static let maxPages = 2000

    /// Page top offsets, in document order, always starting at 0.
    static func pageTops(blocks: [PageBlock],
                         contentHeight: Double,
                         pageHeight: Double) -> [Double] {
        // A zero or negative page height cannot be paginated. One page is the
        // only answer that terminates.
        guard pageHeight > 0, contentHeight > 0 else { return [0] }

        var tops: [Double] = [0]
        var pageTop: Double = 0

        for block in blocks {
            // Zero-height blocks (hidden elements, empty paragraphs) must not
            // open a page of their own.
            guard block.bottom > block.top else { continue }
            // Blocks that sit entirely above the current page top — which
            // absolutely-positioned content such as an equation number can do —
            // must never pull a cut backwards.
            guard block.bottom > pageTop else { continue }
            // Fits on the page being filled.
            guard block.bottom - pageTop > pageHeight else { continue }

            // The block would straddle the boundary: move it whole to the top
            // of a fresh page.
            if block.top > pageTop {
                pageTop = block.top
                tops.append(pageTop)
            }

            // Still overflowing means the block is taller than a page on its
            // own — an oversized image or a long code fence. Nothing can keep
            // it intact, so cut it at fixed intervals. This loop advances
            // pageTop by a positive amount every pass, so it terminates.
            while block.bottom - pageTop > pageHeight {
                pageTop += pageHeight
                tops.append(pageTop)
                if tops.count >= maxPages { return clamp(tops, to: contentHeight) }
            }
        }

        return clamp(tops, to: contentHeight)
    }

    /// The pages themselves, each with the height of content it shows.
    ///
    /// A page STOPS where the next one starts. It does not run on for a full
    /// page height: when a block is moved down to avoid splitting it, the page
    /// above it ends early and the remaining space is left blank. Filling that
    /// space would print the moved block twice — once cut off at the foot of
    /// one page and again whole at the head of the next.
    static func pages(blocks: [PageBlock],
                      contentHeight: Double,
                      pageHeight: Double) -> [PageSlice] {
        guard pageHeight > 0, contentHeight > 0 else {
            return [PageSlice(top: 0, height: max(contentHeight, 1))]
        }
        let tops = pageTops(blocks: blocks,
                            contentHeight: contentHeight,
                            pageHeight: pageHeight)
        return tops.enumerated().map { index, top in
            let end = index + 1 < tops.count ? tops[index + 1] : contentHeight
            return PageSlice(top: top, height: min(end - top, pageHeight))
        }
    }

    /// Drops any cut that lands at or past the end of the document — such a
    /// page would be blank. The first page always survives.
    private static func clamp(_ tops: [Double], to contentHeight: Double) -> [Double] {
        let kept = tops.filter { $0 < contentHeight }
        return kept.isEmpty ? [0] : kept
    }
}
