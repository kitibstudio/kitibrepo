# Paste Healing Preview Toggle

Source: `docs/blueprint-v2.md` §2.4 "the paste hook itself, the paste raw / paste healed
preview toggle, and undo integration" — named as explicitly out of scope in T1-T3.
Spec: this document. Version: **0.2 — gaps resolved.**
Status: **DRAFT — awaiting human approval.**

## Intent

`PasteHealer.heal(_:)` exists and passes 136 tests but has zero call sites. The writer
pastes from a PDF, standard, or Word document and gets broken text. This feature
intercepts paste, runs the heal pipeline, and shows a preview of raw vs healed text
before committing — so the writer can see what changed and reject over-healing before
it becomes document text. The pipeline is the safety net; the preview is the
confirmation gate.

## Scores

Per `build-plan.md` §4.1 convention. This is GREEN-tier under the change-authority
rules (§4): internal implementation, same interfaces, no new dependencies, no
file-format changes.

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Turns 136 passing tests into an actually usable feature. Paste is the dominant input path for technical drafting (§2.4). |
| Verifiability | 5 | Pure UI wiring over a tested pure function. The heal transform is already deterministically correct; the toggle either shows the diff or it doesn't. |
| Blast radius | 2 | Adds a paste hook on both platforms, but the hook only fires a String→String transform before inserting. Cannot corrupt documents on disk. The raw paste is always shown alongside the healed version; rejecting it inserts the raw text. |
| Dependency depth | 1 | `PasteHealer.heal(_:)` is done and tested. Nothing else must exist first. |

## Architecture decisions — LOCKED

Resolved before build. Do not re-litigate.

**A. Paste interception: custom text-view subclasses, not delegate swizzling.**

Both platforms use a lightweight subclass that overrides `paste(_:)` and forwards
to the Coordinator. `paste(_:)` is the single entry point called by ⌘V, Edit → Paste,
tap → Paste, and accessibility — no secondary hooks needed.

- macOS: `PasteInterceptingTextView: NSTextView` — created in `EditorView.makeNSView`
  instead of the plain `NSTextView` currently instantiated. Overrides `paste(_:)`.
- iOS: `PasteInterceptingTextView: UITextView` — created in `EditorView.makeUIView`
  instead of the plain `UITextView`. Overrides `paste(_:)`.

The `isPasting` flag on the Coordinator is the re-entry guard (failure mode 1):
if the flag is already `true` when `paste(_:)` fires, call `super.paste(_:)` and
return — this handles the case where the accepted/rejected text insertion itself
triggers a second paste event.

**B. Undo: single `insertText` call, naturally one group.**

On NSTextView, `insertText(_:replacementRange:)` creates a single undo group by
default. On UITextView, `insertText(_:)` does the same within a single
`shouldChangeTextIn` cycle. No `beginUndoGrouping()` / `endUndoGrouping()` or
`breakUndoCoalescing()` needed. The implementer must NOT add undo grouping —
doing so would double-group the insertion and break ⌘Z muscle memory.

**C. Diff algorithm: standard LCS line-diff, implemented inline.**

Split both texts into lines. Walk the Longest Common Subsequence to produce aligned
`DiffLine` pairs. No external dependency — the algorithm is ~40 lines of Swift and
lives inside `PastePreviewSheet.swift` as a private helper.

Each output position is one of:
- `.equal` — same line in both. Normal text color.
- `.added` — line present in healed, absent in raw. Green background, no strikethrough.
- `.removed` — line present in raw, absent in healed. Red background, strikethrough.

The two columns are always line-aligned: each DiffLine pair has a raw-side entry
(may be empty for `.added`) and a healed-side entry (may be empty for `.removed`).

**D. Visual treatment of diff lines.**

- `.equal`: system label color, no background.
- `.added`: system green background at 15% opacity, no strikethrough. Monospaced font.
- `.removed`: system red background at 15% opacity, strikethrough. Monospaced font.

Colors adapt to the app's active appearance via `@Environment(\.colorScheme)`.
The entire diff area uses `.monospacedSystemFont(size: 11)` so columns align.

**E. Sheet sizing.**

- macOS: `.frame(minWidth: 480, minHeight: 280)`, resizable. Matches the table grid
  editor pattern.
- iOS: `.presentationDetents([.medium, .large])` with `.presentationDragIndicator(.visible)`.

## Acceptance criteria

Each criterion is independently testable.

1. **Paste is intercepted on macOS.** When the user presses ⌘V (or Edit → Paste), the
   clipboard text is captured before insertion via `PasteInterceptingTextView.paste(_:)`.
   The raw text is stored, the heal pipeline runs, and a preview sheet opens. No text
   enters the document until the user accepts or rejects.

2. **Paste is intercepted on iOS.** When the user pastes (tap → Paste, or ⌘V with a
   hardware keyboard), `PasteInterceptingTextView.paste(_:)` fires. The same preview
   flow fires. The preview sheet uses `.medium` and `.large` detents.

3. **Preview shows a side-by-side diff with color coding.** Raw on the left, healed on
   the right, aligned line by line via LCS. Removed lines (in raw, not in healed):
   red background + strikethrough. Added lines (in healed, not in raw): green
   background. Equal lines: normal.

4. **Accept inserts healed text with undo support.** Tapping "Paste Healed" calls
   `acceptPastePreview()`, which inserts `PasteHealer.heal(raw)` via
   `insertAtCaret`. Single ⌘Z undoes the entire insertion.

5. **Reject inserts raw text.** Tapping "Keep Raw" calls `rejectPastePreview()`, which
   inserts the original raw text via `insertAtCaret`. Single ⌘Z undoes it.

6. **Cancel does nothing.** Dismissing the sheet (Escape on macOS, swipe-down on iOS,
   or clicking outside) calls `dismissPastePreview()`. The document is unchanged.

7. **Short pastes skip the preview.** If the pasted text has `count <= 80` AND
   `rangeOfCharacter(from: .newlines) == nil`, the preview is skipped: `paste(_:)`
   calls `super.paste(_:)` directly. The heal pipeline is NOT run.

8. **The preview is optional.** A persisted `showPastePreview` toggle (UserDefaults,
   default `true`) appears in the toolbar (icon: `bandage`). When off,
   `paste(_:)` calls `super.paste(_:)` directly — no interception, no pipeline.

9. **Determinism.** The preview shows the same healed output as `PasteHealer.heal()`
   produces in tests — same code path, no preprocessing.

10. **Undo works correctly.** After accepting healed text, a single ⌘Z undoes the
    entire insertion. After rejecting, a single ⌘Z undoes the raw insertion. The
    preview itself writes nothing to the undo stack.

## Out of scope

Explicitly **not** built in this task:

- **Silent auto-heal on paste.** The preview IS the safety gate.
- **Heal-in-place on existing text.** Paste-only.
- **Any change to the six transforms or their order** — D20 locked.
- **Any change to the fixture corpus or paste-healing tests.**
- **Provenance metadata** on healed text (source file, page number) — needs A4 block IDs.
- **Per-source-class profiles** for different heuristics.
- **Localisation** of the preview sheet strings.

## Test plan

Transform tests are unchanged. New tests cover the UI integration:

- **PasteHealerTests (unchanged):** 136 existing tests continue to pass.
- **PastePreviewStateTests (new):** Unit tests for `shouldSkipPastePreview`:
  - 80 chars, no newline → `true`
  - 80 chars with one newline → `false`
  - 81 chars, no newline → `false`
  - Empty string → `true`
  - Multiline text, any length → `false`
- **DiffLineTests (new):** Unit tests for the LCS diff function:
  - Identical strings → all `.equal`
  - One added line → one `.added`
  - One removed line → one `.removed`
  - Single-line change (same count) → one `.added` + one `.removed`
  - Completely different texts → all `.added` + all `.removed`
  - Empty raw, non-empty healed → all `.added`
  - Non-empty raw, empty healed → all `.removed`
- **Manual verification:** Paste a multi-page PDF extract on each platform. Confirm
  preview opens, diff colors correct, accept/reject/cancel all work, undo works,
  toggle hides preview, short paste skips preview.

Expected total: 136 (existing) + 5 (skip logic) + 7 (diff) = 148 tests.

## Failure modes

What "subtly wrong but plausible" looks like here.

1. **Paste hook fires twice.** `paste(_:)` fires, preview opens, user accepts,
   `insertAtCaret` calls `insertText(_:replacementRange:)` — which on NSTextView is
   NOT `paste(_:)`, so it does not recurse. But if the text view subclass somehow
   routes insertions through paste, the `isPasting` flag on the Coordinator catches
   it: `if coordinator.isPasting { super.paste(sender); return }`.

2. **⌘V bypasses the subclass.** `paste(_:)` on `NSResponder`/`UIResponder` is the
   single action method for paste. ⌘V, Edit → Paste, tap → Paste, and accessibility
   all route through it. The subclass override covers all of them.

3. **Clipboard text mutates between interception and reject.** The raw text is
   captured into `pastePreviewText` on `AppState` before showing the sheet.
   `acceptPastePreview()` and `rejectPastePreview()` read from `pastePreviewText`
   and `pastePreviewHealed` — they NEVER re-read `NSPasteboard.general` or
   `UIPasteboard.general`.

4. **Short-paste skip fires on a clause citation.** `"411.3.3 Protection against electric shock"` is
   44 characters, no newline — criterion 7 would skip the preview. This is correct:
   `preserveClauseNumbers` has nothing to do in a raw paste context (the text isn't
   a Markdown list yet), and the other five transforms are no-ops on a single short
   line. The writer can toggle preview back on if they want to see the (identity)
   output.

5. **iOS paste via drag-and-drop bypasses the hook.** `UITextView` handles drops
   through `paste(itemProviders:)` on `UITextPasteDelegate`, not `paste(_:)`. The
   spec does NOT intercept drag-and-drop or share-sheet paste — only the primary
   paste path. These alternate paths behave as they do today (raw paste).

6. **Diff misaligns on different line counts.** The LCS diff handles insertions and
   deletions correctly. When `stripArtefacts` removes page furniture lines (fewer
   lines in healed), the algorithm produces `.removed` entries for the raw side and
   `.equal` for everything else — no downstream misalignment.

## Rollback

The transform is untouched. The preview UI is self-contained: two AppState properties,
one SwiftUI sheet, and a text-view subclass on each platform. Rollback is: revert the
commit. The paste hook disappears and paste returns to its current behaviour. No
document on disk is affected.

## Named entities

Fixed here so later sessions use these exact identifiers and do not invent variants.

- `PasteInterceptingTextView` (macOS) — `NSTextView` subclass in `EditorView.swift`.
  Stores a weak reference to the Coordinator. Overrides `paste(_:)`.
- `PasteInterceptingTextView` (iOS) — `UITextView` subclass in `EditorView_iOS.swift`.
  Same pattern.
- `showPastePreview` — AppState `@Published var`, persisted in UserDefaults,
  default `true`. The toolbar toggle.
- `pastePreviewText` — AppState `@Published var` holding the raw paste text.
  Set by `paste(_:)`; `nil` when no preview is active.
- `pastePreviewHealed` — AppState computed property:
  `{ PasteHealer.heal($0) }(pastePreviewText ?? "")`. Returns `nil` when
  `pastePreviewText` is `nil`.
- `acceptPastePreview()` — AppState method. Inserts healed text via `insertAtCaret`,
  sets `pastePreviewText = nil`.
- `rejectPastePreview()` — AppState method. Inserts raw text via `insertAtCaret`,
  sets `pastePreviewText = nil`.
- `dismissPastePreview()` — AppState method. Sets `pastePreviewText = nil`.
  Inserts nothing.
- `isPasting` — `Bool` flag on both `EditorView.Coordinator` types. Set `true`
  before showing the preview, set `false` after accept/reject/cancel. The
  `paste(_:)` override checks this flag first.
- `shouldSkipPastePreview(_ raw: String) -> Bool` — static function on
  `PasteHealer`. Returns `true` when `raw.count <= 80 &&
  raw.rangeOfCharacter(from: .newlines) == nil`.
- `DiffLine` — enum with cases `.equal`, `.added`, `.removed`. Private to
  `PastePreviewSheet.swift`.
- `computeDiff(raw: String, healed: String) -> [(DiffLine, String?, String?)]`
  — private function in `PastePreviewSheet.swift`. LCS-based line diff.
- `PastePreviewSheet` — cross-platform SwiftUI view in
  `Sources/Shared/PastePreviewSheet.swift`. Takes `raw: String`,
  `healed: String`, `onAccept`, `onReject`, `onCancel`. macOS:
  `.frame(minWidth: 480, minHeight: 280)`. iOS:
  `.presentationDetents([.medium, .large])`.
- Location: `Sources/Shared/PastePreviewSheet.swift` for the sheet view.
  AppState additions in `Sources/Shared/AppState.swift`. Subclasses inline in
  `EditorView.swift` and `EditorView_iOS.swift`.

## Implementation tasks — single session

The transform is done and tested. This is purely wiring.

1. **PasteHealer + AppState.** Add `shouldSkipPastePreview` to `PasteHealer`.
   Add `showPastePreview`, `pastePreviewText`, `pastePreviewHealed`,
   `acceptPastePreview()`, `rejectPastePreview()`, `dismissPastePreview()` to
   AppState. Write `PastePreviewStateTests` (~5 cases).

2. **Differ + PastePreviewSheet.** Implement the LCS diff (`computeDiff`,
   `DiffLine` enum). Build `PastePreviewSheet` with the side-by-side diff view,
   three buttons, appearance-aware colors. Write `DiffLineTests` (~7 cases).
   Files: `Sources/Shared/PastePreviewSheet.swift`,
   `Tests/KitibTests/PasteHealing/PastePreviewStateTests.swift`,
   `Tests/KitibTests/PasteHealing/DiffLineTests.swift`.

3. **macOS paste hook.** Create `PasteInterceptingTextView` subclass in
   `EditorView.swift`. Override `paste(_:)`: check `isPasting`, `showPastePreview`,
   `shouldSkipPastePreview`; if preview needed, capture clipboard string, set
   `pastePreviewText`, set `isPasting = true`; else call `super.paste(_:)`.
   Wire sheet in `DetailView_macOS.swift` to `pastePreviewText != nil`.

4. **iOS paste hook.** Same subclass pattern in `EditorView_iOS.swift`.
   Wire sheet in `DetailView_iOS.swift` to `pastePreviewText != nil`.

5. **Toolbar toggle.** Add `bandage` icon button to macOS toolbar and iOS menu.
   Toggles `showPastePreview`. Help text: "Paste healing preview — shows raw vs
   healed text before committing."

6. **Regenerate and run.** `xcodegen generate` then full `xcodebuild test`.
   Suite must be green at 148 tests.
