import XCTest

// MARK: - Failure-mode tests
//
// The defect these guard against (D71) is not a wrong page break — it is a
// print operation that never terminates and writes an unbounded PDF. Every
// test here therefore asserts termination and bounded output first, and
// correct break placement second.

final class PagePlanFailureModeTests: XCTestCase {

    /// Blocks of a uniform height, laid end to end.
    private func stack(count: Int, height: Double, from origin: Double = 0) -> [PageBlock] {
        (0..<count).map {
            PageBlock(top: origin + Double($0) * height,
                      bottom: origin + Double($0 + 1) * height)
        }
    }

    // MARK: Termination

    /// A block taller than a whole page cannot be kept intact. It must still
    /// terminate, advancing on every cut — this is the shape of the runaway.
    func testBlockTallerThanAPageTerminates() {
        let blocks = [PageBlock(top: 0, bottom: 5000)]
        let tops = PagePlan.pageTops(blocks: blocks, contentHeight: 5000, pageHeight: 692)

        XCTAssertEqual(tops.count, 8, "5000pt of unbreakable content over 692pt pages")
        XCTAssertEqual(tops.first, 0)
        for i in 1..<tops.count {
            XCTAssertGreaterThan(tops[i], tops[i - 1], "Every cut must advance")
        }
    }

    /// A page height of zero must not divide, loop, or plan a second page.
    func testZeroPageHeightYieldsOnePage() {
        let tops = PagePlan.pageTops(blocks: stack(count: 10, height: 100),
                                     contentHeight: 1000, pageHeight: 0)
        XCTAssertEqual(tops, [0])
    }

    /// Negative geometry is nonsense, but it must not be unbounded nonsense.
    func testNegativePageHeightYieldsOnePage() {
        let tops = PagePlan.pageTops(blocks: stack(count: 10, height: 100),
                                     contentHeight: 1000, pageHeight: -692)
        XCTAssertEqual(tops, [0])
    }

    /// Pathological input must hit the ceiling rather than plan forever.
    func testPageCountIsCapped() {
        let blocks = [PageBlock(top: 0, bottom: 10_000_000)]
        let tops = PagePlan.pageTops(blocks: blocks,
                                     contentHeight: 10_000_000, pageHeight: 1)
        XCTAssertLessThanOrEqual(tops.count, PagePlan.maxPages)
    }

    // MARK: Degenerate documents

    func testEmptyDocumentIsOnePage() {
        XCTAssertEqual(PagePlan.pageTops(blocks: [], contentHeight: 0, pageHeight: 692), [0])
    }

    func testNoBlocksStillYieldsOnePage() {
        XCTAssertEqual(PagePlan.pageTops(blocks: [], contentHeight: 300, pageHeight: 692), [0])
    }

    func testContentShorterThanOnePageIsOnePage() {
        let tops = PagePlan.pageTops(blocks: stack(count: 3, height: 100),
                                     contentHeight: 300, pageHeight: 692)
        XCTAssertEqual(tops, [0])
    }

    /// Content exactly one page tall must not spill onto a blank second page.
    func testContentExactlyOnePageTallIsOnePage() {
        let tops = PagePlan.pageTops(blocks: [PageBlock(top: 0, bottom: 692)],
                                     contentHeight: 692, pageHeight: 692)
        XCTAssertEqual(tops, [0])
    }

    // MARK: Blocks that must not disturb the plan

    /// Hidden or empty elements measure zero. They must not open a page.
    func testZeroHeightBlocksDoNotCreatePages() {
        let blocks = [PageBlock(top: 0, bottom: 100),
                      PageBlock(top: 100, bottom: 100),
                      PageBlock(top: 100, bottom: 200)]
        XCTAssertEqual(PagePlan.pageTops(blocks: blocks, contentHeight: 200, pageHeight: 692), [0])
    }

    /// Absolutely-positioned content (an equation number) can be measured out
    /// of document order. A cut must never move backwards.
    func testOutOfOrderBlocksNeverCutBackwards() {
        var blocks = stack(count: 20, height: 100)
        blocks.append(PageBlock(top: 50, bottom: 70))     // out of order, early
        let tops = PagePlan.pageTops(blocks: blocks, contentHeight: 2000, pageHeight: 692)

        for i in 1..<tops.count {
            XCTAssertGreaterThan(tops[i], tops[i - 1], "Cuts must increase strictly")
        }
    }

    /// No cut may land at or past the end of the document — that is a blank page.
    func testNoCutLandsPastTheEnd() {
        let tops = PagePlan.pageTops(blocks: stack(count: 20, height: 100),
                                     contentHeight: 2000, pageHeight: 692)
        for top in tops {
            XCTAssertLessThan(top, 2000, "A page starting at or past the end is blank")
        }
    }

    // MARK: Break placement

    /// The point of the whole exercise: a block that would straddle a boundary
    /// moves whole to the next page.
    func testStraddlingBlockMovesWholeToNextPage() {
        // 100pt blocks on a 692pt page. The block at 600–700 is the first that
        // will not fit, so the second page starts at 600 rather than at 692.
        let blocks = stack(count: 8, height: 100)
        let tops = PagePlan.pageTops(blocks: blocks, contentHeight: 800, pageHeight: 692)

        XCTAssertEqual(tops, [0, 600], "Page 2 starts at the top of the block that did not fit")
    }

    /// A page ends where the next one starts. Running it on for a full page
    /// height prints the block that was moved down twice — cut off at the foot
    /// of one page and whole at the head of the next.
    func testPageStopsWhereTheNextPageStarts() {
        let pages = PagePlan.pages(blocks: stack(count: 8, height: 100),
                                   contentHeight: 800, pageHeight: 692)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].height, 600, accuracy: 0.001,
                       "Ends at the top of the block that did not fit, not at 692")
        XCTAssertEqual(pages[1].height, 200, accuracy: 0.001, "800 − 600")
    }

    /// No two pages may show the same content.
    func testPagesDoNotOverlap() {
        let pages = PagePlan.pages(blocks: stack(count: 37, height: 73),
                                   contentHeight: 37 * 73, pageHeight: 692)
        for i in 1..<pages.count {
            let previousEnd = pages[i - 1].top + pages[i - 1].height
            XCTAssertEqual(pages[i].top, previousEnd, accuracy: 0.001,
                           "Page \(i + 1) repeats content already printed on page \(i)")
        }
    }

    /// A page may never show more than the paper can hold.
    func testNoPageIsTallerThanThePage() {
        let pages = PagePlan.pages(blocks: stack(count: 37, height: 73),
                                   contentHeight: 37 * 73, pageHeight: 692)
        for page in pages {
            XCTAssertLessThanOrEqual(page.height, 692)
        }
    }

    /// Every planned page must show something.
    func testEveryPageHasPositiveHeight() {
        let total: Double = 37 * 73
        let pages = PagePlan.pages(blocks: stack(count: 37, height: 73),
                                   contentHeight: total, pageHeight: 692)
        XCTAssertFalse(pages.isEmpty)
        for page in pages {
            XCTAssertGreaterThan(page.height, 0)
        }
    }

    /// Pages must cover the document without gaps: each page starts where the
    /// previous one ended, or earlier — never after, which would drop content.
    func testPagesLeaveNoGapInTheDocument() {
        let total: Double = 37 * 73
        let pages = PagePlan.pages(blocks: stack(count: 37, height: 73),
                                   contentHeight: total, pageHeight: 692)
        for i in 1..<pages.count {
            let previousEnd = pages[i - 1].top + pages[i - 1].height
            XCTAssertLessThanOrEqual(pages[i].top, previousEnd,
                                     "Content between two pages would be lost")
        }
        let last = pages[pages.count - 1]
        XCTAssertEqual(last.top + last.height, total, accuracy: 0.001,
                       "The final page must reach the end of the document")
    }
}
