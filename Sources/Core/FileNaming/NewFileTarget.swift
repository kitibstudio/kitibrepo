import Foundation

/// Decides where a new file or folder is created: the folder selected in the
/// navigator, the parent of the selected file, or the vault root when nothing
/// is selected (specs/new-file-in-folder.md).
///
/// Pure: takes already-resolved values and never touches the filesystem. The
/// caller resolves the selection against the live tree, so an id that no
/// longer exists arrives as a nil `selectedIsDirectory` and falls back to the
/// root instead of writing into a stale path.
enum NewFileTarget {
    /// - Parameters:
    ///   - selectedURL: URL of the row selected in the navigator, if any.
    ///   - selectedIsDirectory: whether that row is a folder. `nil` when the
    ///     selection no longer resolves against the live tree.
    ///   - rootURL: the open vault root; nil when no vault is open.
    /// - Returns: the folder the new file/folder should be created in.
    static func target(selectedURL: URL?, selectedIsDirectory: Bool?,
                       rootURL: URL?) -> URL? {
        guard let root = rootURL else { return nil }
        guard let url = selectedURL, let isDirectory = selectedIsDirectory else {
            return root
        }
        return isDirectory ? url : url.deletingLastPathComponent()
    }
}
