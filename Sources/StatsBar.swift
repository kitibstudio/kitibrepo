import SwiftUI

struct Stats {
    let words: Int
    let characters: Int
    let lines: Int
    let paragraphs: Int
    let readingMinutes: Double

    init(text: String) {
        characters = text.count
        words = text.split { $0.isWhitespace || $0.isNewline }.count
        lines = text.isEmpty ? 0 : text.components(separatedBy: "\n").count
        paragraphs = text
            .components(separatedBy: "\n")
            .split(whereSeparator: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            .count
        readingMinutes = Double(words) / 230.0
    }

    var readingTimeLabel: String {
        if words == 0 { return "—" }
        if readingMinutes < 1 { return "<1 min read" }
        return "\(Int(readingMinutes.rounded())) min read"
    }
}

struct StatsBar: View {
    @ObservedObject var state: AppState
    @State private var goalField = ""
    @State private var showGoalPopover = false

    // Goal-celebration state. We remember the previous word count so a burst
    // fires exactly when the count steps from below the goal to at/above it.
    // The burst itself is hosted by ContentView (above the AppKit editor); we
    // only bump the shared counter here.
    @State private var lastWords = -1

    var body: some View {
        let stats = Stats(text: state.text)

        HStack(spacing: 16) {
            statItem("\(stats.words)", "words")
            statItem("\(stats.characters)", "chars")
            statItem("\(stats.lines)", "lines")
            statItem(stats.readingTimeLabel, "")

            if state.selectionChars > 0 {
                Divider().frame(height: 11)
                selectionItem("\(state.selectionWords)", "words selected")
                selectionItem("\(state.selectionChars)", "chars selected")
            }

            Spacer()

            if state.wordGoal > 0 {
                let progress = min(1.0, Double(stats.words) / Double(state.wordGoal))
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 90)
                    Text("\(stats.words)/\(state.wordGoal)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(progress >= 1 ? Color.green : Color.secondary)
                }
            }

            Button {
                goalField = state.wordGoal > 0 ? String(state.wordGoal) : ""
                showGoalPopover = true
            } label: {
                Image(systemName: state.wordGoal > 0 ? "target" : "scope")
                    .foregroundStyle(state.wordGoal > 0 ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help("Word-count goal")
            .popover(isPresented: $showGoalPopover) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Word goal").font(.headline)
                    TextField("e.g. 1000", text: $goalField)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .onSubmit { applyGoal() }
                    HStack {
                        Button("Clear") {
                            state.setWordGoal(0)
                            showGoalPopover = false
                        }
                        Spacer()
                        Button("Set") { applyGoal() }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(14)
            }

            if state.isDirty {
                Circle().fill(Color.orange).frame(width: 7, height: 7)
                    .help("Unsaved changes (autosaves)")
            } else if state.currentFileURL != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green.opacity(0.7))
                    .help("Saved")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.bar)
        .onAppear { lastWords = stats.words }
        .onChange(of: stats.words) { newWords in checkGoal(words: newWords) }
        .onChange(of: state.wordGoal) { _ in lastWords = stats.words }
        .onChange(of: state.selectedFileID) { _ in lastWords = stats.words }
    }

    private func applyGoal() {
        state.setWordGoal(Int(goalField) ?? 0)
        showGoalPopover = false
    }

    /// Fire a burst the moment the count steps from below the goal to at/above
    /// it. Comparing against the previous count (rather than an armed flag)
    /// means opening a finished document or lowering the goal never celebrates,
    /// while genuinely crossing the line always does. Re-crosses re-fire.
    private func checkGoal(words: Int) {
        defer { lastWords = words }
        guard state.celebrateGoal, state.wordGoal > 0, lastWords >= 0 else { return }
        if lastWords < state.wordGoal && words >= state.wordGoal {
            state.goalCelebration += 1
        }
    }

    private func statItem(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.system(size: 11, weight: .semibold).monospacedDigit())
            if !label.isEmpty {
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    /// Selection readout — tinted with the accent colour so it reads as a live,
    /// transient value distinct from the document totals on the left.
    private func selectionItem(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.system(size: 11, weight: .semibold).monospacedDigit())
            Text(label).font(.system(size: 11))
        }
        .foregroundStyle(Color.accentColor)
    }
}
