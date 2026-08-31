import Foundation

/// A clause number is this many digits wide before it is treated as a citation
/// rather than a list marker.
///
/// This is the discriminator for failure mode 6, and it is a judgement about
/// which mistake is survivable. `411. Protection for safety` pasted from a
/// standard is a citation: Markdown reads `411.` as an ordered-list marker and
/// renders it as `1.`, destroying the number the citation is made of while the
/// prose still reads perfectly. An ordered list that reaches a hundred items
/// barely exists — and if one does, its first ninety-nine items are untouched
/// and item one hundred renders as the text `100.`, which is what it looked
/// like anyway. A two-digit marker is genuinely ambiguous and is left alone.
private let clauseNumberDigits = 3

/// Keep a leading clause number as the text it is, rather than letting Markdown
/// consume it as list markup.
///
/// Spec: specs/paste-healing.md criterion 6. Last in the locked pipeline
/// order (D20).
///
/// Both directions of failure mode 6 matter and they pull against each other —
/// a numbered list must stay a list, and a clause number must stay a number:
///
/// * `411.3.3`, `§7.2` and `Table 4-2` are already text to Markdown and are
///   returned untouched. `stripArtefacts` may not delete them
///   (`LineShape.isClauseCitation`) and `unwrapLines` may not pull them into
///   the line above, so by the time they reach here they simply have to be
///   left alone;
/// * `411. Protection for safety` IS list markup to Markdown. Its marker
///   punctuation is escaped — `411\. Protection for safety` — which renders as
///   the clause number exactly as pasted;
/// * `1. Isolate the supply.` is a real list and is never touched.
///
/// Escaping is idempotent: `411\.` is no longer an ordered-list marker, so a
/// second pass does not escape it again.
///
/// - Parameter input: text with all five preceding transforms applied
/// - Returns: text in which clause numbers survive as clause numbers
public func preserveClauseNumbers(_ input: String) -> String {
    let hadTrailingNewline = input.hasSuffix("\n")
    var lines = input.components(separatedBy: "\n")
    if hadTrailingNewline { lines.removeLast() }

    var output: [String] = []
    var insideFence = false
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            insideFence.toggle()
            output.append(line)
            continue
        }
        if insideFence {
            output.append(line)
            continue
        }
        output.append(escapingClauseMarker(line) ?? line)
    }

    var result = output.joined(separator: "\n")
    if hadTrailingNewline { result += "\n" }
    return result
}

/// The line with its clause marker escaped, or `nil` if it carries none.
private func escapingClauseMarker(_ line: String) -> String? {
    let indent = line.prefix(while: { $0 == " " })
    // Four spaces is an indented code block; its content is quoted verbatim
    // and must not be rewritten.
    guard indent.count < 4 else { return nil }

    let rest = line.dropFirst(indent.count)
    let digits = rest.prefix(while: { $0.isNumber })
    guard digits.count == clauseNumberDigits else { return nil }

    let afterDigits = rest.dropFirst(digits.count)
    guard let marker = afterDigits.first, marker == "." || marker == ")" else { return nil }

    // `411.3.3` has a digit after the dot, not a space: already text, not markup.
    let afterMarker = afterDigits.dropFirst()
    guard afterMarker.first == " " else { return nil }

    // A marker with nothing after it is not a clause heading.
    guard afterMarker.contains(where: { !$0.isWhitespace }) else { return nil }

    return String(indent) + String(digits) + "\\" + String(marker) + String(afterMarker)
}
