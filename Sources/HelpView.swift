import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let markdownRows: [(String, String)] = [
        ("# Heading 1", "Largest heading — use ## … ###### for smaller levels"),
        ("**bold**", "Bold text"),
        ("*italic*", "Italic text"),
        ("`code`", "Inline code / monospace"),
        ("[link text](https://url)", "Hyperlink — visible text in [ ], destination in ( )"),
        ("- item   or   * item", "Bulleted list"),
        ("1. item", "Numbered list"),
        ("> quote", "Block quote"),
        ("---", "Horizontal rule / section break"),
        ("| Col A | Col B |", "Table — next line must be | --- | --- |, then one row per line"),
        ("![caption](image.png)", "Image — path relative to the document (or a URL)"),
        ("$x^2 + y^2$", "Inline formula (LaTeX) — use \\$ for a literal dollar sign"),
        ("$$\\int_a^b f(x)\\,dx$$", "Display formula, centered on its own line"),
        ("```", "Code block — close with another ```"),
    ]

    private let shortcutRows: [(String, String)] = [
        ("⌘N", "New document"),
        ("⌘O", "Open folder"),
        ("⌘S", "Save (autosave is always on)"),
        ("⌘P", "Print — honors “Print with Line Numbers”"),
        ("⌘⇧F", "Focus mode — dims all but the current paragraph"),
        ("⌘⇧T", "Typewriter scrolling — keeps the caret centered"),
        ("⌘⇧L", "Line numbers"),
        ("⌘⇧P", "Split preview — rendered view beside your Markdown, scrolls in sync"),
        ("⌃`", "Integrated terminal — opens below the writing area"),
        ("⌘⇧D", "To-do list — per-document checklist in a right panel"),
        ("⌘+ / ⌘−", "Bigger / smaller text"),
        ("⌘Z / ⌘⇧Z", "Undo / redo"),
        ("⌘F", "Find in document"),
        ("⌥⌘F", "Find and replace"),
        ("⌘G / ⌘⇧G", "Find next / previous match"),
        ("⌘E", "Use selection for find"),
        ("⌘/", "This help window"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Kitib Help")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Markdown formatting",
                            subtitle: "Type these characters and Kitib styles them live. Files stay plain Markdown — portable everywhere.") {
                        ForEach(markdownRows, id: \.0) { row in
                            helpRow(code: row.0, explanation: row.1)
                        }
                    }

                    section("Keyboard shortcuts",
                            subtitle: "Everything is also available from the toolbar and the Writer menu.") {
                        ForEach(shortcutRows, id: \.0) { row in
                            helpRow(code: row.0, explanation: row.1, codeWidth: 90)
                        }
                    }

                    section("Tips", subtitle: nil) {
                        tip("Hyperlinks", "Wrap the words you want to show in square brackets and put the destination right after in parentheses: [Anthropic](https://anthropic.com). The bracketed text is what the reader sees; it becomes clickable in the split preview and in HTML/PDF export. To link to another file in your folder use a relative path — [the spec](specs/draft.md) — and for email use [email me](mailto:you@example.com). A bare URL won’t auto-link, so wrap it the same way: [https://example.com](https://example.com).")
                        tip("Templates", "The toolbar’s new-document button offers Report, Design Note, Blog Post, and LinkedIn Post starting points, each with a suggested word goal.")
                        tip("Word goals", "Click the target icon in the stats bar to set a goal for the current document. Progress is saved per file.")
                        tip("Export", "Use the share button to export HTML or PDF, or Copy as Rich Text to paste formatted into LinkedIn or email.")
                        tip("Printing", "Print (⌘P) and PDF export produce the fully rendered document — tables, images, and formulas included. “Print with Line Numbers” adds small source line numbers in the margin.")
                        tip("Formulas", "Math is rendered with KaTeX, which loads from the internet. Offline, formulas show as raw $…$ text.")
                        tip("Numbering", "Figures, tables, and equations are auto-numbered in the preview and exports (Writer menu toggle). An image on its own line becomes “Figure N: <alt text>”. A line starting “Table: caption” right after a table becomes its caption. $$…$$ blocks get (N) on the right.")
                        tip("Lorem Ipsum", "Writer menu → Insert Lorem Ipsum drops placeholder text at the caret — a sentence or one, three, or five paragraphs. Undo (⌘Z) removes it in one step.")
                        tip("Appearance", "Writer menu → Appearance switches between Light, Dark, or System.")
                        tip("To-dos", "⌘⇧D opens a to-do panel on the right. Each document keeps its own list — add items below, click the circle to cross one off, hover for delete.")
                        tip("Terminal", "⌃` opens a lightweight shell below your writing — handy for git or pandoc. Right-click any folder in the sidebar and choose “Open in Terminal” to start it there.")
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 600)
    }

    private func section<Content: View>(_ title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) { content() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        }
    }

    private func helpRow(code: String, explanation: String, codeWidth: CGFloat = 170) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: codeWidth, alignment: .leading)
            Text(explanation)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func tip(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12, weight: .semibold))
            Text(body).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}
