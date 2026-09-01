import Foundation

// MARK: - FrontmatterMetadata

/// The `title` and `aliases` keys of a document's YAML frontmatter block,
/// extracted for the link index (specs/problems-panel.md criterion 5).
///
/// Block detection mirrors ExclusionSpans exactly: the document must open
/// with a `---` line and close with a `---` or `...` line at column 0; an
/// unclosed opener is a horizontal rule, not metadata, and returns nil.
/// Keys must start at column 0 (an indented key belongs to a nested mapping
/// this extractor does not model, and is ignored). Values are the rest of
/// the key's line; surrounding quotes are stripped; a bare `key:` with no
/// value is nil/empty, never a parse error.
///
/// Multi-line YAML values are out of scope: title is one line, aliases is a
/// flow list (`[a, b]`) or a dash block list (`- a` on following lines), or
/// empty. Anything else is ignored, never an error.
struct FrontmatterMetadata: Equatable {

    let title: String?
    let aliases: [String]

    /// Extracts the frontmatter block's title and aliases, or nil when the
    /// document has no complete frontmatter block at its start.
    static func extract(from text: String) -> FrontmatterMetadata? {
        let nsText = text as NSString
        guard nsText.length > 0 else { return nil }

        // --- Block detection (mirrors ExclusionSpans) --------------------
        let firstLineRange = nsText.lineRange(for: NSRange(location: 0, length: 0))
        let firstLine = nsText.substring(with: firstLineRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard firstLine == "---" else { return nil }

        var interior: [String] = []
        var offset = NSMaxRange(firstLineRange)
        var closed = false
        while offset < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: offset, length: 0))
            let line = nsText.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" || trimmed == "..." {
                closed = true
                break
            }
            interior.append(line)
            offset = NSMaxRange(lineRange)
        }
        guard closed else { return nil }

        // --- Key parsing ---------------------------------------------------
        var title: String? = nil
        var aliases: [String] = []
        var i = 0
        while i < interior.count {
            let line = interior[i]
            // Keys must start at column 0. The line keeps its trailing
            // newline (and any CR), so `hasPrefix` on the raw line is the
            // column-0 check; the value is trimmed below.
            if line.hasPrefix("title:") {
                let value = line.dropFirst("title:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                title = value.isEmpty ? nil : unquote(value)
            } else if line.hasPrefix("aliases:") {
                let rest = line.dropFirst("aliases:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if rest.hasPrefix("[") && rest.hasSuffix("]") {
                    // Flow list: [a, b]
                    let inner = rest.dropFirst().dropLast()
                    aliases = inner.split(separator: ",")
                        .map { unquote($0.trimmingCharacters(in: .whitespaces)) }
                } else if rest.isEmpty {
                    // Dash block list: "- item" lines until a non-item line.
                    var j = i + 1
                    while j < interior.count {
                        let itemLine = interior[j]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard itemLine.hasPrefix("- ") else { break }
                        aliases.append(unquote(
                            itemLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                        ))
                        j += 1
                    }
                    i = j - 1
                }
                // A bare single value is ignored; aliases stay [].
            }
            i += 1
        }
        return FrontmatterMetadata(title: title, aliases: aliases)
    }

    /// Strips one matching pair of surrounding single or double quotes.
    private static func unquote(_ s: String) -> String {
        if s.count >= 2,
           (s.hasPrefix("\"") && s.hasSuffix("\"")) ||
           (s.hasPrefix("'") && s.hasSuffix("'")) {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}
