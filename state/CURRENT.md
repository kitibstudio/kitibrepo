# CURRENT.md: the single active task. Rewritten each session. Cap: 40 lines.

## THIS SESSION: dogfood bug report — two findings (2026-09-05)

Not the previously-queued Apple Pencil/Problems-panel work — a dogfood report
came in with two screenshots and took priority.

1. **macOS: "Reopen" hangs on a large vault.** Diagnosed as the compounding
   of two already-PARKED performance items (eager `FileItem` tree walk +
   main-thread FTS5 rebuild), both triggered synchronously and un-debounced
   the moment `rootURL` is assigned. Human authorized the RED fix. Implemented
   as D84: both the tree walk and the index rebuild now run on a background
   `vaultQueue`, guarded by a `vaultGeneration` counter so a superseded pass
   can't clobber a newer one. Verified: both targets build, suite still
   548/548 with only the pre-existing `NewFileTargetTests` failure. NOT
   verified: an actual large/iCloud vault on a real Mac — human check needed.
2. **iPad: app not filling the screen.** Confirmed with the human this is
   Stage Manager (on, on that iPad) giving the app a small windowed default,
   not an app bug — multi-window/Stage Manager support is explicitly unbuilt
   (GAP.md N11). No code change. Logged to PARKED.md with the shape a real
   fix would take (an explicit default window size for iPad's windowed mode,
   AMBER) if it recurs.

## NEXT: two independent queued tasks, unchanged from before this session

1. Human: approve `specs/apple-pencil.md` + rule on its Open RED (target bump
   16.0 → 17.5 for Slice D). Then build Slice A or B.
2. Problems panel slice 2 — inline underlines (specs/problems-panel.md).

## Gotchas carried forward

- D84: `rebuildSearchIndex`'s "first query never empty" guarantee (D73) is now
  soft, not hard — the immediate-rebuild path is also async. A search issued
  the instant a very large folder opens can transiently see an empty index.
- `FileItem.children` MUST stay set-once (only in `init`/`loadChildren`) — D84's
  off-main-thread walk relies on that invariant. Grep before adding any other
  `.children =` assignment.
- Ask "is Stage Manager on?" before diagnosing any iPad "wrong size / doesn't
  fill screen" report — it looks exactly like a layout bug and isn't one.
- PRE-EXISTING RED (unchanged): NewFileTargetTests
  testSelectedFileAtDepthThreeTargetsDepthTwoParent. Human decides.
- D50: SwiftTerm.Color shadows SwiftUI.Color in the macOS target; spell
  SwiftUI.Color explicitly in new macOS views.
- New content in state files stays em-dash-free.
- Uncommitted, unrelated to this session's fix: `.disabled(state.currentFileURL
  == nil)` on the Problems toggle/button across KitibCommands + both
  DetailViews — pre-existed at session start, not reviewed or touched here.
