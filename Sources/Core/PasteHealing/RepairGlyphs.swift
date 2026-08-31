import Foundation

/// Repair mangled glyphs common in pasted text.
///
/// Covers: fi/fl ligature expansion, smart-quote normalisation, dash
/// normalisation, invisible-space removal, and recovery of common
/// engineering symbols (°, Ω, ²) from double-encoded UTF-8 forms.
///
/// Per D20 this is the FIRST transform in the PasteHealer pipeline —
/// it normalises encoding before anything else matches on characters.
///
/// - Parameter input: raw pasted text
/// - Returns: text with glyphs repaired
public func repairGlyphs(_ input: String) -> String {
    var result = input

    // Ligature expansion — single-character → two characters
    result = result.replacingOccurrences(of: "\u{fb01}", with: "fi")  // ﬁ → fi
    result = result.replacingOccurrences(of: "\u{fb02}", with: "fl")  // ﬂ → fl

    // Smart quote normalisation — all smart variants → straight
    // Left double quotes
    result = result.replacingOccurrences(of: "\u{201c}", with: "\"")  // " → "
    result = result.replacingOccurrences(of: "\u{201e}", with: "\"")  // „ → "
    // Right double quotes
    result = result.replacingOccurrences(of: "\u{201d}", with: "\"")  // " → "
    result = result.replacingOccurrences(of: "\u{201f}", with: "\"")  // ‟ → "
    // Single quotes → apostrophe
    result = result.replacingOccurrences(of: "\u{2018}", with: "'")   // ' → '
    result = result.replacingOccurrences(of: "\u{2019}", with: "'")   // ' → '
    result = result.replacingOccurrences(of: "\u{201a}", with: "'")   // ‚ → '
    result = result.replacingOccurrences(of: "\u{201b}", with: "'")   // ‛ → '

    // Dash and hyphen normalisation.
    result = result.replacingOccurrences(of: "\u{2014}", with: "-")   // — em dash → -
    result = result.replacingOccurrences(of: "\u{2013}", with: "-")   // – en dash → -
    // U+2010 HYPHEN and U+2011 NON-BREAKING HYPHEN look identical to a plain
    // hyphen-minus but are different code points. PDFs emit them constantly.
    // Leaving them breaks criterion 3: "low‐voltage" with U+2010 is NOT the
    // protected compound "low-voltage", so the lexicon never matches it.
    result = result.replacingOccurrences(of: "\u{2010}", with: "-")   // ‐ → -
    result = result.replacingOccurrences(of: "\u{2011}", with: "-")   // ‑ → -

    // Double-encoded UTF-8 recovery — common in PDF paste. MUST run before the
    // invisible-space handling below: double-encoded NBSP is "Â" + NBSP, so if
    // the bare NBSP were converted first, the stray "Â" would be left behind.
    // °: UTF-8 C2 B0 → double-encoded C3 82 C2 B0 → Â° → recover to °
    result = result.replacingOccurrences(of: "\u{00c2}\u{00b0}", with: "\u{00b0}")
    // Ω: UTF-8 CE A9 → double-encoded → Î© → recover to Ω
    result = result.replacingOccurrences(of: "\u{00ce}\u{00a9}", with: "\u{03a9}")
    // ²: UTF-8 C2 B2 → double-encoded C3 82 C2 B2 → Â² → recover to ²
    result = result.replacingOccurrences(of: "\u{00c2}\u{00b2}", with: "\u{00b2}")
    // NBSP: UTF-8 C2 A0 → double-encoded → "Â" + NBSP → recover to one space.
    result = result.replacingOccurrences(of: "\u{00c2}\u{00a0}", with: " ")

    // Invisible space handling.
    // NBSP becomes a REGULAR SPACE, not nothing: in this corpus every NBSP is a
    // value/unit separator (1000 kVA, 50 Hz, 240 mm², 300 A). Deleting it yields
    // 1000kVA / 50Hz / 300A — silent corruption that reads as correct and that
    // the unit-system work (N19, N30) would later inherit. See D23.
    result = result.replacingOccurrences(of: "\u{00a0}", with: " ")   // NBSP → space
    // ZWSP carries no width and no meaning — genuinely removed.
    result = result.replacingOccurrences(of: "\u{200b}", with: "")    // ZWSP → removed

    return result
}
