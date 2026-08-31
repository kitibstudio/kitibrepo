import AppKit
import WebKit
import PDFKit

// macOS print / PDF / HTML / rich-text export. Markdown→HTML lives in
// the shared `ExporterCore`.
extension Exporter {

    /// Page geometry for print and PDF export: the user's default paper, with
    /// the 50pt margins this app has always used.
    private static func standardGeometry() -> PageGeometry {
        PageGeometry(paper: NSPrintInfo.shared.paperSize, margin: 50)
    }

    /// Print info for a job whose pages are ALREADY laid out at paper size with
    /// margins baked in, so it must add none of its own. Applying margins here
    /// as well would inset the content twice.
    private static func standardPrintInfo() -> NSPrintInfo {
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.topMargin = 0; printInfo.bottomMargin = 0
        printInfo.leftMargin = 0; printInfo.rightMargin = 0
        printInfo.horizontalPagination = .clip
        printInfo.verticalPagination = .clip
        return printInfo
    }

    static func printDocument(markdown: String, title: String, baseDir: URL?,
                              withLineNumbers: Bool, numbered: Bool = false,
                              showFrontMatter: Bool = false) {
        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered,
                           showFrontMatter: showFrontMatter),
            title: title, lineNumbers: withLineNumbers, forceLight: true, forPrint: true
        )
        WebPaginator.render(html: page, geometry: standardGeometry()) { document in
            guard let document else {
                reportFailure("Kitib could not prepare this document for printing.")
                return
            }
            let keyWindowBeforePrint = NSApp.keyWindow
            guard let op = document.printOperation(for: standardPrintInfo(),
                                                   scalingMode: .pageScaleNone,
                                                   autoRotate: false) else {
                reportFailure("Kitib could not start the print job.")
                return
            }
            op.jobTitle = title
            op.showsPrintPanel = true
            op.showsProgressPanel = true
            op.run()
            // Restore key-window focus so typing works immediately afterwards.
            keyWindowBeforePrint?.makeKeyAndOrderFront(nil)
        }
    }

    static func exportPDF(markdown: String, title: String, baseDir: URL?,
                          withLineNumbers: Bool, numbered: Bool = false,
                          showFrontMatter: Bool = false) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = title + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered,
                           showFrontMatter: showFrontMatter),
            title: title, lineNumbers: withLineNumbers, forceLight: true, forPrint: true
        )
        WebPaginator.render(html: page, geometry: standardGeometry()) { document in
            guard let document, document.write(to: url) else {
                reportFailure("Kitib could not write the PDF.")
                return
            }
            stampPageNumbers(at: url)
        }
    }

    private static func reportFailure(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = "Nothing was printed or saved."
        alert.alertStyle = .warning
        alert.runModal()
    }

    private static func stampPageNumbers(at url: URL) {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { return }
        let total = doc.pageCount
        for i in 0..<total {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let w: CGFloat = 140, h: CGFloat = 16
            let annotation = PDFAnnotation(
                bounds: NSRect(x: bounds.minX + (bounds.width - w) / 2,
                               y: bounds.minY + 22, width: w, height: h),
                forType: .freeText, withProperties: nil
            )
            annotation.contents = "\(i + 1) of \(total)"
            annotation.font = NSFont.systemFont(ofSize: 9)
            annotation.fontColor = NSColor(white: 0.45, alpha: 1)
            annotation.color = .clear
            annotation.alignment = .center
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            annotation.isReadOnly = true
            page.addAnnotation(annotation)
        }
        doc.write(to: url)
    }

    static func exportHTML(markdown: String, title: String, baseDir: URL?,
                           numbered: Bool = false, showFrontMatter: Bool = false) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = title + ".html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered,
                           showFrontMatter: showFrontMatter),
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

// MARK: - Page geometry

/// Paper and margins for one print or export job.
struct PageGeometry {
    let paper: CGSize
    let margin: CGFloat

    var contentWidth: CGFloat { paper.width - margin * 2 }
    var contentHeight: CGFloat { paper.height - margin * 2 }
}

// MARK: - Offscreen web view that renders, then paginates

/// Renders Markdown-derived HTML into a paginated `PDFDocument`.
///
/// It does NOT use `WKWebView.printOperation(with:)`. On macOS 26 that call
/// never returns: it loops inside `_printForCurrentOperation` emitting pages
/// forever, growing the output without bound until the app is killed — which
/// is what ⌘P did (D71). Instead the document is rendered continuously, cut
/// into pages by `PagePlan`, and each page captured with `createPDF`, which
/// terminates and honours the requested rect exactly.
private final class WebPaginator: NSObject, WKNavigationDelegate {
    private static var retained: [WebPaginator] = []

    private let webView: WKWebView
    private let geometry: PageGeometry
    private let completion: (PDFDocument?) -> Void
    private var finished = false

    static func render(html: String, geometry: PageGeometry,
                       completion: @escaping (PDFDocument?) -> Void) {
        let paginator = WebPaginator(geometry: geometry, completion: completion)
        retained.append(paginator)
        paginator.webView.loadHTMLString(html, baseURL: WebAssets.bundleURL)
    }

    private init(geometry: PageGeometry, completion: @escaping (PDFDocument?) -> Void) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        self.webView = WKWebView(
            frame: NSRect(x: 0, y: 0,
                          width: geometry.contentWidth, height: geometry.contentHeight),
            configuration: config)
        self.geometry = geometry
        self.completion = completion
        super.init()
        webView.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        correctLayoutWidth()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                 withError error: Error) {
        finish(nil)
    }

    /// A vertical scrollbar takes width away from layout, so text would be laid
    /// out narrower than the printable area and sit against the left margin
    /// with a gap on the right. Widen the frame by the gutter so the laid-out
    /// width is exactly the printable width. Done before the render wait, since
    /// it changes the width KaTeX and Mermaid lay out against.
    private func correctLayoutWidth() {
        webView.evaluateJavaScript("document.documentElement.clientWidth") {
            [weak self] result, _ in
            guard let self else { return }
            if let clientWidth = (result as? NSNumber)?.doubleValue, clientWidth > 0 {
                let gutter = self.webView.frame.width - CGFloat(clientWidth)
                if gutter > 0 {
                    self.webView.frame = NSRect(x: 0, y: 0,
                                                width: self.geometry.contentWidth + gutter,
                                                height: self.webView.frame.height)
                }
            }
            self.waitForRender(attempts: 12)
        }
    }

    /// Poll KaTeX and Mermaid completion flags so async SVG output isn't
    /// captured half-drawn. Falls through to measure() after timeout.
    private func waitForRender(attempts: Int) {
        webView.evaluateJavaScript(
            "window.kitibMathDone === true && window.kitibDiagramsDone === true"
        ) { [weak self] result, _ in
            guard let self else { return }
            if (result as? Bool) == true || attempts <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.measure()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.waitForRender(attempts: attempts - 1)
                }
            }
        }
    }

    /// Measure the document height and the extent of every top-level block, so
    /// pages can be cut between blocks rather than through them.
    private func measure() {
        let js = """
        (function () {
          var root = document.getElementById('content') || document.body;
          var blocks = [];
          for (var i = 0; i < root.children.length; i++) {
            var r = root.children[i].getBoundingClientRect();
            blocks.push([r.top + window.scrollY, r.bottom + window.scrollY]);
          }
          return JSON.stringify({
            height: Math.max(document.body.scrollHeight,
                             document.documentElement.scrollHeight),
            blocks: blocks
          });
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let height = object["height"] as? Double,
                  let raw = object["blocks"] as? [[Double]], height > 0 else {
                self.finish(nil)
                return
            }
            let blocks = raw.compactMap { pair -> PageBlock? in
                pair.count == 2 ? PageBlock(top: pair[0], bottom: pair[1]) : nil
            }
            let pages = PagePlan.pages(blocks: blocks,
                                       contentHeight: height,
                                       pageHeight: Double(self.geometry.contentHeight))
            self.capture(pages: pages, into: [], index: 0)
        }
    }

    /// Capture one page at a time. Sequential rather than concurrent: each call
    /// re-renders the same web view, so overlapping them would race.
    private func capture(pages: [PageSlice], into captured: [Data], index: Int) {
        guard index < pages.count else {
            finish(assemble(captured))
            return
        }
        let slice = pages[index]
        let config = WKPDFConfiguration()
        config.rect = CGRect(x: 0, y: CGFloat(slice.top),
                             width: geometry.contentWidth, height: CGFloat(slice.height))
        webView.createPDF(configuration: config) { [weak self] result in
            guard let self else { return }
            guard case .success(let data) = result else {
                // A missing page is a silently wrong document. Fail the job.
                self.finish(nil)
                return
            }
            self.capture(pages: pages, into: captured + [data], index: index + 1)
        }
    }

    /// Place each captured page onto a full sheet of paper at the top margin,
    /// at 1:1 scale — no scaling, so text prints at the size it was laid out.
    private func assemble(_ captured: [Data]) -> PDFDocument? {
        guard !captured.isEmpty else { return nil }
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: geometry.paper)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        for data in captured {
            guard let provider = CGDataProvider(data: data as CFData),
                  let document = CGPDFDocument(provider),
                  let page = document.page(at: 1) else { continue }
            let box = page.getBoxRect(.mediaBox)
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: geometry.margin - box.minX,
                                y: geometry.paper.height - geometry.margin
                                   - box.height - box.minY)
            context.drawPDFPage(page)
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        return PDFDocument(data: output as Data)
    }

    /// Calls back exactly once, then lets the web view go.
    private func finish(_ document: PDFDocument?) {
        guard !finished else { return }
        finished = true
        completion(document)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            WebPaginator.retained.removeAll { $0 === self }
        }
    }
}
