import XCTest

/// Interactive REPL for Core functions. Edit the `input` strings below, then
/// run individual tests with:
///
///     xcodebuild test -project Kitib.xcodeproj -scheme KitibTests \
///       -destination 'platform=macOS,arch=arm64' \
///       -only-testing:KitibTests/REPLTests/testREPL_PasteHealing
///
/// Replace the test name to target a different function. Output prints to the
/// xcodebuild log — look for lines starting with `[REPL]`.
///
/// Every test passes trivially so the suite stays green; the value is in the
/// printed output, not the assertion.

final class REPLTests: XCTestCase {

    // MARK: - Paste healing

    func testREPL_PasteHealing() {
        let input = """
            BS 7671:2018 Chapter 41 Page 1

            411.3.3 Additional protection shall be provided by an
            RCD with a rated residual operating current not
            exceeding 30 mA and an operating time not exceeding
            40 ms at a residual current of 5 times the rating.

            BS 7671:2018 Chapter 41 Page 2

            Where the requirements of Regulation 411.3.3 are not
            met, supplementary equipotential bonding shall be
            installed in accordance with Regulation 415.2.
            """
        let result = PasteHealer.heal(input)
        print("[REPL] === PasteHealer.heal ===")
        print(result)
        print("[REPL] === end ===\n")
        XCTAssertFalse(result.isEmpty) // trivially true
    }

    // MARK: - UUID injection

    func testREPL_UUIDInjection() {
        let input = """
            ---
            title: My Document
            author: Sean
            ---

            # Heading

            Some content here.
            """
        let result = DocumentIdentity.injectID(input)
        print("[REPL] === DocumentIdentity.injectID ===")
        print(result)
        print("[REPL] === end ===\n")
        XCTAssertTrue(result.contains("id: "))
    }

    func testREPL_UUIDInjectionAlreadyHasID() {
        let input = """
            ---
            id: 123e4567-e89b-12d3-a456-426614174000
            title: Existing Doc
            ---

            Body.
            """
        let result = DocumentIdentity.injectID(input)
        print("[REPL] === injectID (already has UUID) ===")
        print(result == input ? "UNCHANGED (id already present)" : "MODIFIED")
        print("[REPL] === end ===\n")
        XCTAssertEqual(result, input)
    }

    // MARK: - Wiki-link extraction

    func testREPL_ExtractWikiLinks() {
        let input = """
            See [[Design Note]] for the layout. The [[Cable Schedule]]
            lists all feeders. `[[ignored]]` inside backticks.

            ```
            [[also ignored]]
            ```

            Final reference: [[BS 7671:2018 Notes]]
            """
        let links = extractWikiLinks(input)
        print("[REPL] === extractWikiLinks ===")
        for (range, target) in links {
            print("  target: \"\(target)\" → range: \(range)")
        }
        print("[REPL] === end ===\n")
        XCTAssertEqual(links.count, 3)
    }

    // MARK: - Link index resolution

    func testREPL_LinkIndex() {
        let idx = LinkIndex(entries: [
            .init(path: "/docs/design.md", id: "u1",
                  title: "Design Note", aliases: ["design", "dn"]),
            .init(path: "/docs/cables.md", id: "u2",
                  title: "Cable Schedule", aliases: ["cables"]),
            .init(path: "/docs/protection.md", id: "u3",
                  title: "Protection Study"),
            .init(path: "/docs/bs7671.md", id: "u4",
                  title: "BS 7671:2018 Notes", aliases: ["7671"]),
        ])

        let queries = ["Design Note", "design", "cables", "protection",
                       "BS 7671:2018 Notes", "nonexistent"]
        print("[REPL] === LinkIndex.resolve ===")
        for q in queries {
            let result = idx.resolve(q) ?? "(nil — broken link)"
            print("  \"\(q)\" → \(result)")
        }
        print("[REPL] === end ===\n")
        XCTAssertNotNil(idx.resolve("Design Note"))
    }

    // MARK: - FTS5 search

    func testREPL_Search() throws {
        let idx = try SearchIndex()

        let docs: [(id: String, title: String?, content: String)] = [
            ("1", "Design Note",
             "The main transformer shall be rated for 1000 kVA continuous duty at 40 C ambient temperature."),
            ("2", "Cable Schedule",
             "All LV feeders shall be XLPE/SWA/PVC insulated and rated for the prospective fault current."),
            ("3", "Protection Study",
             "Overcurrent protection shall coordinate with the upstream transformer protection relay."),
            ("4", "Load List",
             "Connected load: 350 kW. Demand factor: 0.8. Transformer loading: 65%."),
        ]

        for d in docs { try idx.index(id: d.id, title: d.title, content: d.content) }

        let queries = ["transformer", "cable OR protection", "\"fault current\"",
                       "transformer NOT protection"]
        print("[REPL] === SearchIndex.search ===")
        for q in queries {
            let results = try idx.search(q)
            print("  Query: \"\(q)\" → \(results.count) result(s)")
            for r in results {
                print("    [\(r.id)] \(r.title ?? "(no title)"): \(r.snippet)")
            }
        }
        print("[REPL] === end ===\n")
        XCTAssertFalse(try idx.search("transformer").isEmpty)
    }

    // MARK: - Table model

    func testREPL_TableParser() {
        let input = """
            Some text before the table.

            | Name    | Value | Unit |
            | ------- | ----- | ---- |
            | Voltage | 11    | kV   |
            | Current | 300   | A    |

            Text after.
            """
        print("[REPL] === MarkdownTableParser.parse ===")
        if let (before, table, after) = MarkdownTableParser.parse(input) {
            print("  Before: \"\(before)\"")
            print("  Headers: \(table.headers)")
            print("  Alignments: \(table.alignments.map { $0.rawValue })")
            for (i, row) in table.rows.enumerated() {
                print("  Row \(i): \(row)")
            }
            print("  After: \"\(after)\"")

            // Mutate and re-serialize
            var t = table
            t.setCell(row: 0, col: 1, text: "400")
            t.insertRow(at: 1, cells: ["Power", "500", "kW"])
            print("\n  Serialized after mutations:")
            print(t.serialize())
        } else {
            print("  No table found.")
        }
        print("[REPL] === end ===\n")
        XCTAssertNotNil(MarkdownTableParser.parse(input))
    }
}
