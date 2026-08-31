import Foundation

/// Pure Markdown → HTML conversion. No platform UI dependencies, so this is
/// shared by macOS and iPadOS. Print / PDF / share live in the per-platform
/// `Exporter+macOS` / `Exporter+iOS` extensions.
enum Exporter {

    // MARK: - Markdown → HTML body

    static func htmlBody(from markdown: String, baseDir: URL?, numbered: Bool = false, showFrontMatter: Bool = false) -> String {
        let src = markdown.components(separatedBy: "\n")
        var out: [String] = []
        var inList = false, inOrdered = false, inQuote = false
        var paragraph: [String] = []
        var paraStart = 1
        var i = 0
        var figN = 0, tabN = 0, eqN = 0, diaN = 0

        func attr(_ n: Int) -> String { " data-line=\"\(n)\"" }
        func mathBlock(_ inner: String, line: Int) -> String {
            guard numbered else { return "<div class=\"mathblock\"\(attr(line))>\(inner)</div>" }
            eqN += 1
            return "<div class=\"mathblock numbered\"\(attr(line))><span class=\"eq\">\(inner)</span><span class=\"eqno\">(\(eqN))</span></div>"
        }
        func closeParagraph() {
            if !paragraph.isEmpty {
                out.append("<p\(attr(paraStart))>\(inline(paragraph.joined(separator: " "), baseDir: baseDir))</p>")
                paragraph = []
            }
        }
        func closeLists() {
            if inList { out.append("</ul>"); inList = false }
            if inOrdered { out.append("</ol>"); inOrdered = false }
        }
        func closeQuote() { if inQuote { out.append("</blockquote>"); inQuote = false } }
        func closeAll() { closeParagraph(); closeLists(); closeQuote() }

        func isTableSeparator(_ s: String) -> Bool {
            let t = s.trimmingCharacters(in: .whitespaces)
            guard t.contains("-"), !t.isEmpty else { return false }
            return t.allSatisfy { "|-: \t".contains($0) }
        }
        func cells(_ s: String) -> [String] {
            var t = s.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("|") { t.removeFirst() }
            if t.hasSuffix("|") { t.removeLast() }
            return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        // YAML front matter — a `---`…`---` block, but only when it's the very
        // first line of the document. Hidden by default; rendered as a metadata
        // table when `showFrontMatter` is on. Either way the body that follows
        // keeps its original line numbers (data-line) for scroll/line sync.
        if let first = src.first, first.trimmingCharacters(in: .whitespaces) == "---" {
            var k = 1
            while k < src.count, src[k].trimmingCharacters(in: .whitespaces) != "---" { k += 1 }
            if k < src.count {                       // found the closing fence
                if showFrontMatter {
                    var rows = ""
                    for idx in 1..<k {
                        let t = src[idx].trimmingCharacters(in: .whitespaces)
                        if t.isEmpty { continue }
                        guard let colon = t.firstIndex(of: ":") else { continue }
                        let key = String(t[..<colon]).trimmingCharacters(in: .whitespaces)
                        let value = String(t[t.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                        let label = key.isEmpty ? "" : key.prefix(1).uppercased() + key.dropFirst()
                        rows += "<tr><th>\(escape(label))</th><td>\(escape(value))</td></tr>"
                    }
                    if !rows.isEmpty {
                        out.append("<table class=\"frontmatter\"\(attr(1))>\(rows)</table>")
                    }
                }
                i = k + 1                            // resume body after the block
            }
        }

        while i < src.count {
            let n = i + 1
            let raw = src[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                closeAll()
                let lang = line.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased()
                var j = i + 1
                var code: [String] = []
                while j < src.count, !src[j].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(src[j]); j += 1
                }
                if lang == "mermaid" {
                    // Rendered client-side by Mermaid. The raw diagram source is
                    // escaped so `<`/`>`/`&` are safe as HTML; Mermaid reads it
                    // back via textContent, which decodes the entities.
                    let diagram = escape(code.joined(separator: "\n"))
                    let pre = "<pre class=\"mermaid\" data-line=\"\(i + 2)\">\(diagram)</pre>"
                    if numbered {
                        diaN += 1
                        out.append("<figure>\(pre)<figcaption>Diagram \(diaN)</figcaption></figure>")
                    } else {
                        out.append(pre)
                    }
                } else {
                    let codeHTML = code.map { escape($0) }.joined(separator: "\n")
                    out.append("<pre data-line=\"\(i + 2)\"><code>\(codeHTML)</code></pre>")
                }
                i = min(j + 1, src.count)
                continue
            }

            if line.hasPrefix("$$") {
                closeAll()
                if line.count > 4 && line.hasSuffix("$$") {
                    out.append(mathBlock(escape(line), line: n))
                    i += 1
                } else {
                    var j = i + 1
                    var math: [String] = [line]
                    while j < src.count {
                        let t = src[j].trimmingCharacters(in: .whitespaces)
                        math.append(src[j]); j += 1
                        if t.hasSuffix("$$") { break }
                    }
                    out.append(mathBlock(escape(math.joined(separator: "\n")), line: n))
                    i = j
                }
                continue
            }

            if numbered, line.range(of: "^!\\[[^\\]]*\\]\\([^)\\s]+\\)$", options: .regularExpression) != nil {
                closeAll()
                figN += 1
                var caption = ""
                if let close = line.firstIndex(of: "]"), line.count > 2 {
                    caption = String(line[line.index(line.startIndex, offsetBy: 2)..<close])
                }
                let img = replaceImages(in: escape(line), baseDir: baseDir)
                let label = caption.isEmpty ? "Figure \(figN)" : "Figure \(figN): \(escape(caption))"
                out.append("<figure\(attr(n))>\(img)<figcaption>\(label)</figcaption></figure>")
                i += 1
                continue
            }

            if line.contains("|"), !line.isEmpty, i + 1 < src.count, isTableSeparator(src[i + 1]) {
                closeAll()
                let header = cells(line)
                var rows: [[String]] = []
                var j = i + 2
                while j < src.count {
                    let t = src[j].trimmingCharacters(in: .whitespaces)
                    guard t.contains("|"), !t.isEmpty else { break }
                    rows.append(cells(src[j])); j += 1
                }
                var html = "<table\(attr(n))><thead><tr>"
                html += header.map { "<th>\(inline($0, baseDir: baseDir))</th>" }.joined()
                html += "</tr></thead><tbody>"
                for row in rows {
                    html += "<tr>" + (0..<header.count).map { k in
                        "<td>\(inline(k < row.count ? row[k] : "", baseDir: baseDir))</td>"
                    }.joined() + "</tr>"
                }
                html += "</tbody></table>"
                if numbered {
                    tabN += 1
                    var caption = "Table \(tabN)"
                    if j < src.count {
                        let next = src[j].trimmingCharacters(in: .whitespaces)
                        if next.lowercased().hasPrefix("table:") {
                            let text = next.dropFirst(6).trimmingCharacters(in: .whitespaces)
                            if !text.isEmpty { caption += ": \(inline(text, baseDir: baseDir))" }
                            j += 1
                        }
                    }
                    html = "<div class=\"tablecaption\">\(caption)</div>" + html
                }
                out.append(html)
                i = j
                continue
            }

            if line.isEmpty {
                // A single blank line between items of the *same* list should not
                // terminate the list (that's a "loose" list, still one <ol>/<ul>).
                // Only close the list if the next non-blank line isn't a matching
                // list item, or if there are two+ blank lines in a row.
                if inList || inOrdered {
                    closeParagraph(); closeQuote()
                    var j = i + 1
                    while j < src.count && src[j].isEmpty { j += 1 }
                    let next = j < src.count ? src[j] : nil
                    let nextIsUnordered = next.map { $0.range(of: "^[-*+]\\s", options: .regularExpression) != nil } ?? false
                    let nextIsOrdered = next.map { $0.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil } ?? false
                    let sameListContinues = (inList && nextIsUnordered) || (inOrdered && nextIsOrdered)
                    if !sameListContinues {
                        closeLists()
                    }
                } else {
                    closeAll()
                }
            } else if let m = line.range(of: "^#{1,6}", options: .regularExpression) {
                closeAll()
                let level = line.distance(from: m.lowerBound, to: m.upperBound)
                let content = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                out.append("<h\(level)\(attr(n))>\(inline(content, baseDir: baseDir))</h\(level)>")
            } else if line == "---" || line == "***" || line == "___" {
                closeAll()
                out.append("<div class=\"hrwrap\"\(attr(n))><hr></div>")
            } else if line.hasPrefix(">") {
                closeParagraph(); closeLists()
                if !inQuote { out.append("<blockquote\(attr(n))>"); inQuote = true }
                out.append("<p>\(inline(String(line.dropFirst()).trimmingCharacters(in: .whitespaces), baseDir: baseDir))</p>")
            } else if line.range(of: "^[-*+]\\s", options: .regularExpression) != nil {
                closeParagraph(); closeQuote()
                if inOrdered { out.append("</ol>"); inOrdered = false }
                if !inList { out.append("<ul>"); inList = true }
                out.append("<li\(attr(n))>\(inline(String(line.dropFirst(2)), baseDir: baseDir))</li>")
            } else if let m = line.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                closeParagraph(); closeQuote()
                if inList { out.append("</ul>"); inList = false }
                if !inOrdered { out.append("<ol>"); inOrdered = true }
                out.append("<li\(attr(n))>\(inline(String(line[m.upperBound...]), baseDir: baseDir))</li>")
            } else {
                closeLists(); closeQuote()
                if paragraph.isEmpty { paraStart = n }
                paragraph.append(line)
            }
            i += 1
        }
        closeAll()
        return out.joined(separator: "\n")
    }

    // MARK: - Inline formatting

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func extract(pattern: String, from text: String, into store: inout [String],
                                open: Character, close: Character) -> String {
        guard let rx = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        while let m = rx.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
              let r = Range(m.range, in: result) {
            store.append(String(result[r]))
            result.replaceSubrange(r, with: "\(open)\(store.count - 1)\(close)")
        }
        return result
    }

    private static func inline(_ s: String, baseDir: URL?) -> String {
        var r = escape(s)
        r = r.replacingOccurrences(of: "\\$", with: "&#36;")

        var codeSpans: [String] = []
        r = extract(pattern: "`[^`]+`", from: r, into: &codeSpans, open: "\u{E000}", close: "\u{E001}")
        var mathSpans: [String] = []
        r = extract(pattern: "\\$[^$]+\\$", from: r, into: &mathSpans, open: "\u{E002}", close: "\u{E003}")

        r = replaceImages(in: r, baseDir: baseDir)

        func sub(_ pattern: String, _ template: String) {
            r = (try? NSRegularExpression(pattern: pattern))?
                .stringByReplacingMatches(in: r, range: NSRange(r.startIndex..., in: r), withTemplate: template) ?? r
        }
        sub("\\*\\*(.+?)\\*\\*", "<strong>$1</strong>")
        sub("(?<!\\*)\\*(?!\\*)([^*]+?)\\*(?!\\*)", "<em>$1</em>")
        sub("\\[([^\\]]+)\\]\\(([^)]+)\\)", "<a href=\"$2\">$1</a>")

        for (k, m) in mathSpans.enumerated() {
            r = r.replacingOccurrences(of: "\u{E002}\(k)\u{E003}", with: m)
        }
        for (k, c) in codeSpans.enumerated() {
            let inner = String(c.dropFirst().dropLast())
            r = r.replacingOccurrences(of: "\u{E000}\(k)\u{E001}", with: "<code>\(inner)</code>")
        }
        return r
    }

    private static func replaceImages(in text: String, baseDir: URL?) -> String {
        guard let rx = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)\\s]+)\\)") else { return text }
        var result = text
        let matches = rx.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for m in matches {
            guard let whole = Range(m.range, in: result),
                  let altR = Range(m.range(at: 1), in: result),
                  let srcR = Range(m.range(at: 2), in: result) else { continue }
            let alt = String(result[altR])
            let src = String(result[srcR])
            let resolved = dataURI(for: src, baseDir: baseDir) ?? src
            result.replaceSubrange(whole, with: "<img src=\"\(resolved)\" alt=\"\(alt)\">")
        }
        return result
    }

    private static func dataURI(for src: String, baseDir: URL?) -> String? {
        if src.hasPrefix("http://") || src.hasPrefix("https://") || src.hasPrefix("data:") { return nil }
        let path = src.removingPercentEncoding ?? src
        let url: URL = path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : URL(fileURLWithPath: path, relativeTo: baseDir)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mimes = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
                     "gif": "image/gif", "svg": "image/svg+xml", "webp": "image/webp",
                     "heic": "image/heic", "tiff": "image/tiff", "bmp": "image/bmp"]
        let mime = mimes[url.pathExtension.lowercased()] ?? "image/png"
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    // MARK: - Full HTML page (KaTeX-enabled)

    static func htmlPage(body: String, title: String, lineNumbers: Bool, forceLight: Bool, forPrint: Bool = false) -> String {
        let darkCSS = forceLight ? "" : """
        @media (prefers-color-scheme: dark) {
          body { background: #1e1e21; color: #e8e8ea; }
          code, pre { background: #2c2c30; }
          blockquote { border-color: #4a4a50; color: #a0a0a8; }
          th { background: #2c2c30; }
          th, td { border-color: #3a3a40; }
          table.frontmatter th { background: none; color: #a0a0a8; }
          table.frontmatter td { color: #e8e8ea; }
          hr { border-color: #3a3a40; }
          a { color: #6cb2ff; }
          figcaption, .tablecaption, .mathblock .eqno { color: #a0a0a8; }
        }
        """
        let printCSS = forPrint ? """
        body { font-size: 12px; max-width: none; padding: 0; }
        """ : ""
        let lineNumCSS = lineNumbers ? """
        body { padding-left: 44px; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        #content [data-line] { position: relative; }
        #content [data-line]::before {
          content: attr(data-line);
          position: absolute; left: -38px; top: 4px;
          width: 30px; text-align: right;
          font: 10px/1 ui-monospace, Menlo, monospace;
          color: #555 !important; pointer-events: none;
        }
        #content pre[data-line]::before { top: 16px; }
        #content blockquote[data-line]::before { top: 16px; }
        #content li[data-line]::before { left: -78px; }
        """ : ""

        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(escape(title))</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(WebAssets.headMarkup)
        <style>
        body { font: 16px/1.6 -apple-system, "Helvetica Neue", sans-serif; color: #1d1d1f;
               background: #ffffff; max-width: 46em; margin: 0 auto; padding: 2.2em 2em; }
        h1, h2, h3, h4 { line-height: 1.25; }
        h1 { font-size: 1.9em; } h2 { font-size: 1.45em; } h3 { font-size: 1.2em; }
        code { font-family: ui-monospace, Menlo, monospace; background: #f2f2f4;
               padding: .15em .35em; border-radius: 4px; font-size: .9em; }
        pre { background: #f2f2f4; padding: 1em; border-radius: 8px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        blockquote { border-left: 3px solid #d2d2d7; margin-left: 0; padding-left: 1.2em; color: #6e6e73; }
        hr { border: none; border-top: 1px solid #d2d2d7; margin: 2.2em 0; }
        a { color: #0066cc; }
        img { max-width: 100%; border-radius: 6px; }
        table { border-collapse: collapse; width: 100%; margin: 1em 0; }
        th, td { border: 1px solid #d2d2d7; padding: .45em .8em; text-align: left; font-size: .95em; }
        th { background: #f5f5f7; font-weight: 600; }
        table.frontmatter { border-collapse: collapse; width: 100%; margin: 0 0 1.8em; }
        table.frontmatter th, table.frontmatter td { border: none;
            border-bottom: 1px solid rgba(128,128,128,.18);
            padding: .55em .2em; text-align: left; vertical-align: top; font-size: .95em; }
        table.frontmatter th { width: 32%; font-weight: 500; color: #6e6e73;
            background: none; white-space: nowrap; }
        table.frontmatter td { color: #1d1d1f; }
        .mathblock { text-align: center; margin: 1.2em 0; }
        .mathblock.numbered { position: relative; padding: 0 3em; }
        .mathblock .eqno { position: absolute; right: 0; top: 50%; transform: translateY(-50%);
                           color: #6e6e73; font-size: .9em; }
        figure { margin: 1.4em 0; text-align: center; }
        figcaption, .tablecaption { font-size: .85em; color: #6e6e73; margin-top: .45em; text-align: center; }
        .tablecaption { margin: 1.4em 0 0; }
        .tablecaption + table { margin-top: .4em; }
        .katex { font-size: 1.12em; }
        .katex-display { margin: 0.4em 0; }
        pre.mermaid { background: none; padding: 0; margin: 1.4em 0; text-align: center;
                      overflow-x: auto; white-space: normal; color: inherit; }
        pre.mermaid svg { max-width: 100%; height: auto; }
        pre.mermaid[data-processed] { font-family: inherit; }
        @media print {
          \(forPrint ? "" : "body { max-width: none; padding: 0; font-size: 12px; }")
          pre, table, img, figure, .mathblock { break-inside: avoid; }
          h1, h2, h3 { break-after: avoid; }
        }
        \(printCSS)
        \(lineNumCSS)
        \(darkCSS)
        </style>
        <script>
        var _forceLightTheme = \(forceLight ? "true" : "false");
        function renderMath() {
          if (window.renderMathInElement) {
            renderMathInElement(document.getElementById('content'), {
              delimiters: [
                {left: '$$', right: '$$', display: true},
                {left: '$', right: '$', display: false}
              ],
              throwOnError: false
            });
          }
          window.kitibMathDone = true;
        }
        function renderDiagrams() {
          window.kitibDiagramsDone = false;
          var nodes = document.querySelectorAll('#content pre.mermaid');
          if (!window.mermaid || nodes.length === 0) { window.kitibDiagramsDone = true; return; }
          var dark = !_forceLightTheme && window.matchMedia &&
                     window.matchMedia('(prefers-color-scheme: dark)').matches;
          mermaid.initialize({ startOnLoad: false, securityLevel: 'loose',
                               fontFamily: 'inherit', theme: dark ? 'dark' : 'default' });
          try {
            mermaid.run({ nodes: nodes })
              .then(function () { window.kitibDiagramsDone = true; })
              .catch(function () { window.kitibDiagramsDone = true; });
          } catch (e) { window.kitibDiagramsDone = true; }
        }
        function renderContent() { renderMath(); renderDiagrams(); }
        window.update = function(html) {
          document.getElementById('content').innerHTML = html;
          renderContent();
        };
        document.addEventListener('DOMContentLoaded', renderContent);
        </script>
        </head><body><div id="content">
        \(body)
        </div></body></html>
        """
    }
}
