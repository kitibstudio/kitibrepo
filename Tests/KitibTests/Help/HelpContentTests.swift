import XCTest

/// Invariants on the help *content* itself.
///
/// Help text is the one part of the app that is believed on sight and checked by
/// nobody. `Sources/Shared` is outside this bundle (D16), so if the content
/// lived in the view none of this could be asserted at all — which is how the
/// smart folder advice stayed wrong long enough to ship (D64).
final class HelpContentTests: XCTestCase {

    // MARK: - Structure

    func testEveryIDIsUnique() {
        let ids = HelpContent.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate help entry id")
    }

    func testNoEntryIsEmpty() {
        for entry in HelpContent.all {
            XCTAssertFalse(entry.title.trimmingCharacters(in: .whitespaces).isEmpty, "\(entry.id) has no title")
            XCTAssertFalse(entry.summary.trimmingCharacters(in: .whitespaces).isEmpty, "\(entry.id) has no summary")
        }
    }

    func testEveryLaneHasContent() {
        for lane in HelpLane.allCases {
            XCTAssertFalse(HelpContent.entries(in: lane).isEmpty, "\(lane.rawValue) is empty")
        }
    }

    // MARK: - Criterion 3: a syntax entry without an example is not help

    func testEveryCheatsheetEntryCarriesAnExample() {
        for entry in HelpContent.entries(in: .cheatsheet) {
            guard let example = entry.example else {
                return XCTFail("cheatsheet entry \(entry.id) ships without an example")
            }
            XCTAssertFalse(example.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "\(entry.id) has an empty example")
        }
    }

    func testEveryShortcutCarriesKeys() {
        for entry in HelpContent.entries(in: .shortcuts) {
            XCTAssertNotNil(entry.shortcut, "shortcut entry \(entry.id) has no key combination")
        }
    }

    func testEveryGuideIsActuallyAWalkthrough() {
        for entry in HelpContent.entries(in: .guides) {
            XCTAssertGreaterThanOrEqual(entry.steps.count, 2,
                                        "guide \(entry.id) has \(entry.steps.count) step(s) — that is a tip, not a guide")
        }
    }

    // MARK: - Criterion 4: the non-obvious features are the ones that need guides

    func testGuidesCoverEveryFeatureAReaderWouldNotGuess() {
        let required = [
            "guide.paste-healing",
            "guide.smart-folders",
            "guide.reorder",
            "guide.numbering",
            "guide.diagram",
            "guide.tables",
            "guide.formulas",
            "guide.export",
        ]
        let present = Set(HelpContent.entries(in: .guides).map(\.id))
        for id in required {
            XCTAssertTrue(present.contains(id), "no guide for \(id)")
        }
    }

    func testGuideTitlesAreWrittenAsTheReadersProblem() {
        // A reader searches for their situation, not for the name of the feature
        // that fixes it. Titles that open with "I" enforce that framing.
        for entry in HelpContent.entries(in: .guides) {
            XCTAssertTrue(entry.title.hasPrefix("I "),
                          "guide \(entry.id) is titled from the app's point of view, not the reader's: \(entry.title)")
        }
    }

    // MARK: - D64: guidance that contradicts the implementation

    /// The shipped help said a hyphenated smart folder query "finds nothing".
    /// Measured against FTS5 it raises an error, and quoting fixes it — the
    /// advice was wrong in both halves.
    func testSmartFolderGuidanceMatchesWhatFTS5ActuallyDoes() {
        guard let guide = HelpContent.all.first(where: { $0.id == "guide.smart-folders" }) else {
            return XCTFail("the smart folder guide is missing")
        }
        let text = HelpSearch.fold(guide.bodyText)

        XCTAssertTrue(text.contains("quot"),
                      "the guide must tell the reader to quote a hyphenated term — that is the fix")
        XCTAssertTrue(text.contains("malformed") || text.contains("error") || text.contains("rejected"),
                      "the guide must say a bare hyphen is an error, not a silent miss")
    }

    func testNoEntryRepeatsTheRetractedAdvice() {
        let retracted = ["finds nothing", "returns nothing", "use single words rather than hyphenated"]
        for entry in HelpContent.all {
            let text = HelpSearch.fold(entry.title + "\n" + entry.bodyText)
            for phrase in retracted {
                XCTAssertFalse(text.contains(HelpSearch.fold(phrase)),
                               "\(entry.id) repeats advice retracted by D64: “\(phrase)”")
            }
        }
    }

    // MARK: - D63: examples belong to the reader's work, not the author's

    func testExamplesStayInTheRegisterOfAWritingApp() {
        // Not a style preference. Domain examples told every reader who is not an
        // electrical engineer that this tool is not for them.
        let authorDomain = [
            "cable schedule", "voltage drop", "earth-fault", "earth fault",
            "busbar", "switchgear", "single-line diagram", "load schedule",
            "short-circuit", "transformer rating",
        ]
        for entry in HelpContent.all {
            let text = HelpSearch.fold(entry.title + "\n" + entry.bodyText + "\n" + entry.keywords.joined(separator: " "))
            for term in authorDomain {
                XCTAssertFalse(text.contains(HelpSearch.fold(term)),
                               "\(entry.id) uses an author-domain example: “\(term)” (D63)")
            }
        }
    }

    // MARK: - Examples must be valid for THIS renderer

    /// `ExporterCore.inline` matches `*italic*` only. Underscore emphasis is
    /// left as typed — so an example using it would render as literal
    /// underscores while claiming to be italics.
    func testNoExampleClaimsUnderscoreEmphasis() {
        for entry in HelpContent.all {
            guard let code = entry.example?.code else { continue }
            // A lone _word_ pattern outside a maths span would be a false promise.
            let looksLikeUnderscoreItalics = code.range(
                of: "(?<![\\w$\\\\])_[A-Za-z][A-Za-z ]*_(?![\\w$])",
                options: .regularExpression
            )
            XCTAssertNil(looksLikeUnderscoreItalics,
                         "\(entry.id) shows _underscore_ emphasis, which this renderer does not support")
        }
    }

    /// A table without the dashed separator line is not a table here — the pipes
    /// stay as text. Any example that draws a table must include it.
    func testTableExamplesIncludeTheSeparatorRow() {
        for entry in HelpContent.all {
            guard let code = entry.example?.code else { continue }
            let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard let headerIndex = lines.firstIndex(where: { $0.contains("|") && !$0.contains("---") }),
                  lines[headerIndex].filter({ $0 == "|" }).count >= 2 else { continue }
            // Only applies when the pipes are being shown as a table, which the
            // table entries are; a prose line containing a pipe has no header shape.
            guard entry.id.contains("table") else { continue }
            XCTAssertTrue(headerIndex + 1 < lines.count && isSeparator(lines[headerIndex + 1]),
                          "\(entry.id) shows a table with no | --- | row, which does not render as a table")
        }
    }

    private func isSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|"), trimmed.contains("-") else { return false }
        return trimmed.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
    }

    /// Fenced examples must close. An unbalanced fence copied into a document
    /// swallows the rest of it.
    func testFencedExamplesAreBalanced() {
        for entry in HelpContent.all {
            guard let code = entry.example?.code else { continue }
            let fences = code.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
                .count
            XCTAssertEqual(fences % 2, 0, "\(entry.id) has an unclosed ``` fence")
        }
    }

    /// Same for display maths: `$$` opens and closes.
    func testDisplayMathExamplesAreBalanced() {
        for entry in HelpContent.all {
            guard let code = entry.example?.code else { continue }
            let markers = code.components(separatedBy: "$$").count - 1
            XCTAssertEqual(markers % 2, 0, "\(entry.id) has an unbalanced $$ block")
        }
    }
}
