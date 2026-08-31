# Kitib for iPad — build & ship notes

This adds an **iPad target** alongside the existing macOS app, from one shared
codebase. The terminal is macOS-only and intentionally absent on iPad.

## Layout

```
Sources/
  Shared/     compiled into BOTH targets (AppState, ContentView, PreviewView,
              ExporterCore, MarkdownHighlighter, SidebarView, StatsBar,
              TodoPanel, HelpView, AboutView, Templates, LoremIpsum, KitibApp)
  Platform/   typealiases + helpers that resolve to AppKit or UIKit
  macOS/      NSTextView editor, terminal, fireworks (NSPanel), AppKit export,
              menu bar commands, app delegate, macOS DetailView
  iOS/        UITextView editor (+ line-number gutter, focus mode, typewriter,
              UIFindInteraction), iPad DetailView, UIKit export, fireworks overlay
Vendor/SwiftTerm/   terminal emulator — macOS target only
Resources/Assets.xcassets/   shared app icon (mac + iPad idioms)
project.yml         XcodeGen spec defining both targets
```

A file named `EditorView`/`DetailView` exists in **both** `macOS/` and `iOS/`;
they never collide because each folder is compiled into only its own target.

## Generating the Xcode project

The repo ships a `project.yml` for [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen      # once
cd /path/to/MD
xcodegen generate          # creates Kitib.xcodeproj
open Kitib.xcodeproj
```

Prefer not to use XcodeGen? Create a new multiplatform App project in Xcode and
drag the `Sources/Shared`, `Sources/Platform` and `Sources/iOS` folders into an
iPad app target (and the macOS folders + Vendor into a macOS target), then set
the build settings listed in `project.yml`.

## Signing & TestFlight

1. In Xcode, select the **Kitib-iOS** target → Signing & Capabilities → pick your
   Team. (Set `DEVELOPMENT_TEAM` once and it sticks.)
2. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` as needed.
3. Product → Destination → **Any iOS Device (arm64)**.
4. Product → **Archive** → Distribute App → **TestFlight & App Store** → Upload.
5. In App Store Connect, add the build to a TestFlight group and invite testers.

The iPad build stays inside App Store sandbox rules: folders are opened through
the system file importer and re-accessed via security-scoped bookmarks, so no
special entitlements beyond the defaults are required.

## Known things to verify on-device (could not be compiled here)

- Line-number gutter alignment across font sizes and wrapped lines.
- Focus-mode dimming + typewriter scrolling feel on touch.
- `UIFindInteraction` next/previous (the system navigator handles iteration).
- PDF export pagination from `WKWebView.createPDF`.
- Drag-and-drop reordering in the sidebar with touch.
