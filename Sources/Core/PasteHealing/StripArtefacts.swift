import Foundation

/// Page furniture must recur at least this many times across the pasted span
/// before it is treated as furniture.
///
/// Criterion 5 forbids single-occurrence pattern matching outright. Three rather
/// than two because the two failures are not symmetric: under-stripping leaves a
/// page number the writer can see and delete, while over-stripping deletes
/// content and the result reads as correct (failure mode 4).
private let artefactRecurrenceThreshold = 3

/// Page furniture is short. A long line is prose, whatever it recurs like.
private let maxFurnitureLength = 72

/// Remove page numbers, running headers and running footers from pasted text.
///
/// Spec: specs/paste-healing.md criterion 5. Second in the locked pipeline
/// order (D20), deliberately BEFORE `unwrapLines`: page furniture is only
/// removable while it is still line-isolated, which is why the blueprint's
/// original order made this criterion unsatisfiable.
///
/// Detection is by RECURRENCE, never by a single-occurrence pattern match. A
/// line is furniture only if all of the following hold:
///
/// * it is ISOLATED — blank or absent line on both sides. Page furniture is
///   separated from the body by the page break that produced it, so this is
///   what distinguishes it from a phrase legitimately repeated inside prose
///   (failure mode 4). It also makes deleting a line out of the middle of a
///   paragraph structurally impossible;
/// * it carries at least one DIGIT. Running furniture is paginated; a repeated
///   defined term is not;
/// * it is short, and is neither structural markup nor a clause citation
///   (failure mode 3: `411.3.3` eaten as a page number leaves the prose intact
///   and the citation unanchored);
/// * its digit-normalised form recurs at least `artefactRecurrenceThreshold`
///   times, so `Page 1 of 9` and `Page 2 of 9` count as the same furniture.
///
/// Known limit, recorded rather than papered over: furniture NOT separated from
/// the body by a blank line survives. That is the conservative direction — the
/// page number stays visible in the text instead of a body line disappearing.
///
/// - Parameter input: text with glyphs already repaired
/// - Returns: text with recurring page furniture removed
public func stripArtefacts(_ input: String) -> String {
    let hadTrailingNewline = input.hasSuffix("\n")
    var lines = input.components(separatedBy: "\n")
    if hadTrailingNewline { lines.removeLast() }

    let keys = lines.indices.map { artefactKey(at: $0, in: lines) }

    var counts: [String: Int] = [:]
    for case let key? in keys { counts[key, default: 0] += 1 }

    var kept: [String] = []
    var droppedSinceLastKept = false
    for (line, key) in zip(lines, keys) {
        if let key, counts[key, default: 0] >= artefactRecurrenceThreshold {
            droppedSinceLastKept = true
            continue
        }
        // Furniture is blank-isolated, so removing it leaves two blank lines
        // where the source had one paragraph break. Swallow one: the writer
        // should not have to tidy up after the page break either.
        if droppedSinceLastKept, isBlankLine(line),
           kept.last.map(isBlankLine) ?? true {
            droppedSinceLastKept = false
            continue
        }
        kept.append(line)
        droppedSinceLastKept = false
    }

    var result = kept.joined(separator: "\n")
    if hadTrailingNewline { result += "\n" }
    return result
}

/// The recurrence key for one line, or `nil` if the line can never be furniture.
private func artefactKey(at index: Int, in lines: [String]) -> String? {
    let line = lines[index]
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    guard !trimmed.isEmpty, trimmed.count <= maxFurnitureLength else { return nil }

    let previousIsBoundary = index == lines.startIndex || isBlankLine(lines[index - 1])
    let nextIsBoundary = index == lines.count - 1 || isBlankLine(lines[index + 1])
    guard previousIsBoundary, nextIsBoundary else { return nil }

    guard !LineShape.isStructural(line) else { return nil }
    guard !LineShape.isClauseCitation(trimmed) else { return nil }
    guard trimmed.contains(where: { $0.isNumber }) else { return nil }

    return normalisedFurnitureKey(trimmed)
}

/// Collapses digit runs to `#` and whitespace runs to a single space, so a
/// running header whose page number changes still keys as one repeated line.
private func normalisedFurnitureKey(_ trimmed: String) -> String {
    var key = ""
    var previousWasDigit = false
    var previousWasSpace = false
    for character in trimmed {
        if character.isNumber {
            if !previousWasDigit { key.append("#") }
            previousWasDigit = true
            previousWasSpace = false
        } else if character.isWhitespace {
            if !previousWasSpace { key.append(" ") }
            previousWasSpace = true
            previousWasDigit = false
        } else {
            key.append(character)
            previousWasDigit = false
            previousWasSpace = false
        }
    }
    return key
}

/// A line that is empty or whitespace only — a block boundary.
func isBlankLine(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).isEmpty
}
