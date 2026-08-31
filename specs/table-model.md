# Markdown Table Model & Parser

Source: `docs/blueprint-v2.md` §2.1. Build order: `docs/build-plan.md` Stage 3.

## Intent

Parse a Markdown pipe table into an editable grid model. Edit cells, add and
remove rows and columns. Serialize back to valid, well-formatted Markdown.
The Markdown source stays canonical; the grid is a projection. This is the
data layer only — no UI.

## Scores

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Tables are the second-most painful thing to edit in raw Markdown (after links). |
| Verifiability | 5 | Pure String → model → String. Golden fixtures fully determine correctness. |
| Blast radius | 2 | Read-only parse + in-memory model. Wrong serialization is visible immediately. |
| Dependency depth | 1 | Nothing must exist first. |

**Priority = 4 × 5 ÷ (2 × 1) = 10.0.** Blast radius < 4 ⇒ no rollback plan.

## Acceptance criteria

1. **Parse.** A valid Markdown pipe table parses into a `MarkdownTable` with the
   correct cell contents, column count, and alignment per column.
2. **Fenced and unfenced.** Tables with leading/trailing `|` on every line AND
   tables without them both parse correctly. Mixed styles are tolerated.
3. **Alignment.** The delimiter row (`:---`, `:---:`, `---:`) determines the
   alignment for each column.
4. **Edit a cell.** Changing a cell's text and serializing regenerates the
   Markdown table with that cell updated.
5. **Add a row.** Inserting a row before or after a given index updates the
   grid and the serialized output includes the new row.
6. **Delete a row.** Removing a row (except the delimiter row, which is
   structural) updates the grid and output.
7. **Add a column.** Inserting a column left or right of a given index adds
   a new column to every row and the delimiter row (default left-aligned).
8. **Delete a column.** Removing a column removes it from every row and the
   delimiter.
9. **Round-trip.** Parse a table → serialize without edits → byte-identical
   Markdown.
10. **Surrounding text.** The table parser extracts only the table rows;
    text before and after is preserved for the caller to reassemble.

## Out of scope

- **UI** — no SwiftUI grid, no cell editing widget, no drag-to-reorder.
- **Paste from Excel/Numbers** — needs clipboard integration (Stage 3+).
- **CSV import/export** — separate feature.
- **Tables without a delimiter row** — detectTables (paste healing) handles
  those; this parser requires a valid delimiter row.
- **Multi-line cells** — cells span a single line only.
- **Escaped pipes** (`\|`) inside cells — treated as literal text for now.

## Test plan

- **Golden fixtures:** a corpus of `.md` table files + expected grid model
  snapshots (row count, column count, alignments, cell contents).
- **Round-trip tests:** parse → serialize → assert byte-identical.
- **Mutation tests:** edit cell, add/delete row, add/delete column → assert
  serialized output matches expected.
- **Edge cases:** empty cells, single-column tables, single-row tables,
  tables with only whitespace in cells, mixed alignment, inconsistent column
  counts (graceful handling).

## Failure modes

1. **Column-count mismatch.** A row has fewer cells than the header — the
   parser pads or truncates silently, shifting data into wrong columns.
2. **Delimiter-row removal.** The user deletes the row that IS the delimiter —
   serialization must still produce valid Markdown (insert a default delimiter).
3. **Whitespace trimming.** The parser strips whitespace from cells, losing
   intentional leading/trailing spaces.
4. **Alignment loss.** Editing a cell and re-serializing changes the delimiter
   row alignment markers.
5. **Invisible corruption.** A cell containing `|` (pipe character) is split
   into two cells on parse, silently destroying data.

## Named entities

- `MarkdownTable` — struct: `headers: [String]`, `alignments: [Alignment]`,
  `rows: [[String]]`, `columnCount: Int`.
- `Alignment` — enum: `left`, `center`, `right`.
- `MarkdownTableParser.parse(_ raw: String) -> (before: String, table: MarkdownTable, after: String)?`
  — extracts the first table from Markdown text. Returns nil if no valid table
  found. Surrounding text is preserved.
- `MarkdownTable.serialize() -> String` — renders the table back to Markdown.
- `MarkdownTable` mutating methods: `setCell(row:col:text:)`, `insertRow(at:)`,
  `deleteRow(at:)` (refuses to delete the delimiter), `insertColumn(at:)`,
  `deleteColumn(at:)`.
- Location: `Sources/Core/TableModel/`. Tests: `Tests/KitibTests/TableModel/`.
