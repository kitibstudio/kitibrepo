import Foundation

// MARK: - HelpSearch

/// Filters and ranks help entries across all three lanes at once.
///
/// Searching one lane at a time would be searching the taxonomy, not the help:
/// a reader who types "diagram" does not know whether the answer is syntax
/// (cheatsheet) or a walkthrough (guides), and being told "not in this tab" is
/// worse than no search at all. So one field, every lane, and the lane is
/// reported on the result rather than being a precondition for finding it.
///
/// Deliberately not FTS5. This corpus is a few dozen fixed entries; an index
/// would add a rebuild step and inherit FTS5's tokenizer quirks — the very thing
/// `QueryLint` exists to apologise for. A linear fold-and-contains is exact,
/// instant at this size, and has no query syntax for the reader to get wrong.
public enum HelpSearch {

    /// Where a token was found. Higher is a better reason to rank an entry first.
    private enum Weight: Int {
        case title = 100
        case keywordExact = 60
        case keyword = 40
        case body = 15
    }

    /// Matching entries, best first. An empty or whitespace-only query returns
    /// `entries` unchanged, so the caller can use this for the resting state too.
    ///
    /// Every token must match somewhere in the entry (AND, not OR). Two words
    /// typed together are a narrowing, which is what a reader means by them.
    public static func results(for query: String, in entries: [HelpEntry] = HelpContent.all) -> [HelpEntry] {
        let tokens = self.tokens(in: query)
        guard !tokens.isEmpty else { return entries }

        var scored: [(entry: HelpEntry, score: Int, order: Int)] = []
        for (order, entry) in entries.enumerated() {
            guard let score = score(entry, against: tokens) else { continue }
            scored.append((entry, score, order))
        }

        // Sort on the original index as a tie-break rather than relying on the
        // sort being stable — Swift's is not guaranteed to be.
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
            .map(\.entry)
    }

    /// `nil` if any token is missing from the entry; otherwise the summed weight
    /// of where each token was found.
    private static func score(_ entry: HelpEntry, against tokens: [String]) -> Int? {
        let title = fold(entry.title)
        let body = fold(entry.bodyText)
        let keywords = entry.keywords.map(fold)

        var total = 0
        for token in tokens {
            var best = 0
            if title.contains(token) { best = max(best, Weight.title.rawValue) }
            if keywords.contains(token) { best = max(best, Weight.keywordExact.rawValue) }
            if keywords.contains(where: { $0.contains(token) }) { best = max(best, Weight.keyword.rawValue) }
            if body.contains(token) { best = max(best, Weight.body.rawValue) }
            guard best > 0 else { return nil }
            total += best
        }
        return total
    }

    /// Terms close to what was typed, for the no-results state.
    ///
    /// A blank pane cannot tell the reader whether they mistyped or whether the
    /// app cannot do the thing at all — the same conflation D64 records for
    /// smart folder queries. Near-misses answer that: offered terms mean "you
    /// were close", nothing offered means "look elsewhere".
    public static func suggestions(
        for query: String,
        in entries: [HelpEntry] = HelpContent.all,
        limit: Int = 3
    ) -> [String] {
        let tokens = self.tokens(in: query)
        guard let typed = tokens.max(by: { $0.count < $1.count }), typed.count >= 3 else { return [] }

        // Candidate vocabulary: the words a reader is likely to be reaching for.
        var vocabulary: [String: String] = [:]   // folded -> as written
        for entry in entries {
            for word in entry.title.split(whereSeparator: { !$0.isLetter }) where word.count >= 4 {
                vocabulary[fold(String(word))] = String(word).lowercased()
            }
            for keyword in entry.keywords where keyword.count >= 4 {
                vocabulary[fold(keyword)] = keyword
            }
        }

        var near: [(term: String, distance: Int)] = []
        for (folded, written) in vocabulary {
            guard folded != typed else { continue }
            // A prefix the reader has started typing is a near-miss at distance 0
            // even when the edit distance is large ("form" -> "formula").
            if folded.hasPrefix(typed) {
                near.append((written, 0))
                continue
            }
            let d = typoDistance(typed, folded)
            let tolerance = max(1, min(2, folded.count / 4))
            if d <= tolerance { near.append((written, d)) }
        }

        return near
            .sorted { $0.distance != $1.distance ? $0.distance < $1.distance : $0.term < $1.term }
            .map(\.term)
            .reduced(to: limit)
    }

    /// How many entries in each lane a query hits. Drives the lane badges, so
    /// the reader can see a match sitting in a lane they are not looking at.
    public static func laneCounts(for query: String, in entries: [HelpEntry] = HelpContent.all) -> [HelpLane: Int] {
        var counts: [HelpLane: Int] = [:]
        for entry in results(for: query, in: entries) {
            counts[entry.lane, default: 0] += 1
        }
        return counts
    }

    // MARK: - Text handling

    /// Case- and diacritic-insensitive, so `Café` matches `cafe` and `PDF`
    /// matches `pdf`. Fixed locale: help text is English, and a Turkish locale
    /// would fold `I` to `ı` and break `⌘I`.
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Splits on whitespace only. Punctuation is kept, because half of what a
    /// reader searches for here *is* punctuation — `**`, `$$`, `|`, `⌘P`.
    static func tokens(in query: String) -> [String] {
        fold(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Edit distance counting a transposition as **one** edit, not two
    /// (Optimal String Alignment).
    ///
    /// Plain Levenshtein makes `tabel` two edits from `table`, which is the same
    /// distance as a word that shares only its first letter — so the single most
    /// common typing mistake scores as if it were a different word entirely.
    /// Only ever run over short words.
    static func typoDistance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }

        // Three rows: the extra one is what makes the transposition visible.
        var twoBack = [Int](repeating: 0, count: y.count + 1)
        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)

        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                var best = min(previous[j] + 1,          // deletion
                               current[j - 1] + 1,       // insertion
                               previous[j - 1] + cost)   // substitution
                if i > 1, j > 1, x[i - 1] == y[j - 2], x[i - 2] == y[j - 1] {
                    best = min(best, twoBack[j - 2] + 1) // transposition
                }
                current[j] = best
            }
            twoBack = previous
            previous = current
            current = [Int](repeating: 0, count: y.count + 1)
        }
        return previous[y.count]
    }
}

private extension Array where Element == String {
    /// First `limit` distinct elements, order preserved.
    func reduced(to limit: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in self where !seen.contains(item) {
            seen.insert(item)
            out.append(item)
            if out.count == limit { break }
        }
        return out
    }
}
