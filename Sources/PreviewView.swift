import SwiftUI
import WebKit

/// Live rendered preview — right half of the split screen.
/// Updates in place via JS (no page reloads), so scroll position is kept.
/// Scrolling is synced both ways with the editor via AppState.scrollSync.
struct PreviewView: NSViewRepresentable {
    @ObservedObject var state: AppState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    /// Injected into the preview page only (not exports): reports user scrolls
    /// to Swift, and exposes a guarded programmatic-scroll entry point.
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

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "scrolled")
        controller.addUserScript(WKUserScript(
            source: Self.scrollSyncJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        context.coordinator.registerScrollSync()
        let page = Exporter.htmlPage(
            body: Exporter.htmlBody(from: state.text, baseDir: baseDir, numbered: state.numberCaptions),
            title: "Preview", lineNumbers: false, forceLight: false
        )
        webView.loadHTMLString(page, baseURL: nil)
        context.coordinator.lastText = state.text
        context.coordinator.lastFile = state.selectedFileID
        context.coordinator.lastNumbered = state.numberCaptions
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let c = context.coordinator
        guard c.lastText != state.text || c.lastFile != state.selectedFileID
                || c.lastNumbered != state.numberCaptions else { return }
        let fileSwitched = c.lastFile != state.selectedFileID
        let settingChanged = c.lastNumbered != state.numberCaptions
        c.lastText = state.text
        c.lastFile = state.selectedFileID
        c.lastNumbered = state.numberCaptions
        c.scheduleUpdate(text: state.text, baseDir: baseDir, numbered: state.numberCaptions,
                         delay: (fileSwitched || settingChanged) ? 0 : 0.35,
                         scrollToTop: fileSwitched)
    }

    private var baseDir: URL? {
        state.currentFileURL?.deletingLastPathComponent()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let state: AppState
        weak var webView: WKWebView?
        var lastText: String?
        var lastFile: String?
        var lastNumbered: Bool?
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

        // Preview was scrolled by the user → move the editor.
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "scrolled",
                  let fraction = (message.body as? NSNumber)?.doubleValue else { return }
            state.scrollSync.previewScrolled(fraction: fraction)
        }

        func scheduleUpdate(text: String, baseDir: URL?, numbered: Bool, delay: TimeInterval, scrollToTop: Bool) {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: max(delay, 0.01), repeats: false) { [weak self] _ in
                guard let webView = self?.webView else { return }
                let body = Exporter.htmlBody(from: text, baseDir: baseDir, numbered: numbered)
                guard let data = try? JSONEncoder().encode(body),
                      let json = String(data: data, encoding: .utf8) else { return }
                let scroll = scrollToTop ? "window.scrollTo(0,0);" : ""
                webView.evaluateJavaScript("window.update(\(json));\(scroll)", completionHandler: nil)
            }
        }
    }
}
