/// Words that may legitimately lead a hyphenated compound.
///
/// `dehyphenate` needs to tell `transfor-mer` (one word broken by the source's
/// hyphenation) from `three-phase` (two words that were always hyphenated).
/// Criterion 2 states the rule: a compound whose leading fragment is itself a
/// valid word does not rejoin. `ProtectedCompounds` covers the six terms this
/// app must never damage; this covers the general case.
///
/// **This list is over-inclusive on purpose, and adding to it is always safe.**
/// A word listed here that need not be leaves a hyphen visible on screen, which
/// the writer removes in one keystroke. A word missing from it fuses two words
/// into one that reads as correct — the failure this feature exists to prevent.
/// So it is weighted towards the fragments that actually lead compounds in
/// engineering prose, not towards dictionary coverage.
///
/// It is deliberately NOT a spell-checker: `NSSpellChecker` is AppKit, the
/// `NaturalLanguage` framework is A6 and still only [proposed], and either would
/// make a pure `String -> String` transform depend on a platform service and on
/// the user's installed dictionaries — which is how the same paste heals
/// differently on two machines.
enum CommonWords {

    /// True if `fragment` is a word that may lead a hyphenated compound.
    /// Case-insensitive: `Low-voltage` at the start of a sentence is the same
    /// fragment as `low-voltage` inside one.
    static func contains(_ fragment: String) -> Bool {
        words.contains(fragment.lowercased())
    }

    private static let words: Set<String> = [
        // Compound-forming prefixes and particles — the ones that actually
        // appear in front of a hyphen in engineering text.
        "all", "anti", "back", "bi", "by", "co", "counter", "cross", "de",
        "double", "down", "dual", "eight", "ex", "extra", "five", "four",
        "front", "half", "high", "in", "inter", "intra", "left", "long", "low",
        "mid", "multi", "near", "non", "off", "on", "one", "out", "over",
        "post", "pre", "pro", "quarter", "re", "right", "self", "semi", "short",
        "side", "single", "six", "small", "sub", "super", "ten", "three",
        "top", "triple", "twin", "two", "un", "under", "up", "well",

        // Engineering vocabulary that leads compounds constantly.
        "air", "arc", "bus", "cable", "circuit", "class", "core", "current",
        "delta", "design", "duty", "earth", "end", "energy", "fault", "field",
        "fire", "fixed", "flame", "flow", "full", "gas", "ground", "heat",
        "heavy", "hot", "cold", "iron", "light", "line", "live", "load",
        "loss", "main", "make", "meter", "motor", "no", "oil", "open", "over",
        "panel", "phase", "pole", "power", "pressure", "rated", "rating",
        "safe", "safety", "series", "service", "shock", "shunt", "site",
        "solid", "spec", "star", "state", "steel", "step", "supply", "surge",
        "switch", "system", "temperature", "test", "type", "unit", "user",
        "value", "voltage", "water", "wire", "work",

        // Ordinary high-frequency words. A broken word rarely leaves one of
        // these as its leading fragment, and treating one as a word only ever
        // keeps a hyphen.
        "a", "able", "about", "after", "and", "any", "are", "as", "at", "bad",
        "base", "be", "been", "best", "big", "both", "but", "can", "case",
        "clear", "close", "cut", "day", "dead", "deep", "did", "do", "does",
        "down", "due", "each", "early", "east", "easy", "even", "ever",
        "every", "far", "fast", "few", "final", "first", "fit", "for", "free",
        "from", "get", "give", "go", "good", "great", "hand", "hard", "has",
        "have", "head", "help", "her", "here", "hold", "home", "how", "if",
        "is", "it", "its", "just", "keep", "kind", "know", "large", "last",
        "late", "law", "lay", "less", "let", "life", "like", "little", "long",
        "look", "made", "make", "man", "many", "may", "mean", "men", "more",
        "most", "much", "must", "name", "need", "new", "next", "night", "no",
        "north", "not", "now", "of", "old", "only", "or", "order", "other",
        "our", "own", "part", "past", "place", "plain", "play", "point",
        "poor", "put", "quick", "rare", "read", "real", "rich", "rough",
        "round", "run", "same", "say", "school", "sea", "see", "self", "sell",
        "send", "set", "she", "show", "shut", "slow", "so", "soft", "some",
        "sound", "south", "speed", "spot", "stand", "start", "stay", "still",
        "stop", "strong", "such", "sun", "sure", "take", "talk", "tall",
        "team", "tell", "than", "that", "the", "their", "them", "then",
        "there", "these", "they", "thin", "think", "this", "those", "through",
        "time", "to", "too", "town", "true", "try", "turn", "use", "used",
        "very", "view", "wait", "walk", "want", "war", "warm", "was", "way",
        "we", "wear", "week", "west", "wet", "what", "when", "where", "which",
        "while", "white", "who", "whole", "why", "wide", "wild", "will",
        "wind", "with", "word", "world", "would", "write", "wrong", "year",
        "yes", "young",
    ]
}
