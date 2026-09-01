import SwiftUI

/// Collapsible right-hand panel: the open document's diagnostics from the
/// rules engine (specs/problems-panel.md). Grouped by severity, engine order
/// preserved within each group; clicking a row scrolls the editor to the
/// finding and leaves the panel open, so the writer can work through the
/// list. Re-runs the engine on appearance and via the refresh button; the
/// AppState triggers (open, save) cover the rest (criterion 2).
///
/// D16-untestable by design: everything testable lives in Core
/// (KitibRules, FrontmatterMetadata, Diagnostic+Navigation). This file is
/// arrangement only.
struct ProblemsPanel: View {
    @ObservedObject var state: AppState

    /// Overrides the header's close action. The side panel (macOS/iPad)
    /// leaves this nil and hides via the toolbar toggle; the iPhone sheet
    /// uses it to dismiss (TodoPanel pattern).
    var onClose: (() -> Void)? = nil

    private var groups: [ProblemGroup] {
        let order: [(DiagnosticSeverity, Int)] = [(.error, 0), (.warning, 1), (.info, 2)]
        return order.compactMap { severity, displayOrder in
            let items = state.problems.filter { $0.severity == severity }
            return items.isEmpty ? nil
                : ProblemGroup(displayOrder: displayOrder, severity: severity, diagnostics: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if state.problems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(groups) { group in
                            HStack(spacing: 6) {
                                Image(systemName: SeverityStyle.icon(group.severity))
                                    .font(.system(size: 9))
                                    .foregroundStyle(SeverityStyle.color(group.severity))
                                Text("\(SeverityStyle.title(group.severity)) (\(group.diagnostics.count))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 6)
                            .padding(.top, 6)

                            VStack(spacing: 0) {
                                ForEach(Array(group.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                                    ProblemRow(diagnostic: diagnostic, documentText: state.text) {
                                        jump(to: diagnostic)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .onAppear { state.evaluateProblems() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Problems")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if !state.problems.isEmpty {
                Text("\(state.problems.count)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                state.evaluateProblems()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: Metrics.hit, height: Metrics.hit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Re-run the checks")

            if let onClose {
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .frame(width: Metrics.hit, height: Metrics.hit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Hide problems panel")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Metrics.touch ? 2 : 8)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No problems")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func jump(to diagnostic: Diagnostic) {
        guard let ns = diagnostic.nsRange(in: state.text) else { return }
        state.scrollToHeading?(ns)
    }
}

// MARK: - Grouping

/// One severity bucket in display order. The engine's deterministic sort is
/// the only order ever used; the panel filters, never sorts (criterion 1).
private struct ProblemGroup: Identifiable {
    let displayOrder: Int
    let severity: DiagnosticSeverity
    let diagnostics: [Diagnostic]
    var id: Int { displayOrder }
}

// MARK: - Severity presentation

/// Severity to icon/colour/title mapping. Presentation only; the severity
/// values themselves come from Core unchanged.
private enum SeverityStyle {
    static func icon(_ severity: DiagnosticSeverity) -> String {
        switch severity {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle"
        }
    }

    static func color(_ severity: DiagnosticSeverity) -> SwiftUI.Color {
        // SwiftUI.Color spelled out: Vendor/SwiftTerm declares its own Color
        // and an unqualified `Color.red` resolves to its UInt16 RGB
        // component (D50).
        switch severity {
        case .error: .red
        case .warning: .orange
        case .info: .secondary
        }
    }

    static func title(_ severity: DiagnosticSeverity) -> String {
        switch severity {
        case .error: "Errors"
        case .warning: "Warnings"
        case .info: "Info"
        }
    }
}

// MARK: - Row

private struct ProblemRow: View {
    let diagnostic: Diagnostic
    let documentText: String
    let onJump: () -> Void

    var body: some View {
        Button(action: onJump) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: SeverityStyle.icon(diagnostic.severity))
                    .font(.system(size: 10))
                    .foregroundStyle(SeverityStyle.color(diagnostic.severity))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(diagnostic.message)
                        .font(.system(size: Metrics.text))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(diagnostic.ruleID) · line \(diagnostic.lineNumber(in: documentText))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, Metrics.rowPad)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Scroll to this problem")
    }
}

// MARK: - Platform metrics

/// Same convention as TodoPanel: Mac is dense (pointer), iOS needs touch
/// targets. The branching lives in one place.
private enum Metrics {
    #if os(iOS)
    static let touch = true
    static let hit: CGFloat = 44
    static let text: CGFloat = 15
    static let rowPad: CGFloat = 4
    #else
    static let touch = false
    static let hit: CGFloat = 18
    static let text: CGFloat = 12
    static let rowPad: CGFloat = 4
    #endif
}
