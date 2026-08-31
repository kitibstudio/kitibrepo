import XCTest

/// Spec: specs/new-file-in-folder.md. Pure target resolution: where a new
/// file/folder lands given the navigator selection. No filesystem access.
final class NewFileTargetTests: XCTestCase {

    private let root = URL(fileURLWithPath: "/Vault")

    private func folder(_ name: String) -> URL {
        root.appendingPathComponent(name)
    }

    private func file(at path: String) -> URL {
        root.appendingPathComponent(path)
    }

    /// URL equality is formatting-sensitive: `deletingLastPathComponent()`
    /// yields a trailing slash (`/Vault/Design/`) where `appendingPathComponent`
    /// does not (`/Vault/Design`). Both resolve to the same directory and
    /// behave identically under `appendingPathComponent`, so tests compare
    /// normalized paths, stripping the trailing slash.
    private func norm(_ url: URL?) -> String {
        guard let url else { return "<nil>" }
        var path = url.standardizedFileURL.path
        if path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }

    // MARK: - Acceptance criterion 6 / failure mode 3: no selection → root

    func testNoSelectionFallsBackToRoot() {
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: nil,
                                                 selectedIsDirectory: nil,
                                                 rootURL: root)),
                       norm(root))
    }

    // MARK: - Acceptance criterion 1: selected folder → that folder

    func testSelectedFolderAtTopLevel() {
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: folder("Design"),
                                                 selectedIsDirectory: true,
                                                 rootURL: root)),
                       norm(folder("Design")))
    }

    // Failure mode 4: depth must not collapse to an ancestor.
    func testSelectedFolderAtDepthThreeTargetsItself() {
        let deep = file(at: "Projects/2026/Riyadh")
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: deep,
                                                 selectedIsDirectory: true,
                                                 rootURL: root)),
                       norm(deep))
    }

    // Edge: the root itself selected as a folder stays the root.
    func testRootItselfSelectedReturnsRoot() {
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: root,
                                                 selectedIsDirectory: true,
                                                 rootURL: root)),
                       norm(root))
    }

    // MARK: - Acceptance criterion 2 (ruling: parent): selected file → parent

    func testSelectedFileTargetsItsParent() {
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: file(at: "Design/notes.md"),
                                                 selectedIsDirectory: false,
                                                 rootURL: root)),
                       norm(folder("Design")))
    }

    func testSelectedFileAtDepthThreeTargetsDepthTwoParent() {
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: file(at: "Projects/2026/Riyadh/spec.md"),
                                                 selectedIsDirectory: false,
                                                 rootURL: root)),
                       norm(file(at: "Projects/2026")))
    }

    // Failure mode 5: a file whose parent is the root collapses to root.
    func testFileWhoseParentIsRootFallsBackToRoot() {
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: file(at: "notes.md"),
                                                 selectedIsDirectory: false,
                                                 rootURL: root)),
                       norm(root))
    }

    // MARK: - Failure modes 1 & 2: unresolvable selection → root

    func testUnresolvableSelectionFallsBackToRoot() {
        // The id no longer resolves against the live tree (renamed, deleted,
        // or a row that has no FileItem): the caller passes a nil isDirectory
        // flag, and the helper must not write into a stale path.
        XCTAssertEqual(norm(NewFileTarget.target(selectedURL: file(at: "gone/old.md"),
                                                 selectedIsDirectory: nil,
                                                 rootURL: root)),
                       norm(root))
    }

    // MARK: - Acceptance criterion 9: no vault → nil (guard)

    func testNilRootReturnsNil() {
        XCTAssertNil(NewFileTarget.target(selectedURL: folder("Design"),
                                          selectedIsDirectory: true,
                                          rootURL: nil))
    }

    func testNilRootWithNoSelectionReturnsNil() {
        XCTAssertNil(NewFileTarget.target(selectedURL: nil,
                                          selectedIsDirectory: nil,
                                          rootURL: nil))
    }
}
