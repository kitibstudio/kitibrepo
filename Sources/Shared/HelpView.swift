import SwiftUI

/// The Help window: one search field over three lanes.
///
/// The content is not here — it is `HelpContent` in `Core`, because
/// `Sources/Shared` is outside the test bundle (D16) and help text that nobody
/// can assert on is help text that quietly goes wrong (D64). This file is
/// presentation only: what is written, and whether it is true, is settled by
/// `HelpContentTests`.
///
/// Sizing is deliberately absent. macOS wraps this in `resizableSheet` and iOS
/// in detents, at the presentation site in `ContentView` (D49).
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query: String
    /// `nil` means "every lane" — what a search switches to, since a reader
    /// who does not know where an answer lives cannot pick the lane first.
    @State private var lane: HelpLane?
    @State private var expanded: Set<String>
    @State private var copiedID: String?
    @State private var wasSearching: Bool
    @FocusState private var searchFocused: Bool

    /// The defaults are the real starting state. The parameters exist so a
    /// render check can put the view into any state without a `sed` copy
    /// drifting from this source (ui-conventions §1.1).
    init(previewQuery: String = "", previewLane: HelpLane? = .cheatsheet, previewExpanded: Set<String> = []) {
        _query = State(initialValue: previewQuery)
        // Honoured as given: the widening to "All" is what *typing* does, via
        // onChange. Deriving it here instead made the lane-with-no-hits state
        // unreachable from a render check, which is how it went unlooked-at.
        _lane = State(initialValue: previewLane)
        _expanded = State(initialValue: previewExpanded)
        _wasSearching = State(initialValue: !previewQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Derived state

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var isSearching: Bool { !trimmedQuery.isEmpty }

    /// Hits in every lane, ranked. Also the resting content when nothing is typed.
    private var matches: [HelpEntry] { HelpSearch.results(for: query) }

    /// What the chosen lane actually shows.
    private var visible: [HelpEntry] {
        guard let lane else { return matches }
        return matches.filter { $0.lane == lane }
    }

    private var laneCounts: [HelpLane: Int] {
        isSearching ? HelpSearch.laneCounts(for: query) : [:]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onChange(of: query) { new in
            let searchingNow = !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            // Typing widens to every lane once; clearing returns to browsing.
            // Only on the transition, so a reader can still narrow mid-search.
            if searchingNow, !wasSearching { lane = nil }
            if !searchingNow, wasSearching { lane = .cheatsheet }
            wasSearching = searchingNow
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Help")
                    .font(.title2.bold())
                Text("\(HelpContent.all.count) entries")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            searchField
            laneChips
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search help — a feature, a symbol, or what you are trying to do", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit { searchFocused = false }
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif

            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SwiftUI.Color.primary.opacity(0.06))
        )
        .onAppear { searchFocused = true }
    }

    /// Scrolls rather than truncates. Four chips do not fit an iPhone width, and
    /// a lane labelled "Ch…" is a lane the reader cannot identify.
    private var laneChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "All", symbol: "square.grid.2x2", lane: nil,
                     count: isSearching ? matches.count : nil)
                ForEach(HelpLane.allCases) { candidate in
                    chip(title: candidate.title, symbol: candidate.symbol, lane: candidate,
                         count: isSearching ? (laneCounts[candidate] ?? 0) : nil)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 1)
        }
    }

    private func chip(title: String, symbol: String, lane candidate: HelpLane?, count: Int?) -> some View {
        let selected = lane == candidate
        // A lane with no hits stays visible but recedes — it is information
        // ("the answer is not there"), not a control worth reaching for.
        let empty = (count ?? 1) == 0

        return Button {
            lane = candidate
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .fixedSize()
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(SwiftUI.Color.primary.opacity(selected ? 0.18 : 0.09)))
                }
            }
            .foregroundStyle(selected ? AnyShapeStyle(SwiftUI.Color.accentColor) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
            .opacity(empty && !selected ? 0.45 : 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(SwiftUI.Color.accentColor.opacity(selected ? 0.14 : 0))
            )
            .overlay(
                Capsule().stroke(SwiftUI.Color.primary.opacity(selected ? 0 : 0.12), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if visible.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !isSearching, let lane {
                        Text(lane.blurb)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 2)
                    }

                    if lane == nil {
                        // Grouped, so a result carries where it came from without
                        // the reader having to have chosen that lane first.
                        ForEach(HelpLane.allCases) { group in
                            let rows = visible.filter { $0.lane == group }
                            if !rows.isEmpty {
                                groupHeader(group, count: rows.count)
                                ForEach(rows) { entry in row(entry) }
                            }
                        }
                    } else {
                        ForEach(visible) { entry in row(entry) }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func groupHeader(_ lane: HelpLane, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: lane.symbol).font(.system(size: 10))
            Text(lane.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
            Text("\(count)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func row(_ entry: HelpEntry) -> some View {
        switch entry.lane {
        case .shortcuts: shortcutRow(entry)
        case .cheatsheet: card(entry, collapsible: false)
        case .guides: card(entry, collapsible: true)
        }
    }

    // MARK: - Rows

    private func shortcutRow(_ entry: HelpEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(entry.shortcut ?? "")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(SwiftUI.Color.primary.opacity(0.07))
                )
                .frame(width: 96, alignment: .leading)
            Text(entry.title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// A cheatsheet entry or a guide. Guides collapse, because a guide is long
    /// by design and fifteen of them open at once is the wall this window
    /// replaced. Searching expands them: a hit the reader cannot see is a miss.
    private func card(_ entry: HelpEntry, collapsible: Bool) -> some View {
        let open = !collapsible || isSearching || expanded.contains(entry.id)

        return VStack(alignment: .leading, spacing: 9) {
            Button {
                guard collapsible, !isSearching else { return }
                if expanded.contains(entry.id) { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.system(size: 13, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(entry.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if collapsible {
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(collapsible ? .isButton : [])

            if open {
                if !entry.steps.isEmpty { steps(entry.steps) }
                if let example = entry.example { exampleBlock(example, id: entry.id) }
                if let note = entry.note { noteBlock(note) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SwiftUI.Color.primary.opacity(0.035))
        )
    }

    private func steps(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 9) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SwiftUI.Color.accentColor)
                        .frame(width: 17, height: 17)
                        .background(Circle().fill(SwiftUI.Color.accentColor.opacity(0.13)))
                    Text(step)
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func exampleBlock(_ example: HelpExample, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Scrolls sideways instead of wrapping. A wrapped example is not
            // just ugly: the table example's trailing pipe fell to the next
            // line at iPhone width, so the entry teaching what a correct table
            // looks like displayed a broken one.
            ZStack(alignment: .topTrailing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(example.code)
                        .font(.system(size: 11.5, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize()
                        // Room for the copy button in its corner: an overlay
                        // must not land on the text it belongs to.
                        .padding(.trailing, 62)
                        .padding(10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(SwiftUI.Color.primary.opacity(0.055))
                )

                copyButton(example.code, id: id)
            }

            if let renders = example.renders {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 9))
                    Text(renders)
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    private func copyButton(_ code: String, id: String) -> some View {
        let done = copiedID == id
        return Button {
            Platform.copy(code)
            copiedID = id
            // Cleared only if this is still the button that was pressed, so a
            // second copy elsewhere does not wipe the newer confirmation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if copiedID == id { copiedID = nil }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: done ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9, weight: .medium))
                Text(done ? "Copied" : "Copy")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(done ? AnyShapeStyle(SwiftUI.Color.green) : AnyShapeStyle(SwiftUI.Color.accentColor))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(4)
        .accessibilityLabel(done ? "Copied" : "Copy example")
    }

    /// The catch. Carried on a rail rather than by indentation alone, so it
    /// still reads as attached to its entry (ui-conventions §5).
    private func noteBlock(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(SwiftUI.Color.accentColor.opacity(0.35))
                .frame(width: 2)
            Text(note)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Nothing found

    /// Three different nothings, and they must not look alike (D64): the answer
    /// is in another lane; you mistyped; or the app does not do this.
    @ViewBuilder
    private var emptyState: some View {
        let elsewhere = matches.count
        let suggestions = HelpSearch.suggestions(for: query)

        VStack(spacing: 10) {
            Image(systemName: elsewhere > 0 ? "arrow.left.arrow.right" : "questionmark.circle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)

            if elsewhere > 0, let lane {
                Text("Nothing about “\(trimmedQuery)” in \(lane.title).")
                    .font(.system(size: 13, weight: .medium))
                Text("\(elsewhere) match\(elsewhere == 1 ? "" : "es") in the other sections.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button("Show all matches") { self.lane = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(SwiftUI.Color.accentColor)
                    .font(.system(size: 12, weight: .medium))
            } else if !suggestions.isEmpty {
                Text("Nothing matches “\(trimmedQuery)”.")
                    .font(.system(size: 13, weight: .medium))
                Text("Did you mean:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { term in
                        Button {
                            query = term
                            lane = nil
                        } label: {
                            Text(term)
                                .font(.system(size: 12))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(SwiftUI.Color.accentColor.opacity(0.12)))
                                .foregroundStyle(SwiftUI.Color.accentColor)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Nothing matches “\(trimmedQuery)”.")
                    .font(.system(size: 13, weight: .medium))
                // Said plainly, because the alternative is a reader hunting for
                // a feature that is not there.
                Text("Kitib may not do this — everything it does is listed here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Clear search") {
                    query = ""
                    searchFocused = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(SwiftUI.Color.accentColor)
                .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
