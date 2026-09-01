import Foundation

// MARK: - Diagnostic navigation helpers

/// Conversion and position helpers the Problems panel uses to jump to a
/// finding (specs/problems-panel.md criterion 3, failure mode 2).
///
/// `Diagnostic` itself is untouched: these live in an extension in a
/// separate file. Adding a stored field to the struct would be a spec
/// change (specs/rules-engine.md "Out of scope": no fix, no UI metadata).
///
/// CONTRACT: `text` must be the string the range was built from. The panel
/// always satisfies this (it re-evaluates on every open and save, so a
/// diagnostic's range always indexes into the text it is converted
/// against). The bounds check below is defence in depth: it safely catches
/// the common stale case, a range from a LONGER previous text against a
/// SHORTER current one, because String.Index comparison is numeric and
/// cannot trap. A foreign range that happens to compare within bounds is
/// not detectable in this stdlib (both `utf16Offset(in:)` and
/// `UTF16View.distance` trap on it), which is why the contract exists.
extension Diagnostic {

    /// The diagnostic's range as an NSRange in UTF-16 coordinates, the
    /// coordinate space both editors' scroll bridge uses. Returns nil when
    /// the range lies numerically outside `text`; with a same-string range
    /// (the contract) it always returns a value.
    func nsRange(in text: String) -> NSRange? {
        guard range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex else {
            return nil
        }
        let utf16 = text.utf16
        let lo = utf16.distance(from: utf16.startIndex, to: range.lowerBound)
        let hi = utf16.distance(from: utf16.startIndex, to: range.upperBound)
        return NSRange(location: lo, length: hi - lo)
    }

    /// The 1-based line number of the range's start: 1 plus the number of
    /// newline SCALARS strictly before the range. Counting scalars, not
    /// characters, matters: Swift folds `\r\n` into a single Character
    /// (grapheme cluster), so a character scan misses the `\n` of every
    /// CRLF line ending.
    func lineNumber(in text: String) -> Int {
        text[..<range.lowerBound].unicodeScalars.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }
}
