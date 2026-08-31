# PARKED.md — good ideas deferred mid-session. Cap: 100 lines.
# Reviewed at phase gates from a clean session.
# Never acted on in the session that raised them.

## 2026-08-10 — raised while scaffolding the test harness

**[RED] swift-markdown dependency for A5.** A5 is now [locked] (human ruling,
GAP C4): an AST layer feeding the rules engine, alongside the untouched regex
highlighter. That needs a swift-markdown package dependency, which is RED under
CLAUDE.md §10 and was NOT part of the project.yml authorisation given this
session — that grant was scoped to test-harness scaffolding only.
Raise again when rules-engine work (N12–N18, N37) actually starts. N7 paste
healing needs no AST, so nothing is blocked today.

**[RESOLVED 2026-08-10] Blueprint §2.4 transform order.** Raised as AMBER, ruled on
by human the same day: the proposed order is locked as DECISIONS.md D20 and
supersedes blueprint §2.4. No longer parked. Left here as the record of why the
blueprint and the spec now disagree.

## 2026-08-10 — raised while building T2

**[note] Furniture not separated by a blank line is not stripped.** `stripArtefacts`
requires a blank-or-absent line on both sides (D30). A PDF paste whose running
header abuts the body text keeps the header. Deliberate — it makes deleting a line
out of the middle of a paragraph impossible — but if real pastes turn out to look
like that, the fix is positional/page-pitch detection, not loosening the isolation
rule.

## 2026-08-11 — raised while building T3

**[RESOLVED 2026-08-11, commit 1b1e562] `CommonWords` is a curated list, not a dictionary.** `dehyphenate` keeps a
hyphen when the leading fragment is a known word. Adding to the list is always
safe; a missing word fuses a compound. If real pastes show fusions, the fix is
more words — NOT a spell-checker: `NSSpellChecker` is AppKit, `NaturalLanguage` is
A6 and still only [proposed], and either makes the transform depend on the user's
installed dictionaries, so the same paste would heal differently on two machines.
Resolved by the inverted rule (D35): an unknown joined form now keeps its
hyphen, so a missing `CommonWords` entry can no longer cause silent fusion.

## 2026-08-11 — raised while authoring the golden documents

**[RED — needs a human ruling] Criterion 10 is narrower than it reads.** "Clean
input is a no-op: well-formed Markdown passes through byte for byte." But a
well-formed document containing an em dash, an en dash, curly quotation marks or
a non-breaking space does NOT round trip — `repairGlyphs` normalises all of them
by design (D23, D24), and typographers write documents full of them. So either
criterion 10 means "well-formed AND already glyph-normalised", or `heal` must not
be run over a document that is already clean. The golden corpus currently avoids
those characters and says so in its README, which sidesteps the question rather
than answering it. The ruling belongs to the human because it decides what the
paste hook may be pointed at later: pasted spans only, or whole documents.

**[RESOLVED 2026-08-11, commit 1b1e562] `CommonWords` gap, with a worked example.** `dehyphenate` fuses a
hyphenated compound whose leading fragment is not in the list. Concretely, the
name of the defect corpus script written bare in prose (leading fragment
"defect") fuses into one word; the same name inside backticks or with its
directory prefix survives, because neither fragment is then all letters. This is
the gap already noted after T3 and it is a good case for the defect corpus, not a
reason to weaken anything. Resolved by the inverted rule (D35): an unknown
leading fragment no longer defaults to fusion.

**[note, not a deviation] One of four gauntlet gates is still blind.**
validate.sh and defect-corpus.sh are real (as of 2026-08-11, after the
defect-corpus.sh correction). golden-roundtrip.sh is still a stub that
`exit 0`s unconditionally. Only two of four gates are real as of today.

## 2026-08-11 — golden document round-trip finding

**[RESOLVED 2026-08-11, commit 1b1e562] dehyphenate fuses five hyphenated compounds in golden documents —**
**CommonWords gap, not a test defect.** The first run of
`GoldenDocumentTests.testGoldenDocumentsRoundTripByteForByte` caught real
transform damage:

- `01-design-note.md`: "Direct-on-line" → "Directon-line" (lines 32, 35),
  "reduced-voltage" → "reducedvoltage" (line 35)
- `02-specification-extract.md`: "socket-outlets" → "socketoutlets" (line 7),
  "project-specific" → "projectspecific" (line 13),
  "factory-fitted" → "factoryfitted" (line 41)

All caused by the same root cause: the leading fragments "Direct", "reduced",
"socket", "project", and "factory" are not in `CommonWords`, so
`dehyphenate` treated them as broken hyphenation and fused them.

Resolved by the inverted rule (D35): `dehyphenate` now removes a hyphen only
when the joined form is a known word, so these five compounds — whose joined
forms are not in `RejoinableWords` — keep their hyphens.  The golden documents
round trip byte for byte.  The old `CommonWords`-gap approach of adding words
one at a time was rejected as whack-a-mole (REJECTED.md).

---

## RED — iOS device build has no development team (2026-08-12)

`xcodebuild build -scheme Kitib-iOS -destination 'generic/platform=iOS'` fails
with:

    error: Signing for "Kitib-iOS" requires a development team. Select a
    development team in the Signing & Capabilities editor.

The iOS **Simulator** build succeeds (`generic/platform=iOS Simulator`,
BUILD SUCCEEDED), so this is not a code defect — paste healing and its preview
sheet compile and are wired on iOS (`Sources/iOS/EditorView_iOS.swift`
`KitibTextView.paste(_:)` → `Coordinator.handlePaste`, sheet in
`DetailView_iOS.swift`). Only code signing for a real device is missing.

Fixing it means setting `DEVELOPMENT_TEAM` (and a bundle identifier the team
owns) in `project.yml`, then `xcodegen generate`. CLAUDE.md §10 lists signing
and provisioning as RED — human decision. Not attempted.

## Outline panel — deferred (2026-08-13)

Raised while rebuilding OutlinePanel's presentation; all beyond GREEN, none
implemented:

- **Autoscroll while dragging** (AMBER). A drag cannot currently reach a target
  that is scrolled out of view. Not a regression — the previous implementation
  could not either — but it is the obvious next gap on a long document.
- **⌥↑ / ⌥↓ to move the selected section** (AMBER — new interface). Would make
  reorder reachable without a pointer, and testable.
- **Filter/search field in the outline** (RED). Explicitly out of scope in
  specs/dynamic-outline.md.
- **Collapse/expand a section in the panel** (AMBER). `OutlineNode` already
  carries `children`, so the tree is there; the interaction is not.

## iOS Simulator app is built UNSIGNED and SpringBoard refuses to launch it (RED, 2026-08-13)

Reported as "Simulator device failed to launch com.sean.kitib / request denied
by service delegate (SBMainWorkspace) / launchd job spawn failed (163)".

Diagnosed, not fixed. Evidence, in order:

1. `xcodebuild build -scheme Kitib-iOS` succeeds — this is a LAUNCH failure,
   not a build failure, and not caused by any Swift change. The process never
   starts.
2. Reproduced outside Xcode: `simctl launch` fails identically on two
   different simulators (iPad Pro 11 M5 / 26.3.1 and iPhone 16), so it is not
   device- or runtime-specific.
3. The simulator itself is healthy — `simctl launch` starts Safari, Settings
   and Contacts on the same device.
4. `codesign -dv <Kitib.app>` on the built product: **"code object is not
   signed at all"**. The simulator still requires a signature; SpringBoard
   denies an unsigned bundle, which surfaces as the SBMainWorkspace refusal.
5. Proved by ad-hoc signing the built product by hand and launching it: the
   app starts and renders (pid confirmed, screenshot taken on the iPad).

Cause: `xcodebuild -showBuildSettings -sdk iphonesimulator` reports
`CODE_SIGN_IDENTITY = iPhone Developer` for the SIMULATOR SDK, with
`DEVELOPMENT_TEAM = ""` (project.yml line 15). There is no matching identity,
so the product comes out unsigned. Simulator builds want the ad-hoc identity.

The fix is one line in `project.yml` under the shared settings:

    CODE_SIGN_IDENTITY[sdk=iphonesimulator*]: "-"

then `xcodegen generate`. That is a **build-settings / signing change — RED per
CLAUDE.md §10** and is a human decision, so it was not made.

Workaround that needs no project change (sign the product after building):

    APP=~/Library/Developer/Xcode/DerivedData/Kitib-*/Build/Products/Debug-iphonesimulator/Kitib.app
    codesign --force --sign - "$APP/Kitib.debug.dylib"
    codesign --force --sign - "$APP/__preview.dylib"
    codesign --force --sign - "$APP"
    xcrun simctl install booted "$APP" && xcrun simctl launch booted com.sean.kitib

Related but separate: the iOS *device* build needs a DEVELOPMENT_TEAM (above).
Both come from the same empty-team setting; the simulator one is fixable
without an Apple Developer account, the device one is not.

## Surface the real FTS5 error instead of swallowing it (AMBER, 2026-08-13)

`AppState.searchSmartFolder` is `(try? index.search(query)) ?? []`, so a
malformed query and a genuine miss are the same empty array to every caller.
That is why the smart folder sheet needed a standing warning about hyphens.

`SmartFolderPanel` now lints the query at entry (`QueryLint`), which covers the
hyphen case — by far the most common — but not an unbalanced quote, a stray
`(`, or anything else FTS5 rejects.

The real fix is for `searchSmartFolder` to return a result type carrying the
error, and for the panel to show it verbatim. That changes an AppState method
signature used by more than one caller: AMBER, so not done here.

## Help: insert an example at the caret instead of copying it (AMBER)

Tapping an example in the Help window copies it to the clipboard (GREEN, shipped
2026-08-13). Inserting it into the open document at the caret is the better
help — one gesture instead of three — but it reaches into `AppState` from a view
that currently knows nothing about the document, which widens the interface.

Ruled AMBER at the time and deferred by the human in the same breath. If taken
up: the insertion needs to be a single undo step, and Help should dismiss on
insert, or the reader cannot see what landed.

## 2026-08-14 — swift-markdown RED is now RAISED, not parked

The 2026-08-10 entry above said "raise again when rules-engine work (N12–N18,
N37) actually starts". It has started: `specs/rules-engine.md` exists and carries
the question as its **Open RED**, with the three possible rulings and their
consequences written out. It is no longer deferred — it is waiting on a human
answer, and the spec is NOT APPROVED until that answer is given.

The spec is deliberately written so that all three rulings are cheap: the engine,
`Diagnostic`, `Rule` and the four first rules are parser-agnostic and identical
under every answer. Nothing is being built ahead of the ruling.

## 2026-08-14 (AMBER) — surface newFolder / newFile write failures

`AppState.newFolder` and `newFile` both use `try?`, so a genuine write failure
(read-only directory, security scope lost) is indistinguishable from success.
The uniquing fix (D72) removed the common cause of the silent no-op but not
this one. Reporting it needs an error surface in the sidebar — new UI, so AMBER.
Precedent: D71 did the same for print/PDF export.

## 2026-08-14 (RED) — move search indexing off the main thread

D73 coalesced the whole-vault re-index to one pass per burst, which removes the
per-save stall. The pass itself is still synchronous on the main thread, so a
large enough vault will still hitch once per burst. Fixing it properly means
running the file reads and FTS5 inserts on a background queue — SQLite
connections have thread affinity, so it means touching `SearchIndex`, which the
suite does cover. Separate change, not a follow-on.

## 2026-08-14 (AMBER) — FileItem loads the entire tree eagerly

`FileItem.init` recurses through every subdirectory before returning, so
`refreshTree()` enumerates the whole vault. Lazy per-folder loading would fix
it, but `rebuildSearchIndex()` walks the same tree to find files to index —
made lazy, it would silently index only expanded folders. Needs the index to
walk the filesystem itself rather than the view model.

## 2026-08-15 — iPad sidebar drag-and-drop deferred (note, not a deviation)

Making selection work on iPad meant gating the sidebar's drag-and-drop
(`onDrag`/`onDrop`) behind `#if os(macOS)` (D75). It was never specified or
tested for iOS, and it is the prime suspect for the "nothing selectable on
iPad" report. If drag-reorder is wanted on iPad, it needs an iOS-native
approach that does not race List selection, plus a real-device check — do not
re-apply the macOS workaround blind.

## 2026-08-17 — status update on the two performance items above (D77)

The "move search indexing off the main thread" (RED) and "FileItem loads the
entire tree eagerly" (AMBER) entries from 2026-08-14 both STAY PARKED, but they
are no longer what makes launch slow. D77 removed the auto-restore from
`AppState.init()`, so launch now does no vault work at all and neither item is
on the launch path.

They still apply to opening a large folder by hand — that pause is now user-
initiated rather than unavoidable, which is a much weaker case for the RED.
Re-raise them only if opening a real vault is measurably painful.
