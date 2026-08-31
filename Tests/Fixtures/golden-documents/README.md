# Golden documents

These are well-formed documents of the kind this app exists to produce. They are the reference for acceptance criterion 10: clean input is a no-op. A healing pass over any file here must return it unchanged, byte for byte.

## The one rule

Never edit a golden document to make a gate pass. If the gate goes red, the transform changed and the document did not. Investigate the code. A corpus that gets adjusted until it agrees with the implementation is a recording of current behaviour, not a check on it.

## Provenance

Every file here was written by hand and was never produced by running the implementation over anything. That matters: if these were generated from the code's own output, the gate would pass by construction and prove nothing.

They have not been tuned to pass. If the first run goes red, that is a finding to report, not a document to fix.

## What these documents deliberately avoid, and why

A healing pass legitimately changes some things. A document containing those shapes will not round trip, and that is correct behaviour rather than a defect. The corpus therefore avoids them:

- **Typographic characters that glyph repair normalises.** Em dash (U+2014), en dash (U+2013), hyphen (U+2010), non-breaking hyphen (U+2011), curly quotation marks (U+2018, U+2019, U+201C, U+201D), non-breaking space (U+00A0), zero width space (U+200B), and the ligatures (U+FB01, U+FB02). All are converted by design, per decisions D23 and D24. Only plain ASCII punctuation appears in these files.
- **Paragraphs wrapped by hand across several lines.** Line unwrap rejoins them on purpose. Every paragraph here is a single line, which is what the editor produces.
- **Columns held apart by runs of spaces, outside a fenced block.** Table detection converts them on purpose. Tables here use pipes and a delimiter row.
- **A list marker of three digits.** Clause number preservation escapes it on purpose, so `05-edge-cases.md` carries the escaped form already.
- **Short lines carrying digits, repeated three or more times with blank lines around them.** Artefact stripping removes those as page furniture on purpose.
- **Hyphenated compounds whose leading fragment is not in `CommonWords`.** Dehyphenation fuses those, which is a gap in the word list rather than intended behaviour. Every compound here uses a leading fragment the list knows.
- **Hyphenated compounds whose joined form is not a known word.** Dehyphenation keeps those by design, per the inverted rule of 2026-08-11: a hyphen is removed only when the joined form is in `RejoinableWords`.  Every compound here has a joined form that is NOT in that lexicon; "Directonline", "reducedvoltage", "socketoutlets", "projectspecific", "factoryfitted"; so the hyphen survives.  This is the safe direction: a hyphen wrongly kept is visible and costs one keystroke; a hyphen wrongly removed reads as correct and is not.

The last point deserves a note, because it is the sharp edge.  Before the inverted rule of 2026-08-11, a hyphenated compound whose leading fragment was unknown would fuse; so the name of the defect corpus script written bare in prose would become one word.  Under the inverted rule, neither the leading fragment nor the joined form needs to be known: an unknown joined form keeps its hyphen by default, which is the safe direction.  The old behaviour was exactly the over-healing the golden corpus exists to catch.

## What is in each file

- `01-design-note.md`: front matter, headings, prose, a bullet list, an ordered list, a pipe table, a block quote, protected compounds, and clause citations in running text.
- `02-specification-extract.md`: clause citations at the start of a line, two tables, nested requirements, and the compounds the lexicon protects.
- `03-test-report.md`: front matter, a results table carrying units and symbols, a display equation, a fenced diagram block, and unit values that must not lose their spacing.
- `04-minimal.md`: the smallest realistic document. Heading, two paragraphs, trailing newline. Catches anything that mishandles a short file.
- `05-edge-cases.md`: the shapes a healing pass must leave alone: an already escaped clause number, citations needing no escape, a genuine ordered list, a two digit marker, safe hyphenated compounds, a valid table, a fenced block whose content looks like markup, an indented block, a block quote, a rule, and inline code.

## Adding a document

Add real documents you would issue, not invented ones, and keep to the constraints above. Then state in the commit what the new file covers that the existing five do not. A corpus that grows without that discipline gets slower without getting stronger.
