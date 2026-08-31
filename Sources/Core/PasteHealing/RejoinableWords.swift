/// Words a hyphenation split may legitimately reconstruct.
///
/// `dehyphenate` removes a hyphen ONLY when the joined form is a known word.
/// Unlike `CommonWords` — which enumerates fragments that may lead a compound
/// and is over-inclusive — this list must contain the exact joined word. A
/// missing word leaves a visible hyphen, which the writer removes in one
/// keystroke; an unwanted word fuses two words silently. So it is weighted
/// towards the words a source PDF actually hyphenates rather than towards
/// dictionary coverage.
///
/// The same design constraint as `CommonWords`: deliberately NOT a
/// spell-checker. No AppKit/NaturalLanguage dependency, so the same paste
/// heals identically on every machine.
enum RejoinableWords {

    /// True if `word` is a word a hyphenation split may reconstruct.
    /// Case-insensitive.  If the exact word is absent and it ends in "s",
    /// tries without the "s" — so a plural such as "transfor-mers" resolves.
    /// Any inflection handling beyond that is out of scope: a missed
    /// inflection leaves a visible hyphen, which is the safe direction.
    static func contains(_ word: String) -> Bool {
        let lowered = word.lowercased()
        guard !lowered.isEmpty else { return false }
        if words.contains(lowered) { return true }
        if lowered.hasSuffix("s") {
            return words.contains(String(lowered.dropLast()))
        }
        return false
    }

    private static let words: Set<String> = [
        // Engineering vocabulary that a source PDF actually hyphenates.
        // Every word here was chosen because it appears hyphenated in real
        // standards documents or equipment specifications.
        "transformer", "operator", "configuration", "distribution",
        "protection", "installation", "equipment", "temperature",
        "requirements", "supplementary", "conductors", "impedance",
        "insulation", "resistance", "commissioning", "manufacturer",
        "specification", "combination", "connection", "construction",
        "application", "operation", "generator", "ventilation",
        "communication", "determination", "consideration", "documentation",
        "investigation", "maintenance", "measurement", "performance",
    ]
}
