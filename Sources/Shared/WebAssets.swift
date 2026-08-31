import Foundation

/// Helpers for locating bundled web assets (KaTeX, Mermaid) and generating
/// the HTML `<head>` markup that loads them.
enum WebAssets {

    /// URL of the `web/` folder inside the app bundle. Used as the `baseURL`
    /// when loading HTML strings into WKWebView so relative script/font paths
    /// resolve correctly.
    static var bundleURL: URL? {
        Bundle.main.url(forResource: "web", withExtension: nil)
    }

    /// `<link>` and `<script>` tags that load KaTeX and Mermaid from the
    /// bundled `web/` folder. Inserted into every generated HTML page.
    static var headMarkup: String {
        """
        <link rel="stylesheet" href="katex.min.css">
        <script defer src="katex.min.js"></script>
        <script defer src="auto-render.min.js"></script>
        <script defer src="mermaid.min.js"></script>
        """
    }
}
