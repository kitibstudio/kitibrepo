import SwiftUI
import AppKit

// MARK: - Line number ruler

final class LineNumberRuler: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
    }

    required init(coder: NSCoder) { fatalError() }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = textView,
              let layoutManager = tv.layoutManager,
              let container = tv.textContainer else { return }

        let visibleRect = tv.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let text = tv.string as NSString

        // Line number of the first visible character. The visible glyph range
        // can start mid-paragraph (a wrapped line), so stop at the start of
        // the line that *contains* it — advancing past it overcounts by one.
        var lineNumber = 1
        var idx = 0
        while idx < charRange.location {
            let next = NSMaxRange(text.lineRange(for: NSRange(location: idx, length: 0)))
            if next > charRange.location { break }
            idx = next
            lineNumber += 1
        }

        let labelFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]

        var lineStart = idx   // start of the line containing the first visible char
        while lineStart < NSMaxRange(charRange) {
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let glyphIdx = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            lineRect.origin.y += tv.textContainerInset.height
            let y = lineRect.minY - visibleRect.minY
            // Align the number's baseline with the text's baseline. Centering
            // in the fragment rect sat too high: lineHeightMultiple (1.35) and
            // paragraph spacing make fragments taller than the glyphs.
            let baseline = layoutManager.location(forGlyphAt: glyphIdx).y
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8,
                                   y: y + baseline - labelFont.ascender),
                       withAttributes: attrs)
            lineNumber += 1
            lineStart = NSMaxRange(lineRange)
        }

        // Extra line if document ends with newline and caret is past last char
        if text.length == 0 || (NSMaxRange(charRange) == text.length && text.hasSuffix("\n")) {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                let y = extraRect.minY + tv.textContainerInset.height - visibleRect.minY
                // No glyphs here; estimate the baseline from the editor font.
                let editorFont = tv.font ?? NSFont.systemFont(ofSize: 16)
                let baseline = extraRect.height + editorFont.descender
                let label = "\(lineNumber)" as NSString
                let size = label.size(withAttributes: attrs)
                label.draw(at: NSPoint(x: ruleThickness - size.width - 8,
                                       y: y + baseline - labelFont.ascender),
                           withAttributes: attrs)
            }
        }
    }
}

// MARK: - Editor

struct EditorView: NSViewRepresentable {
    @ObservedObject var state: AppState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let tv = scrollView.documentView as! NSTextView

        tv.delegate = context.coordinator
        tv.allowsUndo = true
        tv.isRichText = false
        tv.usesFontPanel = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = true
        tv.isContinuousSpellCheckingEnabled = true
        tv.isGrammarCheckingEnabled = true
        tv.drawsBackground = false
        scrollView.drawsBackground = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.textContainerInset = NSSize(width: 0, height: 24)
        tv.font = NSFont.systemFont(ofSize: state.editorFontSize)

        // Comfortable measure: center the text column
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true

        let ruler = LineNumberRuler(textView: tv, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = state.showLineNumbers

        context.coordinator.textView = tv
        context.coordinator.scrollView = scrollView
        tv.string = state.text
        context.coordinator.applyHighlighting()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged),
            name: NSTextView.didChangeSelectionNotification,
            object: tv
        )

        // Live resize: recompute the centered column whenever the pane changes
        // size (split toggle, divider drag, window resize). Computing this only
        // in updateNSView used a stale width and could push the text out of view.
        scrollView.contentView.postsFrameChangedNotifications = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewResized),
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.didScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        context.coordinator.updateInset()
        context.coordinator.registerScrollSync()
        context.coordinator.registerInsertion()
        context.coordinator.registerFind()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let tv = coordinator.textView else { return }

        scrollView.rulersVisible = state.showLineNumbers

        // External text change (file switch / template insert)
        if tv.string != state.text && !coordinator.isEditing {
            tv.string = state.text
            tv.setSelectedRange(NSRange(location: 0, length: 0))
            tv.scrollToBeginningOfDocument(nil)
            coordinator.applyHighlighting()
        }

        if coordinator.lastFontSize != state.editorFontSize {
            coordinator.lastFontSize = state.editorFontSize
            coordinator.applyHighlighting()
        }
        if coordinator.lastFocusMode != state.focusMode {
            coordinator.lastFocusMode = state.focusMode
            coordinator.applyFocusDimming(force: true)
        }
        if coordinator.lastAppearance != state.appearance {
            coordinator.lastAppearance = state.appearance
            // Re-dim after the new appearance has propagated to the view.
            DispatchQueue.main.async { [weak coordinator] in
                coordinator?.applyFocusDimming(force: true)
            }
        }

        // Side padding to keep a readable column width (also kept fresh by
        // the frame-change observer — see makeNSView).
        coordinator.updateInset()
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let state: AppState
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var isEditing = false
        var lastFontSize: Double
        var lastFocusMode: Bool
        var lastAppearance: String
        private var highlightPending = false
        private var suppressScrollEvents = false

        init(state: AppState) {
            self.state = state
            self.lastFontSize = state.editorFontSize
            self.lastFocusMode = state.focusMode
            self.lastAppearance = state.appearance
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            isEditing = true
            state.textChanged(tv.string)
            isEditing = false
            scheduleHighlight()
            if state.typewriterScrolling { centerCaret() }
        }

        @objc func selectionChanged() {
            updateSelectionStats()
            // Display-only dimming — never touches the text storage, so no flicker.
            if state.focusMode { applyFocusDimming() }
        }

        /// Mirror the current selection's word/char counts into AppState so the
        /// status bar can show them. Counts use the same rules as `Stats`, so
        /// "12 words selected" lines up with the document totals.
        private func updateSelectionStats() {
            guard let tv = textView else { return }
            let range = tv.selectedRange()
            guard range.length > 0 else {
                if state.selectionChars != 0 { state.selectionChars = 0 }
                if state.selectionWords != 0 { state.selectionWords = 0 }
                return
            }
            let selected = (tv.string as NSString).substring(with: range)
            let words = selected.split { $0.isWhitespace || $0.isNewline }.count
            let chars = selected.count
            if state.selectionWords != words { state.selectionWords = words }
            if state.selectionChars != chars { state.selectionChars = chars }
        }

        // MARK: Centered column

        @objc func viewResized() { updateInset() }

        func updateInset() {
            guard let tv = textView, let sv = scrollView else { return }
            let width = sv.contentSize.width
            guard width > 0 else { return }
            let column: CGFloat = 760
            let pad = max(24, (width - column) / 2)
            if abs(tv.textContainerInset.width - pad) > 0.5 {
                tv.textContainerInset = NSSize(width: pad, height: 32)
                tv.needsDisplay = true
                sv.verticalRulerView?.needsDisplay = true
            }
        }

        // MARK: Scroll sync (editor ↔ preview)

        @objc func didScroll() {
            guard !suppressScrollEvents, state.showPreview,
                  let tv = textView, let sv = scrollView else { return }
            let maxOffset = tv.frame.height - sv.contentView.bounds.height
            guard maxOffset > 0 else { return }
            let fraction = max(0, min(1, sv.contentView.bounds.origin.y / maxOffset))
            state.scrollSync.editorScrolled(fraction: Double(fraction))
        }

        func registerInsertion() {
            state.insertAtCaret = { [weak self] snippet in
                guard let tv = self?.textView else { return }
                let range = tv.selectedRange()
                if tv.shouldChangeText(in: range, replacementString: snippet) {
                    tv.insertText(snippet, replacementRange: range)
                }
            }
        }

        func registerFind() {
            state.performFind = { [weak self] action in
                guard let tv = self?.textView else { return }
                // NSTextView routes find-bar commands through a sender's tag.
                let item = NSMenuItem()
                item.tag = action.rawValue
                tv.window?.makeFirstResponder(tv)
                tv.performTextFinderAction(item)
            }
        }

        func registerScrollSync() {
            state.scrollSync.scrollEditor = { [weak self] fraction in
                guard let self, let tv = self.textView, let sv = self.scrollView else { return }
                let maxOffset = tv.frame.height - sv.contentView.bounds.height
                guard maxOffset > 0 else { return }
                self.suppressScrollEvents = true
                let origin = NSPoint(x: sv.contentView.bounds.origin.x,
                                     y: maxOffset * CGFloat(fraction))
                sv.contentView.setBoundsOrigin(origin)
                sv.reflectScrolledClipView(sv.contentView)
                DispatchQueue.main.async { [weak self] in self?.suppressScrollEvents = false }
            }
        }

        func scheduleHighlight() {
            guard !highlightPending else { return }
            highlightPending = true
            DispatchQueue.main.async { [weak self] in
                self?.highlightPending = false
                self?.applyHighlighting()
            }
        }

        func applyHighlighting() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let selected = tv.selectedRange()
            MarkdownHighlighter.highlight(
                storage: storage,
                baseSize: CGFloat(state.editorFontSize)
            )
            tv.setSelectedRange(selected)
            tv.typingAttributes = [
                .font: NSFont.systemFont(ofSize: CGFloat(state.editorFontSize)),
                .foregroundColor: NSColor.textColor,
            ]
            scrollView?.verticalRulerView?.needsDisplay = true
            applyFocusDimming(force: true)
        }

        private var lastActiveParagraph = NSRange(location: NSNotFound, length: 0)
        private var dimApplied = false

        func applyFocusDimming(force: Bool = false) {
            guard let tv = textView, let lm = tv.layoutManager else { return }
            let ns = tv.string as NSString
            let full = NSRange(location: 0, length: ns.length)

            guard state.focusMode else {
                if dimApplied || force {
                    lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
                    dimApplied = false
                    lastActiveParagraph = NSRange(location: NSNotFound, length: 0)
                }
                return
            }

            let loc = min(tv.selectedRange().location, ns.length)
            let active = ns.paragraphRange(for: NSRange(location: loc, length: 0))
            if !force && dimApplied && NSEqualRanges(active, lastActiveParagraph) { return }
            lastActiveParagraph = active
            dimApplied = true

            lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            // Resolve the dim color under the editor's own appearance.
            // withAlphaComponent() flattens the dynamic color using the ambient
            // (system) appearance — on a dark-mode Mac with the app forced
            // light, that made dimmed text white-on-white.
            var dim = NSColor.textColor.withAlphaComponent(0.25)
            tv.effectiveAppearance.performAsCurrentDrawingAppearance {
                dim = NSColor.textColor.withAlphaComponent(0.25)
            }
            if active.location > 0 {
                lm.addTemporaryAttribute(.foregroundColor, value: dim,
                                         forCharacterRange: NSRange(location: 0, length: active.location))
            }
            let tail = NSMaxRange(active)
            if tail < ns.length {
                lm.addTemporaryAttribute(.foregroundColor, value: dim,
                                         forCharacterRange: NSRange(location: tail, length: ns.length - tail))
            }
        }

        private func centerCaret() {
            guard let tv = textView,
                  let layoutManager = tv.layoutManager,
                  let container = tv.textContainer,
                  let scrollView = scrollView else { return }
            let caret = tv.selectedRange()
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: min(caret.location, max(0, (tv.string as NSString).length)), length: 0),
                actualCharacterRange: nil
            )
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
            if rect.height == 0 { rect = layoutManager.extraLineFragmentRect }
            let target = rect.midY + tv.textContainerInset.height - scrollView.contentSize.height / 2
            let y = max(0, target)
            scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}
