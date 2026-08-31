import Foundation

/// Rejoin lines that were hard-wrapped at a source column width.
///
/// Spec: specs/paste-healing.md criterion 1. Third in the locked pipeline order
/// (D20), after `stripArtefacts` so page furniture is gone before anything is
/// merged into a paragraph.
///
/// The transform is deliberately reluctant. A rejoin that should not have
/// happened destroys structure and reads as correct prose (failure modes 2 and
/// 5); a rejoin that should have happened but did not leaves visibly broken
/// lines that the writer can fix in one keystroke. So a block is only unwrapped
/// when it actually looks hard-wrapped, and inside such a block a rejoin needs
/// every one of these:
///
/// * both lines are prose — not blank, not a heading, list item, block quote,
///   fence, rule, pipe row, or whitespace-aligned column (failure mode 2);
/// * the following line does not open with a clause citation, so `411.3.3`
///   still starts the line it started on;
/// * the preceding line does not end a sentence. This is the guard against
///   failure mode 5 — a paragraph that ends near the wrap column never merges
///   into the next one;
/// * the text accumulated so far reaches the block's wrap column, so a short
///   standalone line (a plain-text title, a fragment) is not swallowed.
///
/// A line ending in `-` rejoins with NO space, leaving `star-delta` and
/// `transfor-mer` intact for the lexicon (criterion 3) and for `dehyphenate`
/// (T3), which is the transform entitled to decide about the hyphen.
///
/// - Parameter input: text with glyphs repaired and page furniture removed
/// - Returns: text with hard-wrapped paragraphs rejoined
public func unwrapLines(_ input: String) -> String {
    // Pre-split continuous text at lettered list markers so that
    // "for: a) circuits ... excluded. b) circuits ..." becomes
    // "for:\na) circuits ...\nexcluded.\nb) circuits ..."
    // Only fires on single-line input (≤1 newline) — structured documents
    // with proper line breaks are left alone.
    let newlineCount = input.filter { $0 == "\n" }.count
    let split: String
    if newlineCount <= 1 {
        split = splitLetterItems(splitBlockOpeners(input))
    } else {
        split = input
    }

    let hadTrailingNewline = split.hasSuffix("\n")
    var lines = split.components(separatedBy: "\n")
    if hadTrailingNewline { lines.removeLast() }

    var output: [String] = []
    var index = 0
    while index < lines.count {
        if isBlankLine(lines[index]) {
            output.append(lines[index])
            index += 1
            continue
        }
        var end = index
        while end < lines.count, !isBlankLine(lines[end]) { end += 1 }
        let block = Array(lines[index..<end])
        let separable = isSeparable(block)
        // A one-line segment — a heading, a lone clause title — has no margin of
        // its own. The block it came from does, and that is the column the
        // segment was set in.
        let blockMargin = wrapMargin(of: block)
        // Each segment is unwrapped on its own, and the boundary BETWEEN two
        // segments is judged on the evidence the segment that ended carries —
        // its margin, and the last source line folded into its final line.
        var previous: UnwrappedSegment?
        // The last margin actually measured in this block. A page is set in one
        // body column, so for a segment too short to show a margin of its own
        // the nearest measured one is a better estimate than the block's — the
        // block's is skewed by whichever segment is set widest, which is
        // precisely the NOTE in smaller type that segmenting exists to isolate.
        var lastMeasured: BlockMargin?
        for segment in blockSegments(block) {
            let unwrapped = unwrapBlock(segment, fallback: lastMeasured ?? blockMargin)
            if unwrapped.margin.measured { lastMeasured = unwrapped.margin }
            if let previous, separable, let opener = unwrapped.lines.first,
               needsBlankSeparator(
                   after: previous.lastSource,
                   before: opener,
                   margin: previous.margin
               ) {
                output.append("")
            }
            output.append(contentsOf: unwrapped.lines)
            previous = unwrapped
        }
        index = end
    }

    // Insert blank lines before list markers so the Markdown preview
    // renders consecutive items as separate paragraphs rather than
    // one continuous block of text.
    output = separateListItems(output)

    var result = output.joined(separator: "\n")
    if hadTrailingNewline { result += "\n" }
    return result
}

/// Second pass over the output: insert blank lines before list-marker lines
/// that follow prose, so the Markdown preview renders them as separate
/// paragraphs. Tracks fenced code blocks so lines inside fences (which may
/// look like list markers) are never modified.
private func separateListItems(_ lines: [String]) -> [String] {
    var out: [String] = []
    var inFence = false
    for (i, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Track fence state
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            inFence.toggle()
            out.append(line)
            continue
        }
        guard !inFence else { out.append(line); continue }

        if i > 0, LineShape.isListMarker(trimmed) {
            let prevTrimmed = lines[i - 1].trimmingCharacters(in: .whitespaces)
            if prevTrimmed.isEmpty {
                // Already separated.
            } else if !LineShape.isListMarker(prevTrimmed) {
                out.append("")
            } else if LineShape.isLetteredItem(trimmed) {
                // Consecutive `-`, `*`, `1.` and `1)` items are a real Markdown
                // list and stay tight. `a)` and `a.` are NOT list markers in
                // Markdown, so consecutive lettered items render as one
                // soft-wrapped paragraph — the items visibly run together. A
                // blank line makes each one its own block. The marker text is
                // left exactly as pasted: rewriting `a)` to `1.` would renumber
                // the citation, which is failure mode 6.
                out.append("")
            }
        }
        out.append(line)
    }
    return out
}

/// Splits a run of non-blank lines into segments, one per block the source is
/// made of — a list item, a numbered clause, a note.
///
/// A wrap column is a property of a *paragraph*, not of a page, and a standards
/// page has several. A lettered list is indented, so its items wrap short of
/// the prose around them, and a list whose items are mostly one line long
/// (`b) marinas;`) drags the at-margin ratio below the threshold. A NOTE is set
/// in smaller type, so its lines run LONGER than the body's and its margin
/// becomes the whole block's — which puts every body line below the threshold.
/// Either way, measuring the block as a whole finds no usable margin and
/// unwraps nothing, even though each part of it is plainly hard-wrapped.
///
/// Segmenting never loosens a guard: every rejoin still has to satisfy
/// `canRejoin`, and a segment too short to show a margin is left alone.
///
/// A segment starts at each line that opens a block and runs to the line before
/// the next one; any prose ahead of the first opener is its own segment.
private func blockSegments(_ block: [String]) -> [[String]] {
    var segments: [[String]] = []
    var current: [String] = []
    for line in block {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if opensABlock(trimmed), !current.isEmpty {
            segments.append(current)
            current = []
        }
        current.append(line)
    }
    if !current.isEmpty { segments.append(current) }
    return segments
}

/// A line that starts a block of its own in the source: a list item, a numbered
/// clause or table/figure citation, or a note.
///
/// Note that this decides only where a MEASUREMENT starts. Whether a blank line
/// is inserted at the boundary is `needsBlankSeparator`'s decision, so a
/// citation that is genuinely the continuation of the sentence above it still
/// stays on the line it started on, unseparated.
private func opensABlock(_ trimmed: String) -> Bool {
    LineShape.isListMarker(trimmed)
        || LineShape.isClauseCitation(trimmed)
        || isNoteOpener(trimmed)
}

/// `NOTE — …`, `NOTES`, `Note:` — the standards-document aside. It is set in
/// smaller type, so it has its own wrap column, and it is never part of the
/// paragraph above it.
private func isNoteOpener(_ trimmed: String) -> Bool {
    guard trimmed.hasPrefix("NOTE") || trimmed.hasPrefix("Note") else { return false }
    let rest = trimmed.dropFirst(4)
    guard let next = rest.first else { return true }              // exactly "NOTE"
    if next == "S" || next == "s" {                               // "NOTES"
        guard let after = rest.dropFirst().first else { return true }
        return after == " " || after == "-" || after == ":"
    }
    return next == " " || next == "-" || next == ":"
}

/// One segment after unwrapping, with the evidence needed to judge the boundary
/// between it and the segment that follows.
private struct UnwrappedSegment {
    let lines: [String]
    /// The last SOURCE line folded into the final output line. Separation is
    /// judged on its length, never on the accumulated paragraph's: once several
    /// lines are rejoined the accumulated text is always long, which says
    /// nothing about where the source stopped.
    let lastSource: String
    let margin: BlockMargin
}

/// Unwraps one segment.
///
/// A segment of two or three lines cannot show a margin of its own, and losing
/// the one the block has would leave a paragraph hard-wrapped for no better
/// reason than that a heading was measured off it. So the block's margin stands
/// in — it is the column the segment was set in.
private func unwrapBlock(_ block: [String], fallback: BlockMargin) -> UnwrappedSegment {
    let own = wrapMargin(of: block)
    let margin = own.measured ? own : fallback
    let maySeparate = isSeparable(block)

    var out: [String] = []
    var accumulated: String?
    var lastSource = ""
    for line in block {
        guard let current = accumulated else {
            accumulated = line
            lastSource = line
            continue
        }
        if margin.measured, canRejoin(current, with: line, fullLine: margin.fullLine) {
            accumulated = rejoin(current, with: line)
            lastSource = line
        } else {
            out.append(current)
            if maySeparate, needsBlankSeparator(after: lastSource, before: line, margin: margin) {
                out.append("")
            }
            accumulated = line
            lastSource = line
        }
    }
    if let accumulated { out.append(accumulated) }
    return UnwrappedSegment(lines: out, lastSource: lastSource, margin: margin)
}

/// Splits a continuous block of text at the block openers buried inside it, so
/// that "…characteristics. 3.73 Electrically Independent Earth Electrodes — …"
/// becomes two lines.
///
/// A paste copied out of Word or a PDF viewer frequently arrives with NO line
/// breaks at all — the source's are simply not on the clipboard. Everything that
/// gives a clause its own block (`blockSegments`, `opensABlock`,
/// `needsBlankSeparator` signal 4) reads LINES, so with one line there is
/// nothing to segment and a run of numbered definitions renders as one
/// undifferentiated slab: all the text, in the right order, and unusable.
/// Reported 2026-08-13.
///
/// Mid-line evidence is weaker than a line break, so this is deliberately
/// NARROWER than `opensABlock`:
///
/// * the opener must follow a COMPLETED sentence (`.`, `!`, `?`). An ordinary
///   sentence boundary alone is never a split — that is failure mode 5, and it
///   is why a clause CITED inside a sentence ("required by 411.3.3 and by …")
///   is left exactly where it is;
/// * a dotted numeral must be followed by the TITLE it names — `3.73 Electrical`
///   is a definition opener, `0.4 s` is a value in a sentence (failure mode 6);
/// * `NOTE`/`NOTES` count only in capitals, the form standards use for the
///   aside. Lower-case "Note that …" is an ordinary sentence.
///
/// `Table 4-2`, `Clause 5` and the rest of `isClauseCitation`'s vocabulary are
/// deliberately NOT openers here: mid-sentence they are far more often prose
/// ("… as follows. Table 4-2 gives the values.") than the head of a block, and
/// a wrong split cuts a paragraph in half.
///
/// Runs on unlined input only. Text that arrived with its line breaks intact is
/// judged by the line-structured path, whose margin evidence is better than
/// anything a mid-line guess can offer — and which has already been measured
/// against the corpus.
private func splitBlockOpeners(_ text: String) -> String {
    var result = ""
    var index = text.startIndex
    var lastVisible: Character?

    while index < text.endIndex {
        let character = text[index]
        if character == " " || character == "\t",
           let previous = lastVisible, ".!?".contains(previous) {
            var opener = index
            while opener < text.endIndex, text[opener] == " " || text[opener] == "\t" {
                opener = text.index(after: opener)
            }
            if opener < text.endIndex, opensABlockMidLine(window(text, from: opener)) {
                result.append("\n")
                index = opener
                lastVisible = nil
                continue
            }
        }
        result.append(character)
        if character != " " && character != "\t" { lastVisible = character }
        index = text.index(after: index)
    }
    return result
}

/// The first few characters after a candidate boundary — enough for every
/// prefix test below, and bounded so scanning a long paste stays linear.
private func window(_ text: String, from start: String.Index) -> String {
    let end = text.index(start, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
    return String(text[start..<end])
}

/// Does this candidate open a block strongly enough to break a line for it?
/// See `splitBlockOpeners` for why this is narrower than `opensABlock`.
private func opensABlockMidLine(_ candidate: String) -> Bool {
    if candidate.hasPrefix("NOTE"), isNoteOpener(candidate) { return true }
    if candidate.hasPrefix("§") { return true }
    guard LineShape.startsWithDottedNumeral(candidate) else { return false }
    return isTitledClauseNumber(candidate)
}

/// `3.73 Electrical Installation`, `3.76 (Electrode Boiler)` — a dotted numeral
/// followed by the title it names.
///
/// The title is what tells a clause number from a measured value: a clause is
/// followed by a capitalised name, a value by its lower-case unit (`0.4 s`,
/// `1.5 mm²`). Getting this wrong splits a sentence at a number, so the
/// requirement is positive evidence, not the absence of a counter-signal.
private func isTitledClauseNumber(_ candidate: String) -> Bool {
    var index = candidate.startIndex
    while index < candidate.endIndex,
          candidate[index].isNumber || candidate[index] == "." {
        index = candidate.index(after: index)
    }
    guard index < candidate.endIndex, candidate[index] == " " else { return false }
    while index < candidate.endIndex, candidate[index] == " " {
        index = candidate.index(after: index)
    }
    guard index < candidate.endIndex else { return false }
    let first = candidate[index]
    return first.isUppercase || first == "("
}

/// Splits a continuous block of text at lettered list markers so that
/// "for: a) circuits ... excluded. b) circuits" becomes separate lines.
/// Runs before the main unwrap logic; without it a single-line paste with
/// embedded lettered items never fires unwrap at all.
private func splitLetterItems(_ text: String) -> String {
    // Match: any whitespace followed by a single lowercase letter, then
    // ")" or ".", then whitespace. "for: a) circuits" and "like e) fixed"
    // both match. The lookahead guards against "a.c." and "d.c." patterns
    // where the letter is followed by another letter, not whitespace.
    guard let regex = try? NSRegularExpression(
        pattern: "\\s+(?=[a-z][.)]\\s)"
    ) else { return text }

    let ns = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else { return text }

    // Build result by inserting newlines at match positions.
    // Process in reverse so earlier insertions don't shift later ranges.
    var result = text
    for match in matches.reversed() {
        let r = match.range
        if let range = Range(r, in: result) {
            result.replaceSubrange(range, with: "\n")
        }
    }
    return result
}

/// Should a blank line be inserted between two lines that did NOT rejoin?
///
/// This is what makes the render faithful to the paste. A PDF arrives with no
/// blank lines at all: a heading, the paragraph under it, and the note beneath
/// that are all just consecutive lines. Markdown joins consecutive lines into
/// one paragraph, so without this the heading and the note are swallowed into
/// the prose — the text is all present, correctly ordered, and reads as one
/// undifferentiated slab.
///
/// A blank line is inserted only on positive evidence of a boundary — never
/// merely because a rejoin was refused. Two lines left adjacent still render
/// correctly whenever they really were one wrapped paragraph, so the cost of
/// staying quiet is nil and the cost of guessing is a paragraph split in half.
/// Four signals qualify:
///
/// 1. **A label line.** A line that stops at a FRACTION of the margin without
///    finishing a sentence is a title, not a wrap: `1 SCOPE`, `3.88 Fire`.
///    Merely falling short is not enough — justified type sets many an ordinary
///    wrapped line a few characters short, and breaking there splits a
///    definition in half.
/// 2. **A label line ahead.** The previous line completed its sentence and the
///    line after it is a label — the same title, seen from the paragraph above.
/// 3. **A finished list item followed by prose.** The item ended its sentence
///    and what follows is not another item, so the list is over.
/// 4. **A new clause or note.** A clause citation or a `NOTE` opening a line
///    after a completed sentence starts the block it names.
/// 5. **A lead-in.** A line ending in a colon introduces what follows; the
///    introduction is its own paragraph.
///
/// Signals 1 and 2 are margin evidence and need a block that actually has a
/// margin — in a pile of short fragments with no wrap column, a short line
/// means nothing. Signals 3, 4 and 5 are structural and hold regardless.
///
/// Nothing is inserted where a construct needs its lines kept adjacent, or
/// where the renderer already treats the lines as separate blocks.
private func needsBlankSeparator(
    after previousSource: String,
    before next: String,
    margin: BlockMargin
) -> Bool {
    let prev = previousSource.trimmingCharacters(in: .whitespaces)
    let following = next.trimmingCharacters(in: .whitespaces)
    guard !prev.isEmpty, !following.isEmpty else { return false }

    // Table rows must stay contiguous: detectTables is fifth in the locked
    // order (D20) and sees this output. A blank line between two aligned rows
    // is a table split in half — failure mode 2 by another route.
    if prev.contains("|") || following.contains("|") { return false }
    // Both sides, not either: a whitespace table needs three aligned rows, so a
    // column-aligned line next to an ordinary one cannot be part of one. Only
    // one side aligned is a heading padded with spaces, which does need the
    // break.
    if LineShape.hasColumnGap(previousSource), LineShape.hasColumnGap(next) { return false }

    // Headings, rules, quotes and fences are already their own block to a
    // renderer. A blank line adds nothing and would not round-trip.
    if rendersAsItsOwnBlock(prev) || rendersAsItsOwnBlock(following) { return false }

    // A real Markdown list renders as separate items already, and separating
    // them would turn a tight list loose. Lettered items are not a Markdown
    // list at all, so they still need the blank (D40).
    if LineShape.isListMarker(prev), LineShape.isListMarker(following),
       !LineShape.isLetteredItem(following) {
        return false
    }

    let previousIsFinished = LineShape.endsSentence(previousSource)
    let previousIsLabel = !previousIsFinished && visibleLength(previousSource) <= margin.label

    // 1 — a label line: a fragment of a line, and not a finished sentence.
    if margin.measured, previousIsLabel { return true }

    // 2 — a label line ahead of a finished paragraph.
    if margin.measured, previousIsFinished,
       visibleLength(next) <= margin.label, !LineShape.endsSentence(next) { return true }

    // 3 — a finished list item, then something that is not an item.
    if previousIsFinished, LineShape.isListMarker(prev), !LineShape.isListMarker(following) {
        return true
    }

    // 4 — a new clause or note after a finished sentence.
    if previousIsFinished, LineShape.isClauseCitation(following) || isNoteOpener(following) {
        return true
    }

    // 5 — a lead-in: "such as those of:" introduces what comes next.
    if prev.hasSuffix(":") { return true }

    // 6 — a padded heading: `1.3   Installation of Premises`. The run of spaces
    // is the tab that set the title away from its number, and the line below it
    // is ordinary prose. (Two aligned lines in a row were already excluded
    // above as a possible table.)
    if !previousIsFinished, LineShape.hasColumnGap(previousSource) { return true }

    // NOT a signal: a finished sentence followed by a new one, both at the
    // margin. That is where one paragraph ends and the next begins — and it is
    // also the middle of a single justified paragraph. Nothing in the clipboard
    // text tells the two apart (the PDF marks it with leading and indentation,
    // neither of which survives the copy), so the two paragraphs are left
    // adjacent and render as one. Text and order are intact; only the break is
    // lost. Guessing here would split paragraphs in half all over the corpus —
    // failure mode 5 — which is the worse error.
    return false
}

/// A line a Markdown renderer already begins a new block on.
private func rendersAsItsOwnBlock(_ trimmed: String) -> Bool {
    if trimmed.hasPrefix("#") { return true }
    if trimmed.hasPrefix(">") { return true }
    if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { return true }
    return LineShape.isHorizontalRule(trimmed)
}

/// Whether blank lines may be inserted inside this block at all.
///
/// Two constructs carry their meaning in the adjacency of their lines and are
/// destroyed by a blank line inserted anywhere within them: a fenced code block
/// (the blank becomes a blank line of code, or worse, splits the fence from its
/// body) and YAML frontmatter, whose short `key: value` lines would otherwise
/// look exactly like the deliberate breaks this pass is hunting for. Both are
/// recognised by their delimiter, and the whole block is left alone.
private func isSeparable(_ block: [String]) -> Bool {
    for line in block {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { return false }
        if LineShape.isHorizontalRule(trimmed) { return false }
    }
    return true
}

/// What a block's right margin says about it.
private struct BlockMargin {
    /// The wrap column: the longest prose line in the block.
    let column: Int
    /// The block actually looks hard-wrapped — several lines end close to the
    /// same column. Only a measured block is ever rejoined.
    let measured: Bool
    /// Within 20% of the wrap column counts as a full line.
    var fullLine: Int { fullLineThreshold(column) }
    /// At most half the column: a title, not a wrapped line that fell short.
    var label: Int { column / 2 }
}

/// Measure the block's right margin.
///
/// A hard-wrapped block has one: several of its lines end close to the same
/// column. Text with no such margin — a web paste of short fragments, a two-line
/// note — has no wrap to undo, and rejoining it would be invention rather than
/// repair, so `measured` stays false and the block is never rejoined. It still
/// carries a column, because separation has to reason about one either way.
private func wrapMargin(of block: [String]) -> BlockMargin {
    let lengths = block
        .filter { !LineShape.isStructural($0) && !LineShape.hasColumnGap($0) }
        .map(visibleLength)
    guard lengths.count >= 3, let longest = lengths.max() else {
        return BlockMargin(column: lengths.max() ?? 0, measured: false)
    }

    let atMargin = lengths.filter { $0 >= fullLineThreshold(longest) }
    let measured = atMargin.count >= 3 && atMargin.count * 2 >= lengths.count
    return BlockMargin(column: longest, measured: measured)
}

/// Within 20% of the wrap column counts as a full line. Wide enough that a long
/// word forcing an early break still counts, narrow enough that a short
/// standalone line does not.
private func fullLineThreshold(_ measure: Int) -> Int {
    measure - measure / 5
}

private func canRejoin(_ current: String, with next: String, fullLine: Int) -> Bool {
    // CRLF text is left entirely alone: the line content would end in a stray
    // carriage return, and deciding what to do with it is not this task's.
    if current.hasSuffix("\r") || next.hasSuffix("\r") { return false }

    // A list-marker line (a), 1., - item) may have content after the marker
    // that continues across hard-wrapped lines. Other structure does not.
    if LineShape.isStructural(current) && !LineShape.isListMarker(current.trimmingCharacters(in: .whitespaces)) { return false }
    if LineShape.hasColumnGap(current) { return false }

    if LineShape.isStructural(next) || LineShape.hasColumnGap(next) { return false }

    let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
    if LineShape.isClauseCitation(nextTrimmed) { return false }

    if LineShape.endsSentence(current) { return false }

    // A colon introduces what follows. `1.3.1 … as given below:` and the
    // paragraph under it are two blocks, however close to the margin the
    // lead-in ends, and merging them buries the introduction mid-sentence.
    if trimmingTrailingSpaces(current).hasSuffix(":") { return false }

    // Measured on the text accumulated so far, not on the last source line.
    // Once a paragraph is under way it continues to its sentence end, which is
    // what makes the transform idempotent: a second pass sees one long line
    // that already ends where the first pass decided it ended.
    return visibleLength(current) >= fullLine
}

private func rejoin(_ current: String, with next: String) -> String {
    let left = trimmingTrailingSpaces(current)
    let right = String(next.drop(while: { $0 == " " || $0 == "\t" }))
    // A word split at the line end keeps its hyphen and gains no space.
    if left.hasSuffix("-") { return left + right }
    return left + " " + right
}

private func trimmingTrailingSpaces(_ line: String) -> String {
    var out = line
    while let last = out.last, last == " " || last == "\t" { out.removeLast() }
    return out
}

/// Length in characters, ignoring surrounding whitespace — what a wrap column
/// is measured in.
private func visibleLength(_ line: String) -> Int {
    line.trimmingCharacters(in: .whitespaces).count
}
