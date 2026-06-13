import AppKit

/// Lightweight live Markdown styling applied directly to an NSTextStorage.
/// Styles in place — the underlying text stays plain Markdown.
enum MarkdownHighlighter {

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static let headingRx = regex("^(#{1,6})\\s.*$")
    private static let boldRx = regex("\\*\\*(?!\\s)(.+?)(?<!\\s)\\*\\*")
    private static let italicRx = regex("(?<!\\*)\\*(?!\\s|\\*)([^*\\n]+?)(?<!\\s)\\*(?!\\*)")
    private static let codeRx = regex("`[^`\\n]+`")
    private static let linkRx = regex("\\[([^\\]\\n]+)\\]\\(([^)\\n]+)\\)")
    private static let listRx = regex("^\\s*([-*+]|\\d+\\.)\\s")
    private static let mathRx = regex("\\$[^$\\n]+\\$")
    private static let imageRx = regex("!\\[[^\\]\\n]*\\]\\([^)\\n]*\\)")
    private static let pipeRx = regex("\\|")
    private static let fenceRx = regex("^```.*$")
    private static let quoteRx = regex("^>.*$")
    private static let hrRx = regex("^(---|\\*\\*\\*|___)\\s*$")

    static func highlight(storage: NSTextStorage, baseSize: CGFloat) {
        let full = NSRange(location: 0, length: storage.length)

        let bodyFont = NSFont.systemFont(ofSize: baseSize)
        let baseColor = NSColor.textColor

        storage.beginEditing()
        storage.setAttributes([:], range: full)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.35
        paragraph.paragraphSpacing = baseSize * 0.4
        storage.addAttributes([
            .font: bodyFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraph,
        ], range: full)

        // Headings
        headingRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            let level = m.range(at: 1).length
            let sizes: [CGFloat] = [1.7, 1.45, 1.25, 1.12, 1.05, 1.0]
            let size = baseSize * sizes[min(level, 6) - 1]
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .bold), range: m.range)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: m.range(at: 1))
        }

        // Bold / italic / code / links
        boldRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: baseSize, weight: .bold), range: m.range)
        }
        italicRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            let italic = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italic, range: m.range)
        }
        codeRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: baseSize * 0.92, weight: .regular), range: m.range)
            storage.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
        }
        linkRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: m.range(at: 1))
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: m.range(at: 2))
        }
        listRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range(at: 1))
        }
        quoteRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            let italic = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
            storage.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: italic,
            ], range: m.range)
        }
        hrRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.separatorColor, range: m.range)
        }
        mathRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttributes([
                .foregroundColor: NSColor.systemPurple,
                .font: NSFont.monospacedSystemFont(ofSize: baseSize * 0.95, weight: .regular),
            ], range: m.range)
        }
        imageRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: m.range)
        }
        pipeRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: m.range)
        }
        fenceRx.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m = m else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
        }

        storage.endEditing()
    }
}
