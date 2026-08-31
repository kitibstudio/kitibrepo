import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - OutlinePanel

/// Displays the document heading outline with click-to-navigate and
/// drag-and-drop section reorder.
///
/// One reorder engine on both platforms. A drag lifts the heading **and every
/// heading nested under it**, because that is what `SectionMover` actually
/// moves; the rest of the list recedes so the travelling group reads as one
/// object. The landing point is drawn from measured row frames — never from an
/// assumed row height — and as an overlay, so the list never reflows under the
/// pointer mid-drag.
///
/// **macOS:** drag from anywhere on the row (4pt threshold).
/// **iOS:** long-press to lift, then drag. The press threshold is what keeps
///   the gesture from fighting the scroll view.
struct OutlinePanel: View {
    let flatNodes: [OutlineNode]
    var onSelect: ((NSRange) -> Void)?
    var onMove: ((Int, Int) -> Void)?

    private static let listSpace = "outlineList"

    // MARK: State

    /// Live drag, or nil when idle.
    @State private var drag: DragSession?
    /// Row frames in `listSpace`, captured while idle and deliberately frozen
    /// for the duration of a drag — the lifted rows carry a render offset, so
    /// re-reading their geometry mid-drag would chase itself.
    @State private var rowFrames: [Int: CGRect] = [:]
    /// Index span that just landed, briefly highlighted so the eye follows it.
    @State private var landed: Range<Int>?
    @State private var hovered: Int?

    struct DragSession: Equatable {
        let source: Int
        /// Last index of the travelling group, exclusive.
        let groupEnd: Int
        var translation: CGSize = .zero
        var pointerY: CGFloat = 0
        var started = false
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

            if flatNodes.isEmpty {
                emptyState
            } else {
                list
                Divider().opacity(0.5)
                statusBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Outline")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(SwiftUI.Color.primary)

            if !flatNodes.isEmpty {
                Text("\(flatNodes.count)")
                    .font(.system(.caption, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(SwiftUI.Color.primary.opacity(0.07))
                    )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            // Deliberately not lazy. A LazyVStack does not honour `zIndex`
            // between its rows (a still row paints over the lifted card) and
            // gives no frame for rows that are scrolled out, which would make
            // the drop target wrong exactly when the list is long enough to
            // matter. An outline is tens of rows; laziness buys nothing here.
            VStack(spacing: 2) {
                ForEach(Array(zip(flatNodes.indices, flatNodes)),
                        id: \.1.id) { idx, node in
                    row(node, idx)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .coordinateSpace(name: Self.listSpace)
            .background(alignment: .top) { vacatedGhosts }
            .overlay(alignment: .top) { dropIndicator }
            .onPreferenceChange(RowFramePreference.self) { frames in
                // Frozen during a drag — see `rowFrames`.
                if drag == nil { rowFrames = frames }
            }
        }
        // While a section is lifted the pan must drive the drag, not the list.
        // On iOS the reorder drag is a *simultaneous* gesture, so without this
        // the scroll view consumes the same finger and the row slides against
        // a moving background.
        .scrollDisabled(drag != nil)
    }

    private func isTravelling(_ idx: Int) -> Bool {
        guard let drag else { return false }
        return idx >= drag.source && idx < drag.groupEnd
    }

    private func row(_ node: OutlineNode, _ idx: Int) -> some View {
        let travelling = isTravelling(idx)
        let isLead = drag?.source == idx
        let receded = drag != nil && !travelling
        let lift: CGFloat = travelling ? (drag?.translation.height ?? 0) : 0
        let group = isLead ? (drag.map { $0.groupEnd - $0.source } ?? 1) : 1

        let card = HeadingRow(
            node: node,
            depth: node.heading.level,
            isLead: isLead,
            travelling: travelling,
            hovered: hovered == idx && drag == nil,
            landing: landed?.contains(idx) ?? false,
            groupCount: group,
            subsectionCount: descendantCount(from: idx)
        )
            .background(RowFrameReader(index: idx, space: Self.listSpace))
            .offset(y: lift)
            .scaleEffect(travelling ? 1.015 : 1, anchor: .leading)
            .opacity(receded ? 0.28 : 1)
            .grayscale(receded ? 0.6 : 0)
            .zIndex(travelling ? 2 : 0)

        return card
            .contentShape(Rectangle())
            .modifier(ReorderGesture(
                isArmed: { drag != nil },
                begin: { beginDrag(at: idx) },
                arm: { beginDrag(at: idx, replacingExisting: true) },
                update: { translation, pointerY in
                    updateDrag(translation: translation, pointerY: pointerY)
                },
                end: { endDrag() },
                select: { onSelect?(node.heading.range) }
            ))
            .onHover { inside in
                hovered = inside ? idx : (hovered == idx ? nil : hovered)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: receded)
            .animation(.easeOut(duration: 0.18), value: hovered)
            .animation(.easeInOut(duration: 0.35), value: landed)
    }

    // MARK: Vacated slots

    /// Dashed outlines left behind where the travelling section sat. Without
    /// them the drag opens an unexplained hole in the list; with them the hole
    /// reads as "this is the piece you picked up".
    @ViewBuilder
    private var vacatedGhosts: some View {
        if let drag, drag.started {
            ZStack(alignment: .top) {
                ForEach(Array(drag.source ..< drag.groupEnd), id: \.self) { i in
                    if let f = rowFrames[i] {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                SwiftUI.Color.primary.opacity(0.14),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                            )
                            .frame(height: f.height)
                            .offset(y: f.minY)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }

    // MARK: Drop indicator

    @ViewBuilder
    private var dropIndicator: some View {
        if let drag, drag.started, let slot = targetSlot(for: drag),
           isValidDrop(slot, drag: drag), let y = boundaryY(forSlot: slot) {
            HStack(spacing: 0) {
                Circle()
                    .fill(SwiftUI.Color.accentColor)
                    .frame(width: 7, height: 7)
                Capsule()
                    .fill(SwiftUI.Color.accentColor)
                    .frame(height: 3)
            }
            // Indented to the level the section will land at, so the line
            // states the outcome and not just the position.
            .padding(.leading, indent(forLevel: flatNodes[drag.source].heading.level) + 12)
            .padding(.trailing, 16)
            .offset(y: y - 1.5)
            .shadow(color: SwiftUI.Color.accentColor.opacity(0.45), radius: 4, y: 0)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .semibold))
            Text(statusText)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(statusIsWarning ? SwiftUI.Color.orange : SwiftUI.Color.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private var statusIsWarning: Bool {
        guard let drag, drag.started else { return false }
        guard let slot = targetSlot(for: drag) else { return true }
        return !isValidDrop(slot, drag: drag)
    }

    private var statusIcon: String {
        guard let drag, drag.started else { return "hand.tap" }
        return statusIsWarning ? "xmark.circle" : "arrow.down.to.line"
    }

    private var statusText: String {
        guard let drag, drag.started else {
            #if os(macOS)
            return "Click to jump · drag to move a section"
            #else
            return "Tap to jump · press and hold to move a section"
            #endif
        }
        guard let slot = targetSlot(for: drag), isValidDrop(slot, drag: drag) else {
            return "That is inside the section you are moving"
        }
        let moving = drag.groupEnd - drag.source
        let what = moving == 1
            ? "Move “\(title(drag.source))”"
            : "Move “\(title(drag.source))” and \(moving - 1) subsection\(moving == 2 ? "" : "s")"
        if slot >= flatNodes.count {
            return "\(what) to the end"
        }
        return "\(what) above “\(title(slot))”"
    }

    private func title(_ idx: Int) -> String {
        guard flatNodes.indices.contains(idx) else { return "" }
        let t = flatNodes[idx].heading.text
        return t.isEmpty ? "(empty)" : t
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No headings")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
            Text("Add headings to see them here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Drag engine

    /// - Parameter replacingExisting: macOS calls `begin` on every drag frame,
    ///   so there it must be idempotent — a second call may not restart the
    ///   session. A long press is a discrete event, so iOS passes true and
    ///   takes over any session that is already open. That is the recovery
    ///   path: if a lift is ever left armed, the next press claims it instead
    ///   of being refused, and the panel cannot get permanently stuck the way
    ///   it did when a lift could only ever start from an idle state.
    private func beginDrag(at idx: Int, replacingExisting: Bool = false) {
        guard flatNodes.indices.contains(idx) else { return }
        if let open = drag {
            // Re-arming the row that is already lifted would zero its
            // translation and make it jump back mid-drag.
            if open.source == idx { return }
            if !replacingExisting { return }
        }
        let session = DragSession(source: idx, groupEnd: sectionEnd(of: idx))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            drag = session
            landed = nil
        }
        liftFeedback()
    }

    private func updateDrag(translation: CGSize, pointerY: CGFloat) {
        guard var session = drag else { return }
        session.translation = translation
        session.pointerY = pointerY
        session.started = true
        drag = session
    }

    private func endDrag() {
        guard let session = drag else { return }
        defer {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                drag = nil
            }
        }
        guard session.started,
              let slot = targetSlot(for: session),
              isValidDrop(slot, drag: session) else { return }

        let count = session.groupEnd - session.source
        let newStart = slot > session.source ? slot - count : slot
        onMove?(session.source, slot)
        dropFeedback()
        flash(newStart ..< (newStart + count))
    }

    private func flash(_ range: Range<Int>) {
        landed = range
        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            await MainActor.run {
                if landed == range { landed = nil }
            }
        }
    }

    /// The insertion slot (0…count) nearest the pointer, from measured frames.
    private func targetSlot(for session: DragSession) -> Int? {
        guard !rowFrames.isEmpty else { return nil }
        let y = session.pointerY
        var slot = 0
        for i in flatNodes.indices {
            guard let f = rowFrames[i] else { continue }
            if f.midY < y { slot = i + 1 }
        }
        return min(max(slot, 0), flatNodes.count)
    }

    /// Mirrors `SectionMover`'s rejection rules exactly, so the panel can show
    /// the refusal before the user commits to it rather than swallowing the
    /// drop silently.
    ///
    /// Invalid slots are `source` itself (no move) and everything from
    /// `source + 1` through `groupEnd` — that whole span is either inside the
    /// travelling section or the boundary it already sits on.
    private func isValidDrop(_ slot: Int, drag session: DragSession) -> Bool {
        slot < session.source || slot > session.groupEnd
    }

    /// Top edge of the row at `slot`, or the bottom edge of the last row when
    /// the slot is past the end.
    private func boundaryY(forSlot slot: Int) -> CGFloat? {
        if slot < flatNodes.count { return rowFrames[slot]?.minY }
        return rowFrames[flatNodes.count - 1]?.maxY
    }

    /// First index after `idx` whose heading is at an equal or higher level —
    /// the exclusive end of the section that a drag from `idx` carries.
    private func sectionEnd(of idx: Int) -> Int {
        let level = flatNodes[idx].heading.level
        var i = idx + 1
        while i < flatNodes.count, flatNodes[i].heading.level > level { i += 1 }
        return i
    }

    private func descendantCount(from idx: Int) -> Int {
        sectionEnd(of: idx) - idx - 1
    }

    private func indent(forLevel level: Int) -> CGFloat {
        CGFloat(min(level, 6) - 1) * 14
    }

    // MARK: Feedback

    private func liftFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func dropFeedback() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
}

// MARK: - Surface

/// Opaque panel background, used behind a lifted card.
private enum OutlineSurface {
    static var color: SwiftUI.Color {
        #if os(macOS)
        SwiftUI.Color(nsColor: .windowBackgroundColor)
        #else
        SwiftUI.Color(uiColor: .systemBackground)
        #endif
    }
}

// MARK: - Row frame measurement

private struct RowFramePreference: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect],
                       nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct RowFrameReader: View {
    let index: Int
    let space: String

    var body: some View {
        GeometryReader { geo in
            SwiftUI.Color.clear.preference(
                key: RowFramePreference.self,
                value: [index: geo.frame(in: .named(space))]
            )
        }
    }
}

// MARK: - Reorder gesture

/// The one behavioural difference between the platforms: macOS starts a drag
/// on movement, iOS on a long press (a bare drag would be eaten by the scroll
/// view — the failure mode the spec names).
private struct ReorderGesture: ViewModifier {
    let isArmed: () -> Bool
    let begin: () -> Void
    let arm: () -> Void
    let update: (CGSize, CGFloat) -> Void
    let end: () -> Void
    let select: () -> Void

    private static let space = "outlineList"
    /// Finger slop below which a lift counts as a tap, not a drag.
    private static let tapSlop: CGFloat = 10
    /// Hold required before a row lifts.
    private static let holdDuration: TimeInterval = 0.28

    /// iOS hold tracking. The hold is timed here rather than delegated to a
    /// `LongPressGesture` — see the comment in `body`.
    @State private var touchDown = false
    @State private var strayed = false
    @State private var holdToken = 0

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onTapGesture { select() }
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        begin()
                        update(value.translation, value.location.y)
                    }
                    .onEnded { _ in end() }
            )
        #else
        // ONE recogniser. Hold, drag and tap are all decided inside a single
        // zero-distance DragGesture, and the hold is timed by hand.
        //
        // Two earlier shapes both failed, for opposite reasons:
        //
        //  1. `LongPressGesture.sequenced(before: DragGesture)` never delivered
        //     `onEnded` when the finger lifted without a qualifying drag, so a
        //     lift could be armed and never released — the row stayed blue and
        //     every later drag was refused.
        //  2. A `LongPressGesture` running *alongside* a zero-distance drag is
        //     a race: the drag recognises on touch-down and can cancel the
        //     press. That is why the lift worked at first and then stopped —
        //     nothing had changed except which recogniser won.
        //
        // A zero-distance drag reports touch-down, movement and lift, which is
        // everything needed. Timing the hold here means no second recogniser
        // exists to lose a race against.
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                .onChanged { value in
                    let travel = max(abs(value.translation.width),
                                     abs(value.translation.height))
                    if travel > Self.tapSlop { strayed = true }

                    if !touchDown {
                        touchDown = true
                        strayed = travel > Self.tapSlop
                        holdToken &+= 1
                        let token = holdToken
                        // Arms only if this same touch is still down and has
                        // stayed put. A finger that moved first is a scroll.
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + Self.holdDuration
                        ) {
                            guard token == holdToken, touchDown, !strayed else {
                                return
                            }
                            arm()
                        }
                    }
                    update(value.translation, value.location.y)
                }
                .onEnded { _ in
                    touchDown = false
                    holdToken &+= 1          // cancels a hold still pending
                    let wasArmed = isArmed()
                    end()
                    if !wasArmed && !strayed { select() }
                    strayed = false
                }
        )
        #endif
    }
}

// MARK: - HeadingRow

private struct HeadingRow: View {
    let node: OutlineNode
    let depth: Int
    let isLead: Bool
    let travelling: Bool
    let hovered: Bool
    let landing: Bool
    let groupCount: Int
    let subsectionCount: Int

    var body: some View {
        HStack(spacing: 8) {
            rail
            marker

            Text(display)
                .font(fontForLevel)
                .foregroundStyle(SwiftUI.Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if isLead && groupCount > 1 {
                countPill("\(groupCount)", filled: true)
            } else if subsectionCount > 0 && hovered {
                countPill("\(subsectionCount)", filled: false)
            }

            #if os(macOS)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(hovered || travelling ? 1 : 0)
            #endif
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    travelling ? SwiftUI.Color.accentColor.opacity(0.55)
                               : SwiftUI.Color.clear,
                    lineWidth: 1
                )
        )
        .shadow(color: SwiftUI.Color.black.opacity(travelling ? 0.22 : 0),
                radius: travelling ? 10 : 0, y: travelling ? 5 : 0)
        #if os(macOS)
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        #endif
    }

    /// A lifted card floats over rows that have not moved, so it must be
    /// **opaque** — a translucent tint let the list read straight through the
    /// travelling section and the two collided.
    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        if travelling {
            ZStack {
                shape.fill(OutlineSurface.color)
                shape.fill(SwiftUI.Color.accentColor.opacity(0.14))
            }
        } else {
            shape.fill(fillColor)
        }
    }

    private var fillColor: SwiftUI.Color {
        if landing { return SwiftUI.Color.accentColor.opacity(0.22) }
        if hovered { return SwiftUI.Color.primary.opacity(0.06) }
        return SwiftUI.Color.clear
    }

    /// Ancestor guides. Depth is carried by hairlines rather than blank space,
    /// so a level-4 heading still reads as belonging to something.
    private var rail: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< max(0, min(depth, 6) - 1), id: \.self) { _ in
                Rectangle()
                    .fill(SwiftUI.Color.primary.opacity(0.10))
                    .frame(width: 1)
                    .frame(width: 14, alignment: .leading)
            }
        }
        .frame(height: 16)
    }

    /// Level mark: solid and large for H1, hollow and small further down.
    private var marker: some View {
        Group {
            switch depth {
            case 1:
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(SwiftUI.Color.accentColor)
                    .frame(width: 3, height: 13)
            case 2:
                Circle()
                    .fill(SwiftUI.Color.accentColor.opacity(0.75))
                    .frame(width: 5, height: 5)
            default:
                Circle()
                    .strokeBorder(SwiftUI.Color.secondary.opacity(0.55), lineWidth: 1)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 6)
    }

    private func countPill(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(filled ? SwiftUI.Color.white : SwiftUI.Color.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(filled ? SwiftUI.Color.accentColor
                                      : SwiftUI.Color.primary.opacity(0.08))
            )
    }

    private var display: String {
        node.heading.text.isEmpty ? "(empty)" : node.heading.text
    }

    private var fontForLevel: Font {
        switch depth {
        case 1: return .system(.body, weight: .semibold)
        case 2: return .system(.callout, weight: .medium)
        case 3: return .system(.callout)
        default: return .system(.footnote)
        }
    }
}
