# New File / New Folder target the selected folder

Source: user report 2026-08-31 (iPad). Build order: after D78. Status: **DRAFT — awaiting human approval.**

## Intent

Creating a new file or folder from the toolbar/menu always lands in the vault root,
forcing the writer to move it afterwards. The intent: New File and New Folder target
the folder currently selected in the navigator, so creating inside a subfolder is one
step. The plumbing already exists (`AppState.newFile/newFolder` take an `in:` folder);
the prominent call sites just never pass one.

## Ground truth (read from code)

- `SidebarView.swift:64,69` — header `doc.badge.plus` / `folder.badge.plus` buttons call
  `state.newFile(named: "Untitled", contents: "")` and `state.newFolder(named: "New Folder")`
  with no folder: always root.
- `KitibCommands.swift:23` — ⌘N "New Document" → `state.newFile(...)` with no folder: root.
- `ContentView.swift:114` — template picker → `state.newFile(...)` with no folder: root.
- `SidebarView.swift:355-356` — context menu "New File Here" / "New Folder Here" pass
  `in: item.url`. Already correct on BOTH platforms (not gated). This is the reference
  behaviour.
- `AppState.swift:657,681` — `newFile(named:contents:in:)` / `newFolder(named:in:)`,
  `folder ?? rootURL`. The API is ready; nothing else changes.
- `SidebarView.swift:84` — `List(selection: $selectedRowID)`; folder rows are selectable
  (highlight only, per the comment at :92-93). Selection is the signal.
- iPhone browser (`FileBrowser_iOS.swift:372`) already creates in the current directory.
  Unchanged.

## Scores

Per `build-plan.md` §4.1. Tier: **AMBER** — changes where an existing command writes
(a public behaviour). Instructed by the human 2026-08-31 ("DO THREE FIRST"). Not RED:
no data-model change, no file-format change, no sync, no new dependency.

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | One step instead of create-then-move; the reported friction goes away. |
| Verifiability | 4 | Target resolution is a pure Core function, unit-testable. Call-site wiring is not (D16). |
| Blast radius | 2 | Touches where 3 call sites write; the context-menu path and `newFile` itself are untouched. |
| Dependency depth | 1 | `newFile(in:)` exists and is tested by use. Nothing else must exist first. |

## Acceptance criteria

Each independently testable.

1. **Folder selected.** With a folder row selected in the sidebar, the header `doc.badge.plus`
   creates the new file inside that folder (any depth, not just top level).
2. **Folder selected, folder creation.** With a folder row selected, the header
   `folder.badge.plus` creates the new folder inside it.
3. **File selected.** With a file row selected, the new file/folder goes into that file's
   parent folder. [RULING NEEDED: parent folder, or root? Proposed default: parent — "create
   where I am working".]
4. **⌘N parity.** New Document (⌘N) uses the same target rule as the header buttons.
5. **Template picker parity.** A template chosen from the picker creates in the same target.
6. **Nothing selected.** No selection → root, exactly today's behaviour.
7. **Context menus unchanged.** "New File Here" / "New Folder Here" keep working verbatim.
8. **Unchanged mechanics.** Uniquing (D72), open-after-create, autosave, recents, word goals:
   all identical to today.
9. **No vault open.** The empty state is unchanged; the header buttons do not exist there.
10. **Both targets build** (macOS + iOS); suite green.

## Out of scope

- **Surfacing newFile/newFolder write failures** (parked AMBER 2026-08-14; separate).
- **A "New File in…" location picker sheet** — not needed once selection targets the folder.
- **iPhone browser** — already creates in the current directory.
- **iPad navigator drag-and-drop** (user request 2) and **Pencil squiggle** (request 1):
  separate tasks, own sessions, own specs.
- **macOS right-click menus** — already correct.

## Design

One pure Core helper + one AppState bridge + three call sites.

- `NewFileTarget` (Sources/Core/FileNaming/NewFileTarget.swift): pure function
  `target(selectedID: String?, selectedIsDirectory: Bool?, rootURL: URL) -> URL?`.
  - `selectedIsDirectory == true` → `rootURL.appendingPathComponent(selectedID)` (the
    selected folder's URL; `selectedID` is the full path per D4).
  - `selectedIsDirectory == false` → that URL's `deletingLastPathComponent()` (parent).
  - `selectedIsDirectory == nil` (no selection, or the id no longer resolves) → `rootURL`.
  - `rootURL == nil` → `nil` (guard; unreachable via UI, the buttons only exist with a vault).
  No filesystem access; the caller resolves the item.
- AppState bridge (documented pattern: `scrollToHeading`, `replaceTableText`):
  `var newFileTargetProvider: (() -> URL?)?` registered by SidebarView; computed
  `var newFileTarget: URL?` calls it, falling back to `rootURL`. KitibCommands and
  ContentView use `state.newFileTarget` so ⌘N and the template picker see the sidebar's
  selection without AppState owning the List selection state (which stays in SidebarView,
  D74/D75 untouched).
- Call sites: SidebarView header buttons (:64, :69) resolve the selection and pass `in:`;
  KitibCommands :23 and ContentView :114 pass `in: state.newFileTarget`.

## Test plan

- **NewFileTargetTests** (Tests/KitibTests/FileNaming/NewFileTargetTests.swift, Core so it
  is in the test bundle): nil selection → root; folder selection at depth 1 and depth 3 →
  that folder; file selection → its parent; nil root → nil; unresolvable id → root; root
  itself selected → root; folder selected whose id lacks the root prefix (id invented) →
  treated by caller, helper never touches disk. No fixtures needed: pure string/URL
  arithmetic, no filesystem (mirrors UniqueName's style, 12 tests).
- **Build verification:** both schemes compile; suite green (no behavioural change to any
  tested Core transform).
- **Manual (human):** iPad — select subfolder, tap +, file lands inside; select a file,
  tap +, file lands in its parent; ⌘N with folder selected; template picker with folder
  selected. macOS — same checks.

## Failure modes

1. **Selected folder renamed or deleted since the tree refresh.** `findItem` returns nil;
   the target falls back to root instead of writing into a stale path. Guard: resolve
   against the live tree, not the id alone; nil → root.
2. **Selection points at a smart-folder row or anything without a FileItem.** Same guard;
   nil → root. (Currently unreachable: List selection only binds file/folder rows.)
3. **No selection.** Must be root, not the last-used folder; the rule is stateless per
   action, so the writer always knows where the file lands.
4. **Selected folder at depth 3.** Must be that folder, not an ancestor. Guard: use the
   selected URL verbatim, never walk up unless the selection is a file.
5. **Selected file whose parent is the root.** Parent rule collapses to root; the file is
   created at root, which is correct and visible.

## Named entities

- `NewFileTarget` — struct with one static pure function; Sources/Core/FileNaming/NewFileTarget.swift.
- `AppState.newFileTargetProvider` — closure set by SidebarView (bridge pattern).
- `AppState.newFileTarget` — computed `URL?`.
- Call sites: SidebarView.swift :64/:69, KitibCommands.swift :23, ContentView.swift :114.
- Tests: Tests/KitibTests/FileNaming/NewFileTargetTests.swift.
