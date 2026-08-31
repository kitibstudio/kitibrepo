# REJECTED.md — approaches tried and abandoned. Append-only. Cap: 50 lines.

## Session 0 audit — findings

No dead code, commented-out alternatives, or abandoned approaches found in the codebase.

Source files are clean: no FIXME/TODO/HACK/XXX markers, no #if false blocks,
no commented-out functions or type definitions. The code is a single,
consistent implementation layer with no visible detritus from prior attempts.

If abandoned approaches exist, they are not in the source tree.

## 2026-08-10 — T1 paste healing

Fixture directory names `ocr-output`, `standards-pdf`, `word-clipboard` were
created then abandoned mid-session in favour of `scanned-ocr-output`,
`multi-column-standards-pdf`, `word-to-clipboard`. The originals were left behind
as EMPTY directories, which git does not track — so they survived a clean
`git status` and were invisible in the diff. Removed. `CorpusTests`
now asserts the directories on disk match `FixtureCorpus.names` exactly, so this
cannot recur silently.

## 2026-08-10 — T2 paste healing

Rejoining a hyphen-terminated line WITH a space (`star-` + `delta` →
`star- delta`) — the obvious reading of "rejoin with a separator". Rejected: it
breaks criterion 3 at stage 2, because a protected compound split across a line
break is then no longer byte-identical, and it hands `dehyphenate` (T3) a shape
the lexicon cannot match. Hyphen-terminated lines now rejoin with no space.

Deciding each rejoin from the last SOURCE line's length rather than from the text
accumulated so far. Rejected: it is not idempotent — a second pass sees the long
joined line, finds it "full", and swallows the following paragraph.

## 2026-08-11 — T3 paste healing

Using a system spell-checker (`NSSpellChecker` / `UITextChecker` /
`NaturalLanguage`) to decide whether a hyphen's leading fragment is a real word.
Rejected: it makes a pure `String -> String` transform depend on a platform
service and on the user's installed dictionaries, so the same paste heals
differently on two machines and the golden fixtures stop being golden. Replaced
by the hardcoded `CommonWords` list, which is over-inclusive on purpose.

Deciding dehyphenation from `ProtectedCompounds` alone. Rejected: the lexicon has
six entries, so `three-phase`, `short-circuit` and `self-contained` would all
fuse — criterion 2's second clause is a separate requirement from criterion 3's
protected list, and needs its own guard.

## 2026-08-10 — T1/T2 paste healing (continued)

NBSP deletion (`repairGlyphs` mapping U+00A0 to the empty string) — implemented
per the original spec criterion 4, then rejected: every NBSP in the corpus is a
value/unit separator, so deletion produced `1000kVA`, `50Hz`, `300A`. Superseded
by D23 (NBSP → regular space). The spec, not the implementation, was at fault.

## 2026-08-11 — dehyphenate inversion (D35)

Growing `CommonWords` word by word to catch every hyphenated compound a golden
document might contain. Rejected: it is whack-a-mole — every new document
class brings new compounds, every miss is silent over-healing, and the list
must be maintained forever. The inverted rule (D35) replaces the negative-list
approach with positive evidence: a hyphen is removed only when the joined form
is a known word. A missing entry leaves a visible hyphen, not a silently fused
compound.

Non-recursive glob (`"$DEFECT_DIR"/*.md "$DEFECT_DIR"/*.txt`) for scan-mode
file collection — implemented in commit 53849dd, rejected 2026-08-11. A flat
glob cannot recurse into subdirectories, so running scan mode against
`Tests/Fixtures/paste-healing/` matched ZERO files (all fixtures live one level
down) and exited 0 having read nothing. This is the D19 failure pattern: a test
that exercises nothing and reports green. Replaced by `find` with `-type f`.
The "nothing to check" branch now exits non-zero (D33) and the file count is
always printed.

## 2026-08-11 — N8 table grid editor

Using `onTapGesture` on cells inside a `ScrollView` for click-to-focus.
Rejected: on macOS, `NSScrollView` consumes mouse-down events for potential
drag-to-scroll. `onTapGesture` fires on mouse-up, by which time the event is
gone. Replaced by `.simultaneousGesture(DragGesture(minimumDistance: 0).onEnded{})`
which fires on press-down, plus `DispatchQueue.main.async` to defer focus until
the TextField is in the view tree. This is the only approach that works on macOS
for TextFields inside ScrollViews.

Toggling between `Text` (display) and `TextField` (edit) per cell. Rejected:
the toggle never activated reliably on click because the same ScrollView event
interception prevented gesture recognition. Replaced by making every cell a
live `TextField` with `@FocusState` management — simpler code, zero toggle
bugs, and the `.textFieldStyle(.plain)` makes unfocused cells look like plain
text anyway.
