import AppKit
import WebKit
import PDFKit

enum Exporter {

    // MARK: - Markdown → HTML body

    /// Converts Markdown to an HTML body. Block elements carry data-line
    /// attributes (1-based source line) so printing can show line numbers.
    static func htmlBody(from markdown: String, baseDir: URL?, numbered: Bool = false) -> String {
        let src = markdown.components(separatedBy: "\n")
        var out: [String] = []
        var inList = false, inOrdered = false, inQuote = false
        var paragraph: [String] = []
        var paraStart = 1
        var i = 0
        var figN = 0, tabN = 0, eqN = 0

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

        while i < src.count {
            let n = i + 1
            let raw = src[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if line.hasPrefix("```") {
                closeAll()
                var j = i + 1
                var code: [String] = []
                while j < src.count, !src[j].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(src[j]); j += 1
                }
                let codeHTML = code.map { escape($0) }.joined(separator: "\n")
                // The whole block is anchored to the fence's first content line.
                out.append("<pre data-line=\"\(i + 2)\"><code>\(codeHTML)</code></pre>")
                i = min(j + 1, src.count)
                continue
            }

            // Display math block: $$ ... $$
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

            // Standalone image → numbered figure with caption from alt text
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

            // Table
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
                    // Convention: table captions sit above the table
                    html = "<div class=\"tablecaption\">\(caption)</div>" + html
                }
                out.append(html)
                i = j
                continue
            }

            if line.isEmpty {
                closeAll()
            } else if let m = line.range(of: "^#{1,6}", options: .regularExpression) {
                closeAll()
                let level = line.distance(from: m.lowerBound, to: m.upperBound)
                let content = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                out.append("<h\(level)\(attr(n))>\(inline(content, baseDir: baseDir))</h\(level)>")
            } else if line == "---" || line == "***" || line == "___" {
                closeAll()
                // Wrapped so print line-numbering can anchor a number to it
                // (hr itself can't host positioned children).
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

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Pull regex matches out into placeholders so later passes can't mangle them.
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
        r = r.replacingOccurrences(of: "\\$", with: "&#36;")   // \$ = literal dollar

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

    /// ![alt](path) → <img>, with local images embedded as base64 data URIs
    /// so preview, export, and print all work without file-access issues.
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

    /// - Parameter forPrint: bake the print metrics (12px, full width) into the
    ///   base styles so the layout measured on screen — where line numbers are
    ///   positioned — is exactly the layout that gets paginated. Without this,
    ///   the `@media print` reflow invalidates every computed position.
    static func htmlPage(body: String, title: String, lineNumbers: Bool, forceLight: Bool, forPrint: Bool = false) -> String {
        let darkCSS = forceLight ? "" : """
        @media (prefers-color-scheme: dark) {
          body { background: #1e1e21; color: #e8e8ea; }
          code, pre { background: #2c2c30; }
          blockquote { border-color: #4a4a50; color: #a0a0a8; }
          th { background: #2c2c30; }
          th, td { border-color: #3a3a40; }
          hr { border-color: #3a3a40; }
          a { color: #6cb2ff; }
          figcaption, .tablecaption, .mathblock .eqno { color: #a0a0a8; }
        }
        """
        let printCSS = forPrint ? """
        body { font-size: 12px; max-width: none; padding: 0; }
        """ : ""
        // Line numbers are stamped purely in CSS from each block's data-line
        // (its 1-based source line). No JS measurement, so nothing can go
        // stale when WebKit re-lays-out the page for print. The number is
        // anchored inside its own block, so it travels with the text across
        // page breaks and matches the editor gutter (a block on source line 7
        // prints "7"). Numbers reflect SOURCE lines, so values skip blank
        // lines and multi-line paragraphs — exactly like the editor.
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
        /* Blocks whose first text line is pushed down by inner padding/margins
           need the number nudged to meet it. */
        #content pre[data-line]::before { top: 16px; }
        #content blockquote[data-line]::before { top: 16px; }
        /* List items sit inside the list's left padding; pull the number back
           out into the gutter. */
        #content li[data-line]::before { left: -78px; }
        """ : ""

        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(escape(title))</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
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
        // Line numbers are handled entirely in CSS (see [data-line]::before),
        // so the only JS work here is rendering math.
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
        window.update = function(html) {
          document.getElementById('content').innerHTML = html;
          renderMath();
        };
        document.addEventListener('DOMContentLoaded', renderMath);
        </script>
        </head><body><div id="content">
        \(body)
        </div></body></html>
        """
    }

    // MARK: - Print / PDF via rendered web view

    private static func standardPrintInfo() -> NSPrintInfo {
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.topMargin = 50; printInfo.bottomMargin = 50
        printInfo.leftMargin = 50; printInfo.rightMargin = 50
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        return printInfo
    }

    static func printDocument(markdown: String, title: String, baseDir: URL?, withLineNumbers: Bool, numbered: Bool = false) {
        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered),
            title: title, lineNumbers: withLineNumbers, forceLight: true, forPrint: true
        )
        WebPrinter.start(html: page, printInfo: standardPrintInfo(), showsPanel: true, jobTitle: title)
    }

    static func exportPDF(markdown: String, title: String, baseDir: URL?, withLineNumbers: Bool, numbered: Bool = false) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = title + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let printInfo = standardPrintInfo()
        printInfo.jobDisposition = .save
        printInfo.dictionary().setObject(url, forKey: NSPrintInfo.AttributeKey.jobSavingURL.rawValue as NSString)

        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered),
            title: title, lineNumbers: withLineNumbers, forceLight: true, forPrint: true
        )
        WebPrinter.start(html: page, printInfo: printInfo, showsPanel: false, jobTitle: title) { success in
            if success { stampPageNumbers(at: url) }
        }
    }

    /// Adds a centered "X of Y" footer to every page of a saved PDF.
    private static func stampPageNumbers(at url: URL) {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { return }
        let total = doc.pageCount
        for i in 0..<total {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let w: CGFloat = 140, h: CGFloat = 16
            let annotation = PDFAnnotation(
                bounds: NSRect(x: bounds.minX + (bounds.width - w) / 2, y: bounds.minY + 22,
                               width: w, height: h),
                forType: .freeText, withProperties: nil
            )
            annotation.contents = "\(i + 1) of \(total)"
            annotation.font = NSFont.systemFont(ofSize: 9)
            annotation.fontColor = NSColor(white: 0.45, alpha: 1)
            annotation.color = .clear            // freeText background
            annotation.alignment = .center
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            annotation.isReadOnly = true
            page.addAnnotation(annotation)
        }
        doc.write(to: url)
    }

    static func exportHTML(markdown: String, title: String, baseDir: URL?, numbered: Bool = false) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = title + ".html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered),
            title: title, lineNumbers: false, forceLight: false
        )
        try? page.write(to: url, atomically: true, encoding: .utf8)
    }

    static func copyAsRichText(markdown: String) {
        let storage = NSTextStorage(string: markdown)
        MarkdownHighlighter.highlight(storage: storage, baseSize: 15)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([storage])
    }
}

// MARK: - Offscreen web view that renders, then prints

private final class WebPrinter: NSObject, WKNavigationDelegate {
    private static var retained: [WebPrinter] = []

    private let webView: WKWebView
    private let printInfo: NSPrintInfo
    private let showsPanel: Bool
    private let jobTitle: String
    private let onComplete: ((Bool) -> Void)?

    static func start(html: String, printInfo: NSPrintInfo, showsPanel: Bool, jobTitle: String,
                      onComplete: ((Bool) -> Void)? = nil) {
        let printer = WebPrinter(printInfo: printInfo, showsPanel: showsPanel,
                                 jobTitle: jobTitle, onComplete: onComplete)
        retained.append(printer)
        printer.webView.loadHTMLString(html, baseURL: nil)
    }

    private init(printInfo: NSPrintInfo, showsPanel: Bool, jobTitle: String,
                 onComplete: ((Bool) -> Void)?) {
        let width = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 800))
        self.printInfo = printInfo
        self.showsPanel = showsPanel
        self.jobTitle = jobTitle
        self.onComplete = onComplete
        super.init()
        webView.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        waitForMath(attempts: 12)   // poll up to ~3s for KaTeX (CDN), then print anyway
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        startPrint()
    }

    private func waitForMath(attempts: Int) {
        webView.evaluateJavaScript("window.kitibMathDone === true && !!window.renderMathInElement") { [weak self] result, _ in
            guard let self else { return }
            if (result as? Bool) == true || attempts <= 0 {
                // small grace period for images/fonts to settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.startPrint() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.waitForMath(attempts: attempts - 1)
                }
            }
        }
    }

    private func startPrint() {
        // Keep the webView's width unchanged (it already matches the print
        // column width: paperSize minus margins). Only grow its height to
        // fit all content so the print operation paginates without re-wrapping
        // the text (which would shift pagination). Line numbers are CSS-anchored
        // to their blocks, so they stay aligned regardless.
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            guard let self else { return }
            let contentHeight = (result as? NSNumber)?.doubleValue ?? Double(self.webView.frame.height)
            let width = self.webView.frame.width
            let height = max(CGFloat(contentHeight), self.printInfo.paperSize.height)
            self.webView.frame = NSRect(x: 0, y: 0, width: width, height: height)

            let op = self.webView.printOperation(with: self.printInfo)
            op.jobTitle = self.jobTitle
            op.showsPrintPanel = self.showsPanel
            op.showsProgressPanel = self.showsPanel
            if let window = NSApp.mainWindow ?? NSApp.windows.first {
                op.runModal(for: window, delegate: self,
                            didRun: #selector(self.printOperationDidRun(_:success:contextInfo:)),
                            contextInfo: nil)
            } else {
                let success = op.run()
                self.onComplete?(success)
                self.release()
            }
        }
    }

    @objc private func printOperationDidRun(_ printOperation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        onComplete?(success)
        release()
    }

    private func release() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            WebPrinter.retained.removeAll { $0 === self }
        }
    }
}
