import XCTest
@testable import Kitib

/// `PasteHealer.shouldSkipPastePreview` — the short-paste guard.
/// Spec: specs/paste-preview-toggle.md, criterion 7.
final class PastePreviewStateTests: XCTestCase {

    func testShortSingleLineSkipsPreview() {
        let text = String(repeating: "a", count: 80)
        XCTAssertTrue(
            PasteHealer.shouldSkipPastePreview(text),
            "≤80 chars, no newline → should skip preview"
        )
    }

    func testSingleLineWithNewlineDoesNotSkip() {
        let text = "hello\nworld"
        XCTAssertFalse(
            PasteHealer.shouldSkipPastePreview(text),
            "text with a newline, even short, must show preview"
        )
    }

    func testLongSingleLineDoesNotSkip() {
        let text = String(repeating: "b", count: 81)
        XCTAssertFalse(
            PasteHealer.shouldSkipPastePreview(text),
            ">80 chars, even without newline, should show preview"
        )
    }

    func testEmptyStringSkipsPreview() {
        XCTAssertTrue(
            PasteHealer.shouldSkipPastePreview(""),
            "empty string has nothing to heal"
        )
    }

    func testMultilineDoesNotSkip() {
        let text = "a\nb\nc"
        XCTAssertFalse(
            PasteHealer.shouldSkipPastePreview(text),
            "any multiline text should show preview"
        )
    }
}
