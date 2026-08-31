# CURRENT.md — the single active task. Rewritten each session. Cap: 40 lines.

## COMPLETED this session — no vault work at launch (2026-08-17) — D77

Reported as a dock bounce on macOS launch plus "I want a simple open button".
Both had one cause: `AppState.init()` restored the persisted root, which walked
the whole tree and indexed every file into FTS5 inside `App.init()`, before the
first window existed. The persisted root here was `/`, so launch was enumerating
the entire filesystem. That same auto-restore hid all four existing "Open
Folder…" buttons, every one of which is gated on no folder being open.

init() now reads only the folder *name*. `reopenLastFolder()` sits behind a
"Reopen “name”" button beside "Open Folder…" in all three empty states. A folder
button was added to the SidebarView header beside the D76 chevron.up. Two
duplicate walk+index passes removed from the restore path (didSet already did
both). Both targets build, 403/403 green. Ruled RED by the human before build.

## NEEDS A HUMAN CHECK — launch and open (D77)

1. Launch the app cold. The window must appear immediately with NO dock bounce,
   showing "No folder open" with two buttons. This is the whole point.
2. Click Reopen “/” — it opens, and this WILL be slow, because the root is `/`.
   Recommend using Open Folder… to pick a real vault instead; the reopen offer
   then names that one.
3. With a folder open: the sidebar header shows ↑ then a folder icon. The folder
   icon opens the picker. Cancelling it leaves the open document untouched.
4. iPad: same header check — this is the only in-app route to another folder.
5. macOS only: verify the empty state LOOKS right (iPad now verified below).

## COMPLETED this session — iPad menu bar (2026-08-17) — D78

Reported: the iOS File menu held only "Close Window". `KitibCommands` lived in
Sources/macOS/, which the iOS target does not compile, and `.commands` was
inside `#if os(macOS)`. Moved to Sources/Shared/KitibCommands.swift and applied
on both platforms; Print and Terminal stay macOS-gated (their implementations
are macOS-only). Five colliding `.keyboardShortcut` modifiers removed from the
DetailView_iOS toolbar — the menu owns them now. Both build, 403/403 green.

## NEEDS A HUMAN CHECK — iPad menu bar (D78)

1. iPad with a hardware keyboard: File must now hold New Document (⌘N), Open
   Folder… (⌘O), Save (⌘S) — not just Close Window. Check Edit (Find), the
   Writer menu, and Help too.
2. ⌘N on iPad now creates an Untitled document instead of opening the template
   picker — deliberate, for macOS parity. Templates are still on the toolbar
   doc.badge.plus button, now without a shortcut. Confirm that trade is what you
   wanted.
3. Confirm no shortcut fires twice (⇧⌘F focus, ⇧⌘L line numbers, ⇧⌘P preview,
   ⇧⌘D to-dos).

## VERIFIED VISUALLY — iPad, this session

D77's empty state was rendered on an iPad Pro 11 M4 simulator: "Open Folder…"
prominent, and "Reopen “Field Notes”" beside it once a previous root was seeded.
Launch reaches the window immediately with no folder open. The menu bar itself
could NOT be captured — it needs a held ⌘ and simctl cannot send key events.

## STILL OUTSTANDING — earlier human checks

- D76 up-navigation: the relaunch step ("reopens at the last parent") is
  SUPERSEDED by D77 — it now offers to reopen instead. The other steps stand.
- iPad sidebar selection (D75); macOS sidebar click + lag (D73, D74).

## NEXT — human ruling, before any Stage 5 code

Authorise swift-markdown for Sources/Core + KitibTests: yes, not yet, or no?
Written up as the Open RED in specs/rules-engine.md. Recommendation: not yet.

## Gotchas carried forward

- PagePlan protects TOP-LEVEL blocks only; standardPrintInfo() sets ZERO margins.
- FTS5 splits hyphenated terms; a saved query for one errors unless quoted.
- iPad in portrait reports .regular width; the sidebar collapses until toggled.
- PARKED still: background indexing (RED), lazy FileItem (AMBER) — no longer
  launch blockers after D77, but they still bite when opening a huge folder.
