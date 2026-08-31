import Foundation

// MARK: - HelpContent

/// Everything the Help window knows, as data.
///
/// Two rules govern what may be written here, both learned the expensive way:
///
/// 1. **Examples are about the reader's work, not the author's** (D63). This is
///    a writing environment. `draft revision` belongs here; `cable schedule`
///    does not, however much the author happens to write about cables.
/// 2. **Guidance is checked against the implementation before it is written
///    down** (D64). The previous help told writers a hyphenated smart folder
///    query "finds nothing", which was wrong twice over: FTS5 raises an error,
///    and quoting the term fixes it. Wrong help is worse than absent help — it
///    is believed. `HelpContentTests` guards both rules.
///
/// Everything documented below exists in `ExporterCore`, checked line by line.
/// The renderer is small and hand-written: generic Markdown that other tools
/// accept is not automatically valid here, and an example that quietly does
/// nothing is exactly the confident-but-wrong output CLAUDE.md §9 warns about.
public enum HelpContent {

    public static let all: [HelpEntry] = cheatsheet + guides + shortcuts

    public static func entries(in lane: HelpLane) -> [HelpEntry] {
        all.filter { $0.lane == lane }
    }

    // MARK: - Cheatsheet

    /// Syntax. Every entry carries an example that works in this app as written.
    static let cheatsheet: [HelpEntry] = [
        HelpEntry(
            id: "cs.headings",
            lane: .cheatsheet,
            title: "Headings",
            summary: "One # for the document title, more for each level below. Up to six.",
            note: "Headings are what the outline (⌘⇧O) lists, and what section reordering moves.",
            example: HelpExample("""
            # Site survey — Nov 2026
            ## What we found
            ### Access road
            """, renders: "Three levels, largest first."),
            keywords: ["title", "h1", "h2", "hash", "section", "subheading"]
        ),
        HelpEntry(
            id: "cs.bold",
            lane: .cheatsheet,
            title: "Bold",
            summary: "Two asterisks either side, no spaces inside them.",
            example: HelpExample("The deadline is **Friday 14th**, not Monday."),
            keywords: ["strong", "asterisk", "emphasis", "heavy"]
        ),
        HelpEntry(
            id: "cs.italic",
            lane: .cheatsheet,
            title: "Italic",
            summary: "One asterisk either side.",
            note: "Asterisks only. Underscores around a word — _like this_ — stay as written; they are not italics in Kitib.",
            example: HelpExample("She called it *provisional*, which it was not."),
            keywords: ["emphasis", "slanted", "underscore", "oblique"]
        ),
        HelpEntry(
            id: "cs.code-inline",
            lane: .cheatsheet,
            title: "Inline code",
            summary: "Backticks around anything that should read as literal text.",
            note: "Nothing inside backticks is interpreted, so it is also the way to show Markdown itself without it taking effect.",
            example: HelpExample("Run `git status` before you commit."),
            keywords: ["monospace", "backtick", "literal", "verbatim", "fixed width"]
        ),
        HelpEntry(
            id: "cs.link",
            lane: .cheatsheet,
            title: "Link",
            summary: "Visible words in square brackets, destination in parentheses immediately after.",
            note: "A bare URL is not turned into a link — wrap it the same way, with the address in both halves. Relative paths reach other documents in your folder; mailto: addresses work too.",
            example: HelpExample("""
            See the [style guide](guides/style.md) before filing.
            Ask [the editor](mailto:editor@example.com) if unsure.
            Source: [https://example.com](https://example.com)
            """),
            keywords: ["hyperlink", "url", "href", "anchor", "mailto", "relative path", "cross-reference"]
        ),
        HelpEntry(
            id: "cs.bullets",
            lane: .cheatsheet,
            title: "Bulleted list",
            summary: "Start each line with a dash, asterisk or plus, then a space.",
            note: "One blank line between items is fine — it stays a single list. Two blank lines end it. Indenting an item does not make a sub-list; this renderer keeps lists flat.",
            example: HelpExample("""
            - Interviews complete
            - Transcripts checked
            - Quotes cleared
            """),
            keywords: ["unordered", "dash", "points", "itemise", "itemize"]
        ),
        HelpEntry(
            id: "cs.numbers",
            lane: .cheatsheet,
            title: "Numbered list",
            summary: "A number, a full stop, then a space.",
            note: "Number every line 1. if you like — the output counts them in order regardless, so inserting a step does not mean renumbering the rest.",
            example: HelpExample("""
            1. Draft the opening
            2. Send for comment
            3. Cut it by a third
            """),
            keywords: ["ordered", "steps", "enumerate", "sequence"]
        ),
        HelpEntry(
            id: "cs.quote",
            lane: .cheatsheet,
            title: "Block quote",
            summary: "A > at the start of the line.",
            example: HelpExample("""
            > The report was accepted without amendment.

            — Minutes, 3 November
            """),
            keywords: ["citation", "quotation", "excerpt", "pull quote", "indent"]
        ),
        HelpEntry(
            id: "cs.rule",
            lane: .cheatsheet,
            title: "Section break",
            summary: "Three dashes alone on a line draw a horizontal rule.",
            note: "Three asterisks or three underscores do the same. Careful: three dashes directly under a line of text is not a heading here — it is a rule.",
            example: HelpExample("""
            …that concluded the first phase.

            ---

            The second phase began in March.
            """),
            keywords: ["divider", "horizontal rule", "hr", "separator", "scene break"]
        ),
        HelpEntry(
            id: "cs.table",
            lane: .cheatsheet,
            title: "Table",
            summary: "A header row, then a row of dashes, then one line per row.",
            note: "The dashed line is required — without it the pipes are just text. Once the caret is inside a table, a grid icon appears in the toolbar so you never have to line the pipes up by hand.",
            example: HelpExample("""
            | Section    | Owner  | Status   |
            | ---------- | ------ | -------- |
            | Summary    | Priya  | Draft    |
            | Findings   | Tom    | Review   |
            """, renders: "Three columns with a header. Columns need not be aligned in the source."),
            keywords: ["grid", "columns", "rows", "pipe", "tabular", "spreadsheet"]
        ),
        HelpEntry(
            id: "cs.table-caption",
            lane: .cheatsheet,
            title: "Table caption",
            summary: "A line beginning “Table:” directly under a table becomes its caption.",
            note: "Needs auto-numbering on (Writer menu). The number is supplied for you — write only the words after the colon.",
            example: HelpExample("""
            | Draft | Words |
            | ----- | ----- |
            | v1    | 2,400 |

            Table: Length by revision
            """, renders: "Table 1: Length by revision"),
            keywords: ["caption", "label", "numbering", "figure legend"]
        ),
        HelpEntry(
            id: "cs.image",
            lane: .cheatsheet,
            title: "Image",
            summary: "Like a link, with an exclamation mark in front. The bracketed text is the caption.",
            note: "The path is relative to the document. With auto-numbering on, an image alone on its line becomes “Figure N: <your caption>”. Images are embedded on export, so the HTML or PDF travels on its own.",
            example: HelpExample("![The east elevation at dusk](photos/east-elevation.jpg)",
                                 renders: "Figure 1: The east elevation at dusk"),
            keywords: ["picture", "photo", "figure", "screenshot", "alt text", "embed", "png", "jpg"]
        ),
        HelpEntry(
            id: "cs.formula-inline",
            lane: .cheatsheet,
            title: "Formula in a sentence",
            summary: "Wrap LaTeX in single dollar signs to set it inside running text.",
            note: "For a literal dollar sign, escape it: \\$40 renders as $40. Maths is rendered by KaTeX bundled inside the app — it works with no network.",
            example: HelpExample("The area scales as $\\pi r^2$, so doubling $r$ quadruples it."),
            keywords: ["math", "maths", "equation", "latex", "katex", "dollar", "symbol", "greek"]
        ),
        HelpEntry(
            id: "cs.formula-block",
            lane: .cheatsheet,
            title: "Formula on its own line",
            summary: "Double dollar signs centre the formula as a display equation.",
            note: "With auto-numbering on it gets an equation number on the right. Open and close on separate lines to write it across several lines.",
            example: HelpExample("""
            The estimator is unbiased:

            $$
            \\bar{x} = \\frac{1}{n} \\sum_{i=1}^{n} x_i
            $$
            """, renders: "A centred equation, numbered (1) on the right when numbering is on."),
            keywords: ["math", "maths", "display equation", "latex", "katex", "centred", "centered", "sum", "fraction"]
        ),
        HelpEntry(
            id: "cs.formula-cookbook",
            lane: .cheatsheet,
            title: "Formulas worth copying",
            summary: "The LaTeX pieces most writing actually needs, in one place.",
            note: "Anything KaTeX supports works. Subscript is _, superscript is ^, and braces group more than one character: x^{10} not x^10.",
            example: HelpExample("""
            $x^2$            $x_{min}$        $x^{n+1}$
            $\\frac{a}{b}$    $\\sqrt{2}$       $\\sqrt[3]{x}$
            $\\alpha \\beta$   $\\Sigma$         $\\mu$
            $\\pm 5\\%$        $90^{\\circ}$     $12\\,\\text{kg}$
            $\\le \\ge \\ne$    $\\approx$        $\\times \\div$
            $\\sum_{i=1}^{n}$ $\\int_a^b$       $\\bar{x}$
            """, renders: "Powers, subscripts, fractions, roots, Greek letters, units, comparisons, sums and integrals."),
            keywords: ["latex", "symbols", "cheatsheet", "greek", "fraction", "square root", "sigma", "degrees", "percent", "plus minus", "units", "mean"]
        ),
        HelpEntry(
            id: "cs.code-block",
            lane: .cheatsheet,
            title: "Code block",
            summary: "Three backticks, your lines, three backticks to close.",
            note: "Nothing inside is interpreted, which makes it the safe way to show configuration, output, or Markdown itself.",
            example: HelpExample("""
            ```
            rsync -av ./drafts/ backup:/drafts/
            ```
            """),
            keywords: ["fence", "preformatted", "monospace", "snippet", "terminal output", "listing"]
        ),
        HelpEntry(
            id: "cs.mermaid",
            lane: .cheatsheet,
            title: "Diagram",
            summary: "A code block opened with ```mermaid renders as a drawn diagram.",
            note: "Flowcharts, sequence, class, state, entity-relationship, Gantt and pie. Renders live in the split preview and in HTML and PDF export, offline.",
            example: HelpExample("""
            ```mermaid
            flowchart LR
              A[Draft] --> B[Review]
              B --> C{Approved?}
              C -->|yes| D[Publish]
              C -->|no| A
            ```
            """, renders: "A left-to-right flowchart with a decision that loops back."),
            keywords: ["mermaid", "flowchart", "chart", "graph", "sequence diagram", "gantt", "pie", "drawing", "visual"]
        ),
        HelpEntry(
            id: "cs.frontmatter",
            lane: .cheatsheet,
            title: "Front matter",
            summary: "A block fenced by --- at the very top of the file holds the document's details.",
            note: "Hidden from the preview and from exports unless you turn it on in the Writer menu — the two are separate toggles, so you can see it while writing and keep it out of what you send. Kitib keeps a stable id here so links to this document survive renaming it.",
            example: HelpExample("""
            ---
            title: Site survey
            author: P. Raman
            date: 2026-11-03
            status: draft
            ---

            # Site survey
            """, renders: "A small details table above the document, or nothing at all when the toggle is off."),
            keywords: ["yaml", "metadata", "header", "properties", "title", "author", "date", "id"]
        ),
    ]

    // MARK: - Guides

    /// The situation first. A reader with a problem does not search for the name
    /// of the feature that solves it — they search for the problem.
    static let guides: [HelpEntry] = [
        HelpEntry(
            id: "guide.paste-healing",
            lane: .guides,
            title: "I pasted from a PDF and every line breaks in the wrong place",
            summary: "Text copied out of a PDF or Word carries the old page's line breaks, split words and page furniture. Kitib repairs it as it arrives.",
            steps: [
                "Paste as normal (⌘V).",
                "A preview opens with the raw text on one side and the repaired text on the other. Read the repaired side.",
                "Choose “Paste Healed” to take the repair, or “Keep Raw” to paste exactly what was on the clipboard.",
            ],
            note: "What it repairs: lines hard-wrapped mid-sentence are rejoined; words split across a line break are put back together; page headers, footers and running page numbers are dropped; curly quotes and dashes are normalised. It keeps real structure — headings, list items, numbered clauses and table rows each stay on their own line, and it handles a paste that arrives as one long line with no breaks at all. Compound words that belong hyphenated are protected. The bandage icon in the toolbar turns the preview off; a short single-line paste skips it anyway.",
            keywords: ["paste", "pdf", "word", "clipboard", "broken lines", "hard wrap", "line breaks", "hyphen", "ocr", "scanned", "copy", "mangled", "reflow", "heal", "repair"]
        ),
        HelpEntry(
            id: "guide.smart-folders",
            lane: .guides,
            title: "I need every document that mentions something",
            summary: "A smart folder is a saved search that sits in the sidebar and stays current.",
            steps: [
                "In the sidebar, find SMART FOLDERS and click +.",
                "Give it a name and a query, then save.",
                "Open it like any folder: matching documents are listed with the matching words highlighted in a snippet.",
                "Click a result to open that document at the match.",
            ],
            note: "Query syntax: two words with a space between them means both must appear; OR means either; NOT excludes; and quotation marks match an exact phrase. Hyphens and other punctuation need quoting — draft-revision unquoted is rejected as malformed, \"draft-revision\" in quotes matches. The panel tells you which happened, so an empty list never leaves you guessing whether the query was wrong or the words simply aren't there.",
            // Queries only, nothing else. Whatever is in an example block is
            // what the Copy button hands over, so a gloss alongside the code
            // would arrive in the reader's document as text.
            example: HelpExample("""
            draft revision
            chapter OR appendix
            interview NOT withdrawn
            "opening paragraph"
            "draft-revision"
            """, renders: "In order: both words · either word · excludes the second · that exact phrase · a hyphenated term, which must be quoted."),
            keywords: ["search", "find", "saved search", "query", "smart folder", "filter", "boolean", "phrase", "hyphen", "across files", "everywhere", "grep"]
        ),
        HelpEntry(
            id: "guide.reorder",
            lane: .guides,
            title: "I want to move a section, with everything under it",
            summary: "The outline moves a heading and its whole subtree as one piece, so a long document can be restructured without cutting and pasting.",
            steps: [
                "Open the outline with ⌘⇧O, or the list icon in the toolbar.",
                "Click any heading to jump the document to it.",
                "Drag a heading — on macOS you can also use the ≡ handle — and the heading plus everything beneath it lifts as one card.",
                "The line shows where it will land, indented to the level it will land at, and a status line names the move in words before you let go.",
            ],
            note: "A move it will refuse — dropping a section inside itself — is refused while the finger is still down rather than silently doing nothing. Undo (⌘Z) reverses a move in one step.",
            keywords: ["outline", "reorder", "restructure", "drag", "move section", "rearrange", "subtree", "headings", "organise", "organize", "shuffle"]
        ),
        HelpEntry(
            id: "guide.numbering",
            lane: .guides,
            title: "I need my figures, tables and equations numbered",
            summary: "Turn numbering on and the counting is done for you, in the preview and in every export.",
            steps: [
                "Writer menu → turn on numbering.",
                "Write an image on a line of its own: it becomes “Figure N: <your caption>”, taken from the caption in the brackets.",
                "A ```mermaid block becomes “Diagram N”, counted separately from figures.",
                "Put a line starting “Table:” directly under a table for “Table N: <your words>”.",
                "$$…$$ blocks get an equation number on the right.",
            ],
            note: "Numbers are generated at render time, never written into your file — so inserting a figure halfway through renumbers everything after it with no editing.",
            keywords: ["numbering", "auto number", "figure", "table", "diagram", "equation", "caption", "cross-reference", "count", "label"]
        ),
        HelpEntry(
            id: "guide.diagram",
            lane: .guides,
            title: "I want a diagram in a report, without leaving the app",
            summary: "Diagrams are written as text in a ```mermaid block and drawn for you — no separate tool, no exported image to keep in step with the document.",
            steps: [
                "Open a fenced block with ```mermaid and close it with ```.",
                "Write the diagram (start with flowchart LR for left-to-right, or TD for top-down).",
                "Open the split preview (⌘⇧P) to watch it draw as you type.",
            ],
            note: "It renders in HTML and PDF export too, and entirely offline — Mermaid is bundled in the app. Because the diagram is text, it diffs, it is searchable, and it never goes stale against the prose around it.",
            example: HelpExample("""
            ```mermaid
            sequenceDiagram
              Author->>Editor: Submit draft
              Editor->>Author: Comments
              Author->>Editor: Revision
              Editor-->>Author: Accepted
            ```
            """, renders: "A sequence diagram of four exchanges."),
            keywords: ["diagram", "mermaid", "flowchart", "sequence", "gantt", "chart", "drawing", "visual", "offline"]
        ),
        HelpEntry(
            id: "guide.tables",
            lane: .guides,
            title: "I don't want to line up table pipes by hand",
            summary: "Any Markdown table can be edited as a grid, and stays plain Markdown on disk.",
            steps: [
                "Put the caret anywhere inside a table. A grid icon appears in the toolbar.",
                "Click it to open the table as a grid.",
                "Click a cell to type. Tab and Shift-Tab move between cells; Return commits.",
            ],
            note: "The file on disk stays a normal Markdown table throughout — readable, diffable, and openable in anything. On macOS the editor window can be dragged bigger and remembers the size.",
            keywords: ["table", "grid", "cells", "columns", "rows", "align", "pipes", "spreadsheet", "edit table"]
        ),
        HelpEntry(
            id: "guide.formulas",
            lane: .guides,
            title: "I need to write an equation",
            summary: "Maths is written in LaTeX between dollar signs and rendered by KaTeX inside the app.",
            steps: [
                "For maths inside a sentence, wrap it in single dollar signs: $E = mc^2$.",
                "For an equation on its own centred line, use double dollar signs on their own lines.",
                "Open the split preview (⌘⇧P) to check it as you type — an unclosed brace shows up immediately.",
            ],
            note: "For a literal dollar sign write \\$. Nothing is fetched from the network: formulas render on a plane. See “Formulas worth copying” in the Cheatsheet for the pieces most documents need.",
            keywords: ["formula", "equation", "math", "maths", "latex", "katex", "dollar", "offline", "symbols"]
        ),
        HelpEntry(
            id: "guide.export",
            lane: .guides,
            title: "I need to hand this to someone who doesn't have the app",
            summary: "Export to HTML or PDF, or copy the document as rich text to paste into mail or a web form.",
            steps: [
                "Use the share button for HTML or PDF.",
                "Or choose Copy as Rich Text and paste straight into an email, LinkedIn or a document.",
                "⌘P prints, and honours “Print with Line Numbers”.",
            ],
            note: "Export is the fully rendered document: tables, embedded images, formulas and diagrams. Images are inlined, so a single exported HTML file is self-contained. Your own file stays plain Markdown — nothing is locked in, and the document is readable without Kitib.",
            keywords: ["export", "pdf", "html", "print", "share", "rich text", "send", "publish", "email", "linkedin", "deliver"]
        ),
        HelpEntry(
            id: "guide.templates",
            lane: .guides,
            title: "I want to start from something, not a blank page",
            summary: "The new-document button offers starting points, each with a suggested length.",
            steps: [
                "Click the new-document button in the toolbar.",
                "Pick Report, Design Note, Blog Post or LinkedIn Post.",
                "The word goal that suits it is set for you; change it any time from the stats bar.",
            ],
            keywords: ["template", "boilerplate", "starter", "new document", "report", "blog", "linkedin", "design note", "blank page"]
        ),
        HelpEntry(
            id: "guide.focus",
            lane: .guides,
            title: "I keep getting distracted by the rest of the document",
            summary: "Two settings narrow the page to the sentence you are actually writing.",
            steps: [
                "⌘⇧F is focus mode: everything but the current paragraph dims.",
                "⌘⇧T is typewriter scrolling: the line you are typing stays at the centre of the window.",
                "They work together, and both survive a restart.",
            ],
            keywords: ["focus", "typewriter", "distraction free", "dim", "concentrate", "zen", "centred", "centered"]
        ),
        HelpEntry(
            id: "guide.goals",
            lane: .guides,
            title: "I want to see whether I'm getting anywhere",
            summary: "The stats bar counts as you write, and a word goal turns the count into progress.",
            steps: [
                "Click the target icon in the stats bar.",
                "Set a goal for this document.",
                "Progress is kept per file, so each draft carries its own target.",
            ],
            keywords: ["word count", "goal", "target", "progress", "stats", "how many words", "reading time"]
        ),
        HelpEntry(
            id: "guide.todos",
            lane: .guides,
            title: "I want a checklist beside the draft, not inside it",
            summary: "Each document has its own to-do list in a side panel, kept out of the text.",
            steps: [
                "⌘⇧D opens the to-do panel on the right.",
                "Add items at the bottom of the panel.",
                "Click the circle to cross one off; hover an item to delete it.",
            ],
            note: "The list belongs to the document, not the app — nothing you add here appears in what you export.",
            keywords: ["todo", "to-do", "checklist", "tasks", "notes to self", "reminders", "outstanding"]
        ),
        HelpEntry(
            id: "guide.terminal",
            lane: .guides,
            title: "I need a shell without switching apps",
            summary: "A terminal opens below the writing area — enough for git, pandoc or a quick script.",
            steps: [
                "⌃` opens and closes it.",
                "To start it in a particular folder, right-click that folder in the sidebar and choose “Open in Terminal”.",
            ],
            keywords: ["terminal", "shell", "command line", "git", "pandoc", "console", "bash", "zsh"]
        ),
        HelpEntry(
            id: "guide.placeholder",
            lane: .guides,
            title: "I want to see the layout before I have the words",
            summary: "Placeholder text, inserted at the caret and removed in one undo.",
            steps: [
                "Writer menu → Insert Lorem Ipsum.",
                "Choose a sentence, or one, three or five paragraphs.",
                "⌘Z removes the lot in a single step.",
            ],
            keywords: ["lorem ipsum", "placeholder", "dummy text", "filler", "greeking", "mock", "layout"]
        ),
        HelpEntry(
            id: "guide.appearance",
            lane: .guides,
            title: "I want it darker, lighter, or bigger",
            summary: "Appearance and text size are in the Writer menu, and both are remembered.",
            steps: [
                "Writer menu → Appearance for Light, Dark or System.",
                "⌘+ and ⌘− change the text size.",
                "⌘⇧L shows line numbers in the margin.",
            ],
            keywords: ["dark mode", "light mode", "theme", "appearance", "font size", "bigger text", "zoom", "line numbers", "contrast"]
        ),
    ]

    // MARK: - Shortcuts

    static let shortcuts: [HelpEntry] = [
        shortcut("⌘N", "New document", ["create", "blank"]),
        shortcut("⌘O", "Open folder", ["import", "root"]),
        shortcut("⌘S", "Save — autosave is always on anyway", ["write", "store"]),
        shortcut("⌘P", "Print, honouring “Print with Line Numbers”", ["paper", "pdf"]),
        shortcut("⌘⇧F", "Focus mode — dims all but the current paragraph", ["distraction"]),
        shortcut("⌘⇧T", "Typewriter scrolling — keeps the caret centred", ["centre", "center"]),
        shortcut("⌘⇧L", "Line numbers", ["margin", "gutter"]),
        shortcut("⌘⇧P", "Split preview — rendered beside the source, scrolling in sync", ["render", "live"]),
        shortcut("⌃`", "Terminal, below the writing area", ["shell", "console"]),
        shortcut("⌘⇧D", "To-do panel for this document", ["checklist", "tasks"]),
        shortcut("⌘⇧O", "Document outline, with drag-to-reorder", ["headings", "navigate", "structure"]),
        shortcut("⌘+ / ⌘−", "Bigger / smaller text", ["zoom", "font size"]),
        shortcut("⌘Z / ⌘⇧Z", "Undo / redo", ["revert", "mistake"]),
        shortcut("⌘F", "Find in document", ["search"]),
        shortcut("⌥⌘F", "Find and replace", ["substitute", "swap"]),
        shortcut("⌘G / ⌘⇧G", "Next / previous match", ["again", "repeat"]),
        shortcut("⌘E", "Use the selection as the search term", ["selection"]),
        shortcut("⌘/", "This help window", ["help", "reference"]),
    ]

    private static func shortcut(_ keys: String, _ what: String, _ keywords: [String]) -> HelpEntry {
        HelpEntry(
            id: "key." + keys,
            lane: .shortcuts,
            title: what,
            summary: keys,
            shortcut: keys,
            keywords: keywords + ["shortcut", "keyboard"]
        )
    }
}
