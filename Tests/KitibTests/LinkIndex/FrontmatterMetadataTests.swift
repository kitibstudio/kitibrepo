import XCTest

/// Tests for the frontmatter title/aliases extractor that feeds the link
/// index (specs/problems-panel.md criterion 5, failure mode 5). Block
/// detection mirrors ExclusionSpans: a "---" first line, closed by a "---"
/// or "..." line; no closer means no frontmatter. Keys must start at column
/// 0; indented keys are body text, not metadata.
final class FrontmatterMetadataTests: XCTestCase {

    func testNoFrontmatterReturnsNil() {
        XCTAssertNil(FrontmatterMetadata.extract(from: ""))
        XCTAssertNil(FrontmatterMetadata.extract(from: "# Title\n\nBody.\n"))
    }

    func testTitleOnly() {
        let meta = FrontmatterMetadata.extract(from: "---\ntitle: Design Note\n---\n# Body\n")
        XCTAssertEqual(meta?.title, "Design Note")
        XCTAssertEqual(meta?.aliases, [])
    }

    func testTitleAndFlowAliases() {
        let meta = FrontmatterMetadata.extract(from: "---\ntitle: Report\naliases: [draft, rev]\n---\nBody\n")
        XCTAssertEqual(meta?.title, "Report")
        XCTAssertEqual(meta?.aliases, ["draft", "rev"])
    }

    func testBlockAliases() {
        let text = "---\ntitle: Report\naliases:\n  - draft\n  - rev\n---\nBody\n"
        let meta = FrontmatterMetadata.extract(from: text)
        XCTAssertEqual(meta?.title, "Report")
        XCTAssertEqual(meta?.aliases, ["draft", "rev"])
    }

    func testMissingTitle() {
        let meta = FrontmatterMetadata.extract(from: "---\naliases: [x]\n---\nBody\n")
        XCTAssertNil(meta?.title)
        XCTAssertEqual(meta?.aliases, ["x"])
    }

    /// A bare "title:" is a YAML null, not an empty string.
    func testEmptyTitleValueIsNil() {
        XCTAssertNil(FrontmatterMetadata.extract(from: "---\ntitle:\n---\nBody\n")?.title)
    }

    func testQuotedTitleUnquoted() {
        let double = FrontmatterMetadata.extract(from: "---\ntitle: \"Draft: Part 1\"\n---\n")
        XCTAssertEqual(double?.title, "Draft: Part 1")
        let single = FrontmatterMetadata.extract(from: "---\ntitle: 'Notes'\n---\n")
        XCTAssertEqual(single?.title, "Notes")
    }

    /// Failure mode 5: a colon in the value is part of the value; the key
    /// split is on the FIRST colon only.
    func testColonInsideTitleValue() {
        let meta = FrontmatterMetadata.extract(from: "---\ntitle: Design Note: Rev B\n---\n")
        XCTAssertEqual(meta?.title, "Design Note: Rev B")
    }

    /// Failure mode 5: an unclosed opener is a horizontal rule, not
    /// metadata (mirrors ExclusionSpans).
    func testUnclosedOpenerReturnsNil() {
        XCTAssertNil(FrontmatterMetadata.extract(from: "---\ntitle: Draft\n"))
    }

    func testDotsCloserAccepted() {
        let meta = FrontmatterMetadata.extract(from: "---\ntitle: Notes\n...\nBody\n")
        XCTAssertEqual(meta?.title, "Notes")
    }

    /// A "---" in the body is a horizontal rule, not an opener.
    func testFrontmatterNotAtDocumentStartIsIgnored() {
        let text = "# Title\n\n---\ntitle: Not Metadata\n---\n"
        XCTAssertNil(FrontmatterMetadata.extract(from: text))
    }

    /// Failure mode 5: an indented key belongs to a nested mapping, which
    /// the extractor does not model; it is ignored, not misread.
    func testIndentedKeyIgnored() {
        XCTAssertNil(FrontmatterMetadata.extract(from: "---\n  title: Indented\n---\n")?.title)
    }

    /// Failure mode 5: a key that merely CONTAINS "title:" is not the key.
    func testSubstringKeyIgnored() {
        let meta = FrontmatterMetadata.extract(from: "---\ndescription: title: x\n---\n")
        XCTAssertNil(meta?.title)
    }

    func testCRLFLineEndings() {
        let meta = FrontmatterMetadata.extract(from: "---\r\ntitle: Report\r\naliases: [a]\r\n---\r\nBody\r\n")
        XCTAssertEqual(meta?.title, "Report")
        XCTAssertEqual(meta?.aliases, ["a"])
    }

    /// A frontmatter block with no keys is valid frontmatter, not nil.
    func testEmptyFrontmatterBlockIsValid() {
        let meta = FrontmatterMetadata.extract(from: "---\n---\nBody\n")
        XCTAssertNotNil(meta)
        XCTAssertNil(meta?.title)
        XCTAssertEqual(meta?.aliases, [])
    }

    func testQuotedAliasItems() {
        let meta = FrontmatterMetadata.extract(from: "---\naliases: ['a b', \"c\"]\n---\n")
        XCTAssertEqual(meta?.aliases, ["a b", "c"])
    }
}
