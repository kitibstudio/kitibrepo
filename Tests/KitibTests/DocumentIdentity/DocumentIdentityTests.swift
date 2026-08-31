import XCTest

/// Loads the uuid-injection fixture corpus from disk.
private enum IDCorpus {

    /// Every fixture directory, in order.
    static let names = [
        "01-empty",
        "02-content-no-frontmatter",
        "03-frontmatter-no-id",
        "04-frontmatter-multiple-keys",
        "05-has-valid-uuid",
        "06-has-human-id",
    ]

    /// The test UUID used in every expected.md so golden comparisons are
    /// deterministic. Valid v4: position 14 is '4', position 19 is '8'.
    static let testUUID = "00000000-0000-4000-8000-000000000001"

    static var corpusRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DocumentIdentity
            .deletingLastPathComponent()   // KitibTests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("uuid-injection")
    }

    static func load(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (input: String, expected: String)? {
        let dir = corpusRoot.appendingPathComponent(name)
        let inputURL = dir.appendingPathComponent("input.md")
        let expectedURL = dir.appendingPathComponent("expected.md")
        do {
            return (
                try String(contentsOf: inputURL, encoding: .utf8),
                try String(contentsOf: expectedURL, encoding: .utf8)
            )
        } catch {
            XCTFail(
                "Fixture '\(name)' could not be loaded from \(dir.path): \(error)",
                file: file, line: line
            )
            return nil
        }
    }
}

final class DocumentIdentityTests: XCTestCase {

    // MARK: - Acceptance criteria (fixture-backed)

    /// Criterion 1: missing ID gets one injected.
    /// Criterion 2: no frontmatter at all gets one created.
    /// Criterion 3: existing ID is left untouched.
    /// Criterion 5: non-UUID left alone.
    /// Criterion 8: rest of frontmatter preserved.
    func testEveryFixtureProducesExpectedOutput() {
        for name in IDCorpus.names {
            guard let f = IDCorpus.load(name) else { continue }
            let result = DocumentIdentity.injectID(f.input, uuid: IDCorpus.testUUID)
            XCTAssertEqual(
                result, f.expected,
                "\(name): injectID did not produce expected output"
            )
        }
    }

    // MARK: - Criterion 4: idempotence

    func testInjectIDIsIdempotentAcrossCorpus() {
        for name in IDCorpus.names {
            guard let f = IDCorpus.load(name) else { continue }
            let first = DocumentIdentity.injectID(f.input, uuid: IDCorpus.testUUID)
            let second = DocumentIdentity.injectID(first, uuid: IDCorpus.testUUID)
            XCTAssertEqual(second, first, "\(name): injectID(injectID(x)) != injectID(x)")
        }
    }

    func testInjectIDIsIdempotentForAlreadyHavingAnID() {
        for name in IDCorpus.names {
            guard let f = IDCorpus.load(name) else { continue }
            let once = DocumentIdentity.injectID(f.input, uuid: IDCorpus.testUUID)
            // Run again with a DIFFERENT UUID — must still return the first result.
            let twice = DocumentIdentity.injectID(once, uuid: "different-uuid")
            XCTAssertEqual(twice, once,
                "\(name): second injection with a different UUID changed the document")
        }
    }

    // MARK: - Criterion 6: UUID format

    func testPublicAPIGeneratesValidUUIDv4() {
        let result = DocumentIdentity.injectID("# Test\n")
        let lines = result.components(separatedBy: "\n")
        // Line 1 should be "id: <uuid>"
        XCTAssertTrue(lines.count >= 2)
        let idLine = lines[1]
        XCTAssertTrue(idLine.hasPrefix("id: "))
        let uuidString = String(idLine.dropFirst(4))
        // UUIDv4 check: lowercase hex with dashes, version nibble is '4'.
        let uuidRegex = try! NSRegularExpression(
            pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
        )
        let range = NSRange(uuidString.startIndex..., in: uuidString)
        XCTAssertNotNil(
            uuidRegex.firstMatch(in: uuidString, range: range),
            "Generated UUID is not a valid lowercase v4: \(uuidString)"
        )
    }

    // MARK: - Criterion 7: determinism of the decision

    func testSameInputWithSameUUIDProducesSameOutput() {
        let doc = "---\ntitle: Test\n---\n\nBody.\n"
        let a = DocumentIdentity.injectID(doc, uuid: IDCorpus.testUUID)
        let b = DocumentIdentity.injectID(doc, uuid: IDCorpus.testUUID)
        XCTAssertEqual(a, b)
    }

    // MARK: - Edge cases

    func testEmptyInputGetsFrontmatterOnly() {
        let result = DocumentIdentity.injectID("", uuid: IDCorpus.testUUID)
        XCTAssertEqual(result, "---\nid: \(IDCorpus.testUUID)\n---\n")
    }

    func testFrontmatterWithoutClosingFenceGetsOnePrepended() {
        // A document starting with --- but no closing --- is not valid frontmatter.
        let doc = "---\ntitle: Broken\n\nBody text.\n"
        let result = DocumentIdentity.injectID(doc, uuid: IDCorpus.testUUID)
        XCTAssertTrue(result.hasPrefix("---\nid: \(IDCorpus.testUUID)\n---\n\n---\n"))
    }

    func testWhitespaceBeforeIDKeyIsDetected() {
        let doc = "---\n  id: abc-123\n---\n\nBody.\n"
        let result = DocumentIdentity.injectID(doc, uuid: IDCorpus.testUUID)
        XCTAssertEqual(result, doc, "leading whitespace before id: should be detected")
    }

    func testIDInBodyNotInFrontmatterTriggersInjection() {
        let doc = "---\ntitle: Test\n---\n\nid: some-value\n"
        let result = DocumentIdentity.injectID(doc, uuid: IDCorpus.testUUID)
        XCTAssertTrue(result.contains("id: \(IDCorpus.testUUID)"),
                      "id: in body should not prevent injection")
        XCTAssertTrue(result.contains("\nid: some-value"),
                      "id: in body should survive")
    }

    func testNoFalsePositiveOnDescriptionContainingIDColon() {
        // "description: The id: field is..." — id: appears in the value, not as a key.
        let doc = "---\ndescription: The id: field is important\n---\n\nBody.\n"
        let result = DocumentIdentity.injectID(doc, uuid: IDCorpus.testUUID)
        XCTAssertTrue(result.contains("id: \(IDCorpus.testUUID)"),
                      "id: in a value should not prevent injection")
        XCTAssertTrue(result.contains("description: The id: field is important"),
                      "description line should survive intact")
    }

    func testNonEmptyInputWithoutFrontmatterPreservesContent() {
        let doc = "# Heading\n\nParagraph.\n"
        let result = DocumentIdentity.injectID(doc, uuid: IDCorpus.testUUID)
        XCTAssertTrue(result.hasPrefix("---\nid: \(IDCorpus.testUUID)\n---\n\n"))
        XCTAssertTrue(result.hasSuffix(doc))
    }

    // MARK: - Failure mode 5: no collisions in bulk

    func testNoUUIDCollisionsInTenThousandGenerations() {
        var seen = Set<String>()
        for _ in 0..<10_000 {
            let result = DocumentIdentity.injectID("# Test\n")
            let lines = result.components(separatedBy: "\n")
            let uuidString = String(lines[1].dropFirst(4))
            XCTAssertFalse(seen.contains(uuidString),
                           "UUID collision after \(seen.count) generations")
            seen.insert(uuidString)
        }
    }
}
