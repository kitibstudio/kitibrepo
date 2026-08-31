# UI Conventions

Locked UI rules for this project. Read this **before** building or changing any
view. It is short on taste and long on traps: every rule here was paid for by a
defect that shipped, and each one names the decision that recorded it.

**These are locked.** Changing one is RED under CLAUDE.md §4 — park it, do not
re-litigate it in code. Adding a new rule after a new defect is the intended way
this file grows.

---

## 0. The one that outranks the others

**A view is not verified because it compiles, and not because the suite is
green.** `Sources/Shared` is outside the `KitibTests` bundle by design (D16),
so no UI in this project is regression-tested. A green 304-test run says
nothing about anything on this page.

Two consequences, both non-negotiable:

- **Never report UI work as done on the strength of reading the code.** Reading
  SwiftUI is how the stretched header row, the invisible z-order defect and the
  translucent-card collision all got through review and none got through a
  render.
- **Say plainly which parts were verified and which were not.** "Renders
  correctly, gesture unverified" is a useful report. "Done" is not.

---

## 1. How UI actually gets verified here

### 1.1 Static appearance — render it

Compile a copy of the view into a throwaway binary and render it with
`ImageRenderer`, then *look at the PNG*. This is the standard check and it is
cheap. Pattern (see the table editor and outline sessions):

- `sed` the real source into a scratch copy — never hand-copy a view into a
  preview file, or the preview drifts from the thing it claims to check.
- Render **every state**, not the happy one: idle, mid-interaction, the invalid
  case, empty, and one oversized layout (iPad width).
- `MainActor.assumeIsolated { }` to render from a plain script.
- Render **twice** and keep the second image — the first pass is what lets
  preferences and `onAppear` land.

`ImageRenderer` limits, all confirmed the hard way:

| It cannot | Do this instead |
|---|---|
| Snapshot `ScrollView`, `Menu` or `TextField` content | `sed` `ScrollView {` → `Group {` in the scratch copy |
| Advance animation time | Drop `.animation(value:)` on anything whose *content* changes (text), or it renders the stale value |
| Deliver `@State` set from a live gesture | Add a `previewX` injection property in the scratch copy only |
| Draw `.buttonStyle(.borderless)` or a `TextField` — both come out as a yellow ⃠ block | Prefer `.plain` with an explicit accent colour, which renders and looks the same on macOS. A control you cannot render is a control you cannot check |
| Show a `.sheet` | Render the sheet's root view directly; drop `private` off it in the scratch copy |

Verify a suspected renderer artefact with a **probe** — a five-line view holding
the suspect control beside a known-good one — before changing anything. The
yellow ⃠ blocks above were nearly "fixed" as a real defect.

If a value the view depends on is measured at runtime (row frames, viewport
width), print it to stderr from the scratch copy first, then feed the real
measured numbers back in. A preview built on invented geometry checks the
drawing and nothing else — say so when reporting it.

### 1.2 Gestures — you cannot verify these; a human must

Touch injection into the Simulator needs Accessibility permission the agent
environment does not have (`AXIsProcessTrusted() == false`), and `KitibTests`
has no app host. **There is no way to drive a gesture from a session.**

So: gesture work is T4 (build-plan §4.3) and ends with a request, not a claim.
Hand back an ordered check the human can run in under a minute, and ask them to
repeat the critical step — gesture bugs here have been *intermittent before
becoming permanent*, so one success proves nothing.

Prefer designs that need less faith (§3).

### 1.3 Never mark a UI feature ✅ on a render alone

Definition of Done (CLAUDE.md §6) needs a test per criterion. UI criteria have
no tests. Mark 🔨 and record exactly what was and was not checked.

---

## 2. Platform traps

These are not style preferences. Each one silently produces a wrong build.

- **`SwiftUI.Color`, always qualified, in every file in the macOS target.**
  Vendor/SwiftTerm declares its own `Color`; an unqualified `Color.primary`
  resolves to the terminal's and fails to compile — or worse, is dodged with
  leading-dot syntax that hides the trap from the next reader (D50).
- **`Color.clear` is greedy.** Without an explicit height it expands to fill the
  parent, which is how a corner cell stretched a header row to the full sheet
  height with the text stranded in the middle (D48-era fix).
- **`LazyVStack` does not honour `zIndex` between its rows**, and gives no frame
  at all for rows scrolled out of view. Use a plain `VStack` for any list that
  floats a row above its neighbours or measures row geometry. Laziness buys
  nothing at outline/table scale (D52).
- **Deployment targets are macOS 13 / iOS 16.** No `ScrollViewReader`
  positioning APIs, no `pointerStyle`, no Observation macros.
- **A new `.swift` file is in no target until `xcodegen generate` runs**, and
  the failure is silent (D22, CLAUDE.md §10).

---

## 3. Gestures

Direct manipulation is the highest-risk UI in this codebase — three separate
shapes shipped broken on iOS before one held (D56, D60). The rules below are
the residue.

- **One recogniser per interaction.** Two recognisers on the same view is a
  race, and a race is not a bug you can see: it works, then it does not, with
  nothing changed but which one won. A zero-distance `DragGesture` recognises
  on touch-down and *will* cancel a `LongPressGesture` beside it (D60).
- **Never `LongPressGesture.sequenced(before: DragGesture)`.** It does not
  deliver `onEnded` when the finger lifts without a qualifying drag, so an
  armed interaction is never released (D56).
- **A zero-distance `DragGesture` reports touch-down, movement and lift** —
  that is the whole vocabulary. Time holds yourself with a token-guarded
  `asyncAfter` that checks the same touch is still down and has not strayed.
- **The teardown path must be reachable from every exit**, including the one
  where nothing happened. State that is only cleared on the success path will
  eventually stick.
- **Provide a recovery path.** Arming must be able to take over an already-open
  session rather than being refused by it (D57). The difference between an
  annoying bug and an unusable feature is whether the next interaction can
  recover — the iOS lift was fatal only because a lift could not start while
  one was armed.
- **Resolve the tap inside the drag** when a zero-distance drag exists on the
  same row; a separate `onTapGesture` races it (D58). Where the drag has a real
  threshold (macOS, 4pt) the two cannot race and `onTapGesture` is fine.
- **Disable the scroll view while a direct-manipulation drag is live**
  (`.scrollDisabled`), or it consumes the same finger (D59).
- **Never assume a row height.** Measure with a `PreferenceKey` in a named
  coordinate space. A constant row height was wrong by 10pt for any wrapped
  heading and made every drop indicator lie (D51).
- **Freeze measured geometry for the duration of a drag.** Lifted rows carry a
  render offset that `frame(in:)` reports, so re-reading mid-drag chases itself
  (D51).

---

## 4. Showing the user what will happen

The outline's original defect was not ugliness; it was that the feedback
described something other than what the code would do. That is the class of bug
to design against.

- **Show what actually moves.** If the model moves a section, the UI lifts the
  heading *and* its descendants as one object — not the single row under the
  finger (D53). A UI that understates the blast radius of an action is lying.
- **Feedback must not reflow the thing being aimed at.** Insertion indicators
  are overlays. An inserted gap moves the target out from under the pointer
  (D51).
- **A floating element must be opaque.** A translucent lifted card let the
  stationary list read straight through it and the two collided illegibly
  (D53).
- **Mirror the model's refusals in the UI, before the commit point.** If the
  transform will reject a drop, say so while the finger is still down. Dropping
  into your own section was accepted by the panel, rejected by `SectionMover`,
  and did nothing at all (D54). Silent no-ops read as broken software.
- **Name the outcome in words.** A status line that says *Move "3 Load
  schedule" and 3 subsections above "2 Normative references"* is worth more
  than any amount of animation, and it is the one affordance that survives
  being unable to test the animation.
- **Leave a trace of where things came from and where they went** — ghosts in
  the vacated slots, a brief highlight on the landed range.
- **Indent/align the cue to the outcome**, not just the position: the drop line
  sits at the level the section will land at.

---

## 4a. Words in the interface

- **Examples must be about the reader's work, not the author's.** The smart
  folder sheet shipped with `cable schedule`, `voltage drop` and `earth-fault`.
  Those read as "this tool is for electrical engineers" to everyone who isn't
  one. The app is a writing environment; examples belong in that register —
  `draft revision`, `chapter NOT appendix`, `"opening paragraph"` (D63).
- **An example you can use beats one you must retype.** Make them tappable.
- **Check guidance against the implementation before writing it down.** The
  hyphenation note claimed a hyphenated query "returns nothing"; run against
  FTS5 it actually raises an error, and quoting fixes it — so the advice was
  wrong in both halves and had been shipped as help text (D64).
- **Show a warning only when it applies.** A permanent orange triangle is
  noise; the same sentence shown at the moment the query contains a hyphen is
  help. Lint the input, do not lecture it.
- **Never let a failure and an empty result look identical.** If the layer
  below swallows errors, say which case this is — "no matches" and "that query
  is malformed" are different problems for the writer (D64).

## 5. Chrome, density and sizing

- **Per-item command buttons are clutter and they cost the width the content
  needs.** Commands belong in a menu revealed on hover or focus (macOS) or
  long-press (iOS), from a gutter or header — not one drag handle plus one
  delete button in every row (D47). Keep the resting state quiet: the gutter
  shows the row number, so nothing shifts when the menu appears.
- **Size to content, then distribute slack equally.** Fixed column widths
  truncated every real heading; proportional slack lets one wide column eat the
  window. Measure content, clamp to a min/max, share what is left evenly (D48).
- **macOS sheets are not resizable by default.** Use the `ResizableSheet`
  modifier — corner grabber, size persisted in `UserDefaults` under a
  per-sheet key (D49). iOS uses detents and a visible drag indicator instead;
  keep the shared view free of platform conditionals and put the difference in
  the presentation site.
- **Every panel gets a header with a count and an empty state.** "No headings"
  plus a line saying how to get some.
- **Hierarchy is carried by rails and markers, not by indentation alone** — a
  level-4 row should still read as belonging to something.

---

## 6. Checklist before reporting UI work

1. Rendered every state, including invalid and empty — and *looked* at them?
2. Any runtime-measured value confirmed from a real measurement, not invented?
3. Does the feedback describe what the model will actually do, including its
   refusals?
4. Does every interaction have a teardown path from every exit, and a recovery
   path if state sticks?
5. `SwiftUI.Color` qualified; no `LazyVStack` under a floating row; no assumed
   row heights?
6. `xcodegen generate` run if any file was added; both platforms build?
7. Report states **what was verified and how**, and names the gesture work as
   human-check-required with an ordered test.
