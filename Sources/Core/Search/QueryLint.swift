import Foundation

// MARK: - QueryLint

/// Client-side checks for the one query mistake that reads as "no results".
///
/// FTS5 does not treat `draft-notes` as a word: it raises an error, which
/// `AppState.searchSmartFolder` swallows with `try?`, so a malformed query and
/// a genuine miss both arrive as an empty array. Quoting the term makes it
/// match. This catches it at the point of typing rather than explaining it
/// after the fact.
enum QueryLint {

    /// The first hyphenated term that sits outside quotes, if any.
    static func bareHyphenatedTerm(in query: String) -> String? {
        var inQuotes = false
        var token = ""
        var found: [String] = []

        func endToken() {
            if isHyphenated(token) { found.append(token) }
            token = ""
        }

        for ch in query {
            if ch == "\"" {
                endToken()
                inQuotes.toggle()
                continue
            }
            if inQuotes { continue }
            if ch.isLetter || ch.isNumber || ch == "-" {
                token.append(ch)
            } else {
                endToken()
            }
        }
        endToken()
        return found.first
    }

    /// The query with `term` wrapped in quotes.
    static func quoting(_ term: String, in query: String) -> String {
        guard let r = query.range(of: term) else { return query }
        return query.replacingCharacters(in: r, with: "\"\(term)\"")
    }

    private static func isHyphenated(_ token: String) -> Bool {
        guard token.contains("-") else { return false }
        let parts = token.split(separator: "-", omittingEmptySubsequences: false)
        return parts.count >= 2 && parts.allSatisfy { !$0.isEmpty }
    }
}
