import Foundation

// MARK: - LinkIndex

/// Resolves `[[wiki-links]]` to file paths via a frontmatter-based index.
///
/// Built from caller-supplied `(path, id?, title?, aliases)` tuples — no
/// filesystem access. Resolution priority: title match → alias match →
/// filename-stem fallback. Case-insensitive. First entry wins when two
/// map to the same key (deterministic).
struct LinkIndex {

    /// One document's metadata, supplied by the caller.
    struct Entry {
        let path: String
        let id: String?
        let title: String?
        let aliases: [String]

        init(path: String, id: String? = nil, title: String? = nil,
             aliases: [String] = []) {
            self.path = path
            self.id = id
            self.title = title
            self.aliases = aliases
        }
    }

    private let titleToPath: [String: String]
    private let aliasToPath: [String: String]
    private let stemToPath: [String: String]

    init(entries: [Entry]) {
        var titleMap: [String: String] = [:]
        var aliasMap: [String: String] = [:]
        var stemMap: [String: String] = [:]

        for entry in entries {
            if let t = entry.title {
                let key = t.lowercased()
                if titleMap[key] == nil { titleMap[key] = entry.path }
            }
            for a in entry.aliases {
                let key = a.lowercased()
                if aliasMap[key] == nil { aliasMap[key] = entry.path }
            }
            let stem = Self.filenameStem(entry.path).lowercased()
            if stemMap[stem] == nil { stemMap[stem] = entry.path }
        }

        self.titleToPath = titleMap
        self.aliasToPath = aliasMap
        self.stemToPath = stemMap
    }

    /// Resolves `target` — the text between `[[` and `]]` — to a file path,
    /// or `nil` when no entry matches.
    func resolve(_ target: String) -> String? {
        let key = target.trimmingCharacters(in: .whitespaces).lowercased()
        return titleToPath[key] ?? aliasToPath[key] ?? stemToPath[key]
    }

    /// Number of entries in the index.
    var count: Int { titleToPath.count + aliasToPath.count + stemToPath.count }

    private static func filenameStem(_ path: String) -> String {
        (path as NSString).lastPathComponent.components(separatedBy: ".").first ?? path
    }
}

// MARK: - Wiki-link extraction

/// Finds every `[[target]]` span in `raw` that is NOT inside a fenced code
/// block or an inline backtick span. Returns (global-range, target-text) pairs
/// in document order.
func extractWikiLinks(_ raw: String) -> [(range: Range<String.Index>, target: String)] {
    var results: [(Range<String.Index>, String)] = []
    let lines = raw.components(separatedBy: "\n")
    var inFence = false
    var lineOffset = raw.startIndex

    for line in lines {
        defer {
            lineOffset = raw.index(lineOffset, offsetBy: line.utf16.count + 1,
                                   limitedBy: raw.endIndex) ?? raw.endIndex
        }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") { inFence.toggle(); continue }
        if inFence { continue }

        let backtickRanges = findBacktickSpans(in: line)

        // Find [[...]] patterns on this line.
        var searchStart = line.startIndex
        while let open = line[searchStart...].range(of: "[[") {
            let absOpen = open.lowerBound
            guard let close = line[absOpen...].range(of: "]]") else { break }
            let absClose = close.upperBound

            let targetStart = line.index(absOpen, offsetBy: 2)
            let targetEnd = close.lowerBound
            guard targetStart < targetEnd else {
                // Empty link [[]] — skip.
                searchStart = absClose
                continue
            }
            let target = String(line[targetStart..<targetEnd])

            // The midpoint of the link must not fall inside a backtick span.
            let mid = line.index(targetStart, offsetBy:
                line.distance(from: targetStart, to: targetEnd) / 2)
            if !backtickRanges.contains(where: { $0.contains(mid) }) {
                let globalStart = raw.index(lineOffset,
                    offsetBy: line.distance(from: line.startIndex, to: absOpen))
                let globalEnd = raw.index(lineOffset,
                    offsetBy: line.distance(from: line.startIndex, to: absClose))
                results.append((globalStart..<globalEnd, target))
            }

            searchStart = absClose
        }
    }

    return results
}

/// Returns the ranges of every `` `...` `` span on a single line.
private func findBacktickSpans(in line: String) -> [Range<String.Index>] {
    var spans: [Range<String.Index>] = []
    var idx = line.startIndex
    while idx < line.endIndex {
        if line[idx] == "`" {
            let start = idx
            idx = line.index(after: idx)
            // Scan for closing backtick.
            while idx < line.endIndex, line[idx] != "`" {
                idx = line.index(after: idx)
            }
            if idx < line.endIndex {
                idx = line.index(after: idx)   // past closing backtick
                spans.append(start..<idx)
            }
        } else {
            idx = line.index(after: idx)
        }
    }
    return spans
}
