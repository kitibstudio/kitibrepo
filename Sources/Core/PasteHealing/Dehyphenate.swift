import Foundation

/// Rejoin a word that was split across a line break by the source's
/// hyphenation, without touching a compound that was always hyphenated.
///
/// Spec: specs/paste-healing.md criterion 2. Fourth in the locked pipeline
/// order (D20), after `unwrapLines` — which rejoins a hyphen-terminated line
/// with NO space, so a split word arrives here as `transfor-mer` in the middle
/// of a line with its hyphen still attached, and this is the transform
/// entitled to rule on that hyphen.
///
/// This is failure mode 1, the signature failure of the whole feature:
/// `star-delta` rejoined to `stardelta` is a valid-looking word, one character
/// from the truth, in a diff nobody will catch by reading. Every guard below
/// therefore errs towards KEEPING the hyphen. A hyphen wrongly kept is visible
/// and costs one keystroke; a hyphen wrongly removed is invisible and wrong.
///
/// A hyphen is removed only when all of these hold:
///
/// * the whole whitespace-delimited token carries no digit — `Model-T-1000-K`,
///   `Table 4-2` and `11kV/415V` are never touched;
/// * no protected compound appears anywhere in the token (criterion 3), which
///   also covers `spec-XLPE/SWA/PVC-must`, the shape em dashes leave behind
///   after `repairGlyphs` normalises them (D24);
/// * the fragment before the hyphen is two or more letters, is not an acronym
///   in capitals, and is not a word in `CommonWords`;
/// * the fragment after the hyphen starts with a lowercase letter — a split
///   word continues in lowercase, so `Model-T` and `spec-XLPE` are excluded;
/// * the JOINED form (left + right, with trailing punctuation stripped) is a
///   known word in `RejoinableWords` — this is the inverted rule: positive
///   evidence is required before a hyphen is removed.  An unknown joined
///   form keeps its hyphen, because under-healing is visible and costs a
///   keystroke while over-healing reads as correct and is not.
///
/// A split spanning an actual line break is left alone. `unwrapLines` decides
/// whether a block is hard-wrapped; if it declined to rejoin one, this
/// transform does not overrule it.
///
/// - Parameter input: text with glyphs repaired, furniture stripped, lines unwrapped
/// - Returns: text with source hyphenation undone
public func dehyphenate(_ input: String) -> String {
    var result = ""
    var token = ""
    for character in input {
        if character.isWhitespace {
            if !token.isEmpty {
                result += dehyphenateToken(token)
                token = ""
            }
            result.append(character)
        } else {
            token.append(character)
        }
    }
    if !token.isEmpty { result += dehyphenateToken(token) }
    return result
}

/// Rules on every hyphen inside one whitespace-delimited token.
private func dehyphenateToken(_ token: String) -> String {
    guard token.contains("-") else { return token }

    // A token carrying a digit is a rating, a model number or a citation, not
    // a hyphenated word: `Model-T-1000-K-rated`, `4-2`, `-300`.
    guard !token.contains(where: { $0.isNumber }) else { return token }

    let lowered = token.lowercased()
    for compound in ProtectedCompounds.compounds
    where lowered.contains(compound.lowercased()) {
        return token
    }

    let parts = token.components(separatedBy: "-")
    guard parts.count >= 2 else { return token }

    var out = parts[0]
    for index in 1..<parts.count {
        let left = parts[index - 1]
        let right = parts[index]
        out += shouldRejoin(left: left, right: right) ? right : "-" + right
    }
    return out
}

/// Whether the hyphen between these two fragments was put there by the
/// source's line breaking rather than by the writer.
///
/// Every guard errs towards KEEPING the hyphen.  A hyphen wrongly kept is
/// visible and costs one keystroke; a hyphen wrongly removed reads as
/// correct and is not.  The final gate — the joined form must be a known
/// word — is the most important: it inverts the old default (fuse unless
/// the leading fragment is a common word) to require positive evidence
/// before destroying a hyphen.
private func shouldRejoin(left: String, right: String) -> Bool {
    // `e-mail`: a single letter is never half of a broken word.
    guard left.count >= 2, left.allSatisfy({ $0.isLetter }) else { return false }

    // `PVC-sheathed`: an acronym is a word.
    guard left != left.uppercased() else { return false }

    // A split word continues in lowercase. `Model-T`, `spec-XLPE`.
    guard let first = right.first, first.isLetter, first.isLowercase else { return false }

    // Criterion 2's second clause: `three-phase`, `short-circuit`, `self-contained`.
    guard !CommonWords.contains(left) else { return false }

    // The inverted rule (human ruling 2026-08-11): the joined form must
    // be a known word.  Strip trailing punctuation so "transfor-mer."
    // resolves, then consult the lexicon.  An unknown joined form keeps
    // its hyphen — under-healing is visible, over-healing is not.
    let joined = left + right
    let word = String(joined.reversed().drop(while: { !$0.isLetter }).reversed())
    guard RejoinableWords.contains(word) else { return false }

    return true
}
