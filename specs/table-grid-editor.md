# N8 Table Grid Editor

Source: `docs/blueprint-v2.md` §2.1. Data layer: `specs/table-model.md` (Stage 3 — built).
Build order: `docs/build-plan.md` Stage 3, T4.

## Intent

Project the `MarkdownTable` model into a SwiftUI editable grid. Click/tap a cell to
edit inline. Changes serialize back to valid Markdown, replacing the table text in
the underlying editor. The Markdown source stays canonical; the grid is a preview
and editing surface only. Cross-platform (macOS + iOS/iPadOS) — the same SwiftUI
grid view on both, differing only in how it is presented.

## Scores

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Tables are painful in raw Markdown; a grid editor removes the #2 friction for technical authors. |
| Verifiability | 4 | Grid → model → serialize → byte compare. Human-visible UI behaviour harder to test than pure data. |
| Blast radius | 3 | Touches both editor views (macOS NSTextView, iOS UITextView) and introduces a new shared view. |
| Dependency depth | 1 | `MarkdownTable` is already built and tested. |

**Priority = 4 × 4 ÷ (3 × 1) = 5.33.** Blast radius < 4 ⇒ no rollback plan.

## Acceptance criteria

1. **Grid rendering.** A SwiftUI view renders a `MarkdownTable` as an editable grid:
   headers in a distinct row (bold), data rows below, alignment indicators visible
   per column.
2. **Cell editing.** Tapping/clicking a cell enters edit mode (inline `TextField`).
   Committing the edit (Return or focus loss) updates the cell in the model and
   re-serializes. Escape discards the edit.
3. **Round-trip.** Editing a cell and serializing produces valid Markdown that
   re-parses to the same grid state.
4. **Cross-platform.** macOS presents the grid as a resizable sheet window.
   iOS presents it as a sheet. The grid view itself has zero platform conditionals.
5. **Source stays canonical.** The NSTextView/UITextView contains the Markdown pipe
   table text. The grid is a projection — closing the grid leaves the source
   updated with the serialized table.

## Out of scope (this session)

- Row/column add/delete buttons in the grid UI (model supports it; UI deferred)
- Drag-to-reorder rows/columns
- Paste from Excel/Numbers
- CSV import/export
- Column-width resizing
- Multi-line cell editing
- Inline grid (embedding the grid inside the text view) — popover/sheet only for now

## Data flow

```
NSTextView/UITextView
    │ cursor in table?
    ▼
findTableRange(in: text, cursorPosition: Int) → NSRange?
    │
    ▼
MarkdownTableParser.parse(tableText) → MarkdownTable
    │
    ▼
TableGridEditor(table: Binding<MarkdownTable>)  ← SwiftUI
    │ user edits cell
    ▼
table.serialize() → String
    │
    ▼
Replace NSRange in text view with serialized string
```

## Named entities

- `TableGridEditor` — SwiftUI `View` in `Sources/Shared/TableGridEditor.swift`.
  Takes `@Binding MarkdownTable`, presents editable grid.
- `findTableRange(in:text:Int, cursorPosition:Int) -> NSRange?` — helper in
  `Sources/Core/TableModel/MarkdownTable.swift`. Finds the extent of the Markdown
  pipe table containing `cursorPosition`. Returns nil when cursor is not inside
  a table.
- macOS: popover triggered from `EditorView.Coordinator`, anchored to the table's
  text rect in the NSTextView.
- iOS: sheet triggered from `EditorView_iOS`, presented when cursor enters a table
  and user activates the grid button.

## Test plan

- **Grid model tests** (KitibTests): existing `MarkdownTableTests` already cover
  parse/serialize/mutate. No new data-layer tests needed.
- **Table-range detection tests**: `findTableRange` unit tests — cursor inside
  table returns range, cursor outside returns nil, cursor on delimiter row, cursor
  in surrounding text, table at start/end of document.
- **Integration smoke**: manual verification on macOS — open a document with a
  table, open the grid, edit a cell, confirm the source updates. Same on iOS.
- Full automated UI tests are out of scope (XCUITest needs an app host, and
  KitibTests is a logic-test bundle per D16).

## Failure modes

1. **Table not detected.** Cursor inside a table but `findTableRange` returns nil
   — grid never opens, user thinks the feature is broken.
2. **Wrong range.** `findTableRange` returns a range that includes non-table text
   (surrounding paragraphs) or truncates the table (missing rows).
3. **Serialization drift.** Grid edits produce Markdown that doesn't round-trip —
   alignment lost, column count changes, cells corrupted.
4. **Focus fight.** Popover steals focus from NSTextView and doesn't return it
   cleanly, leaving the editor in a broken state.
5. **iOS sheet dismiss.** Dismissing the sheet on iOS without committing the last
   edit — the cell edit is lost.
