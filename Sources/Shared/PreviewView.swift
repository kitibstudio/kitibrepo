import SwiftUI
import WebKit

/// Live rendered preview — updates in place via JS (no reloads), scroll synced
/// with the editor. Cross-platform: NSViewRepresentable on macOS,
/// UIViewRepresentable on iPadOS, sharing one Coordinator and the WebKit setup.
struct PreviewView {
    @ObservedObject var state: AppState

    private var baseDir: URL? { state.currentFileURL?.deletingLastPathComponent() }

    private static let scrollSyncJS = """
    (function () {
      window.__progScroll = false;
      window.addEventListener('scroll', function () {
        if (window.__progScroll) return;
        var max = document.documentElement.scrollHeight - window.innerHeight;
        var f = max > 0 ? (window.scrollY / max) : 0;
        if (window.webkit && window.webkit.messageHandlers.scrolled) {
          window.webkit.messageHandlers.scrolled.postMessage(f);
        }
      }, { passive: true });
      window.__setScrollFraction = function (f) {
        window.__progScroll = true;
        var max = document.documentElement.scrollHeight - window.innerHeight;
        window.scrollTo(0, f * max);
        setTimeout(function () { window.__progScroll = false; }, 120);
      };
    })();
    """

    func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "scrolled")
        controller.addUserScript(WKUserScript(
            source: Self.scrollSyncJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        config.userContentController = controller
        // Allow the HTML loaded via loadHTMLString to read local bundle files
        // (KaTeX/Mermaid scripts) when baseURL points to the bundle's web/ folder.
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        #endif
        context.coordinator.webView = webView
        context.coordinator.registerScrollSync()
        let page = Exporter.htmlPage(
            body: Exporter.htmlBody(from: state.text, baseDir: baseDir, numbered: state.numberCaptions,
                                    showFrontMatter: state.showFrontMatterPreview),
            title: "Preview", lineNumbers: false, forceLight: false
        )
        webView.loadHTMLString(page, baseURL: WebAssets.bundleURL)
        context.coordinator.lastText = state.text
        context.coordinator.lastFile = state.selectedFileID
        context.coordinator.lastNumbered = state.numberCaptions
        context.coordinator.lastShowFM = state.showFrontMatterPreview
        return webView
    }

    func syncWebView(_ webView: WKWebView, context: Context) {
        let c = context.coordinator
        guard c.lastText != state.text || c.lastFile != state.selectedFileID
                || c.lastNumbered != state.numberCaptions
                || c.lastShowFM != state.showFrontMatterPreview else { return }
        let fileSwitched = c.lastFile != state.selectedFileID
        let settingChanged = c.lastNumbered != state.numberCaptions
                || c.lastShowFM != state.showFrontMatterPreview
        c.lastText = state.text
        c.lastFile = state.selectedFileID
        c.lastNumbered = state.numberCaptions
        c.lastShowFM = state.showFrontMatterPreview
        c.scheduleUpdate(text: state.text, baseDir: baseDir, numbered: state.numberCaptions,
                         showFrontMatter: state.showFrontMatterPreview,
                         delay: (fileSwitched || settingChanged) ? 0 : 0.35,
                         scrollToTop: fileSwitched)
    }

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let state: AppState
        weak var webView: WKWebView?
        var lastText: String?
        var lastFile: String?
        var lastNumbered: Bool?
        var lastShowFM: Bool?
        private var timer: Timer?

        init(state: AppState) { self.state = state }

        func registerScrollSync() {
            state.scrollSync.scrollPreview = { [weak self] fraction in
                self?.webView?.evaluateJavaScript(
                    "window.__setScrollFraction(\(fraction));",
                    completionHandler: nil
                )
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "scrolled",
                  let fraction = (message.body as? NSNumber)?.doubleValue else { return }
            state.scrollSync.previewScrolled(fraction: fraction)
        }

        func scheduleUpdate(text: String, baseDir: URL?, numbered: Bool, showFrontMatter: Bool, delay: TimeInterval, scrollToTop: Bool) {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: max(delay, 0.01), repeats: false) { [weak self] _ in
                guard let webView = self?.webView else { return }
                let body = Exporter.htmlBody(from: text, baseDir: baseDir, numbered: numbered, showFrontMatter: showFrontMatter)
                guard let data = try? JSONEncoder().encode(body),
                      let json = String(data: data, encoding: .utf8) else { return }
                let scroll = scrollToTop ? "window.scrollTo(0,0);" : ""
                webView.evaluateJavaScript("window.update(\(json));\(scroll)", completionHandler: nil)
            }
        }
    }
}

#if os(macOS)
extension PreviewView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateNSView(_ nsView: WKWebView, context: Context) { syncWebView(nsView, context: context) }
}
#else
extension PreviewView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateUIView(_ uiView: WKWebView, context: Context) { syncWebView(uiView, context: context) }
}
#endif
