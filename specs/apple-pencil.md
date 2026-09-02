# Apple Pencil Support (iPadOS editor)

Source: `docs/blueprint-v2.md` §5 platform matrix (line 294 — "Touch + Pencil").
No build-plan Stage node exists for it yet; this spec proposes one.
Depends on: the iOS editor (`Sources/iOS/EditorView_iOS.swift`, exists).

**Status: DRAFT — NOT APPROVED.** Two things are owed by the human before code:
(1) approval of the acceptance criteria below, (2) a ruling on the **Open RED**
(raising the iOS deployment target for the Apple Pencil Pro squeeze palette).
Written so slices A–C are identical regardless of the RED ruling.

## Intent

A writer using an Apple Pencil on iPad can format text, act on a selection, and
correct handwriting-entered text without reaching for the keyboard — and the
app's own code never makes Scribble less precise than iPadOS makes it.

## Scores

Per `build-plan.md` §4.1.

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | iPad + Pencil is a primary interaction mode for field notes and review; the user asked for it directly. |
| Verifiability | 2 | The formatting helpers are pure and golden-testable (5), but the feature as shipped is UIKit interaction wiring + Pencil gestures, which need a real-device human check (D16, ui-conventions §1.2). |
| Blast radius | 3 | Menu actions mutate the open document. Bad range math on a wrap/unwrap could corrupt text. Editor-local, single undo step, no file-format change. |
| Dependency depth | 2 | The editor exists. Slice D additionally needs a deployment-target bump (the Open RED). |

**Priority = 4 × 2 ÷ (3 × 2) = 1.33.** Blast radius < 4 ⇒ no rollback plan
required; a short one is in § Rollback anyway because this touches the editor.

## Background — what exists today

`Sources/iOS/EditorView_iOS.swift` is a hand-built `UITextView` (TextKit 1, D10)
in a `UIViewRepresentable`. Confirmed absent: PencilKit, any Scribble code,
`UIPencilInteraction`, `UIEditMenuInteraction` / `editMenuForTextIn`, any input
accessory view. Apple Pencil works only through stock `UITextView` behaviour.
Traits: `smartQuotesType = .no`, `smartDashesType = .no`,
`autocorrectionType = .default`, `autocapitalizationType = .sentences`.
`applyHighlighting()` runs the regex highlighter on `tv.textStorage` (debounced)
and restores `selectedRange` on every text change.

## The Scribble scratch-to-delete report

The user reports: scratching out a few characters *inside* a word deletes the
whole word. **Apple's Scribble scratch-out gesture is word-granular by design**
(Apple Support: "scratch out a word or words to delete"); there is no public API
to make it delete a sub-word span. `UIScribbleInteractionDelegate` only gates
*whether* Scribble begins.

Before this is written down as pure system behaviour, one Kitib-side variable is
checked on a real device (criterion A1). If it is not the cause, criterion A2/A3
stand as the response.

## Acceptance criteria

Max 10, grouped by slice. A slice is one session.

### Slice A — Scribble precision (no new interaction surface)

1. **Highlighter does not fight Scribble.** On a real iPad with Apple Pencil,
   with `applyHighlighting()`'s scheduled call temporarily disabled, a scratch
   through 2–3 characters mid-word is compared against the shipped build. If the
   disabled build deletes only the scratched characters, `applyHighlighting()` is
   suppressed for the duration of a Scribble interaction (guarded by
   `UIScribbleInteractionDelegate.scribbleInteractionWillBeginWriting` /
   `…DidFinishWriting`, mirroring the existing `isEditing` flag) and the mid-word
   scratch then deletes only the scratched characters. If the disabled build
   still deletes the whole word, this criterion is met by recording the finding
   (system behaviour) and A2/A3 carry the response.
2. **iPad line spacing.** The iOS editor applies a paragraph line spacing (via
   `NSParagraphStyle` in `typingAttributes` and the highlighter's base
   attributes) that measurably improves Scribble character hit accuracy, without
   changing exported bytes (line spacing is a display attribute only).
3. **Help answers "delete part of a word".** `Sources/Core/Help` gains a
   Cheatsheet/Guide entry: circle a sub-word span to select exactly those
   characters, then delete. Entry satisfies the existing `HelpContentTests` rules
   (D68).

### Slice B — selection edit menu with Markdown actions

4. **Custom actions in the selection menu.** `textView(_:editMenuForTextIn:
   suggestedActions:)` (iOS 16, `UIEditMenuInteraction`) adds Bold, Italic,
   Code, and Link actions to the text selection menu, after the system's
   suggested actions, never replacing them.
5. **Actions are pure and reversible.** Each action is a pure function in
   `Sources/Core` (`(text, range) -> (newText, newSelection)`), applied to the
   `UITextView` as one undoable edit. Wrapping a span already wrapped in the same
   delimiter unwraps it (toggle). Round-trip: wrap then unwrap == original.
6. **No selection, no custom items.** With an empty selection the menu shows only
   the system items — a Markdown wrap with no range is not offered.

### Slice C — Apple Pencil double-tap

7. **Double-tap is handled.** `UIPencilInteraction` on the editor; a double-tap
   performs one configurable action (default: toggle the split preview,
   `state.showPreview`). Respects `UIPencilInteraction.preferredTapAction` when
   the user set it to `.ignore`.
8. **Discoverable.** The double-tap action is named in Help and does nothing
   destructive (no action that loses text or selection).

### Slice D — Apple Pencil Pro squeeze palette (BLOCKED by the Open RED)

9. **Squeeze shows a Kitib palette.** When the deployment target permits it
   (see Open RED), `pencilInteraction(_:didReceiveSqueeze:)` with
   `preferredSqueezeAction == .showContextualPalette` presents a compact
   floating palette of the Slice B Markdown actions plus heading level, anchored
   near the Pencil. Uses the same pure Core functions as criterion 5.
10. **Graceful absence.** On a build/device without squeeze support, nothing
    regresses: Slices A–C behave identically and no squeeze code path is reached.

## Out of scope

- **PencilKit / `PKCanvasView` / `PKToolPicker` / drawing / PDF markup.** That is
  the blueprint's separate "PDF markup in sidebar" idea and is not this feature.
- **Handwriting recognition beyond stock Scribble.** No custom ink model.
- **Changing `MarkdownHighlighter` (D11).** Slice A only *schedules* it
  differently; it does not change what it styles or how.
- **The macOS editor.** `UIPencilInteraction` and Scribble are iOS-only; the
  macOS `NSTextView` path is untouched.
- **An on-disk / JSON action-pack format.** The menu actions are fixed Swift
  values.
- **A general formatting toolbar / input accessory view.** If wanted, that is a
  separate spec; this feature adds actions to menus that already appear.
- **Raising the deployment target for anything other than Slice D.** Slices A–C
  are iOS 16.

## The Open RED — iOS deployment target (human ruling required)

Slice D needs `pencilInteraction(_:didReceiveSqueeze:)` and
`UIPencilPreferredAction.showContextualPalette`, which are **iOS 17.5+**. The
project's deployment target is **iOS 16.0** (D13, `project.yml`). Raising it is a
build-settings change — RED under CLAUDE.md §10 — and is a human decision.

**The question for the human: raise `Kitib-iOS` deployment target from 16.0 to
17.5 (or higher) in `project.yml`, then `xcodegen generate` — yes or no?**

| Ruling | Consequence |
|---|---|
| **Not yet** (safe default) | Slices A–C ship. Slice D stays specced but unbuilt. No device on iOS 16 is dropped. Re-raise if squeeze is later wanted. |
| **Yes** | Slices A–C ship first, unchanged. Slice D is then built in its own session behind `#available` guards. Devices below the new target lose the whole app. |
| **No, ever** | Slice D is deleted from this spec. Slices A–C are unaffected. |

Nothing in Slices A–C changes under any ruling — that is deliberate, so the
question can be answered after A–C are built.

## Test plan

- **Unit / golden (Slice B, C actions):** the pure Core wrap/unwrap/heading
  functions get `KitibTests` coverage — exact `newText` and `newSelection` for
  each action; toggle idempotence; wrap-then-unwrap round-trip == original;
  caret-at-boundary and multi-line-selection cases; a golden document run
  asserting an action on a known range produces the exact expected bytes.
- **Render check (Slice B, D):** `ImageRenderer` pass on the editor with a
  selection, showing the custom menu items / the palette root view (ui-conventions
  §1.1). Menu content that `ImageRenderer` cannot draw is rendered via its root
  view directly.
- **Manual, unavoidable (Slices A, C, D — Pencil gestures):** real iPad + Apple
  Pencil. Ordered steps handed to the human, the critical step repeated
  (gesture bugs here have been intermittent-then-permanent — ui-conventions §1.2).
  Specifically: A1's disabled-highlighter comparison; C's double-tap; D's squeeze.
  No in-session "works" claim for any of these.
- **Regression:** full suite green before/after; `xcodegen generate` for any new
  file with the `Executed N` count confirmed to rise (D22); both targets build;
  golden documents round-trip unchanged (line spacing must not change bytes).

## Failure modes

1. **A wrap action corrupts text with off-by-one range math.** Passes a test
   asserting "text changed" and visibly eats a character. Every action test
   asserts the *exact* resulting string and selection, not a diff.
2. **Toggle unwrap removes the wrong delimiters** — unwraps `**bold**` inside a
   larger `*italic*` span, or strips a literal `*` that was content. The unwrap
   only fires when the selection's immediate neighbours are the exact delimiter.
3. **The custom menu replaces the system actions** instead of appending — Cut,
   Copy, Paste, Look Up disappear when text is selected. The delegate returns
   `suggestedActions + custom`, never `custom` alone.
4. **Slice A line spacing changes exported bytes.** A `\n` gets duplicated, or
   the paragraph style leaks into `ExporterCore`. Golden round-trip catches it;
   line spacing is display-only and never touches the string.
5. **`applyHighlighting()` suppression during Scribble never re-enables** —
   highlighting silently stops after the first Pencil use because the
   `DidFinishWriting` callback path has an early return. The teardown must be
   reachable from every exit (ui-conventions §3), same lesson as the gesture work.
6. **Double-tap fires a destructive action.** Default must be inert-if-wrong
   (toggle a panel), never "delete", "clear", or anything that moves the caret
   unpredictably.
7. **Squeeze palette (Slice D) is built without an `#available` guard** and the
   iOS 16 build breaks — or worse, compiles against a raised target nobody
   ruled on. Slice D does not start until the Open RED is ruled.
8. **Scribble "fix" claimed on a render.** Slice A1's outcome is asserted only
   by the human device comparison; a green suite says nothing about it
   (ui-conventions §0).

## Rollback

Slices A–C are additive and editor-local. To remove: delete the
`editMenuForTextIn` delegate method, the `UIPencilInteraction` and its delegate,
the `UIScribbleInteractionDelegate` conformance, and the line-spacing attribute;
the pure Core functions and their tests can stay (dead but harmless) or be
deleted with their test files. No file-format, no data, no `project.yml` change
in A–C. Slice D's rollback is reverting the `project.yml` target bump + `xcodegen
generate`.

## Named entities

Exact identifiers — to be fixed at approval, proposed here:

- `MarkdownEdit` — `enum` in `Sources/Core/`. `static func wrap(_ text: String,
  range: Range<String.Index>, delimiter: String) -> (text: String, selection:
  Range<String.Index>)` and `static func toggleWrap(...)`, `static func
  setHeadingLevel(...)`. Pure, no UIKit.
- `KitibTextView` — existing `UITextView` subclass; gains the
  `UIScribbleInteractionDelegate` conformance (Slice A) and `UIPencilInteraction`
  host (Slice C/D).
- `Coordinator` — existing `UITextViewDelegate`; gains
  `textView(_:editMenuForTextIn:suggestedActions:)` (Slice B).
- Tests: `Tests/KitibTests/MarkdownEdit/`. Help: `Sources/Core/Help/`.
