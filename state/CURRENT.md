# CURRENT.md: the single active task. Rewritten each session. Cap: 40 lines.

## THIS SESSION: Apple Pencil review + draft spec (2026-09-02)

A review, not an implementation. NO source changes. Deliverables:

- `specs/apple-pencil.md` — DRAFT, NOT APPROVED. 4 slices: (A) Scribble
  precision, (B) selection edit menu with Markdown actions, (C) Pencil
  double-tap, (D) Pencil Pro squeeze palette (BLOCKED by an Open RED).
- `state/FEATURES.md` — new "Specced, not built" section, ⬜ row + ⬜ legend.
- `state/PARKED.md` — RED entry: iOS target 16.0 → 17.5 for Slice D.

Findings: the iOS editor (`Sources/iOS/EditorView_iOS.swift`) has NO PencilKit,
NO Scribble code, NO `UIPencilInteraction`, NO `editMenuForTextIn` — Apple
Pencil is entirely stock `UITextView`. The user's mid-word scratch-delete
report is Apple's system-owned word-granular Scribble behaviour; no public API
changes it. One Kitib-side variable to check first on a real device: whether
the debounced `applyHighlighting()` (which re-sets `selectedRange` every
change) disturbs a multi-step Scribble edit (spec criterion A1).

## NEXT: two independent queued tasks, human picks order

1. Human: approve `specs/apple-pencil.md` + rule on its Open RED (target bump).
   Then build Slice A (or B — B is the most self-verifying: pure Core
   wrap/unwrap functions + `editMenuForTextIn` wiring).
2. Problems panel slice 2 — inline underlines (specs/problems-panel.md, out of
   scope of slice 1). Per-platform editor overlay driven by `state.problems`
   ranges: NSTextView temporary attributes on macOS, TextKit on iOS. D11 stays
   the sole source of editor styling (A5). After it, the QA export gate.

## Gotchas carried forward

- Apple Pencil Scribble scratch-out is WORD-granular by Apple's design. Sub-word
  precision comes from text size / line spacing / circle-to-select, not an API.
- `UIPencilInteraction` double-tap is iOS 12.1+ (fine on the iOS 16 target);
  squeeze + `.showContextualPalette` are iOS 17.5+ (the Open RED).
- Pencil gestures are NOT verifiable in-session (ui-conventions §1.2) — ship one
  reasoned change, hand back an ordered human device check.
- PRE-EXISTING RED (unchanged): NewFileTargetTests
  testSelectedFileAtDepthThreeTargetsDepthTwoParent. Human decides.
- D50: SwiftTerm.Color shadows SwiftUI.Color in the macOS target; spell
  SwiftUI.Color explicitly in new macOS views.
- New content in state files stays em-dash-free.
- PARKED: iOS signing/target bump (RED), background indexing (RED), lazy
  FileItem (AMBER), rules settings UI (AMBER), inline-underline overlay.
