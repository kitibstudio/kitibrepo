import SwiftUI
import AppKit
import SwiftTerm

// MARK: - Terminal session

/// A real terminal (vendored SwiftTerm, xterm-class emulation) running your
/// login zsh in a PTY — Claude CLI, vim, colors, and arrow keys all work.
/// The underlying NSView lives here, owned by AppState, so hiding the panel
/// keeps the shell and its scrollback alive.
final class TerminalSession: NSObject, ObservableObject, LocalProcessTerminalViewDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var title: String = "Terminal"
    private(set) var workingDirectory: URL?
    private(set) var view: LocalProcessTerminalView?

    /// Creates (or reuses) the terminal view, with the shell started in `directory`.
    @discardableResult
    func start(in directory: URL) -> LocalProcessTerminalView {
        if let existing = view, isRunning { return existing }

        let tv = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
        tv.processDelegate = self
        view = tv
        applyColors(to: tv, appearance: NSApp.effectiveAppearance)
        workingDirectory = directory
        title = directory.lastPathComponent

        // User's login + interactive zsh, so ~/.zprofile and ~/.zshrc load
        // (PATH, aliases — and CLI tools like `claude`) just like Terminal.app.
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        let envArray = env.map { "\($0.key)=\($0.value)" }

        tv.startProcess(
            executable: shell,
            args: ["-i", "-l"],
            environment: envArray,
            execName: nil,
            currentDirectory: directory.path
        )
        isRunning = true
        return tv
    }

    func changeDirectory(to directory: URL) {
        workingDirectory = directory
        title = directory.lastPathComponent
        guard isRunning, let tv = view else { return }
        let quoted = "'" + directory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        tv.send(txt: "cd \(quoted)\n")
    }

    func stop() {
        view?.terminate()
        view = nil
        isRunning = false
    }

    // MARK: Appearance

    /// Re-matches the terminal colors to the given appearance.
    /// Called when the host view's appearance changes — whether from the
    /// in-app Light/Dark setting (NSApp.appearance) or, in System mode,
    /// from macOS. The appearance is passed in by the caller because during
    /// an appearance transition the terminal view's own `effectiveAppearance`
    /// may not be updated yet (AppKit updates views one at a time).
    func syncColors(appearance: NSAppearance) {
        guard let tv = view else { return }
        applyColors(to: tv, appearance: appearance)
    }

    private func applyColors(to tv: LocalProcessTerminalView, appearance: NSAppearance) {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            tv.nativeForegroundColor = NSColor(white: 0.92, alpha: 1)
            tv.nativeBackgroundColor = NSColor(white: 0.08, alpha: 1)
            tv.caretColor = NSColor(white: 0.80, alpha: 1)
        } else {
            tv.nativeForegroundColor = NSColor(white: 0.10, alpha: 1)
            tv.nativeBackgroundColor = .white
            tv.caretColor = NSColor(white: 0.30, alpha: 1)
        }
        // colorsChanged() only dirties the character rows; repaint everything
        // so the area below the last row picks up the new background too.
        tv.needsDisplay = true
    }

    // MARK: LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async { [weak self] in
            if !title.isEmpty { self?.title = title }
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        if let directory, let url = URL(string: directory), url.isFileURL {
            workingDirectory = URL(fileURLWithPath: url.path)
        }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
            self?.view?.feed(text: "\r\n[shell exited — reopen the terminal to restart]\r\n")
        }
    }
}

// MARK: - SwiftUI host for the terminal NSView

/// Container that notifies when its effective appearance changes, so the
/// terminal can be recolored for light/dark/system switches.
private final class AppearanceTrackingView: NSView {
    var onAppearanceChange: ((NSAppearance) -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Our own effectiveAppearance is guaranteed current inside this
        // callback; the terminal subview's may still be stale.
        onAppearanceChange?(effectiveAppearance)
    }
}

private struct TerminalHostView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = AppearanceTrackingView()
        container.onAppearanceChange = { [weak session] appearance in
            session?.syncColors(appearance: appearance)
        }
        if let tv = session.view {
            embed(tv, in: container)
        }
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if let tv = session.view, tv.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            embed(tv, in: container)
        }
        session.syncColors(appearance: container.effectiveAppearance)
    }

    private func embed(_ tv: LocalProcessTerminalView, in container: NSView) {
        tv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tv)
        NSLayoutConstraint.activate([
            tv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tv.topAnchor.constraint(equalTo: container.topAnchor),
            tv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
        }
    }
}

// MARK: - Terminal panel (header + terminal)

struct TerminalPanel: View {
    @ObservedObject var state: AppState
    @ObservedObject var session: TerminalSession

    init(state: AppState) {
        self.state = state
        self.session = state.terminal
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(session.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !session.isRunning {
                    Text("— stopped")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    state.showTerminal = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Hide terminal (⌃`) — the shell keeps running")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            TerminalHostView(session: session)
        }
    }
}
