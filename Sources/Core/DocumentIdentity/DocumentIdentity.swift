import Foundation

/// Stable document identity via UUID injection into YAML frontmatter.
///
/// Every document gets a v4 UUID on first load or save so renames don't break
/// links. Injection is idempotent: a document that already carries an `id` key
/// — UUID or otherwise — is returned unchanged.
///
/// This is a pure `String -> String` transform. No state, no platform API, no
/// dependency beyond Foundation.UUID.
enum DocumentIdentity {

    // MARK: - Public API

    /// Injects a randomly generated UUIDv4 into the document's frontmatter.
    /// Returns the document unchanged if an `id` key already exists.
    static func injectID(_ raw: String) -> String {
        injectID(raw, uuid: UUID().uuidString.lowercased())
    }

    // MARK: - Internal (testable with a known UUID)

    /// Same as `injectID(_:)` but with a caller-supplied UUID string so golden
    /// fixtures can assert against a literal value.
    static func injectID(_ raw: String, uuid: String) -> String {
        let lines = raw.components(separatedBy: "\n")

        // No frontmatter — prepend one carrying only the id.
        guard let first = lines.first,
              first.trimmingCharacters(in: .whitespaces) == "---" else {
            return prependFrontmatter(uuid: uuid, to: raw)
        }

        // Scan for the closing fence. If it's missing, treat as no frontmatter.
        var closeIdx: Int?
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closeIdx = i
                break
            }
        }

        guard let close = closeIdx else {
            return prependFrontmatter(uuid: uuid, to: raw)
        }

        // An `id` key already exists — leave the document untouched.
        for i in 1..<close {
            if isIDKey(lines[i]) { return raw }
        }

        // Inject `id: <uuid>` after the opening fence.
        var out = lines
        out.insert("id: \(uuid)", at: 1)
        return out.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func prependFrontmatter(uuid: String, to body: String) -> String {
        let frontmatter = "---\nid: \(uuid)\n---"
        if body.isEmpty { return frontmatter + "\n" }
        return frontmatter + "\n\n" + body
    }

    /// True when the trimmed line starts with `id:` — the key, not a substring
    /// inside a value.
    private static func isIDKey(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let colon = t.firstIndex(of: ":") else { return false }
        return t[..<colon] == "id"
    }
}
