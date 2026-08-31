import XCTest

/// Locates and loads the rules-engine fixture corpus
/// (Tests/KitibTests/Rules/Fixtures/).
///
/// Mirrors FixtureCorpus (paste-healing): prefers the copy inside the test
/// bundle (D29), falls back to the source tree only if that copy is missing.
/// RulesCorpusTests.testFixturesAreBundledNotReadFromSourceTree fails when
/// the bundled copy is absent, so the fallback cannot silently mask a broken
/// resources phase.
enum RulesFixtures {

    /// Every fixture file (without the .md suffix), sorted. RulesCorpusTests
    /// asserts the on-disk set matches this list exactly, so a stray or
    /// missing fixture fails. README.md is documentation, not a fixture.
    static let names = [
        "broken-link-clean",
        "broken-link-defect",
        "empty-section-clean",
        "empty-section-defect",
        "exclusion-zones",
        "forbidden-clean",
        "forbidden-defect",
        "heading-jump-clean",
        "heading-jump-defect",
    ]

    /// Prefers the bundled copy over the source tree.
    static var root: URL {
        if let bundled = bundledRoot { return bundled }
        return sourceTreeRoot
    }

    /// The fixtures as copied into the test bundle by the `resources` build
    /// phase. Nil when absent, which the corpus test treats as a failure.
    static var bundledRoot: URL? {
        let bundle = Bundle(for: BundleMarker.self)
        guard let resources = bundle.resourceURL else { return nil }
        let candidate = resources.appendingPathComponent("Fixtures")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    static var sourceTreeRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Rules
            .deletingLastPathComponent()   // KitibTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Tests")
            .appendingPathComponent("KitibTests")
            .appendingPathComponent("Rules")
            .appendingPathComponent("Fixtures")
    }

    /// Anchor class used only to locate the test bundle.
    private final class BundleMarker {}

    static func fileURL(_ name: String) -> URL {
        root.appendingPathComponent(name + ".md")
    }

    /// Loads one fixture. Fails the calling test if the file is missing or
    /// unreadable, so a corpus that quietly stops existing cannot pass.
    static func load(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        let url = fileURL(name)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            XCTFail(
                "Rules fixture '\\(name)' could not be loaded from \\(url.path): "
                    + "\\(error)",
                file: file, line: line
            )
            return nil
        }
    }
}
