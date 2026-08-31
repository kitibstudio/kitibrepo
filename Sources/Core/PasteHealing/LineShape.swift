import Foundation

/// Shape classification for a single line of pasted text.
///
/// `stripArtefacts` and `unwrapLines` both have to answer the same two
/// questions — "is this line structure rather than prose?" and "is this a
/// clause citation?" — and they must answer them IDENTICALLY. A line that
/// unwrap treats as prose but stripArtefacts treats as a running footer is how
/// a table loses a row silently. One implementation, used by both.
///
/// Every predicate here is deliberately over-inclusive. Classifying a line as
/// structure only ever prevents a change (no rejoin, no deletion), so a false
/// positive leaves text visibly unhealed. A false negative deletes or merges
/// content and reads as correct — see specs/paste-healing.md failure modes 2-5.
enum LineShape {

    /// Markdown or plain-text structure that must never be merged into a
    /// paragraph, and never deleted as page furniture.
    ///
    /// Blank lines count as structural: they are block boundaries.
    static func isStructural(_ line: String) -> Bool {
        // Indented block — fenced-free code, or a continued list item.
        if line.hasPrefix("    ") || line.hasPrefix("\t") { return true }

        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return true }

        // Any pipe at all is treated as a table row. Restrictive on purpose:
        // failure mode 2 is a table flattened by unwrap, where the information
        // survives but the structure — which IS the meaning — does not.
        if t.contains("|") { return true }

        if t.hasPrefix("#") { return true }                              // heading
        if t.hasPrefix(">") { return true }                              // block quote
        if t.hasPrefix("```") || t.hasPrefix("~~~") { return true }      // fence
        if isHorizontalRule(t) { return true }
        if isBulletItem(t) { return true }
        if isOrderedItem(t) { return true }
        return false
    }

    /// A clause, table, or figure citation — the thing this app exists to quote.
    ///
    /// Never stripped as page furniture (failure mode 3: `411.3.3` eaten as a
    /// page number leaves the prose intact and the citation unanchored) and
    /// never pulled up into the preceding line by unwrap, so a citation always
    /// starts the line it started on.
    static func isClauseCitation(_ trimmed: String) -> Bool {
        if trimmed.hasPrefix("§") { return true }

        let lower = trimmed.lowercased()
        for word in ["table ", "figure ", "clause ", "annex ", "appendix ", "regulation "]
        where lower.hasPrefix(word) {
            return true
        }

        return startsWithDottedNumeral(trimmed)
    }

    /// `411.3.3`, `4.2`, `7.2.1` — digits, a dot, then more digits.
    ///
    /// A bare integer is deliberately NOT a dotted numeral: `12` alone on a
    /// line is a page number, which criterion 5 exists to remove.
    static func startsWithDottedNumeral(_ trimmed: String) -> Bool {
        var sawLeadingDigit = false
        var sawDot = false
        for ch in trimmed {
            if ch.isNumber {
                if sawDot { return true }   // digit, dot, digit
                sawLeadingDigit = true
            } else if ch == "." {
                if !sawLeadingDigit { return false }
                sawDot = true
            } else {
                return false
            }
        }
        return false
    }

    /// Two or more consecutive spaces inside the line — a whitespace-aligned
    /// column gap.
    ///
    /// Only `unwrapLines` uses this. Rejoining such lines destroys the columns
    /// before `detectTables` (T3, and fifth in the locked order) ever sees
    /// them. `stripArtefacts` must NOT use it: a running footer such as
    /// `BS 7671:2018   Chapter 41   12` is padded exactly this way and has to
    /// stay strippable.
    static func hasColumnGap(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        var previousWasSpace = false
        for ch in t {
            let isSpace = (ch == " ")
            if isSpace && previousWasSpace { return true }
            previousWasSpace = isSpace
        }
        return false
    }

    /// Sentence-ending punctuation, ignoring trailing quotes and brackets.
    ///
    /// This is the primary guard against failure mode 5 (a genuine paragraph
    /// break swallowed): a line that ends a sentence never continues onto the
    /// next line, however close to the wrap column it ends.
    static func endsSentence(_ line: String) -> Bool {
        var t = line.trimmingCharacters(in: .whitespaces)
        while let last = t.last, "\"')]}".contains(last) {
            t.removeLast()
        }
        guard let last = t.last else { return true }
        return ".!?;".contains(last)
    }

    /// `- item`, `* item`, `+ item`, or a lone marker.
    static func isBulletItem(_ trimmed: String) -> Bool {
        for marker in ["-", "*", "+"] {
            if trimmed == marker || trimmed.hasPrefix(marker + " ") { return true }
        }
        return false
    }

    /// `1. item`, `2) item`, `a) item` — numeric or single-letter ordered markers.
    /// A dotted clause numeral is NOT an ordered item:
    /// `411.3.3 …` has a digit after the dot, not a space (failure mode 6).
    static func isOrderedItem(_ trimmed: String) -> Bool {
        guard let first = trimmed.first else { return false }

        // Numeric: "1.", "2) "
        if first.isNumber {
            var digits = 0
            var index = trimmed.startIndex
            while index < trimmed.endIndex, trimmed[index].isNumber {
                digits += 1
                index = trimmed.index(after: index)
            }
            guard digits <= 3, index < trimmed.endIndex else { return false }
            guard trimmed[index] == "." || trimmed[index] == ")" else { return false }
            let after = trimmed.index(after: index)
            return after == trimmed.endIndex || trimmed[after] == " "
        }

        // Lettered: "a)", "A)", "a. "
        if first.isLetter, trimmed.count >= 2 {
            let second = trimmed[trimmed.index(after: trimmed.startIndex)]
            if second == ")" || second == "." {
                let after = trimmed.index(trimmed.startIndex, offsetBy: 2)
                return after == trimmed.endIndex || trimmed[after] == " "
            }
        }

        return false
    }

    /// `a)`, `A.`, `j) …` — an ordered item whose marker is a letter.
    ///
    /// Markdown has no lettered list, so these are prose to a renderer: two
    /// consecutive lettered items are one paragraph unless a blank line
    /// separates them. `unwrapLines` needs to tell them from `1.` and `-`,
    /// which are real list markers and stay tight.
    static func isLetteredItem(_ trimmed: String) -> Bool {
        guard let first = trimmed.first, first.isLetter else { return false }
        return isOrderedItem(trimmed)
    }

    /// A list-marker line (ordered or bullet) may continue across hard-wrapped
    /// lines — the marker's own prose should rejoin with the next line.
    /// Headings, fences, rules, and table rows do not continue.
    static func isListMarker(_ trimmed: String) -> Bool {
        isOrderedItem(trimmed) || isBulletItem(trimmed)
    }

    /// `---`, `***`, `___`, with optional spaces between the characters.
    static func isHorizontalRule(_ trimmed: String) -> Bool {
        let stripped = trimmed.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3 else { return false }
        let unique = Set(stripped)
        guard unique.count == 1, let ch = unique.first else { return false }
        return ch == "-" || ch == "*" || ch == "_"
    }
}
