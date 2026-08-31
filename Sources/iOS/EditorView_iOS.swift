import SwiftUI
import UIKit

// MARK: - Line number gutter (iPad)

/// Draws source line numbers in a fixed left strip, mirroring the macOS
/// NSRulerView. Numbers track the text view's scroll offset.
final class LineNumberGutter: UIView {
    weak var textView: UITextView?
    var isEnabled = true { didSet { isHidden = !isEnabled; setNeedsDisplay() } }

    static let width: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard isEnabled,
              let tv = textView,
              let lm = tv.layoutManager as NSLayoutManager?,
              let container = tv.textContainer as NSTextContainer? else { return }

        let text = tv.text as NSString
        let offsetY = tv.contentOffset.y
        let insetTop = tv.textContainerInset.top
        let visibleRect = CGRect(x: 0, y: offsetY - insetTop,
                                 width: tv.bounds.width, height: tv.bounds.height)
        let glyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Line number of the first visible character.
        var lineNumber = 1
        var idx = 0
        while idx < charRange.location {
            let next = NSMaxRange(text.lineRange(for: NSRange(location: idx, length: 0)))
            if next > charRange.location { break }
            idx = next
            lineNumber += 1
        }

        let labelFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.tertiaryLabel,
        ]

        var lineStart = idx
        while lineStart <= NSMaxRange(charRange) && lineStart <= text.length {
            let lineRange = text.lineRange(for: NSRange(location: min(lineStart, text.length), length: 0))
            let glyphIdx = lm.glyphIndexForCharacter(at: lineRange.location)
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            let y = lineRect.minY + insetTop - offsetY
            if y > bounds.height { break }
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: CGPoint(x: Self.width - size.width - 8, y: y + 2), withAttributes: attrs)
            lineNumber += 1
            let nextStart = NSMaxRange(lineRange)
            if nextStart <= lineStart { break }
            lineStart = nextStart
        }
    }
}

// MARK: - UITextView subclass (paste interception)

/// Thin subclass that intercepts paste to show the healing preview sheet.
final class KitibTextView: UITextView {
    /// Called when the user pastes. Returns `true` if the subclass handled
    /// the paste (preview sheet shown); returns `false` to fall through to
    /// `super.paste(_:)`.
    var onPaste: ((UIPasteboard) -> Bool)?

    override func paste(_ sender: Any?) {
        guard let onPaste else {
            super.paste(sender)
            return
        }
        if !onPaste(.general) {
            super.paste(sender)
        }
    }
}

// MARK: - Container that lays out the text view + gutter

final class EditorContainerView: UIView {
    let textView: UITextView
    let gutter = LineNumberGutter()

    init(textView: UITextView) {
        self.textView = textView
        super.init(frame: .zero)
        addSubview(textView)
        gutter.textView = textView
        addSubview(gutter)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        gutter.frame = CGRect(x: 0, y: 0, width: LineNumberGutter.width, height: bounds.height)
    }
}

// MARK: - Editor (iPad)

struct EditorView: UIViewRepresentable {
    @ObservedObject var state: AppState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> EditorContainerView {
        // Force TextKit 1 by building the stack explicitly — gives us
        // layoutManager temporary attributes (focus dimming) and the gutter.
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)

        let tv = KitibTextView(frame: .zero, textContainer: container)
        tv.delegate = context.coordinator
        tv.backgroundColor = UIColor.clear
        tv.allowsEditingTextAttributes = false
        tv.autocorrectionType = UITextAutocorrectionType.default
        tv.autocapitalizationType = UITextAutocapitalizationType.sentences
        tv.smartQuotesType = UITextSmartQuotesType.no
        tv.smartDashesType = UITextSmartDashesType.no
        tv.keyboardDismissMode = UIScrollView.KeyboardDismissMode.interactive
        tv.alwaysBounceVertical = true
        tv.font = UIFont.systemFont(ofSize: state.editorFontSize)
        tv.textContainerInset = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        if #available(iOS 16.0, *) { tv.isFindInteractionEnabled = true }

        context.coordinator.textView = tv
        tv.onPaste = { [weak coordinator = context.coordinator] pasteboard in
            coordinator?.handlePaste(pasteboard) ?? false
        }
        tv.text = state.text
        context.coordinator.applyHighlighting()

        let containerView = EditorContainerView(textView: tv)
        context.coordinator.containerView = containerView
        containerView.gutter.isEnabled = state.showLineNumbers

        context.coordinator.registerScrollSync()
        context.coordinator.registerInsertion()
        context.coordinator.registerFind()
        context.coordinator.registerTableGrid()
        context.coordinator.registerOutline()
        return containerView
    }

    func updateUIView(_ view: EditorContainerView, context: Context) {
        let c = context.coordinator
        guard let tv = c.textView else { return }

        view.gutter.isEnabled = state.showLineNumbers

        if tv.text != state.text && !c.isEditing {
            tv.text = state.text
            tv.selectedRange = NSRange(location: 0, length: 0)
            c.applyHighlighting()
            tv.setContentOffset(.zero, animated: false)
            view.gutter.setNeedsDisplay()
        }
        if c.lastFontSize != state.editorFontSize {
            c.lastFontSize = state.editorFontSize
            c.applyHighlighting()
            view.gutter.setNeedsDisplay()
        }
        if c.lastFocusMode != state.focusMode {
            c.lastFocusMode = state.focusMode
            c.applyFocusDimming(force: true)
        }
        if c.lastAppearance != state.appearance {
            c.lastAppearance = state.appearance
            DispatchQueue.main.async { c.applyHighlighting() }
        }
        c.updateInset()
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        let state: AppState
        weak var textView: UITextView?
        weak var containerView: EditorContainerView?
        var isEditing = false
        var lastFontSize: Double
        var lastFocusMode: Bool
        var lastAppearance: String
        private var highlightPending = false
        private var suppressScroll = false

        init(state: AppState) {
            self.state = state
            self.lastFontSize = state.editorFontSize
            self.lastFocusMode = state.focusMode
            self.lastAppearance = state.appearance
        }

        func textViewDidChange(_ textView: UITextView) {
            isEditing = true
            state.textChanged(textView.text)
            isEditing = false
            scheduleHighlight()
            if state.typewriterScrolling { centerCaret() }
            containerView?.gutter.setNeedsDisplay()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSelectionStats()
            updateCursorInTable()
            if state.focusMode { applyFocusDimming() }
        }

        private func updateCursorInTable() {
            guard let tv = textView else { return }
            let pos = tv.selectedRange.location
            let inTable = MarkdownTableParser.findTableRange(
                in: tv.text, cursorPosition: pos
            ) != nil
            if state.cursorInTable != inTable {
                state.cursorInTable = inTable
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            containerView?.gutter.setNeedsDisplay()
            guard !suppressScroll, state.showPreview, let tv = textView else { return }
            let maxOffset = tv.contentSize.height - tv.bounds.height
            guard maxOffset > 0 else { return }
            let fraction = max(0, min(1, tv.contentOffset.y / maxOffset))
            state.scrollSync.editorScrolled(fraction: Double(fraction))
        }

        private func updateSelectionStats() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            guard range.length > 0 else {
                if state.selectionChars != 0 { state.selectionChars = 0 }
                if state.selectionWords != 0 { state.selectionWords = 0 }
                return
            }
            let selected = (tv.text as NSString).substring(with: range)
            let words = selected.split { $0.isWhitespace || $0.isNewline }.count
            let chars = selected.count
            if state.selectionWords != words { state.selectionWords = words }
            if state.selectionChars != chars { state.selectionChars = chars }
        }

        // Centered, readable column — matches the macOS editor's 760pt measure.
        func updateInset() {
            guard let tv = textView else { return }
            let width = tv.bounds.width
            guard width > 0 else { return }
            let column: CGFloat = 760
            let base = state.showLineNumbers ? LineNumberGutter.width : 24
            let pad = max(base, (width - column) / 2)
            let newInset = UIEdgeInsets(top: 24, left: pad, bottom: 24, right: max(24, (width - column) / 2))
            if abs(tv.textContainerInset.left - newInset.left) > 0.5
                || abs(tv.textContainerInset.right - newInset.right) > 0.5 {
                tv.textContainerInset = newInset
                containerView?.gutter.setNeedsDisplay()
            }
        }

        func registerScrollSync() {
            state.scrollSync.scrollEditor = { [weak self] fraction in
                guard let self, let tv = self.textView else { return }
                let maxOffset = tv.contentSize.height - tv.bounds.height
                guard maxOffset > 0 else { return }
                self.suppressScroll = true
                tv.setContentOffset(CGPoint(x: 0, y: maxOffset * CGFloat(fraction)), animated: false)
                DispatchQueue.main.async { self.suppressScroll = false }
            }
        }

        func registerInsertion() {
            state.insertAtCaret = { [weak self] snippet in
                guard let tv = self?.textView else { return }
                if let r = tv.selectedTextRange {
                    tv.replace(r, withText: snippet)
                } else {
                    tv.insertText(snippet)
                }
            }
        }

        func registerFind() {
            state.performFind = { [weak self] action in
                guard let tv = self?.textView else { return }
                if #available(iOS 16.0, *), let fi = tv.findInteraction {
                    switch action {
                    case .find, .next, .previous:
                        fi.presentFindNavigator(showingReplace: false)
                    case .replace:
                        fi.presentFindNavigator(showingReplace: true)
                    case .useSelection:
                        if let r = tv.selectedTextRange, let t = tv.text(in: r) {
                            fi.searchText = t
                        }
                        fi.presentFindNavigator(showingReplace: false)
                    }
                }
            }
        }

        func registerTableGrid() {
            state.openTableGrid = { [weak self] in
                guard let self, let tv = self.textView else { return }
                let pos = tv.selectedRange.location
                guard let range = MarkdownTableParser.findTableRange(
                    in: tv.text, cursorPosition: pos
                ) else { return }
                let tableText = (tv.text as NSString).substring(with: range)
                guard let result = MarkdownTableParser.parse(tableText) else { return }
                state.editingTable = result.table
                state.editingTableRange = range
            }

            state.replaceTableText = { [weak self] newText in
                guard let self, let tv = self.textView else { return }
                let range = state.editingTableRange ?? tv.selectedRange
                tv.selectedRange = range
                tv.insertText(newText)
                state.editingTable = nil
                state.editingTableRange = nil
            }
        }

        func registerOutline() {
            // Scroll the editor to a heading range (NSRange → UITextView
            // scrollRangeToVisible).
            state.scrollToHeading = { [weak self] range in
                guard let tv = self?.textView else { return }
                tv.scrollRangeToVisible(range)
            }
        }

        /// Called by `KitibTextView.paste(_:)` before the pasteboard text
        /// enters the document.
        func handlePaste(_ pasteboard: UIPasteboard) -> Bool {
            guard state.pastePreviewText == nil else { return false }
            guard state.showPastePreview else { return false }

            guard let raw = pasteboard.string,
                  !raw.isEmpty else { return false }

            if PasteHealer.shouldSkipPastePreview(raw) {
                return false
            }

            state.pastePreviewText = raw
            return true
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
            guard let tv = textView, let storage = tv.textStorage as NSTextStorage? else { return }
            let selected = tv.selectedRange
            MarkdownHighlighter.highlight(storage: storage, baseSize: CGFloat(state.editorFontSize))
            tv.selectedRange = selected
            tv.typingAttributes = [
                .font: UIFont.systemFont(ofSize: CGFloat(state.editorFontSize)),
                .foregroundColor: UIColor.label,
            ]
            containerView?.gutter.setNeedsDisplay()
            applyFocusDimming(force: true)
        }

        private var lastActiveParagraph = NSRange(location: NSNotFound, length: 0)
        private var dimApplied = false

        func applyFocusDimming(force: Bool = false) {
            guard let tv = textView else { return }
            let storage = tv.textStorage
            let ns = tv.text as NSString
            let full = NSRange(location: 0, length: ns.length)

            guard state.focusMode else {
                if dimApplied || force {
                    storage.removeAttribute(.foregroundColor, range: full)
                    storage.addAttribute(.foregroundColor, value: UIColor.label, range: full)
                    dimApplied = false
                    lastActiveParagraph = NSRange(location: NSNotFound, length: 0)
                }
                return
            }

            let loc = min(tv.selectedRange.location, ns.length)
            let active = ns.paragraphRange(for: NSRange(location: loc, length: 0))
            if !force && dimApplied && NSEqualRanges(active, lastActiveParagraph) { return }
            lastActiveParagraph = active
            dimApplied = true

            let dim = UIColor.label.withAlphaComponent(0.25)
            storage.removeAttribute(.foregroundColor, range: full)
            storage.addAttribute(.foregroundColor, value: UIColor.label, range: full)
            if active.location > 0 {
                storage.addAttribute(.foregroundColor, value: dim,
                                     range: NSRange(location: 0, length: active.location))
            }
            let tail = NSMaxRange(active)
            if tail < ns.length {
                storage.addAttribute(.foregroundColor, value: dim,
                                     range: NSRange(location: tail, length: ns.length - tail))
            }
        }

        private func centerCaret() {
            guard let tv = textView else { return }
            let caret = tv.selectedRange
            guard let lm = tv.layoutManager as NSLayoutManager?,
                  let container = tv.textContainer as NSTextContainer? else { return }
            let glyphRange = lm.glyphRange(
                forCharacterRange: NSRange(location: min(caret.location, (tv.text as NSString).length), length: 0),
                actualCharacterRange: nil
            )
            var rect = lm.boundingRect(forGlyphRange: glyphRange, in: container)
            if rect.height == 0 { rect = lm.extraLineFragmentRect }
            let target = rect.midY + tv.textContainerInset.top - tv.bounds.height / 2
            let maxOffset = max(0, tv.contentSize.height - tv.bounds.height)
            let y = max(0, min(target, maxOffset))
            tv.setContentOffset(CGPoint(x: 0, y: y), animated: true)
        }
    }
}
