import XCTest

// MARK: - Failure-mode tests (written first — must fail on stubs)

final class RepairGlyphsFailureModeTests: XCTestCase {

    /// FM7: Idempotence — healing an already-healed paste must not damage it.
    /// This is a failure-mode test: the stub returns input unchanged, so this
    /// passes on the stub (idempotent by identity). But once repairGlyphs
    /// actually transforms, the double-application must be stable.
    func testRepairGlyphsIsIdempotent() {
        let input = "“low-voltage” — test ’ data   here ​ now Â°C Î© Â²"
        let once = repairGlyphs(input)
        let twice = repairGlyphs(once)
        XCTAssertEqual(twice, once, "repairGlyphs must be idempotent")
    }

    /// FM1: A rejoined compound — the signature failure mode.
    /// repairGlyphs must leave every protected compound unchanged.
    func testRepairGlyphsPreservesProtectedCompounds() {
        let compounds: [(String, String)] = [
            ("The “low-voltage” winding", "low-voltage"),
            ("connected in “star-delta”", "star-delta"),
            ("cable type XLPE/SWA/PVC", "XLPE/SWA/PVC"),
            ("the “Dyn11” unit", "Dyn11"),
            ("redundancy is “N+1”", "N+1"),
            ("voltage is “11kV/415V”", "11kV/415V"),
        ]
        for (text, compound) in compounds {
            let result = repairGlyphs(text)
            XCTAssertTrue(
                result.contains(compound),
                "repairGlyphs must preserve '\(compound)' — got: \(result)"
            )
        }
    }
}

// MARK: - Acceptance-criteria tests

final class ProtectedCompoundsTests: XCTestCase {

    func testProtectedCompoundsContainsAllSix() {
        let required: Set<String> = [
            "low-voltage",
            "star-delta",
            "XLPE/SWA/PVC",
            "Dyn11",
            "N+1",
            "11kV/415V",
        ]
        for compound in required {
            XCTAssertTrue(
                ProtectedCompounds.compounds.contains(compound),
                "ProtectedCompounds must contain '\(compound)'"
            )
        }
    }
}

final class RepairGlyphsAcceptanceTests: XCTestCase {

    // MARK: Criterion 4 — Glyph repair

    func testExpandsFiLigature() {
        XCTAssertEqual(repairGlyphs("ﬁle"), "file")
    }

    func testExpandsFlLigature() {
        XCTAssertEqual(repairGlyphs("ﬂame"), "flame")
    }

    func testNormalizesLeftSmartDoubleQuote() {
        XCTAssertEqual(repairGlyphs("“test”"), "\"test\"")
    }

    func testNormalizesRightSmartSingleQuote() {
        XCTAssertEqual(repairGlyphs("it’s"), "it's")
    }

    func testNormalizesEmDash() {
        XCTAssertEqual(repairGlyphs("a—b"), "a-b")
    }

    func testNormalizesEnDash() {
        let endash = "–"
        XCTAssertEqual(repairGlyphs("a–b"), "a-b")
    }

    /// D23: NBSP is a value/unit separator (1000 kVA, 50 Hz, 300 A), so it
    /// becomes a regular space. Deleting it yields 1000kVA â silent corruption.
    func testConvertsNonBreakingSpaceToRegularSpace() {
        XCTAssertEqual(repairGlyphs("hello\u{00a0}world"), "hello world")
    }

    func testRemovesZeroWidthSpace() {
        XCTAssertEqual(repairGlyphs("hello​world"), "helloworld")
    }

    func testRecoversDegreeSymbol() {
        XCTAssertEqual(repairGlyphs("40Â°C"), "40°C")
    }

    func testRecoversOhmSymbol() {
        XCTAssertEqual(repairGlyphs("47Î©"), "47Ω")
    }

    func testRecoversSuperscriptTwo() {
        XCTAssertEqual(repairGlyphs("mmÂ²"), "mm²")
    }

    // MARK: Criterion 8 — Determinism

    func testRepairGlyphsIsDeterministic() {
        let input = "ﬁle “test”   40Â°C"
        let a = repairGlyphs(input)
        let b = repairGlyphs(input)
        XCTAssertEqual(a, b, "repairGlyphs must be deterministic")
    }

    // MARK: Criterion 3 — Protected compounds survive

    func testProtectedCompoundFixtureRoundTrips() {
        let input = "The transformer “low-voltage” winding is connected in “star-delta”.\nCable type XLPE/SWA/PVC is specified for the “Dyn11” unit.\nRedundancy is “N+1” and the primary voltage is “11kV/415V”.\n"
        let result = repairGlyphs(input)

        let expectedCompounds = [
            "low-voltage",
            "star-delta",
            "XLPE/SWA/PVC",
            "Dyn11",
            "N+1",
            "11kV/415V",
        ]
        for compound in expectedCompounds {
            XCTAssertTrue(
                result.contains(compound),
                "Compound '\(compound)' must survive repairGlyphs — got: \(result)"
            )
        }

        XCTAssertFalse(result.contains("“"), "Left smart quotes must be normalised")
        XCTAssertFalse(result.contains("”"), "Right smart quotes must be normalised")
    }
}
