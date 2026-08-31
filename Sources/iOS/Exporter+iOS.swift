import UIKit
import WebKit

// iPad export: PDF via WKWebView.createPDF, HTML to a temp file for the share
// sheet, and rich text to the system pasteboard. Markdown→HTML is shared.
extension Exporter {

    /// Renders the document to a temporary PDF file and returns its URL.
    static func makePDF(markdown: String, title: String, baseDir: URL?,
                        withLineNumbers: Bool, numbered: Bool = false,
                        completion: @escaping (URL?) -> Void) {
        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered),
            title: title, lineNumbers: withLineNumbers, forceLight: true, forPrint: true
        )
        WebPDFRenderer.render(html: page, fileName: title + ".pdf", completion: completion)
    }

    /// Writes a standalone HTML file to a temp URL for sharing.
    static func makeHTMLFile(markdown: String, title: String, baseDir: URL?, numbered: Bool = false) -> URL? {
        let page = htmlPage(
            body: htmlBody(from: markdown, baseDir: baseDir, numbered: numbered),
            title: title, lineNumbers: false, forceLight: false
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(title + ".html")
        do {
            try page.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch { return nil }
    }

    /// Copies the document to the pasteboard as rich text (RTF) plus plain text,
    /// so it pastes formatted into Mail, Notes, LinkedIn, etc.
    static func copyAsRichText(markdown: String) {
        let storage = NSTextStorage(string: markdown)
        MarkdownHighlighter.highlight(storage: storage, baseSize: 15)
        let full = NSRange(location: 0, length: storage.length)
        let pb = UIPasteboard.general
        var items: [String: Any] = [:]
        if let rtf = try? storage.data(from: full,
                                       documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            items["public.rtf"] = rtf
        }
        items["public.utf8-plain-text"] = markdown
        pb.items = [items]
    }
}

// MARK: - Offscreen web view that renders, then exports a PDF

private final class WebPDFRenderer: NSObject, WKNavigationDelegate {
    private static var retained: [WebPDFRenderer] = []

    private let webView: WKWebView
    private let fileName: String
    private let completion: (URL?) -> Void

    static func render(html: String, fileName: String, completion: @escaping (URL?) -> Void) {
        let r = WebPDFRenderer(fileName: fileName, completion: completion)
        retained.append(r)
        // US Letter content width at 72dpi minus margins (~512pt) keeps the
        // on-screen layout identical to the paginated PDF.
        r.webView.frame = CGRect(x: 0, y: 0, width: 512, height: 800)
        r.webView.loadHTMLString(html, baseURL: WebAssets.bundleURL)
    }

    private init(fileName: String, completion: @escaping (URL?) -> Void) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 512, height: 800), configuration: config)
        self.fileName = fileName
        self.completion = completion
        super.init()
        webView.navigationDelegate = self
        webView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        waitForMath(attempts: 12)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(nil)
    }

    private func waitForMath(attempts: Int) {
        webView.evaluateJavaScript("window.kitibMathDone === true && window.kitibDiagramsDone === true") { [weak self] result, _ in
            guard let self else { return }
            if (result as? Bool) == true || attempts <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.exportPDF() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.waitForMath(attempts: attempts - 1) }
            }
        }
    }

    private func exportPDF() {
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(self.fileName)
                try? data.write(to: url)
                self.finish(url)
            case .failure:
                self.finish(nil)
            }
        }
    }

    private func finish(_ url: URL?) {
        DispatchQueue.main.async {
            self.completion(url)
            WebPDFRenderer.retained.removeAll { $0 === self }
        }
    }
}
