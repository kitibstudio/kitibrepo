import XCTest

/// Tests for the two navigation helpers the Problems panel uses to jump to a
/// finding (specs/problems-panel.md criterion 3, failure mode 2): the UTF-16
/// NSRange conversion and the 1-based line number. The panel itself is
/// D16-untestable; these are the parts that can be pinned.
final class DiagnosticNavigationTests: XCTestCase {

    func makeDiagnostic(_ range: Range<String.Index>,
                        ruleID: String = "test-rule") -> Diagnostic {
        Diagnostic(ruleID: ruleID, severity: .warning, message: "hit", range: range)
    }

    func testNSRangeRoundTripsOnASCII() {
        let text = "# Title\n\nBody text here.\n"
        let range = text.range(of: "text here")!
        let ns = makeDiagnostic(range).nsRange(in: text)
        XCTAssertEqual(ns, NSRange(location: 14, length: 9))
        XCTAssertEqual((text as NSString).substring(with: ns!), "text here")
    }

    /// Failure mode 2: an emoji before the range is TWO UTF-16 units; the
    /// conversion must land on the exact substring, not one character over.
    func testNSRangeWithEmojiPrefix() {
        let text = "Emoji 🎉 text"
        let range = text.range(of: "text")!
        let ns = makeDiagnostic(range).nsRange(in: text)
        // "Emoji" = 5 units, space = 1, 🎉 = 2, space = 1 -> offset 9.
        XCTAssertEqual(ns, NSRange(location: 9, length: 4))
        XCTAssertEqual((text as NSString).substring(with: ns!), "text")
    }

    func testNSRangeAtDocumentStart() {
        let text = "abc"
        let range = text.startIndex..<text.index(text.startIndex, offsetBy: 2)
        XCTAssertEqual(makeDiagnostic(range).nsRange(in: text),
                       NSRange(location: 0, length: 2))
    }

    func testNSRangeAtDocumentEnd() {
        let text = "abc"
        let range = text.index(text.startIndex, offsetBy: 1)..<text.endIndex
        XCTAssertEqual(makeDiagnostic(range).nsRange(in: text),
                       NSRange(location: 1, length: 2))
    }

    /// The stale-range case the bounds guard can actually catch: a range
    /// built from a LONGER text, converted against a SHORTER one, must
    /// yield nil rather than a coordinate the editor would scroll to.
    /// (Index comparison is numeric and cannot trap, so this is safe; a
    /// foreign range that compares within bounds is not detectable in this
    /// stdlib, since `utf16Offset(in:)` and `UTF16View.distance` both trap
    /// on it, which is why the helper's contract is "pass the range's own
    /// string".)
    func testStaleLongerRangeAgainstShorterTextReturnsNil() {
        let foreign = "a much longer document here"
        let range = foreign.range(of: "much longer")!
        XCTAssertNil(makeDiagnostic(range).nsRange(in: "short"))
    }

    /// Failure mode 2, the other direction: a multi-byte character INSIDE
    /// the range. The conversion must land on the exact substring.
    func testNSRangeSpanningEmoji() {
        let text = "start 🎉 end"
        let range = text.range(of: "🎉 end")!
        // "start " = 6 units, 🎉 = 2, " end" = 4 -> NSRange(6, 6).
        let ns = makeDiagnostic(range).nsRange(in: text)
        XCTAssertEqual(ns, NSRange(location: 6, length: 6))
        XCTAssertEqual((text as NSString).substring(with: ns!), "🎉 end")
    }

    /// A range ending exactly at endIndex when the document ends with a
    /// two-unit character: the upper bound must convert to the full UTF-16
    /// count.
    func testNSRangeEndingAtEmojiEndIndex() {
        let text = "abc🎉"
        let range = text.index(text.startIndex, offsetBy: 1)..<text.endIndex
        XCTAssertEqual(makeDiagnostic(range).nsRange(in: text),
                       NSRange(location: 1, length: 4))
    }

    func testLineNumberIsOneBased() {
        let text = "first\nsecond\nthird\nfourth"
        XCTAssertEqual(makeDiagnostic(text.range(of: "first")!).lineNumber(in: text), 1)
        XCTAssertEqual(makeDiagnostic(text.range(of: "second")!).lineNumber(in: text), 2)
        XCTAssertEqual(makeDiagnostic(text.range(of: "third")!).lineNumber(in: text), 3)
        XCTAssertEqual(makeDiagnostic(text.range(of: "fourth")!).lineNumber(in: text), 4)
    }

    func testLineNumberOfRangeStartingMidLine() {
        let text = "first\nsecond\nthird"
        let range = text.range(of: "nd")! // inside "second"
        XCTAssertEqual(makeDiagnostic(range).lineNumber(in: text), 2)
    }

    func testLineNumberWithCRLF() {
        let text = "a\r\nb\r\nc"
        XCTAssertEqual(makeDiagnostic(text.range(of: "c")!).lineNumber(in: text), 3)
    }

    /// A range at the very start of a single-line document is line 1.
    func testLineNumberAtDocumentStart() {
        let text = "solo line"
        let range = text.startIndex..<text.index(text.startIndex, offsetBy: 2)
        XCTAssertEqual(makeDiagnostic(range).lineNumber(in: text), 1)
    }
}
