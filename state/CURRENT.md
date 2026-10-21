# CURRENT.md: the single active task. Rewritten each session. Cap: 40 lines.

## LAST SESSION: D85 macOS App Sandbox for TestFlight Validate (2026-10-21)

Validate failed with "App sandbox not enabled" on `Kitib.app/Contents/MacOS/Kitib`.
Fixed on branch `cursor/macos-app-sandbox-7ffb`: XcodeGen entitlements for
`Kitib-macOS` (`Resources/Kitib-macOS.entitlements`) with app-sandbox +
user-selected read-write + bookmarks app-scope. `navigateUp()` aligned for
sandbox. No PR opened (coordinator asked for local/branch fix + Sean steps).

## NEXT: two independent queued tasks

1. Human: approve `specs/apple-pencil.md` + rule on its Open RED (target bump
   16.0 → 17.5 for Slice D). Then build Slice A or B.
2. Problems panel slice 2 — inline underlines (specs/problems-panel.md).

## Gotchas carried forward

- D85: entitlement keys in `project.yml` must be YAML-quoted or xcodegen
  writes an empty entitlements plist.
- D85: integrated terminal under MAS sandbox is PARKED — no temporary
  exceptions added.
- D84: `rebuildSearchIndex`'s "first query never empty" guarantee (D73) is now
  soft, not hard — the immediate-rebuild path is also async.
- `FileItem.children` MUST stay set-once — D84 off-main-thread walk.
- Ask "is Stage Manager on?" before diagnosing iPad "wrong size" reports.
- PRE-EXISTING RED: NewFileTargetTests
  testSelectedFileAtDepthThreeTargetsDepthTwoParent.
- D50: SwiftTerm.Color shadows SwiftUI.Color in the macOS target.
- Uncommitted, unrelated: `.disabled(state.currentFileURL == nil)` on the
  Problems toggle across KitibCommands + both DetailViews — left unstaged.
