# Dynamic Outline

## Intent
Show a live heading outline of the current document. Click a heading to navigate to
it; drag a heading to reorder its section — rewriting the underlying Markdown
atomically with a snapshot taken first.

## Scores
Value 4 / Verifiability 4 / Blast radius 3 / Dep depth 2 → priority 2.67

## Acceptance criteria

1. Parse: given Markdown text, `OutlineParser.parse()` returns an ordered list of
   headings with level (1–6), text, and the line range of the heading line itself.
2. Hierarchy: an `OutlineNode` tree encodes parent-child relationships: a heading of
   level N is a child of the nearest preceding heading of level < N. Level-1
   headings are roots.
3. Section boundaries: the section owned by a heading spans from that heading's
   line through to (but not including) the next heading of equal or higher level
   (or end of document).
4. Click-to-navigate: selecting a heading in the outline scrolls the editor so that
   heading is at the top of the viewport.
5. Drag-to-reorder: dragging a heading in the outline moves its entire section
   (heading + content) to the drop position's line boundary, rewriting the document
   text. The move is atomic — a single undo step after the text replacement.
6. The outline view is a sidebar panel, toggled via a toolbar button (list.bullet
   icon) and a Writer menu item.
7. The outline updates live as the document text changes (debounced, same 1.2 s
   cadence as autosave).
8. An empty document or a document with no headings shows "No headings" in the
   panel.
9. The parser is a pure function in Sources/Core, tested in KitibTests. No
   AppKit/UIKit dependency.

## Out of scope

- Renaming headings via the outline
- Filtering or searching the outline
- Auto-numbering headings
- Multi-document outline
- Persisting outline state across sessions
- Snapshot storage (A2/A3 not yet implemented — undo is via NSTextView's built-in
  undo manager)
- The reference sidebar (pinned PDFs, glossary, citations) — that is a separate
  future feature

## Test plan

- Unit tests (KitibTests):
  - parseOutline: empty doc, doc with no headings, single heading, multiple
    headings at mixed levels, headings with inline formatting (bold, code, links),
    ATX headings with closing #, setext headings
  - buildHierarchy: flat list (all same level), nested (H1 > H2 > H3), sibling
    groups at same level, level skip (H2 after H4)
  - sectionRange: heading at start, middle, end of document; adjacent headings
  - moveSection: move to earlier position, later position, top, bottom; move a
    nested section (children follow); move to within own section (no-op or beep);
    move preserves surrounding text (text before first heading, text after last
    heading)
  - Round-trip: parse → move → reparse produces consistent heading order
- Manual check (T4): drag feel, scroll animation, live update cadence

## Failure modes

- Moving a section into itself produces an infinite loop or corrupts the document
- Heading text with Markdown formatting (e.g. `## **Bold** heading`) is misparsed
- Setext headings (underlined with === or ---) are missed
- A heading inside a fenced code block is parsed as a real heading
- Drag-and-drop on iOS conflicts with scroll in a way that loses the drop
- Outline update during active typing causes visual jitter
- Section boundary off-by-one: the moved section loses its first line or swallows
  the preceding heading
- Concurrent modification: user types while a drag is in progress

## Rollback
Not required (blast radius 3). The feature writes to the editor text, which is
covered by NSTextView/UITextView undo. If the outline panel is removed, the only
loss is the UI — no data is persisted.
